
-- waf 防火墙 v18.01.06 by Killsen -------------------
--（Web Application Firewall）
-- https://github.com/loveshell/ngx_lua_waf
-- Copyright (c) 2013- loveshell

local ngx           = ngx
local ngx_var       = ngx.var
local ngx_ctx       = ngx.ctx
local re_find       = ngx.re.find
local smatch        = string.match
local io_open       = io.open
local type          = type
local pairs         = pairs
local ipairs        = ipairs

local waf           = require "app.comm.waf"
local conf          = waf.conf

local iputils       = require "resty.iputils"
iputils.enable_lrucache() -- 启动IP缓存

local parse_cidrs   = iputils.parse_cidrs
local binip_in_cidrs= iputils.binip_in_cidrs

local ip_white_list = parse_cidrs ( conf.ip_white_list ) -- IP白名单
local ip_black_list = parse_cidrs ( conf.ip_black_list ) -- IP黑名单

local err_redirect  = conf.err_redirect     -- 是否拦截后重定向
local err_html      = conf.err_html         -- 警告内容

local rule_path     = conf.rule_path        -- 规则存放目录
local log_path      = conf.log_path         -- 攻击信息存放目录
local attack_log    = conf.attack_log       -- 是否开启攻击信息记录

local url_allow     = conf.url_allow        -- 是否开启 URL 白名单
local url_deny      = conf.url_deny         -- 是否拦截 URL 黑名单

local ua_deny       = conf.ua_deny          -- 是否拦截 User Agent
local args_deny     = conf.args_deny        -- 是否拦截 SQL 注入等攻击
local cookie_deny   = conf.cookie_deny      -- 是否拦截 cookie 攻击

local cc_deny       = conf.cc_deny          -- 是否开启拦截cc攻击
local cc_rate       = conf.cc_rate          -- 设置cc攻击频率（默认1分钟同一个IP只能请求同一个地址100次）
local cc_count      = tonumber(smatch(cc_rate,'(.*)/'))
local cc_seconds    = tonumber(smatch(cc_rate,'/(.*)'))


-- 添加日志
local function add_log(method, url, data, rule)

    if not attack_log then return end

    local ip          = ngx_var.remote_addr     or "unknown"
    local user_agent  = ngx_var.http_user_agent or "unknown"
    local server_name = ngx_var.server_name     or "unknown"
    local today, time = ngx.today(), ngx.localtime()

    ngx_ctx.waf_log_file = log_path .. '/waf_' .. today .. ".log"

    ngx_ctx.waf_log_info =     ip
                    .. ' [' .. time       .. '] '
                    .. ' "' .. method     .. ' ' .. server_name .. url .. '" '
                    .. ' "' .. data       .. '" '
                    .. ' "' .. user_agent .. '" '
                    .. ' "' .. rule       .. '" ' .. "\n"

end

-- 错误信息跳转
local function print_html()
    if err_redirect and err_html then
        ngx.header.content_type = "text/html"
        ngx.status = 403
        ngx.print(err_html)
    end
    ngx.exit(403)
end

---------------------- 读取规则 -----------------------

local function read_rule( rule_file )
    local  file = io_open(rule_path .. '/' .. rule_file, "r")
    if not file then return nil end
    local rules, index = {}, 0
        for line in file:lines() do
            index = index + 1
            rules[index] = line
        end
    file:close()
    return rules
end

local url_deny_rules  = read_rule('url_deny')
local url_allow_rules = read_rule('url_allow')
local args_rules      = read_rule('args')
local ua_rules        = read_rule('user_agent')
local cookie_rules    = read_rule('cookie')

---------------------- 检查规则 -----------------------

local function check_rule( rules, to_check )
    for _, rule in ipairs(rules) do
        if rule ~="" and re_find(to_check, rule, "isjo") then
            return rule
        end
    end
end

-- 1) 检查 IP 白名单/黑名单
local function check_ip()

    local addr = ngx_var.binary_remote_addr

    -- IP 白名单
    if binip_in_cidrs(addr, ip_white_list) then
        return true

    -- IP 黑名单
    elseif binip_in_cidrs(addr, ip_black_list) then
        ngx.exit(403)
        return true
    end

end

-- 2) 检查 URL 白名单/黑名单
local function check_url()

    local uri = ngx_var.uri

    -- URL 白名单
    if url_allow and check_rule(url_allow_rules, uri) then
        return true

    -- URL 黑名单
    elseif url_deny and check_rule(url_deny_rules, uri) then
        ngx.exit(404)
        return true
    end

end

-- 3) 拦截 CC 攻击
local  limit = ngx.shared.waf_limit
local function check_cc_attack()

    if not cc_deny then return end
    if not limit then return end

    local uri   = ngx_var.uri
    local token = ngx_var.remote_addr .. uri
    local count = limit:get(token)

    if not count then
        limit:set(token, 1, cc_seconds)
        return
    end

    if count > cc_count then
        ngx.exit(503)
        return true
    else
        limit:incr(token, 1)
    end
end

-- 4) 拦截压力测试工具
local function check_user_agent()

    if not ua_deny then return end

    local ua   = ngx_var.http_user_agent
    local rule = check_rule(ua_rules, ua)

    if rule then
        add_log('UA', ngx_var.request_uri, "-", rule)
        print_html()
        return true
    end

end

-- 5) 拦截 SQL 注入等
local function check_uri_args()

    if not args_deny then return false end

    local args = ngx.req.get_uri_args()

    for _, v in pairs(args) do
        if type(v)=='table' then v=table.concat(v," ") end
        if v and type(v) ~= "boolean" then
            local rule = check_rule(args_rules, v)
            if rule then
                add_log('GET', ngx_var.request_uri, "-", rule)
                print_html()
                return true
            end
        end
    end

end

-- 6) 拦截 cookie 攻击
local function check_cookie()

    if not cookie_deny then return end

    local  cookies = ngx_var.http_cookie
    if not cookies then return end

    local rule = check_rule(cookie_rules, cookies)

    if rule then
        add_log('Cookie', ngx_var.request_uri, "-", rule)
        print_html()
        return true
    end
end

local __ = {}

-- access_by_lua 调用
__.access_by_lua = function()

    if check_ip         ()  then return end -- 1) 检查 IP 白名单/黑名单
    if check_url        ()  then return end -- 2) 检查 URL 白名单/黑名单
    if check_cc_attack  ()  then return end -- 3) 拦截 CC 攻击

    if check_user_agent ()  then return end -- 4) 拦截压力测试工具
    if check_uri_args   ()  then return end -- 5) 拦截 SQL 注入等
    if check_cookie     ()  then return end -- 6) 拦截 cookie 攻击

    if ngx_var.http_Acunetix_Aspect or
       ngx_var.http_X_Scan_Memo then
        ngx.exit(444)
    end

end

-- log_by_lua 调用
__.log_by_lua = function()

    if not attack_log then return end

    local file = ngx_ctx.waf_log_file
    local info = ngx_ctx.waf_log_info

    if not file then return end
    if not info then return end

    local  f = io_open(file, "ab")
    if not f then return end

        f:write(info)
        f:flush()
        f:close()

end

return __
