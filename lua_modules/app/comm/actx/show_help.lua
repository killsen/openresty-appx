
local function show_help(app_name)

    local app = require "app.comm.appx".new(app_name)

    local template  = require "resty.template"
    local help_html = require "app.comm.actx.help_html"
    local load_acts = require "app.comm.actx.load_acts"
    local load_daos = require "app.comm.daox.load_daos"

    -- app:clean_up()

    ngx.header["content-type"] = "text/html; charset=utf-8"

    template.render ( help_html, {
        app_name    = app.name,
        app_title   = app.title,
        app_ver     = app.ver,
        help_html   = app.help_html,
        app_acts    = load_acts(app.name),
        app_daos    = load_daos(app.name),
    })

end

return show_help

