
local file_list = require "app.comm.utils".file_list
local path_list = require "app.comm.utils".path_list

local _split    = require "ngx.re".split
local _insert   = table.insert
local _concat   = table.concat
local _sort     = table.sort
local _sub      = string.sub

local __ = { _VERSION = "v21.09.09" }

-- JavaScript 的保留字
local NAMEX = {
    ["delete"] = "delete$",
    ["class" ] = "class$",
}

__.get_namex = function(name)

    local names = _split(name, [[\.]])

    for i, n in ipairs(names) do
        names[i] = NAMEX[n] or n
    end

    return _concat(names, ".")

end

-- 加载 api 目录及其子目录下全部 lua 文件
__.load_path = function(list, path, name)

    -- 文件列表
    local flist = file_list (path)

    for _, f in ipairs(flist) do
        _insert(list, name .. f)
    end

    -- 目录列表
    local plist = path_list (path)

    for _, p in ipairs(plist) do
        __.load_path(list, path .. p .. "/",
                            name .. p .. ".")
    end

end

-- 取得 key 列表及最大长度
__.get_fun_keys = function(mod)

    local keys, max_len = {}, 0

    if type(mod) ~= "table" then return keys, max_len end

    for key, fun in pairs(mod) do
        if type(key) == "string" and _sub(key, 1, 1) ~= "_" and type(fun) == "function" then
            _insert(keys, key)
            if #key > max_len then max_len = #key end
        end
    end

    _sort(keys)

    return keys, max_len

end

-- 排序迭代器
__.sort_pairs = function(t)

    local keys, index = {}, 0

    for k, _ in pairs(t) do
        if type(k) == "string" or type(k) == "number" then
            _insert(keys, k)
        end
    end

    _sort(keys, function(a, b)

        if type(a) == type(b) then
            return a < b
        elseif type(a) == "number" then
            return true
        else
            return false
        end

    end)

    return function ()
        index = index + 1
        local k = keys[index]
        return k, t[k]
    end

end


return __
