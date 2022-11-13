
local __ = {}

-- 获取调试文件或代码
__.get_debug_file = function()

    -- 仅用于本机调试
    if ngx.var.remote_addr ~= "127.0.0.1" or
        ngx.var.http_user_agent ~= "sublime" then
        return
    end

    -- 程序名称
    local app_name = ngx.var.http_app_name
    if app_name and app_name ~= "" then
        ngx.ctx.app_name = app_name
    end

    local file_name, codes

    -- 运行的lua文件
    file_name = ngx.var.http_file_name
    if not file_name and file_name == "" then return end

    ngx.ctx.file_name = file_name

    if ngx.req.get_method() == "POST" then
        ngx.req.read_body()
        codes = ngx.req.get_body_data()
    end

    return file_name, codes

end

-- 重新加载 appx
__.reload_appx = function()

    -- 清除已加载的 app.* 模块
    for k in pairs(package.loaded) do
        if type(k) == "string" then
            if string.sub(k, 1, 4) == "app." then
                package.loaded[k] = nil
            end
        end
    end

    return require "app.comm.appx"

end

-- 执行调试文件或代码
__.do_debug_file = function(file_name, codes)

    if not file_name then return end

    local pok, func

    if codes then
        pok, func = pcall(loadstring, codes)
    else
        pok, func = pcall(loadfile, file_name)
    end

    if not pok then return ngx.say(func) end

    local  pok, mod = pcall(func)
    if not pok then return ngx.say(mod) end

    if type(mod) ~= "table" then return end

    func = type(mod._TESTING) == "function" and mod._TESTING
        or type(mod.actx) == "function" and mod.actx

    if not func then return end

    local  pok, res = pcall(func)
    if not pok then return ngx.say(res) end

    if type(res) == "table" then
        ngx.header["content-type"] = "text/json"
        local encode = require "resty.prettycjson"
        ngx.print(encode(res))
    elseif res ~= nil then
        ngx.header["content-type"] = "text/plain"
        ngx.say(tostring(res))
    end

end

------------------------------------------------------
return __
