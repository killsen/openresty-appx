
-- 动态加载证书 v20.08.24

local ngx           = ngx
local cjson         = require "cjson.safe"
local ssl           = require "ngx.ssl"
local ocsp          = require "ngx.ocsp"
local mlcache       = require "resty.mlcache"
local get_request   = require "resty.core.base".get_request

local _request      = require "app.utils.request"
local _open         = io.open
local _timer_at     = ngx.timer.at
local _timer_every  = ngx.timer.every
local prefix        = ngx.config.prefix()

local __ = { _VERSION = "v20.08.24" }

--------------------------------------------------------------------------------

local cache = mlcache.new("my_cache", "my_cache", {
        lru_size    = 100   -- 本地缓存数量: 100条
    ,   ttl         = 3600  -- 数据缓存时间: 60分钟
    ,   neg_ttl     = 10    -- 空值缓存时间: 10秒钟

    ,   shm_locks   = "my_locks"   -- 存储锁
    ,   shm_miss    = "my_miss"    -- 存储空值
    ,   ipc_shm     = "my_ipc"     -- 进程间通信
})

-- 读取文件
local function read_file(file_name)

    if not file_name then return end

    local  file = _open(prefix .. "/conf/cert/" .. file_name, "rb")
    if not file then return end

    local  data = file:read("*a")
                  file:close()
    if not data then return end

    return data

end

-- 加载服务器（域名）
local SERVER_LIST
local function load_servers()

    if SERVER_LIST then return SERVER_LIST end

    local servers = {}

    local text = read_file("domain.json")
    if not text then return servers end

    local domains = cjson.decode(text)
    if type(domains) ~= "table" then return servers end

    for _, d in ipairs(domains) do
        if type(d) == "table" and type(d.domain_name) == "string" and d.domain_name ~= "" then
            table.insert(servers, d.domain_name)
            servers[d.domain_name] = d.domain_name
        end
    end

    SERVER_LIST = servers

    return servers

end

-- 取得证书
local function get_cert_der(server_name)

    if not server_name then return end

    local file_crt = server_name .. "-crt.pem"
    local cert_pem = read_file(file_crt)
    if not cert_pem then
        ngx.log(ngx.ERR, "failed to get PEM cert: ", file_crt)
        return
    end

    local cert_der, err = ssl.cert_pem_to_der(cert_pem)
    if not cert_der then
        ngx.log(ngx.ERR, "failed to get DER cert: ", err)
        return
    end

    return cert_der

end

-- 取得秘钥
local function get_pkey_der(server_name)

    if not server_name then return end

    local file_key = server_name .. "-key.pem"
    local pkey_pem = read_file(file_key)
    if not pkey_pem then
        ngx.log(ngx.ERR, "failed to get PEM cert: ", file_key)
        return
    end

    local pkey_der, err = ssl.priv_key_pem_to_der(pkey_pem)
    if not pkey_der then
        ngx.log(ngx.ERR, "failed to get DER pkey: ", err)
        return
    end

    return pkey_der

end

-- 下载OCSP
local function get_ocsp_resp(server_name, cert_der)

    if not server_name or not cert_der then return end

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
                   , "\n", " server  name  :  ", server_name
                   , "\n", " request url   :  ", ocsp_url
                   , "\n", " request time  :  ", t2 - t1
                   , "\n", " ------------------------------------------------- "
                   , "\n"
                   , "\n")

    return ocsp_resp

end

-- 设置OCSP
local function set_ocsp_resp(server_name, cert_der)

    if not server_name or not cert_der then return end

    local key = "ocsp/" .. server_name
    local _, _, ocsp_resp = cache:peek(key)

    if not ocsp_resp then return end

    -- 检查OCSP
    local ok, err = ocsp.validate_ocsp_response(ocsp_resp, cert_der)
    if not ok then
        cache:delete(key)
        ngx.log(ngx.ERR, "failed to validate ocsp response: ", err)
        return
    end

    -- 设置OCSP
    local ok, err = ocsp.set_ocsp_status_resp(ocsp_resp)
    if not ok then
        cache:delete(key)
        ngx.log(ngx.ERR, "failed to set ocsp status response: ", err)
        return
    end

