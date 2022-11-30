
-- 域名基础知识
-- https://support.google.com/a/answer/2573637

local ngx               = ngx
local prefix            = ngx.config.prefix()
local cjson             = require "cjson.safe"
local _decode           = cjson.decode
local _open             = io.open
local _insert           = table.insert
local _sub              = string.sub

local cert_path         = prefix .. "/conf/cert/"
local cert_log          = prefix .. "/logs/cert.log"
local sslx              = require "app.comm.sslx"
local x509              = require "resty.openssl.x509"

local ngx_ssl           = require "ngx.ssl"
local cert_pem_to_der   = ngx_ssl.cert_pem_to_der
local pkey_pem_to_der   = ngx_ssl.priv_key_pem_to_der

local my_index          = ngx.shared.my_index
local my_key            = "sslx.domain.index"

local __ = { }

local DOMAINS, LAST_INDEX

-- 更新缓存 index
local function update_index()

    local index = ngx.now() * 1000
    return my_index:set(my_key, index)

end
__.update_index = update_index

-- 更新缓存: index 不一致清空缓存
local function update_cache()

    local index = my_index:get(my_key)
    if type(index) ~= "number" then
        index = 0
        my_index:set(my_key, index)
    end

    if LAST_INDEX ~= index then
        LAST_INDEX = index
        DOMAINS    = nil
    end

end

-- 读取文件
local function read_file(file_name)

    if not file_name then return end

    local  file = _open(cert_path .. file_name, "rb")
    if not file then return end

    local  data = file:read("*a")
                  file:close()
    if not data then return end

    return data

end

__.load_domains__ = {
    "加载域名定义列表",
    types = {
        DomainInfo = {
            { "domain_name"     , "待申请证书域名"              },
            { "dnspod_token"    , "dnspod登录凭证"              },
            { "issuance_time"   , "证书颁发日期"    , "number"  },
            { "expires_time"    , "证书截止日期"    , "number"  },
            { "cert_der?"       , "证书DER"                     },
            { "pkey_der?"       , "私钥DER"                     },
            { "ocsp_resp?"      , "在线证书状态"                },
        }
    },
    res = "@DomainInfo[]"
}
__.load_domains = function ()

    update_cache()  -- 更新缓存

    if DOMAINS then return DOMAINS end
       DOMAINS = {}

    local text = read_file("domains.json")
    if not text then return DOMAINS end

    -- @list : @DomainInfo[]
    local list = _decode(text)
    if type(list) ~= "table" then return DOMAINS end

    for _, d in ipairs(list) do
        if type(d) == "table" and type(d.domain_name) == "string" and d.domain_name ~= "" then

            local cert_pem = read_file(d.domain_name .. "-crt.pem")
            local pkey_pem = read_file(d.domain_name .. "-key.pem")

            d.cert_der = cert_pem and cert_pem_to_der(cert_pem) or nil
            d.pkey_der = pkey_pem and pkey_pem_to_der(pkey_pem) or nil

            local cert = cert_pem and x509.new(cert_pem)

            if type(d.dnspod_token) ~= "string" then
                d.dnspod_token = ""
            end

            if cert then
                d.issuance_time = cert:get_not_before()
                d.expires_time  = cert:get_not_after()
            else
                d.issuance_time = 0
                d.expires_time  = 0
            end

            _insert(DOMAINS, d)
            DOMAINS[d.domain_name] = d
        end
    end

    return DOMAINS

end

-- 获取域名信息
__.get_domain = function(server_name)
-- @return : @DomainInfo

    if type(server_name) ~= "string" then return end

    local domains = __.load_domains()
    if #domains == 0 then return end

    local domain = domains[server_name]
    if domain then return domain end
    if domain == false then return end

    domains[server_name] = false

    for _, d in ipairs(domains) do
        if _sub(server_name, 0 - #d.domain_name) == d.domain_name then
            domains[server_name] = d
            return d
        end
    end

end

-- 输出日志
local function _echo(...)
    local file = io.open(cert_log, "ab+")
    if not file then return end
    file:write(ngx.localtime(), "  ", ...)
    file:write("\n")
    file:close()
end

-- 等待几秒
local function _wait(msg, seconds)
    _echo(msg)
    ngx.sleep(seconds)
end

-- 获取需要申请证书的域名列表
local function get_domains_to_update()
-- @return : @DomainInfo[]

    local list  = {}

    local domains = __.load_domains()
    if #domains == 0 then return list end

    local expires_time = ngx.time() + 24*60*60*30 -- 30天后到期

    for _, d in ipairs(domains) do
        if d.expires_time < expires_time and d.dnspod_token ~= "" then
            _insert(list, d)
        end
    end

    return list

end

-- 升级证书: 证书不存在自动申请, 30天后到期自动延期
__.update_certs = function(is_tasks)

    local domains = get_domains_to_update()

    if #domains == 0 then
        if not is_tasks then _echo("暂无需要升级的证书") end
        return domains
    end

    _echo("共有 ", #domains, " 个域名需要申请证书")

    local updated

    for _, d in ipairs(domains) do
        _echo("-------------------------------------")
        local res, err = sslx.order.order_cert {
            domain_name     = d.domain_name,
            dnspod_token    = d.dnspod_token,
            debug_mode      = false,
            retry_times     = 10,
            echo            = _echo,
            wait            = _wait,
        }
        if res then -- 更新证书证书有效期
            d.issuance_time = res.issuance_time
            d.expires_time  = res.expires_time
            updated = true
        end
    end

    -- 更新缓存 index
    if updated then update_index() end

    return updated

end

local is_started = false
local is_running = false

-- 执行任务
local function run_tasks(premature, is_tasks)
    if premature  then return end
    if is_running then return end
    is_running = true

    __.update_certs(is_tasks)

    is_running = false
end

-- 开启自动升级证书任务
__.run_tasks = function()
    if is_started then return end
       is_started = true

    -- 只需要一个 worker 执行任务
    if ngx.worker.id() ~= 0 then return end

    ngx.log(ngx.ERR, "sslx.domain.run_tasks")

    local h = 60 * 60  -- 1小时

    ngx.timer.at   (0, run_tasks, false)  -- 初次加载
    ngx.timer.every(h, run_tasks, true )  -- 每小时检查一次

end

return __
