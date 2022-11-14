
local help_html         -- 网页

local function show_help(app_name)

    local app = require "app.comm.appx".new(app_name)
    if not app then return ngx.exit(404) end

    -- 应用配置模板位置
    local help_config_template = app.help_config.template

    if not help_html then
        local file

        -- 加载应用配置的帮助模板
        if help_config_template then
            local str  = require "app.utils.str"
            local temp = help_config_template

            -- 远程模板
            if str.startsWith(temp, 'https://') or str.startsWith(temp, 'http://') then
                -- TODO: 待实现
            else
                -- 本地模板
                local temp_path = ngx.config.prefix() .. ("html/" .. help_config_template)
                file = io.open(temp_path, "rb")
            end
        end

        -- 默认模板托底
        if not file then
            local info = debug.getinfo(1, "S")
            local path = string.sub(info.source, 2)  -- 去掉开头的@符号
            path = string.gsub(path, "show_help.lua", "help.html")
            file = io.open(path, "rb")
        end

        if not file then return ngx.exit(404) end
        help_html = file:read("a")
        file:close()
    end

    local template  = require "resty.template"
    local cjson     = require "cjson.safe"
    local actx      = require "app.comm.actx"
    local daox      = require "app.comm.daox"
    local apix      = require "app.comm.apix"

    -- app:clean_up()

    ngx.header["content-type"] = "text/html; charset=utf-8"

    if help_config_template then
        template.render ( help_html, {
            G = cjson.encode({
                app_name    = app.name,
                app_title   = app.title,
                app_ver     = app.ver,
                help_html   = app.help_html,
                help_config = app.help_config,
                app_apis    = apix.gen_api_code(app.name),
                app_acts    = actx.load_acts(app.name),
                app_daos    = daox.load_daos(app.name),
            })
        })
    else
        template.render ( help_html, {
            app_name    = app.name,
            app_title   = app.title,
            app_ver     = app.ver,
            help_html   = app.help_html,
            app_acts    = actx.load_acts(app.name),
            app_daos    = daox.load_daos(app.name),
        })
    end
end

return show_help
