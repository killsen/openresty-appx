
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

-- 加载域名列表
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


local function echo(...)
    local file = io.open(cert_log, "ab+")
    if not file then return end
    file:write(ngx.localtime(), "  ", ...)
    file:write("\n")
    file:close()
end

local function wait(msg, seconds)
    echo(msg)
    ngx.sleep(seconds)
end

-- 申请证书
__.order_certs = function()

    local domains = __.load_domains()

    for _, d in ipairs(domains) do
        local domain_name  = d.domain_name
        local dnspod_token = d.dnspod_token
        sslx.order.order_cert (domain_name, dnspod_token, echo, wait)
    end

end

return __
