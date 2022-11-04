
local ngx           = ngx
local type          = type
local pcall         = pcall
local require       = require
local daox          = require "app.comm.daox"
local actx          = require "app.comm.actx"
local apix          = require "app.comm.apix"
local load_mod      = require "app.comm.load_mod"
local _cleart       = require "table.clear"
local _lower        = string.lower
local _sub          = string.sub

local _M = {}
local mt = { __index = _M }

-- 新版 openresty：
-- 不同请求、timer：共用 _G 和 gm
-- 不同请求、timer：ngx.ctx 隔离

local gm = getmetatable(_G)

-- 严格模式（不允许创建全局变量）
gm.__newindex = function(_, k, v)

    -- if GLOBAL[k] then return end

        ngx.status = 500
        ngx.header["content-type"] = "text/plain"

        ngx.say ( "------ 出 错 啦 ------" )
        ngx.say ( "不允许创建全局变量：", tostring(k), " = ", tostring(v) )
        ngx.say ( "\n", debug.traceback() )

    return ngx.exit(500) -- ngx.HTTP_INTERNAL_SERVER_ERROR

end

local APPS = {}

local function _load(mod_name)
    local app = _M.new(ngx.ctx.app_name)
    if not app then return end
    return app:load_mod(mod_name)
end
rawset(_G, "_load", _load)

local function _unload()
    local app = _M.new(ngx.ctx.app_name)
    if not app then return end
    return app:unload()
end
rawset(_G, "_unload", _unload)

-- 创建应用
function _M.new (app_name)  --@@

    app_name = app_name or ngx.ctx.app_name
    if type(app_name) ~= "string" or app_name == "" then
        return nil, "app not found"
    end

    app_name = _lower(app_name)  -- 转小写
    ngx.ctx.app_name = app_name

    local app = APPS[app_name]
    if app then return app end

    -- local conf = require("app.demo")
    local pok, conf = pcall(require, "app." .. app_name)
    if not pok then return nil, "app not found" end
    if type(conf) ~= "table" then return nil, "app not found" end

    -- 加载 db 库
    package.loaded["app.lib.db"] = nil
    local db = require "app.lib.db"
    package.loaded["app.lib.db"] = nil
    db.load(conf.db_config, conf.db_slave)

    app = {
        name        = app_name,
        title       = conf.title or app_name,
        ver         = conf.ver,
        db_config   = conf.db_config,
        help_html   = conf.help_html,
        db          = db,
        db_execute  = db.execute,
        mod_loaded  = {},
        fun_unload  = {},   -- 卸载时回调函数
    }

    APPS[app_name] = setmetatable(app, mt)

    return app

end

-- 清空缓存
function _M:clean_up()
    _cleart(self.mod_loaded)
    _cleart(self.fun_unload)
end

-- 在线帮助
function _M:help()
    actx.show_help(self.name)
end

-- 重新加载
function _M:reload()
    self:clean_up()
    actx.reload_app(self.name)
end

-- 卸载程序
function _M:unload()
    self.db.unload()
end

-- 运行程序
function _M:action()
    actx.do_action(self.name)
end

-- 重新建表
function _M:init_dao ()

    local args = ngx.req.get_uri_args()

    daox.init_dao {
        app_name    = self.name,
        dao_name    = args.name,
        drop_nonce = tonumber(args.drop),
    }

end

-- 升级表结构
function _M:init_daos ()

    local args = ngx.req.get_uri_args()

    daox.init_daos {
        app_name    = self.name,
        add_column  = args.add_column  and true or false,
        drop_column = args.drop_column and true or false,
    }

end

function _M:gen_api_code ()
    apix.gen_api_code(self.name)
end

function _M:gen_api_ts ()
    apix.gen_api_ts(self.name)
end

function _M:gen_api_js ()
    apix.gen_api_js(self.name)
end

-- 加载 dao 模块
function _M:load_dao(mod_name, reload_mod)

    local mod

    if not reload_mod then
        mod = self.mod_loaded[mod_name]
        if mod ~= nil then return mod end
    end

    if type(mod_name) ~= "string" or mod_name == "" then return end
    if _sub(mod_name, 1, 1) ~= "$" then mod_name = "$" .. mod_name end

    mod = load_mod (self.name, mod_name, reload_mod)
    if type(mod) ~= "table" then return end

    mod = daox.new_dao (mod, self.db_execute)
    self.mod_loaded[mod_name] = mod

    return mod

end

-- 加载 act 模块
function _M:load_act(mod_name, reload_mod)

    if type(mod_name) ~= "string" or mod_name == "" then return end
    if _sub(mod_name, 1, 4) ~= "act." then mod_name = "act." .. mod_name end

    return self:load_mod(mod_name, reload_mod)

end

-- 加载模块
function _M:load_mod(mod_name, reload_mod)

    local mod

    if not reload_mod then
        mod = self.mod_loaded[mod_name]
        if mod ~= nil then return mod end
    end

    if type(mod_name) ~= "string" or mod_name == "" then return end

    if (mod_name == "%db") then
        return self.db
    elseif _sub(mod_name, 1, 1) == "$" then
        return self:load_dao(mod_name, reload_mod)
    end

    mod = load_mod (self.name, mod_name, reload_mod)
    self.mod_loaded[mod_name] = mod

    return mod

end

-----------------------------------------------------------
return _M
