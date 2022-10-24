
-- 执行程序 v18.10.24 by Killsen ------------------

local require        = require
local templ          = require "resty.template"
local cjson          = require "cjson.safe"

--空表编码为array还是object v16.10.14
cjson.encode_empty_table_as_object(false) -- 空表 >> []

local templ_render   = templ.render
local cjson_encode   = cjson.encode
local cjson_pretty   = require "resty.prettycjson"

local iputils        = require "app.utils.iputils"
iputils.enable_lrucache() -- 启动IP缓存

local parse_cidrs    = iputils.parse_cidrs
local binip_in_cidrs = iputils.binip_in_cidrs

local split          = require "app.utils".split      -- 分隔字符串
local file_name      = require "app.utils".file_name  -- 获取文件名
local exe_name       = require "app.utils".exe_name   -- 获取扩展名
local _argx          = require "app.utils.argx"       -- 参数验证

------------------------------------------------------

local html_err = [[
<!doctype html>
<html>
    <head><title>出错啦</title></head>
    <body>
        <h1>出错啦</h1>
        <h3>错误编码：{{ code }}</h3>
        <h3>错误信息：{{ err  }}</h3>
    </body>
</html>
]]

local html_form = [[
<h2>{{name}} {{page}}</h2>
<form action="{{action}}.{{page}}" method="get">
{% for _, f in ipairs(argx) do %}
  {% if f.name then %}
    <label>{{f.text}}:</label>
    <input name="{{f.name}}" type="{{f.type}}" value="{{f.value}}"> ({{f.name}}) -- {*encode(f.vali)*}
    <br><br>
  {% end %}
{% end %}
    <input type="submit" value="提交">
</form>
]]

local function _show_form(name, argx, action_name, action_type)

    if action_type == "lform" then

        ngx.header["content-type"] = "text/html; charset=utf-8"

        local ctx =  { name = name,  action = action_name, encode = cjson_encode }

        if argx.add  then ctx.page="add";    ctx.argx=argx.add;   templ_render(html_form, ctx) end
        if argx.del  then ctx.page="del";    ctx.argx=argx.del;   templ_render(html_form, ctx) end
        if argx.set  then ctx.page="set";    ctx.argx=argx.set;   templ_render(html_form, ctx) end
        if argx.get  then ctx.page="get";    ctx.argx=argx.get;   templ_render(html_form, ctx) end
        if argx.list then ctx.page="list";   ctx.argx=argx.list;  templ_render(html_form, ctx) end
    if not ctx.page  then ctx.page="lpage";  ctx.argx=argx;       templ_render(html_form, ctx) end

    else

        ngx.header["content-type"] = "application/json; charset=utf-8"
        ngx.print ( cjson_encode (argx) ) --输出JSON

    end

end

local function _get_args(argx)

    local args = ngx.req.get_uri_args()

        if ngx.req.get_method()=="POST" then
            ngx.req.read_body()
            local arg2 = ngx.req.get_post_args()
            for k, v in pairs(arg2) do
                args[k] = v
            end
        end

    return _argx(argx, args)

end

