
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

local waf = require "app.comm.waf"

local err_html = waf.html("error.html")

local info = debug.getinfo(1, "S")
local path = string.sub(info.source, 2)  -- 去掉开头的@符号
local rule_path = string.gsub(path, "init.lua", "rules/")
local log_path  = ngx.config.prefix() .. "logs/"

local on, off  = true, false

local conf = {

    rule_path       = rule_path,    -- 规则存放目录
    log_path        = log_path,     -- 日志存放目录
    attack_log      = on,           -- 是否开启攻击信息记录

    err_html        = err_html,     -- 警告内容
    err_redirect    = on,           -- 是否拦截后重定向

    url_allow       = on,           -- 是否开启 URL 白名单
    url_deny        = on,           -- 是否拦截 URL 黑名单

    ua_deny         = off,          -- 是否拦截 User Agent
    args_deny       = off,          -- 是否拦截 SQL 注入等攻击
    cookie_deny     = off,          -- 是否拦截 cookie 攻击

    -- ip白名单
    ip_white_list = {
       "127.0.0.1",
    --	"10.10.10.0/24",
    },

    -- ip黑名单
    ip_black_list = {
    --	"1.0.0.1",
    --	"192.168.0.0/16",
    },

    cc_deny = on,           -- 是否开启拦截cc攻击(lua_shared_dict waf_limit 10m;)
    cc_rate = "100/60",     --设置cc攻击频率，单位为秒.（默认1分钟同一个IP只能请求同一个地址100次）

}

return conf
