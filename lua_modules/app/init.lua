
local err_log   = require "app.utils".err_log  -- 错误日志输出
local load_app  = require "app.comm.load_app"

local __ = {}

__.info = function()
    local pok, resty_info = pcall(require, "resty.info")
    if not pok then return ngx.exit(404) end
    resty_info.info()
end

__.monitor = function()
    require "app.comm.monitor".start()
end

__.auth = function()

    -- Nginx-Lua HTTP 401 认证校验
    -- http://chenxiaoyu.org/2012/02/08/nginx-lua-401-auth/

    -- 本机访问无需认证
    if ngx.var.remote_addr == "127.0.0.1" then return end

    local uid = ngx.var.remote_user
    local psw = ngx.var.remote_passwd  -- 读不到密码

    if uid=="nginx@openresty" then return end

    -- 检查账号密码
    if uid=="nginx" and psw=="openresty" then return end

    -- 返回 HTTP 401 认证输入框
    ngx.header.www_authenticate = [[Basic realm="Restricted"]]
    ngx.exit(401)

end

-- 帮助文档 v20.08.21 by Killsen ------------------
__.help = function()

    -- 程序名称
    local  app_name = ngx.var.app_name
    if not app_name then return ngx.exit(404) end

    -- 接口名称
    local  act_type = ngx.var.act_type
    if not act_type then return ngx.exit(404) end

    ngx.ctx.app_name = app_name
    ngx.ctx.act_type = act_type

    -- 加载程序
    local  app = load_app()
    if not app then return ngx.exit(404) end

    -- 加载接口
    local  fun = app[act_type]
    if not fun then return ngx.exit(404) end

    -- 运行程序
    xpcall(fun, err_log)

end

-- 程序入口 v20.08.21 by Killsen ------------------
__.main = function()

    -- 程序名称
    local  app_name = ngx.var.app_name
    if not app_name then return ngx.exit(404) end

    -- 程序名称
    ngx.ctx.app_name = app_name

    -- 加载程序
    local  app = load_app()
    if not app then return ngx.exit(404) end

    -- 运行程序
    xpcall(app.run, err_log)

end

return __
