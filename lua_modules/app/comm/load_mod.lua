
-- 模块加载器 v21.08.26 by Killsen ------------------

local require   = require
local pcall     = pcall
local type      = type
local rawget    = rawget
local rawset    = rawset
local pairs     = pairs
local ipairs    = ipairs
local ssub      = string.sub

-- 生成参数校验函数接口
local gen_valid_func = require "app.comm.apix.gen_valid_func"

-- 模块懒加载
local function lazy_load (mod_name)

    -- 载入模块
    local ok, mod = pcall(require, mod_name)
    if not ok then return false, nil end

    -- 模块互相引用将返回数字类型的值
    if type(mod) ~= "number" then return true, mod end

    local is_loaded

    local function load_mod()

        if is_loaded then return end
           is_loaded = true

        ok, mod = pcall(require, mod_name)
        if not ok then return end

    end

    local t = { __LAZY = true }

    setmetatable(t, {

        __index = function(_, key)
            load_mod()
            local val = rawget(mod, key)
            if val ~= nil then
                rawset(t, key, val)
                return val
            else
                return mod[key]
            end
        end,

        __newindex = function(_, key, val)
            load_mod()
            mod[key] = val
        end,

        __call = function(_, ...)
            load_mod()
            return mod(...)
        end,

        __pairs = function ()
            load_mod()
            return pairs(mod)
        end,

        __ipairs = function ()
            load_mod()
            return ipairs(mod)
        end,

    })

    return true, t, true

end

local function load_mod (app_name, mod_name, reload_mod)

    -- 取出第一个字符
    local t = ssub (mod_name, 1, 1)
    local n = ssub (mod_name, 2   )

    -- 是否 api.* 接口
    local is_api = "api." == ssub(mod_name, 1, 4)

    if t=="#" then -- app.utils.*
        mod_name = "app.utils." .. n

    elseif t=="@" then -- app.app_name.action.*
        mod_name = "app." .. app_name .. ".act." .. n

    elseif t=="$" then -- app.app_name.dao.*
        mod_name = "app." .. app_name .. ".dao." .. n

    elseif t=="%" then -- app.app_name.comm.*
        mod_name = "app." .. app_name .. ".com." .. n

    else -- app.app_name.*
        mod_name = "app." .. app_name .. "." .. mod_name
    end

    -- 卸载模块
    if reload_mod then
        package.loaded[mod_name] = nil
    end

    -- 载入模块
    local ok, mod, is_lazy = lazy_load(mod_name)

    if ok and mod then
        -- 生成参数校验函数接口
        if is_api and not is_lazy then gen_valid_func(mod) end
        return mod, t

    elseif t=="$" and n and #n>0 then
        return { table_name=n }, t -- 返回空dao

    elseif t=="%" then
        -- 加载通用库: 不同app独立副本
        mod_name = "app.lib." .. n
        package.loaded[mod_name] = nil
        ok, mod = pcall(require, mod_name)
        package.loaded[mod_name] = nil
        if ok then return mod, t end
    end

end

---------------------------------------------------
return load_mod

