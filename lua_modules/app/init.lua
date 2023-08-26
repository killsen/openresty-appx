
local ngx  = ngx
local appx = require "app.comm.appx"

local __ = { _VERSION = "1.0.0" }

do  -- 改写 ngx.on_abort
    local ngx_on_abort = rawget(_G, "ngx_on_abort")
    if not ngx_on_abort then
        ngx_on_abort = ngx.on_abort
        rawset(_G, "ngx_on_abort", ngx_on_abort)

        local function on_abort()
            local cb = ngx.ctx[on_abort]
            if type(cb) == "function" then
                pcall(cb)
            elseif type(cb) == "number" then
                ngx.exit(cb)
            end
        end

        ngx.on_abort = function(cb)
            ngx.ctx[on_abort] = cb
            pcall(ngx_on_abort, on_abort)
        end
    end
end

-- 服务器实时监控
__.waf = function()
    require "app.comm.waf".run()
end

-- 程序助手
__.help = function()

    local  app_name = ngx.var.app_name
    local  act_type = ngx.var.act_type

    if not app_name then return ngx.exit(404) end
    if not act_type then return ngx.exit(404) end

    ngx.ctx.app_name = app_name
    ngx.ctx.act_type = act_type

    local app  = appx.new(app_name)
    if not app then return ngx.exit(404) end

    ngx.on_abort(nil)  -- 开启客户端退出事件

    if act_type ~= "api.d.ts" and act_type ~= "api.js" then
        local waf = require "app.comm.waf"
        if not waf.auth.check() then return end  -- 认证校验
    end

        if act_type == "help"     then app:help()
    elseif act_type == "reload"   then app:reload()
    elseif act_type == "initdao"  then app:init_dao()
    elseif act_type == "initdaos" then app:init_daos()
    elseif act_type == "api"      then app:gen_api_code()
    elseif act_type == "api.d.ts" then app:gen_api_ts()
    elseif act_type == "api.js"   then app:gen_api_js()
    else
        ngx.exit(404)
    end

    app:unload()  -- 卸载程序

end

-- 程序入口
__.main = function()

    -- 程序名称
    local  app_name = ngx.var.app_name
    if not app_name then return ngx.exit(404) end

    ngx.ctx.app_name = app_name
    ngx.ctx.file_name = ngx.var.file_name

    local app  = appx.new(app_name)
    if not app then return ngx.exit(404) end

    ngx.on_abort(nil)  -- 开启客户端退出事件

    app:action(ngx.var.uri)

    app:unload()  -- 卸载程序

end

-- 程序调试
__.debug = function()

    local actx = require "app.comm.actx"

    -- 获取调试文件或代码
    local file_name, codes = actx.debug.get_debug_file()
    if not file_name then return ngx.exit(403) end

    -- 重新加载 appx
    appx = actx.debug.reload_appx()

    -- 执行调试文件或代码
    actx.debug.do_debug_file(file_name, codes)

end

return __
