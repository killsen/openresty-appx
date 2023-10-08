
-- 执行程序 v18.10.24 by Killsen ------------------

local ngx           = ngx
local require       = require
local templ         = require "resty.template"
local cjson         = require "cjson.safe"

local _split        = require "app.comm.utils".split      -- 分隔字符串
local file_name     = require "app.comm.utils".file_name  -- 获取文件名
local exe_name      = require "app.comm.utils".exe_name   -- 获取扩展名
local is_local      = require "app.comm.utils".is_local   -- 是否本机访问

--空表编码为array还是object v16.10.14
cjson.encode_empty_table_as_object(false) -- 空表 >> []

local templ_render   = templ.render
local cjson_encode   = cjson.encode
local cjson_pretty   = require "resty.prettycjson"

local iputils        = require "app.comm.iputils"
iputils.enable_lrucache() -- 启动IP缓存

local parse_cidrs    = iputils.parse_cidrs
local binip_in_cidrs = iputils.binip_in_cidrs

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

local function _response (res, html, action_type)
-- @res         : any
-- @html        : string
-- @action_type : string
-- @return      : void

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
-- @mod      : any
-- @return   : any

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

local APPX -- = require "app.comm.appx"

-- 执行程序
local function do_action (app_name, uri)
-- @app_name    : string
-- @uri       ? : string
-- @return      : void

    -- 延时加载 appx 避免相互应用
    if APPX == nil then APPX = require "app.comm.appx" end
    local app = APPX.new(app_name)
    if not app then return ngx.exit(404) end

    -- 获取path
    local path = _split (uri or ngx.var.uri, "/")
    local action_name = file_name ( path[#path] )
    local action_type = exe_name  ( path[#path] )

    -- 获取action
    if not action_name or action_name == "" then
        _response(
            {ok=false, code="not_found", err="路径不存在"},
            html_err, action_type
        )
        return
    end

    -- 是否本机调试
    local is_debug = is_local() and ngx.var.http_user_agent == "sublime"

    local mod

    if is_debug then
        mod = app:load_act(action_name, true)
        mod = get_debug_mod(mod) -- 通过调试代码创建模块
    else
        mod = app:load_act(action_name)
    end

    local actx

    if type(mod) == "table" then
        actx = mod.actx

        if mod.host then -- 检查IP地址
            if mod.host == "127.0.0.1" then
                -- 只能本机访问
                if not is_local() then return ngx.exit(403) end
            else
                -- IP地址段检查: 如 192.168.0.0/16 则表示局域网可访问
                mod._host_ip_list = mod._host_ip_list
                or parse_cidrs ( type(mod.host)=="table" and mod.host or { mod.host } )

                if not binip_in_cidrs(ngx.var.binary_remote_addr, mod._host_ip_list) then
                    return ngx.exit(403) -- Forbidden （不在IP列表不允许访问）
                end
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

    local pok, res, html = pcall(actx)
    if not pok then
        _response(
            {ok=false, code="not_found", err=res},
            html_err, action_type
        )
        return
    end

    _response(res, html, action_type)

end

------------------------------------------------------
return do_action -- 返回方法
