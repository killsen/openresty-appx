-- @@api : openresty-vsce

local pcall         = pcall
local dofile        = dofile
local type          = type
local rawset        = rawset
local setmetatable  = setmetatable
local getinfo       = debug.getinfo
local gsub          = string.gsub
local sub           = string.sub
local lower         = string.lower

local __ = { __VERSION = "v1.0.0" }

-- 检查目录是否存在
local function path_exists(path)
    local file, err = io.open(path)
    if file then file:close() end
    if err and sub(err, -6) == "denied" then
        -- 如果目录存在错误信息以 Permission denied 结尾
        return true
    end
end

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
            local exists   = path_exists(apipath)

            local pok, mod = pcall(dofile, filename)
            if not pok then
                filename = apipath .. "/init.lua"
                pok, mod = pcall(dofile, filename)
                if not pok and exists then
                    mod = {}  -- 目录存在: 创建空表
                end
            end

            if type(mod) == "table" then
                __.gen_valid_func(mod)
                rawset(mod, "__filename", filename)
                if exists then -- 目录存在: 创建API模块
                    mod = __.new(mod, apipath)
                end
            end

            rawset(self, key, mod)
            return mod
        end,

        __call = function(self)
            return nil, "API Not Found: " .. path
        end

    })

end

-- 生成API模块
__.new(__)

return __
