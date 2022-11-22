-- @@api : openresty-vsce

local __ = { __VERSION = "v1.0.0" }

local HTML_PATH
local function get_html_path()

    if HTML_PATH then return HTML_PATH end

    local info = debug.getinfo(1, "S")
    local path = string.sub(info.source, 2)  -- 去掉开头的@符号

    HTML_PATH = string.gsub(path, "init.lua", "html/")
    return HTML_PATH

end

__.html = function(file_name)

    local  path = get_html_path() .. file_name

    local  file = io.open(path, "rb")
    if not file then return end

    local  html = file:read("a"); file:close()
    return html

end

local FILES = {}

local function try_file()

    -- /waf/js/vue.js
    local uri = string.sub(ngx.var.uri, 5)

    local data = FILES[uri]
    if not data then
        local  file = io.open(get_html_path() .. uri, "rb")
        if not file then return ngx.exit(404) end
        data = file:read("a"); file:close()
        FILES[uri] = data
    end

    if string.sub(uri, -3) == ".js" then
        ngx.header["content-type"] = "application/javascript; charset=utf-8"
    elseif string.sub(uri, -4) == ".css" then
        ngx.header["content-type"] = "text/css"
    elseif string.sub(uri, -3) == ".ttf" then
        ngx.header["content-type"] = "font/woff"
    elseif string.sub(uri, -4) == ".woff" then
        ngx.header["content-type"] = "font/woff"
    end

    ngx.header["content-length"] = #data
    ngx.header["cache-control"] = "max-age=2592000"

    ngx.print(data)

end

local FUNCS

__.run = function()

    local  waf = __
    if not waf then waf = require "app.comm.waf" end

    FUNCS = FUNCS or {
        ["/waf"             ] = waf.monitor.start,
        ["/waf/"            ] = waf.monitor.start,
        ["/waf/monitor"     ] = waf.monitor.start,
        ["/waf/access"      ] = waf.access.start,
        ["/waf/summary"     ] = waf.summary.start,
        ["/waf/server"      ] = waf.api_server.list,
        ["/waf/server/add"  ] = waf.api_server.add,
        ["/waf/server/del"  ] = waf.api_server.del,
        ["/waf/server/set"  ] = waf.api_server.set,
    }

    local func = FUNCS[ngx.var.uri] or try_file

    local pok = pcall(func)
    if not pok then
        ngx.exit(404)
    end

end

__.init = function()

    local  waf = __
    if not waf then waf = require "app.comm.waf" end

    waf.status.init()
    waf.summary.init()
    waf.access.init()

end

__.log = function()

    local  waf = __
    if not waf then waf = require "app.comm.waf" end

    waf.status.log()
    waf.summary.log()
    waf.access.log()
    waf.check.log_by_lua()

end

-- 生成API模块
require "app.comm.apix".new(__)

return __
