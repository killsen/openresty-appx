
-- 新版 openresty：
-- 不同请求、timer：共用 _G 和 gm
-- 不同请求、timer：ngx.ctx 隔离

local require   = require
local debug     = debug
local tostring  = tostring

-- 允许创建的全局变量
local GLOBAL    = {
        lfs     = true
    ,   gd      = true
    ,   socket  = true
}

-- 已加载过的程序
local APPS = {}

local function load_app()

    -- 取得程序名
    local  app_name = ngx.ctx.app_name
    if not app_name then return nil end

    local ok, app

       app = APPS[app_name]
    if app then return app end
    if app == false then return nil end

    -- 加载程序
    ok, app = pcall(require, "app." .. app_name)

    if not ok or type(app) ~= "table" then
        APPS[app_name] = false
        return nil
    end

    if type(app.load) ~= "function" or
       type(app.help) ~= "function" or
       type(app.run ) ~= "function" then
        APPS[app_name] = false
        return nil
    end

    APPS[app_name] = app
    return app

end

local gm = getmetatable(_G)

gm.__index = function(_, k)

    if k ~= "_load" then return end

    local  app = load_app()
    if not app then return end

    return app.load

end

-- 严格模式（不允许创建全局变量）
gm.__newindex = function(_, k, v)

    if GLOBAL[k] then return end

        ngx.status = 500
        ngx.header["content-type"] = "text/plain"

        ngx.say ( "------ 出 错 啦 ------" )
        ngx.say ( "不允许创建全局变量：", tostring(k), " = ", tostring(v) )
        ngx.say ( "\n", debug.traceback() )

    return ngx.exit(500) -- ngx.HTTP_INTERNAL_SERVER_ERROR

end

return load_app
