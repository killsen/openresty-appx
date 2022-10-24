
-- 新建app v21.08.26 by Killsen ------------------

local require       = require
local _run_app      = require "app.comm.run_app"        -- 运行程序
local _load_mod     = require "app.comm.load_mod"       -- 加载模块
local _show_help    = require "app.comm.show_help"      -- 帮助文档
local _reload_app   = require "app.comm.reload_app"     -- 重新模块
local _new_dao      = require "app.comm.new_dao"        -- 创建dao
local _init_dao     = require "app.comm.init_dao"       -- 创建dao表
local _init_daos    = require "app.comm.init_daos"      -- 创建全部dao表


local function new_app (app)

    app = app or {}

    local mod_loaded = {}
    local fun_unload = {} -- 卸载时回调函数
    local fun_index  = 0
    -------------------------------------------------------

        -- 清空缓存
        local function _clean_up()
            mod_loaded = {}
            fun_unload = {}
            fun_index  = 0
        end

        -- 卸载程序
        function app.unload()
            for i=1, fun_index do
                fun_unload[i]()
            end
        end

        -- 运行程序
        function app.run ()
            _run_app (app)
        end

        -- 在线帮助
        function app.help ()
            _clean_up()
            _show_help (app)
        end

        -- 创建表
        function app.initdao ()
            _init_dao (app)
        end

        -- 创建全部表
        function app.initdaos ()
            _init_daos (app)
        end

        -- 重载 app
        function app.reload ()
            _clean_up()
            _reload_app (app.name)
        end

        -- 测试
        function app.testing ()
            local _testing = app.load("_testing")
            if type(_testing)~="function" then return end
            _testing ()
        end

        -- 模块加载器
        function app.load (mod_name, reload_mod)

            -- 未指定参数：则卸载
            if type(mod_name)~="string" or mod_name=="" then
                app.unload()
                return
            end

            -- 卸载模块
            if reload_mod then
                mod_loaded[mod_name] = nil
            end

            local mod, t

            mod = mod_loaded[mod_name]
            if mod then return mod end

            mod, t = _load_mod (app.name, mod_name, reload_mod)
            if not mod then return end

            if t=="$" then -- dao
                mod = _new_dao(app, mod)
                if not mod then return end
            end

            if t=="%" and type(mod)=="table" then
                -- 处理加载事件
                if "function" == type(rawget(mod, "_on_load")) then
                    mod._on_load(app)
                end

                -- 注册卸载事件
                if "function" == type(rawget(mod, "_on_unload")) then
                    fun_index = fun_index + 1
                    fun_unload[fun_index] = mod._on_unload
                end
            end

            mod_loaded[mod_name] = mod
            return mod

        end

    -------------------------------------------------------
    return app

end

-----------------------------------------------------------
return new_app
