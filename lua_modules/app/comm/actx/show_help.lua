
local help_html
local function get_def_help()

    if help_html ~= nil then
        return help_html
    else
        help_html = false
    end

    local info = debug.getinfo(1, "S")
    local path = string.sub(info.source, 2)  -- 去掉开头的@符号
    path = string.gsub(path, "show_help.lua", "help.html")

    local file = io.open(path, "rb")
    if not file then return end

    help_html = file:read("a"); file:close()
    return help_html

end

local app_helps = {}
local function get_app_help(app_name)

    local app = require "app.comm.appx".new(app_name)
    if not app then return end

    local html = app_helps[app_name]

    if html ~= nil then
        return html
    else
        app_helps[app_name] = false
    end

    local path = type(app.help_config) == "table" and app.help_config.template
    if type(path) ~= "string" or path == "" then return end

    path = ngx.config.prefix() .. "/html/" .. path

    local file = io.open(path, "rb")
    if not file then return end

    html = file:read("a"); file:close()
    app_helps[app_name] = html
    return html

end

local function show_help(app_name)

    local app = require "app.comm.appx".new(app_name)
    if not app then return ngx.exit(404) end

    local template  = require "resty.template"
    local cjson     = require "cjson.safe"
    local actx      = require "app.comm.actx"
    local daox      = require "app.comm.daox"
    local apix      = require "app.comm.apix"

    -- app:clean_up()

    local app_help = get_app_help(app_name)
    local def_help = get_def_help()

    if app_help then
        ngx.header["content-type"] = "text/html; charset=utf-8"
        template.render ( app_help, {
            app_name    = app.name,
            app_title   = app.title,
            app_ver     = app.ver,

            G = cjson.encode({
                app_name    = app.name,
                app_title   = app.title,
                app_ver     = app.ver,
                help_html   = app.help_html,
                help_config = app.help_config,
                app_apis    = apix.load_apis(app.name),
                app_acts    = actx.load_acts(app.name),
                app_daos    = daox.load_daos(app.name),
            })
        })

    elseif def_help then
        ngx.header["content-type"] = "text/html; charset=utf-8"
        template.render ( def_help, {
            app_name    = app.name,
            app_title   = app.title,
            app_ver     = app.ver,
            help_html   = app.help_html,
            app_acts    = actx.load_acts(app.name),
            app_daos    = daox.load_daos(app.name),
        })

    else
        ngx.exit(404)
    end
end

return show_help