end

-- 加载OCSP
__.load_ocsp = function (server_name, reload)

    if not server_name then return end

    local cert = __.load_cert(server_name)
    if not cert then return end

    local cert_der = cert.cert_der

    local key = "ocsp/" .. server_name
    if reload then cache:delete(key) end

    local ocsp_resp = cache:get(key, nil, function()

        local ocsp_resp = get_ocsp_resp(server_name, cert_der)

        if not ocsp_resp then
            return nil, nil, 10  -- 缓存 10 秒
        else
            return ocsp_resp, nil, 24 * 60 * 60  -- 缓存一天
        end

    end)

    if ocsp_resp then
        -- 检查OCSP
        local ok, err = ocsp.validate_ocsp_response(ocsp_resp, cert_der)
        if not ok then
            cache:delete(key)
            ngx.log(ngx.ERR, "failed to validate ocsp response: ", err)
            ocsp_resp = nil
        end
    end

    return ocsp_resp

end

-- 加载证书及秘钥
__.load_cert = function (server_name, reload)

    if not server_name then return end

    local key = "cert/" .. server_name
    if reload then cache:delete(key) end

    return cache:get(key, nil, function()

        local cert_der = get_cert_der(server_name)
        if not cert_der then return nil, nil, 10 end  -- 缓存 10 秒

        local pkey_der = get_pkey_der(server_name)
        if not pkey_der then return nil, nil, 10 end  -- 缓存 10 秒

        return {
            cert_der = cert_der,
            pkey_der = pkey_der
        }, nil, 24 * 60 * 60  -- 缓存一天

    end)

end

-- 获取域名
local function get_server_name()

    local server_name = ssl.server_name()
    if not server_name then return end

    local servers = load_servers()
    if #servers == 0 then return end

    local domain_name = servers[server_name]
    if domain_name then return domain_name end
    if domain_name == false then return end

    servers[server_name] = false

    for _, name in ipairs(servers) do
        if string.sub(server_name, 0-#name) == name then
            servers[server_name] = name
            return name
        end
    end

end

-- 动态加载证书和秘钥以及OCSP
__.set_cert = function ()

    -- 检查请求
    local req = get_request()
    if not req then return end

    local server_name = get_server_name()
    if not server_name then return end

    -- 取得证书及秘钥
    local cert = __.load_cert(server_name)
    if not cert then return end

    local cert_der = cert.cert_der  -- 证书
    local pkey_der = cert.pkey_der  -- 秘钥

    -- 清除之前设置的证书和私钥
    local ok, err = ssl.clear_certs()
    if not ok then
        ngx.log(ngx.ERR, "failed to clear certs: ", err)
        return
    end

    -- 设置证书
    local ok, err = ssl.set_der_cert(cert_der)
    if not ok then
        ngx.log(ngx.ERR, "failed to set DER cert: ", err)
        return
    end

    -- 设置秘钥
    local ok, err = ssl.set_der_priv_key(pkey_der)
    if not ok then
        ngx.log(ngx.ERR, "failed to set DER pkey: ", err)
        return
    end

    -- 设置OCSP
    set_ocsp_resp(server_name, cert_der)

end

--------------------------------------------------------------------------------

-- 更新缓存
local function update_cache(premature)

    -- 定时器已过期
    if premature then return end

    -- 更新缓存
    cache:update()

end

-- 更新服务器OCSP
local function update_ocsp(premature, servers)

    -- 定时器已过期
    if premature then return end

    for _, server_name in ipairs(servers) do
        local ocsp_resp = __.load_ocsp(server_name)
        if not ocsp_resp then
            __.load_ocsp(server_name, true)
        end
    end

end

-- 每5秒更新一次缓存
_timer_every(5, update_cache)

-- 只需第一个 worker 负责
if ngx.worker.id() == 0 then
    local servers = load_servers()
    if #servers > 0 then
        _timer_at   ( 0, update_ocsp, servers)  -- 初次加载
        _timer_every(60, update_ocsp, servers)  -- 每1分钟检查一次
    end
end

--------------------------------------------------------------------------------
return __
