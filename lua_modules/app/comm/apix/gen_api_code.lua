
-- 生成参数校验函数代码 v21.08.30

local apix      = require "app.comm.apix"
local utils     = require "app.comm.utils"
local _split    = require "ngx.re".split
local _insert   = table.insert

-- 加载 api 目录及其子目录下全部 lua 文件
local function load_path (list, path, name)

    -- 文件列表
    local flist = utils.file_list (path)
        for _, f in ipairs(flist) do
            _insert(list, name .. f)
        end

    -- 目录列表
    local plist = utils.path_list (path)
        for _, p in ipairs(plist) do
            load_path(list, path .. p .. "/",
                            name .. p .. ".")
        end

end

local function _err(api, codes, err)

    ngx.say("")
    ngx.say("生成api参数校验函数代码失败：", api)
    ngx.say("-------------------------------------------------------------")
    ngx.say(err)
    ngx.say("-------------------------------------------------------------")
    ngx.say("")

    local t = _split(codes, "\n")
    for i, line in ipairs(t) do
        ngx.say("--[[ ", i, " ]]    ", line)
    end

end

return function(app_name, base_path, base_name, args)

    local app = require "app.comm.appx".new(app_name)
    if not app then return ngx.exit(404) end

    app_name = app.name

    base_path = base_path or ("app/" .. app_name .. "/api/")
    base_name = base_name or  ""

    args = args or ngx.req.get_uri_args()
    local api = args.api

    local query = ngx.encode_args(args)
    if query ~= "" then query = "?" .. query end

    if type(args.base) == "string" and args.base ~= "" then
        base_path = base_path .. args.base .. "/"
        base_name = base_name .. args.base .. "."
    end

    if type(api) == "string" and api ~= "" then
        ngx.header['content-type'] = "text/plain"
        ngx.header['language'] = "lua"
        local t = apix.load_api(base_name .. api)
        if t.ok then
            ngx.say(t.codes)
        else
            _err(t.name, t.codes, t.err)
        end
        return
    end

    ngx.header['content-type'] = "text/html"

ngx.say [[
<!DOCTYPE html>
<html lang="zh">
<head>
    <title>API列表</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=0">
    <style type="text/css">

        table {
            font-family: verdana,arial,sans-serif;
            font-size:11px;
            color:#333333;
            border-width: 1px;
            border-color: #666666;
            border-collapse: collapse;
        }
        table th {
            border-width: 1px;
            padding: 8px;
            border-style: solid;
            border-color: #666666;
            background-color: #dedede;
            text-align:left;
        }
        table td {
            border-width: 1px;
            padding: 8px;
            border-style: solid;
            border-color: #666666;
            background-color: #ffffff;
            text-align:left;
        }
        table tr:hover td {
            background: #DEDEDE;
        }

    </style>
</head>
<body>
]]

    local url1 = "/" .. app_name .. "/api"      .. query
    local url2 = "/" .. app_name .. "/api.d.ts" .. query
    local url3 = "/" .. app_name .. "/api.js"   .. query

    ngx.say("<h2>", app_name, "项目API列表")

    ngx.say('   <a style="margin-left: 30px;" target="_blank" href="', url2,'"', ">api.d.ts</a>")
    ngx.say('   <a style="margin-left: 20px;" target="_blank" href="', url3,'"', ">api.js</a>")
    ngx.say("</h2>")

    local base_list = utils.path_list("app/" .. app_name .. "/api")
    if #base_list > 0 then
        ngx.say("<h3>")
        local url = "/" .. app_name .. "/api"
        ngx.say('   <a href="', url,'"', ">", "全部", "</a>")
        for _, base in ipairs(base_list) do
            url = "/" .. app_name .. "/api?base=" .. base
            ngx.say([[<span style="margin-left: 10px;"> | <span>]])
            ngx.say('   <a style="margin-left: 10px;" href="', url,'"', ">", base, "</a>")
        end
        ngx.say("</h3>")
    end

    ngx.say("<table>")

    ngx.say("<tr>")
    ngx.say("   <th>#</th>")
    ngx.say("   <th>api</th>")
    ngx.say("   <th>act</th>")
    ngx.say("   <th>ver</th>")
    ngx.say("   <th>查看验参代码</a></th>")
    ngx.say("   <th>查看api.d.ts</a></th>")
    ngx.say("   <th>查看api.js</a></th>")
    ngx.say("   <th>错误信息</th>")
    ngx.say("</tr>")

    local list = {}

    load_path (list, base_path, "")
    table.sort(list)

    for i, name in ipairs(list) do
        local t = apix.load_api(base_name .. name)

        ngx.say("<tr>")
        ngx.say("   <th>", i , "</th>")
        ngx.say("   <th>", "$api." .. name, "</th>")

        ngx.say("   <td>")
        table.sort(t.actions)
        for _, act in ipairs(t.actions) do
            ngx.say("       <li>", act, "</li>")
        end
        ngx.say("   </td>")

        ngx.say("   <td>", t.ver, "</td>")

        local arg_api_name = (query == "" and "?" or "&") .. "api=" .. name

        if t.codes ~= "" then
            ngx.say("   <td><a ", 'target="_blank" href="', url1, arg_api_name ,'"', ">验参代码</a></td>")
        else
            ngx.say("   <td> </td>")
        end

        ngx.say("   <td><a ", 'target="_blank" href="', url2, arg_api_name ,'"', ">api.d.ts</a></td>")
        ngx.say("   <td><a ", 'target="_blank" href="', url3, arg_api_name ,'"', ">api.js</a></td>")

        ngx.say("   <td>", t.err , "</td>")
        ngx.say("</tr>")
    end

    ngx.say("</table>")

    ngx.say [[
</body>
</html>
]]

end
