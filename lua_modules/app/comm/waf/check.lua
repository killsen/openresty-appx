
-- waf 防火墙 v18.01.06 by Killsen -------------------
--（Web Application Firewall）
-- https://github.com/loveshell/ngx_lua_waf
-- Copyright (c) 2013- loveshell

local ngx           = ngx
local ngx_var       = ngx.var
local io_open       = io.open
local type          = type
local pairs         = pairs

local waf           = require "app.comm.waf"
local conf          = waf.config

local log_path      = ngx.config.prefix() .. "/logs/"
local err_html      = waf.html("error.html")

-- 添加日志
local function add_log(method, url, data, rule)

    if not conf.attack_log then return end

    local ip          = ngx_var.remote_addr     or "unknown"
    local user_agent  = ngx_var.http_user_agent or "unknown"
    local server_name = ngx_var.server_name     or "unknown"
    local today, time = ngx.today(), ngx.localtime()

    local file = log_path .. '/waf_' .. today .. ".log"

    local  f = io_open(file, "ab")
    if not f then return end

    f:write(     ip
        , ' [' , time       , '] '
        , ' "' , method     , ' ' , server_name , url , '" '
        , ' "' , data       , '" '
        , ' "' , user_agent , '" '
        , ' "' , rule       , '" ' , "\n"
    )

    f:flush()
    f:close()

end

-- 错误信息跳转
local function print_html()
    if conf.err_redirect and err_html then
        ngx.header.content_type = "text/html"
        ngx.status = 403
        ngx.print(err_html)
    end
    ngx.exit(403)
end

-- 1) 检查 IP 白名单/黑名单
local function check_ip()

    local addr = ngx_var.binary_remote_addr

    -- IP 白名单
    if conf.ip_allow and conf.check_ip_allow(addr) then
        return true

    -- IP 黑名单
    elseif conf.ip_deny and conf.check_ip_deny(addr) then
        ngx.exit(403)
        return true
    end

end

-- 2) 检查 URL 白名单/黑名单
local function check_url()

    local uri = ngx_var.uri

    -- URL 白名单
    if conf.url_allow and conf.check_url_allow(uri) then
        return true

    -- URL 黑名单
    elseif conf.url_deny and conf.check_url_deny(uri) then
        ngx.exit(404)
        return true
    end

end

-- 3) 拦截 CC 攻击
local  limit = ngx.shared.waf_limit
local function check_cc_deny()

    if not conf.cc_deny then return end
    if not limit then return end

    local uri   = ngx_var.uri
    local token = ngx_var.remote_addr .. uri
    local count = limit:get(token)

    if not count then
        limit:set(token, 1, conf.cc_seconds)
        return
    end

    if count > conf.cc_count then
        ngx.exit(503)
        return true
    else
        limit:incr(token, 1)
    end
end

-- 4) 拦截压力测试工具
local function check_ua_deny()

    if not conf.ua_deny then return end

    local ua   = ngx_var.http_user_agent
    local rule = conf.check_ua_deny(ua)

    if rule then
        add_log('UA', ngx_var.request_uri, "-", rule)
        print_html()
        return true
    end

end

-- 5) 拦截 SQL 注入等
local function check_args_deny()

    if not conf.args_deny then return false end

    local args = ngx.req.get_uri_args()

    for _, v in pairs(args) do
        if type(v)=='table' then v=table.concat(v," ") end
        if v and type(v) ~= "boolean" then
            local rule = conf.check_args_deny(v)
            if rule then
                add_log('GET', ngx_var.request_uri, "-", rule)
                print_html()
                return true
            end
        end
    end

end

-- 6) 拦截 cookie 攻击
local function check_cookie_deny()

    if not conf.cookie_deny then return end

    local  cookies = ngx_var.http_cookie
    if not cookies then return end

    local rule = conf.check_cookie_deny(cookies)

    if rule then
        add_log('Cookie', ngx_var.request_uri, "-", rule)
        print_html()
        return true
    end
end

local __ = {}

-- access_by_lua 调用
__.access_by_lua = function()

    conf.update()  -- 刷新配置信息

    if check_ip         ()  then return end -- 1) 检查 IP 白名单/黑名单
    if check_url        ()  then return end -- 2) 检查 URL 白名单/黑名单
    if check_cc_deny    ()  then return end -- 3) 拦截 CC 攻击

    if check_ua_deny    ()  then return end -- 4) 拦截压力测试工具
    if check_args_deny  ()  then return end -- 5) 拦截 SQL 注入等
    if check_cookie_deny()  then return end -- 6) 拦截 cookie 攻击

    if ngx_var.http_Acunetix_Aspect or
       ngx_var.http_X_Scan_Memo then
        ngx.exit(444)
    end

end

return __
