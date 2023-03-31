
local __ = {}

-- 获取调试文件或代码
__.get_debug_file = function()
-- @return: file_name?: string, codes?: string

    -- 仅用于本机调试
    if ngx.var.remote_addr ~= "127.0.0.1" then return end

    -- 检查客户端
    local ua = ngx.var.http_user_agent
    if ua ~= "vscode" and ua ~= "sublime" then return end

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

    local appx = require "app.comm.appx"
    return appx

end

-- 执行调试文件或代码
__.do_debug_file = function(file_name, codes)
-- @file_name : string
-- @codes     : string
-- @return    : void

    if not file_name then return end

    local fun, err, pok, obj

    if codes then
        fun, err = loadstring(codes)                -- 加载代码
    else
        fun, err = loadfile(file_name)              -- 加载文件
    end
    if not fun then return ngx.print(err) end       -- 输出错误信息

    local debuger = require "app.comm.debuger"

    rawset(_G, "_PRINT_LOCAL_", debuger.debug)
    rawset(_G, "_PRINT_VALUE_", debuger.watch)

    pok, obj = pcall(fun)

    rawset(_G, "_PRINT_LOCAL_", nil)
    rawset(_G, "_PRINT_VALUE_", nil)

    if not pok then return ngx.print(obj) end       -- 输出错误信息

    if type(obj) == "table" then
        local apix = require "app.comm.apix"
        apix.gen_valid_func(obj)                    -- 生成验参函数

        if type(obj._TESTING) == "function" then
            pok, obj = pcall(obj._TESTING)          -- 运行测试代码
        elseif type(obj.actx) == "function" then
            pok, obj = pcall(obj.actx)              -- 运行操作代码
        end
    end

    if not pok then return ngx.print(obj) end       -- 输出错误信息

    if type(obj) == "string" then
        ngx.print(obj)
    elseif obj ~= nil then
        debuger.print(obj)
    end

end

------------------------------------------------------
return __
