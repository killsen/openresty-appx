
-- OCSP: 在线证书状态协议
-- https://help.trustasia.com/what-is-ocsp/

local ngx           = ngx
local ocsp          = require "ngx.ocsp"
local _request      = require "app.utils.request"
local sslx          = require "app.comm.sslx"

local __ = { }

--------------------------------------------------------------------------------

-- 下载OCSP
__.get_ocsp_resp = function (domain_name, cert_der)

    if not domain_name or not cert_der then return end

    local ocsp_url, err = ocsp.get_ocsp_responder_from_der_chain(cert_der)
    if not ocsp_url then
        ngx.log(ngx.ERR, "failed to get ocsp responder: ", err)
        return
    end

    local ocsp_req, err = ocsp.create_ocsp_request(cert_der)
    if not ocsp_req then
        ngx.log(ngx.ERR, "failed to create ocsp request: ", err)
        return
    end

               ngx.update_time()
    local t1 = ngx.now() * 1000

    local res, err = _request(ocsp_url, {
        method = "POST",
        body = ocsp_req,
        headers = {
            ["Content-Type"] = "application/ocsp-request",
        }
    })

               ngx.update_time()
    local t2 = ngx.now() * 1000

    if not res then
        ngx.log(ngx.ERR, "failed to request ocsp url: ", err)
        return
    end

    if res.status ~= 200 then
        ngx.log(ngx.ERR, "OCSP responder returns bad HTTP status code: ", res.status)
        return
    end

    local ocsp_resp = res.body
    if not ocsp_resp or ocsp_resp=="" then
        ngx.log(ngx.ERR, "OCSP responder returns no body")
        return
    end

    ngx.log(ngx.ERR, "\n"
                   , "\n", " get ocsp response success: "
                   , "\n", " ------------------------------------------------- "
                   , "\n", " domain  name  :  ", domain_name
                   , "\n", " request url   :  ", ocsp_url
                   , "\n", " request time  :  ", t2 - t1
                   , "\n", " ------------------------------------------------- "
                   , "\n"
                   , "\n")

    return ocsp_resp

end

-- 加载OCSP
__.load_ocsp = function (domain_name)

    if not domain_name then return end

    local d = sslx.domain.get_domain(domain_name)
    if not d or not d.cert_der then return end

    if not d.ocsp_resp then
        d.ocsp_resp = __.get_ocsp_resp(d.domain_name, d.cert_der)
        return
    end

    -- 检查OCSP
    local ok = ocsp.validate_ocsp_response(d.ocsp_resp, d.cert_der)
    if not ok then
        d.ocsp_resp = __.get_ocsp_resp(d.domain_name, d.cert_der)
    end

end

local is_started = false
local is_running = false

-- 执行任务
local function run_tasks(premature)
    if premature  then return end
    if is_running then return end
    is_running = true

    local domains = sslx.domain.load_domains()

    for _, d in ipairs(domains) do
        __.load_ocsp(d.domain_name)
    end

    is_running = false
end

-- 开启自动更新OCSP任务
__.run_tasks = function()
    if is_started then return end
       is_started = true

    -- 每个 worker 都要执行任务
    -- if ngx.worker.id() ~= 0 then return end

    ngx.log(ngx.ERR, "sslx.ocsp.run_tasks")

    ngx.timer.at   ( 0, run_tasks)  -- 初次加载
    ngx.timer.every(60, run_tasks)  -- 每1分钟检查一次

end

--------------------------------------------------------------------------------
return __
