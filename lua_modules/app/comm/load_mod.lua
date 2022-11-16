
-- 模块加载器 ------------------

local require   = require
local pcall     = pcall
local ssub      = string.sub

-- 生成参数校验函数接口
local gen_valid_func

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
    local ok, mod = pcall(require, mod_name)

    if ok and mod then
        -- 生成参数校验函数接口
        if is_api and type(mod) == "table" then
            if not gen_valid_func then
                gen_valid_func = require "app.comm.apix".gen_valid_func
            end
            gen_valid_func(mod)
        end
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