local function _do_action(argx, actx)

    if argx then
        local args, errs = _get_args(argx)
        if errs then return {ok=false, err=errs} end
        return actx( unpack(args,1,#argx) ) -- 避免nil参数
    else
        return actx()
    end

end

local function _response (res, html, action_type)

    -- 无任何内容输出
    if res==nil then return end

    -- 直接输出
    if type(res) ~= "table" then
        ngx.header["content-type"] = "text/html; charset=utf-8"
        return ngx.print (res)
    end

    if action_type == "lpage" and type(html) == "string" then
        ngx.header["content-type"] = "text/html; charset=utf-8"
        templ_render ( html, res ) -- 输出网页

    elseif action_type == "jsonp" then
        local args = ngx.req.get_uri_args()
        local cb   = args.callback or "callback"
        ngx.header["content-type"] = "application/javascript; charset=utf-8"
        ngx.print ( cb , "(" , cjson_encode (res) , ")" ) -- 输出JS
    elseif action_type == "jsony" then
        ngx.header["content-type"] = "application/json; charset=utf-8"
        ngx.print ( cjson_pretty (res) ) --输出JSON（格式美化）
    else
        ngx.header["content-type"] = "application/json; charset=utf-8"
        ngx.print ( cjson_encode (res) ) --输出JSON
    end

end

-- 通过调试代码创建模块 v18.10.21
local function get_debug_mod(mod)

    if ngx.req.get_method()=="POST" then
         -- 读取上传的代码
                      ngx.req.read_body()
        local  code = ngx.req.get_body_data()
        if not code then return end

        -- 载入lua代码
        local  func, err = loadstring(code)
        if not func then ngx.print(err); return end

        -- 运行lua代码
        local  ok, debug_mod = pcall(func)
        if not ok then ngx.print(debug_mod); return end

        mod = debug_mod
    end

    -- 使用demo作为参数
    if type(mod)=="table" then

        if type(mod.demo)=="string" and mod.demo~="" then
            local m = ngx.re.match(mod.demo, "(.+)?\\?(.+)")
            if m then
                ngx.req.set_uri     ( m[1] ) -- 重写路径
                ngx.req.set_uri_args( m[2] ) -- 重写参数
            else
                ngx.req.set_uri ( mod.demo ) -- 重写路径
            end

        elseif type(mod.demo)=="table" then
            ngx.req.set_uri_args(mod.demo)

        elseif type(mod.argx)=="table" then
            local demo = {}
            for _, x in ipairs(mod.argx) do
                demo[x.name] = x.value
            end
            ngx.req.set_uri_args(demo)
        end
    end

    return mod

end

-- 执行程序
local function _run_app ( app, is_sublime )

    -- 获取path
    local path = split (ngx.var.uri, "/")
    local action_name = file_name ( path[#path] )
    local action_type = exe_name  ( path[#path] )

    -- 获取action
    if not action_name then
        _response(
            {ok=false, code="not_found", err="路径不存在"},
            html_err, action_type
        )
        return
    end

    local mod, argx, actx, auth, _url

    if is_sublime then
        mod = app.load("act." .. action_name, true)
        mod = get_debug_mod(mod) -- 通过调试代码创建模块
    else
        mod = app.load("act." .. action_name)
    end

    if type(mod) == "table" then
        argx, actx, auth, _url = mod.argx, mod.actx, mod.auth, mod._url

        if mod.host then --检查IP地址
        -- 如设定为 127.0.0.1      则表示只能本机访问
        -- 如设定为 192.168.0.0/16 则表示局域网可访问

            mod._host_ip_list = mod._host_ip_list
              or parse_cidrs ( type(mod.host)=="table" and mod.host or { mod.host } )

            if not binip_in_cidrs(ngx.var.binary_remote_addr, mod._host_ip_list) then
                return ngx.exit(403) -- Forbidden （不在IP列表不允许访问）
            end
        end

        -- 输出表单
        if action_type=="lform" or action_type=="jform" then
            _show_form(mod.name, argx, action_name, action_type)
            return
        end

        if type(argx)=="table" and type(actx) == "table" then
                if action_type == "add"  then argx, actx = argx.add,  actx.add
            elseif action_type == "del"  then argx, actx = argx.del,  actx.del
            elseif action_type == "set"  then argx, actx = argx.set,  actx.set
            elseif action_type == "get"  then argx, actx = argx.get,  actx.get
            elseif action_type == "list" then argx, actx = argx.list, actx.list
               end
        end

    elseif type(mod) == "function" then
        actx = mod
    end

    -- 检查action
    if type(actx) ~= "function" then
        _response(
            {ok=false, code="not_found", err="路径不存在"},
            html_err, action_type
        )
        return
    end

    -- 检查权限
    if auth then
        local _name  = type(auth)=="string"   and auth or nil
        local _allow = type(auth)=="function" and auth or app.auth_allow

        if _allow == nil then
            local _auth = app.load("%auth")
            _allow = type(_auth)=="table" and _auth.allow
            _allow = type(_allow)=="function" and _allow or false
            app.auth_allow = _allow
        end

        if type(_allow)=="function" then
            local  ok, err, code = _allow(_name)
            if not ok then -- 授权不通过则退出
                if app.unload then app.unload() end -- 卸载程序

                if type(_url) == "string" and action_type=="lpage" then
                    ngx.redirect(_url) -- 跳转
                else
                    _response(
                        {   ok   = false, url = _url,
                            code = code or "not_allowed",
                            err  = err  or "尚未登录系统或权限不足"
                        },
                        html_err, action_type)
                end
                return
            end
        end
    end

    local res, html = _do_action(argx, actx)

    if app.unload then app.unload() end -- 卸载程序
    _response(res, html, action_type)

end

-- 程序入口
local function run_app ( app )

    -- 是否sublime测试 v18.10.24
    local is_sublime = ngx.var.remote_addr  == "127.0.0.1" and
                       ngx.req.get_headers()["user-agent"] == "sublime"
    local is_debug   = is_sublime and ngx.req.get_method() == "GET"

    if is_debug then require "mobdebug".start() end

    if ngx.var.lua_debug == "on" then require "LuaDebug".start() end

    --[[ 程序入口 ]] _run_app ( app, is_sublime )

    if ngx.var.lua_debug == "on" then require "LuaDebug".stop() end

    if is_debug then require "mobdebug".done() end

end

------------------------------------------------------
return run_app -- 返回方法
