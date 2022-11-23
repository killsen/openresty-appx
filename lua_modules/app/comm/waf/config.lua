
-- ngx_lua_waf是一个基于lua-nginx-module(openresty)的web应用防火墙
-- https://github.com/loveshell/ngx_lua_waf
-- 用途：---------------------------------------------------------
-- 防止sql注入，本地包含，部分溢出，fuzzing测试，xss,SSRF等web攻击
-- 防止svn/备份之类文件泄漏
-- 防止ApacheBench之类压力测试工具的攻击
-- 屏蔽常见的扫描黑客工具，扫描器
-- 屏蔽异常的网络请求
-- 屏蔽图片附件类目录php执行权限
-- 防止webshell上传

local cjson         = require "cjson.safe"
local iputils       = require "resty.iputils"
local parse_cidrs   = iputils.parse_cidrs
local binip_in_cidrs= iputils.binip_in_cidrs

iputils.enable_lrucache() -- 启动IP缓存

local CACHE         = {}
local _insert       = table.insert
local _cleart       = require "table.clear"

local ngx_path      = ngx.config.prefix()
local log_path      = ngx_path .. "/logs/"

local info = debug.getinfo(1, "S")
local path = string.sub(info.source, 2)  -- 去掉开头的@符号
local rule_path = string.gsub(path, "config.lua", "rules/")

local on, off  = true, false

-- 读取配置
local function read_conf()

    local conf = {
        attack_log      = on,           -- 是否开启攻击信息记录
        err_redirect    = on,           -- 是否拦截后重定向

        ip_allow        = on,           -- 是否开启 IP 白名单
        ip_deny         = on,           -- 是否拦截 IP 黑名单

        url_allow       = on,           -- 是否开启 URL 白名单
        url_deny        = on,           -- 是否拦截 URL 黑名单

        ua_deny         = off,          -- 是否拦截 User Agent
        args_deny       = off,          -- 是否拦截 SQL 注入等攻击
        cookie_deny     = off,          -- 是否拦截 cookie 攻击

        cc_deny         = on,           -- 是否开启拦截cc攻击
        cc_seconds      = 60,           -- 默认 60 秒
        cc_count        = 100,          -- 最多 100 个请求(同一个url)
    }

    local  file = io.open(log_path .. "/waf_config.json", "rb")
    if not file then return conf end

    local data = file:read("a"); file:close()
    local obj  = cjson.decode(data)

    if type(obj) == "table" then
        for k, v in pairs(obj) do
            if type(v) == type(obj[k]) then
                conf[k] = v
            end
        end
    end

    return conf

end

-- 保存配置
local function save_conf(t)

    if type(t) ~= "table" then return end

    local c = read_conf()
    for k, v in pairs(c) do
        if type(v) == type(t[k]) then
            c[k] = t[k]
        end
    end

    local pok, encode = pcall(require, "resty.prettycjson")
    if not pok then encode = cjson.encode end

    local data = encode(c)

    local  file = io.open(log_path .. "/waf_config.json", "wb+")
    if not file then return end

    file:write(data)
    file:close()

    return true

end

-- 读取规则列表
local function read_rules(rule_name)

    local rules = CACHE[rule_name]
    if rules then return rules end

    rules = {}
    CACHE[rule_name] = rules

    local file = io.open(log_path .. '/waf_' .. rule_name, "r") or
                 io.open(rule_path .. '/'    .. rule_name, "r")
    if not file then return rules end

    for line in file:lines() do
        if line ~= "" then
            _insert(rules, line)
        end
    end

    file:close()
    return rules
end

-- 保存规则列表
local function save_rules(rule_name, rules)

    if type(rules) == "table" then
        rules = table.concat(rules, "\n")
    end

    if type(rules) ~= "string" then return end

    local file = io.open(log_path .. '/waf_' .. rule_name, "wb+")
    if not file then return end

    file:write(rules)
    file:close()

    return true
end

-- 检查规则列表
local function check_rules(rule_name, to_check)
    local rules = read_rules(rule_name)
    for _, rule in ipairs(rules) do
        if ngx.re.find(to_check, rule, "isjo") then
            return rule
        end
    end
end

local function get_ip_list(rule_name)

    local key = rule_name .. "_list"

    local list = CACHE[key]
    if list then return list end

    local rules = read_rules(rule_name)
    list = parse_cidrs(rules) or {}
    CACHE[key] = list

    return list
end

local __ = {}

do
    local conf = read_conf()
    for k, v in pairs(conf) do
        __[k] = v
    end
end

-- IP 白名单
__.check_ip_allow = function(addr)
    local ip_white_list = get_ip_list("ip_allow")
    return binip_in_cidrs(addr, ip_white_list)
end

-- IP 黑名单
__.check_ip_deny = function(addr)
    local ip_black_list = get_ip_list("ip_deny")
    return binip_in_cidrs(addr, ip_black_list)
end

-- URL 白名单
__.check_url_allow = function(uri)
    return check_rules("url_allow", uri)
end

-- URL 黑名单
__.check_url_deny = function(uri)
    return check_rules("url_deny", uri)
end

-- 拦截 SQL 注入等
__.check_args_deny = function(args)
    return check_rules("args_deny", args)
end

-- 拦截压力测试工具
__.check_ua_deny = function(ua)
    return check_rules("ua_deny", ua)
end

-- 拦截 cookie 攻击
__.check_cookie_deny = function(cookie)
    return check_rules("cookie_deny", cookie)
end

local waf_limit = ngx.shared.waf_limit
local waf_index = 0

-- 刷新配置信息
__.update = function()

    local index = waf_limit:get("waf_index")
    if type(index) ~= "number" then
        index = 0
        waf_limit:set("waf_index", index)
    end

    if waf_index == index then return end
       waf_index = index

    _cleart(CACHE)

    local conf = read_conf()
    for k, v in pairs(conf) do
        __[k] = v
    end

end

-- 保存配置
__.save = function()

    if ngx.req.get_method() ~= "POST" then return end

    ngx.req.read_body()
    local body = ngx.req.get_body_data()
    local t = cjson.decode(body)
    if type(t) ~= "table" then return end

    t.cc_count   = tonumber(t.cc_count)
    t.cc_seconds = tonumber(t.cc_seconds)

    save_conf(t)

    local rule_names = {
        "ip_allow", "ip_deny",
        "url_allow", "url_deny",
        "ua_deny", "args_deny", "cookie_deny",
    }

    for _, rule_name in ipairs(rule_names) do
        local rules = t[rule_name .. "_rules"]
        if type(rules) == "string" then
            save_rules(rule_name, rules)
        end
    end

    waf_limit:set("waf_index", ngx.now() * 1000)
    __.update()

    ngx.print("OK")

end

-- 输出网页
__.html = function()

    local waf = require "app.comm.waf"

    local  html = waf.html("config.html")
    if not html then return ngx.exit(404) end

    local g = {}
    for k, v in pairs(read_conf()) do
        g[k] = v
    end

    local rule_names = {
        "ip_allow", "ip_deny",
        "url_allow", "url_deny",
        "ua_deny", "args_deny", "cookie_deny",
    }

    for _, rule_name in ipairs(rule_names) do
        local rules = read_rules(rule_name)
        g[rule_name .. "_rules"] = table.concat(rules, "\n")
    end

    html = string.gsub(html, "{ G }" , cjson.encode(g) )

    ngx.header["content-type"] = "text/html; charset=utf-8"
    ngx.print(html)

end


return __
