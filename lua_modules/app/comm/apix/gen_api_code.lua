
-- 生成参数校验函数代码

local apix      = require "app.comm.apix"
local _split    = require "ngx.re".split

local function _err(api, codes, err)
-- @api     : string
-- @codes   : string
-- @err     : string
-- @return  : void

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

local function print_html()
-- @return : void

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
end

-- 生成 api 验参代码
return function(app_name, base_name, api_name)
-- @app_name    : string
-- @base_name ? : string
-- @api_name  ? : string
-- @return      : void

    base_name = base_name or ngx.req.get_uri_args().base or ""
    api_name  = api_name  or ngx.req.get_uri_args().api  or nil

    local query = base_name ~= "" and ("?base=" .. base_name) or ""

    local api_list, base_list = apix.load_apis(app_name, base_name)
    if not api_list then return ngx.exit(404) end

    if type(api_name) == "string" then
        ngx.header['content-type'] = "text/plain"
        for _, t in ipairs(api_list) do
            if t.name == api_name then
                if t.ok then
                    ngx.header['language'] = "lua"
                    ngx.say(t.codes)
                else
                    _err(t.name, t.codes, t.err)
                end
                return
            end
        end
        return ngx.exit(404)
    end

    print_html()

    local url1 = "/" .. app_name .. "/api"      .. query
    local url2 = "/" .. app_name .. "/api.d.ts" .. query
    local url3 = "/" .. app_name .. "/api.js"   .. query

    ngx.say("<h2>", app_name, "项目API列表")

    ngx.say('   <a style="margin-left: 30px;" target="_blank" href="', url2,'"', ">api.d.ts</a>")
    ngx.say('   <a style="margin-left: 20px;" target="_blank" href="', url3,'"', ">api.js</a>")
    ngx.say("</h2>")

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

    for i, t in ipairs(api_list) do

        ngx.say("<tr>")
        ngx.say("   <th>", i , "</th>")
        ngx.say("   <th>", "$api" .. (t.name ~= "" and "." or "") .. t.name, "</th>")

        ngx.say("   <td>")

        for _, act in ipairs(t.actions) do
            ngx.say("       <li>", act, "</li>")
        end
        ngx.say("   </td>")

        ngx.say("   <td>", t.ver, "</td>")

        local arg_api_name = (query == "" and "?" or "&") .. "api=" .. t.name

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

    ngx.say ("</table>")
    ngx.say ("</body>")
    ngx.say ("</html>")

end
