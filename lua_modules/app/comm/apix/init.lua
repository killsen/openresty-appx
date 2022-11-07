
local pcall         = pcall
local dofile        = dofile
local type          = type
local rawset        = rawset
local setmetatable  = setmetatable
local getinfo       = debug.getinfo
local gsub          = string.gsub
local sub           = string.sub
local lower         = string.lower

local __ = {}

-- API模块构造器
__.new = function(t, path)

    if type(t) ~= "table" then t = {} end

    if type(path) ~= "string" then
        local info = getinfo(2, "S")
        if sub(info.short_src, 1, 1) == "[" then
            path = ngx.ctx.file_name or ""  -- debug 模式使用
        elseif sub(info.source, 1, 1) == "@" then
            path = sub(info.source, 2)      -- 去掉第一个字符 @
        end
    end

    path = lower(path)
    path = gsub(path, "\\", "/")

    if sub(path, -9) == "/init.lua" then
        path = sub(path, 1, -10)
    elseif sub(path, -4) == ".lua" then
        path = sub(path, 1, -5)
    end

    rawset(t, "__apipath", path)

    return setmetatable(t, {

        __index = function(self, key)
            local apipath  = path .. "/" .. key
            local filename = apipath .. ".lua"

            local pok, mod = pcall(dofile, filename)
            if not pok then
                filename = apipath .. "/init.lua"
                pok, mod = pcall(dofile, filename)
                if not pok then mod = {} end
            end

            if type(mod) == "table" then
                __.gen_valid_func(mod)
                rawset(mod, "__filename", filename)
                mod = __.new(mod, apipath)
            end

            rawset(self, key, mod)
            return mod
        end,

        __call = function(self)
            return nil, "API Not Found: " .. path
        end

    })

end

__.gen_valid_func = require "app.comm.apix.gen_valid_func"
__.gen_valid_code = require "app.comm.apix.gen_valid_code"
__.gen_api_code   = require "app.comm.apix.gen_api_code"
__.gen_api_ts     = require "app.comm.apix.gen_api_ts"
__.gen_api_js     = require "app.comm.apix.gen_api_js"

return __
