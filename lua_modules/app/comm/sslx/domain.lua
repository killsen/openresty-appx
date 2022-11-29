
-- 域名基础知识
-- https://support.google.com/a/answer/2573637

local ngx           = ngx
local prefix        = ngx.config.prefix()
local cjson         = require "cjson.safe"
local _decode       = cjson.decode
local _open         = io.open
local _insert       = table.insert
local _sub          = string.sub

local cert_path     = prefix .. "/conf/cert/"
local cert_log      = prefix .. "/logs/cert.log"
local sslx          = require "app.comm.sslx"
local x509          = require "resty.openssl.x509"

local __ = { }

local DOMAINS, SERVERS

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
            { "issuance_time?"  , "证书颁发日期"    , "number"  },
            { "expires_time?"   , "证书截止日期"    , "number"  },
        }
    },
    res = "@DomainInfo[]"
}
__.load_domains = function ()

    if DOMAINS then return DOMAINS end
       DOMAINS = {}

    local text = read_file("domains.json")
    if not text then return DOMAINS end

    local list = _decode(text)
    if type(list) ~= "table" then return DOMAINS end

    for _, d in ipairs(list) do
        if type(d) == "table" and type(d.domain_name) == "string" and d.domain_name ~= "" then
            _insert(DOMAINS, {
                domain_name  = d.domain_name,   -- 主域名: 如 baidu.com, qq.com 等
                dnspod_token = d.dnspod_token,  -- 域名服务器登录凭证: 目前只支持 dnspod
                issuance_time= nil,
                expires_time = nil
            })
        end
    end

    return DOMAINS

end

-- 加载服务器名称列表
__.load_servers = function ()

    if SERVERS then return SERVERS end
       SERVERS = {}

    local domains = __.load_domains()

    for _, d in ipairs(domains) do
        _insert(SERVERS, d.domain_name)
        SERVERS[d.domain_name] = d.domain_name
    end

    return SERVERS

end

-- 获取子域名对应的主域名: 如 www.baidu.com -> baidu.com
__.get_domain_name = function(server_name)

    local servers = __.load_servers()
    if #servers == 0 then return end

    local domain_name = servers[server_name]
    if domain_name then return domain_name end
    if domain_name == false then return end

    servers[server_name] = false

    for _, s in ipairs(servers) do
        if _sub(server_name, 0-#s) == s then
            servers[server_name] = s
            return s
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

-- 申请证书
__.order_certs = function(debug_mode)

    local domains = __.load_domains()

    if #domains == 0 then
        _echo("尚未定义域名: 请在 conf/cert/domains.json 定义")
        return
    end

    _echo("共有 ", #domains, " 个域名需要申请证书")

    for _, d in ipairs(domains) do
        _echo("-------------------------------------")
        sslx.order.order_cert {
            domain_name     = d.domain_name,
            dnspod_token    = d.dnspod_token,
            debug_mode      = (debug_mode ~= false),
            retry_times     = 10,
            echo            = _echo,
            wait            = _wait,
        }
    end

end

-- 获取需要申请证书的域名列表
local function get_domain_list()
-- @return : @DomainInfo[]

    local list  = {}

    local domains = __.load_domains()
    if #domains == 0 then return list end

    local expires_time = ngx.time() + 24*60*60*30 -- 30天后

    for _, d in ipairs(domains) do
        if not d.expires_time then
            local cert_pem = read_file(d.domain_name .. "-crt.pem")
            if not cert_pem then
                d.issuance_time = 0
                d.expires_time  = 0
            else
                local cert = x509.new(cert_pem)
                d.issuance_time = cert:get_not_before()
                d.expires_time  = cert:get_not_after()
            end
        end
        if d.expires_time < expires_time then
            _insert(list, d)
        end
    end

    return list


end

-- 升级证书：证书不存在自动申请，证书快过期自动延期
__.update_certs = function(is_tasks)

    local domains = get_domain_list()

    if #domains == 0 then
        if not is_tasks then _echo("暂无需要升级的证书") end
        return domains
    end

    _echo("共有 ", #domains, " 个域名需要申请证书")

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
        end
    end

    return domains

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
    if ngx.worker.id() ~= 0 then return end

    ngx.log(ngx.ERR, "start tasks: sslx.domain.run_tasks")

    ngx.timer.at   ( 0, run_tasks, false)  -- 初次加载
    ngx.timer.every(60, run_tasks, true )  -- 每1分钟检查一次

end


return __
