
local lfs           = require "lfs"
local _load         = _load
local setmetatable  = setmetatable
local rawset        = rawset
local type          = type
local _gsub         = string.gsub

local api = { _VERSION = '21.12.25' }
------------------------------------------------------

-- 检查是否目录
local function is_directory(name)

    local app_name = ngx.ctx.app_name
    if type(app_name) ~= "string" then return end

    local path = "app/" .. app_name .. "/" .. _gsub(name, "%.+", "/")
    local attr = lfs.attributes(path) or {}

    return attr.mode == "directory"

end

-- API模块构造器
local function API(t, pname)

    return setmetatable(t, {

        __index = function(self, key)

            local name = (pname and (pname .. ".") or "") .. key
            local mod  = _load("api." .. name)

            -- 如果是目录: 支持下级目录或文件懒加载
            if mod == nil or type(mod) == "table" then
                if is_directory("api." .. name) then
                    mod = API(mod or {}, name)
                end
            end

            rawset(self, key, mod)
            return mod
        end,

        __call = function(self)

            if pname then
                return nil, "接口不存在：" .. pname
            else
                return nil, "接口不存在"
            end

        end

    })

end

------------------------------------------------------
return API(api)
