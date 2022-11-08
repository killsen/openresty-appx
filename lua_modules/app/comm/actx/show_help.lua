
local help_html  -- 网页

local function show_help(app_name)

    local app = require "app.comm.appx".new(app_name)
    if not app then return ngx.exit(404) end

    if not help_html then
        local info = debug.getinfo(1, "S")
        local path = string.sub(info.source, 2)  -- 去掉开头的@符号
        local file = io.open(path .. "/../help.html", "rb")
        if not file then return ngx.exit(404) end
        help_html = file:read("a")
        file:close()
    end

    local template  = require "resty.template"
    local actx      = require "app.comm.actx"
    local daox      = require "app.comm.daox"

    -- app:clean_up()

    ngx.header["content-type"] = "text/html; charset=utf-8"

    template.render ( help_html, {
        app_name    = app.name,
        app_title   = app.title,
        app_ver     = app.ver,
        help_html   = app.help_html,
        app_acts    = actx.load_acts(app.name),
        app_daos    = daox.load_daos(app.name),
    })

end

return show_help
