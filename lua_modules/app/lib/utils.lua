
local __ = { _VERSION = "v22.08.06" }

local type    = type
local _insert = table.insert
local _concat = table.concat
local _gsub   = string.gsub


local function _copy(into, from, keys)

    if keys == nil then
        for k, v in pairs(from) do
            into[k] = v
        end

    elseif type(keys) == "string" then
        into[keys] = from[keys]

    elseif type(keys) == "table" then
        for k, v in pairs(keys) do
            if type(k) == "number" and type(v) == "string" then
                into[v] = from[v]
            elseif type(k) == "string" and type(v) == "string" then
                into[k] = from[v]
            end
        end
    end

end

__.copy = function(into, from, keys, ...)

    into = into or {}

    _copy(into, from, keys)

    for _, key in ipairs {...} do
        _copy(into, from, key)
    end

    return into

end

-- 将指定的key列表的值列表合并
__.concat_by_keys = function(t, keys, sep)

    if type(t) ~= "table" then return nil end

    if type(keys) == "table" and #keys == 1 then
        keys = keys[1]
    end

    if type(keys) ~= "table" then
        return tostring(t[keys])
    end

    local vals = {}

    for i, k in ipairs(keys) do
        vals[i] = tostring(t[k])
    end

    return _concat(vals, sep or "/")

end

-- 将列表转换成group
__.list_to_group = function(list, keys)

    local group = {}

    for _, d in ipairs(list) do
        local k = __.concat_by_keys(d, keys)
        if k then
            group[k] = group[k] or {}
            _insert(group[k], d)
        end
    end

    return group

end

-- 将列表转换成dict
__.list_to_dict = function(list, keys)

    local dict = {}

    for _, d in ipairs(list) do
        local k = __.concat_by_keys(d, keys)
        if k then dict[k] = d end
    end

    return dict

end

local function gen_on_keys(on_keys)

    local into_keys, from_keys

    if type(on_keys) == "string" then
        into_keys = on_keys
        from_keys = on_keys

    elseif type(on_keys) == "table" then
        into_keys = {}
        from_keys = {}

        for k, v in pairs(on_keys) do
            if type(v) == "string" then
                if type(k) == "string" then
                    _insert(into_keys, k)
                    _insert(from_keys, v)
                elseif type(k) == "number" then
                    _insert(into_keys, v)
                    _insert(from_keys, v)
                end
            end
        end
    end

    return into_keys, from_keys

end

-- 合并数据
__.join = function(into_list, from_list, on_keys, join_keys, ...)

    if type(into_list) ~= "table" then return end
    if type(from_list) ~= "table" then return end

    local into_keys, from_keys = gen_on_keys(on_keys)

    local from_dict = __.list_to_dict(from_list, from_keys)

    for _, into in ipairs(into_list) do
        local key = __.concat_by_keys(into, into_keys)
        local from = from_dict[key]
        if from then __.copy(into, from, join_keys, ...) end
    end

    return into_list

end

__.clone = _load "#clone"
__.strip = _load "#str".strip
__.quote = ngx.quote_sql_str

-- 清除名称中的空字符串
__.strip_name = function(name)

    name = __.strip(name)
    if not name then return nil end

    name = _gsub(name, "%(", "（")
    name = _gsub(name, "%)", "）")

    return name

end

-- 清除值为空字符串的参数
__.strip_keys = function(t, keys, ...)

    if type(t) ~= "table" then return end

    if keys == nil then

        for k, v in pairs(t) do
            if type(k) == "string" and type(v) == "string" then
                t[k] = __.strip(v)
            end
        end

    elseif type(keys) == "string" then

        for _, k in ipairs {keys, ...} do
            t[k] = __.strip(t[k])
        end

    elseif type(keys) == "table" then

        for _, k in ipairs(keys) do
            t[k] = __.strip(t[k])
        end

    end

end

-- 生成待更新数据
__.gen_update = function(tNew, tOld, pkeys, ...)

    if type(tNew) ~= "table" then return nil end
    if type(tOld) ~= "table" then return nil end

    if type(pkeys) == "string" then
        pkeys = {pkeys, ...}
    end

    if type(pkeys) ~= "table" then return nil end
    if next(pkeys) == nil     then return nil end

    local tWhere, tUpdate = {}, {}

    for _, k in ipairs(pkeys) do
        pkeys[k]  = true
        tWhere[k] = tOld[k]  -- 更新条件
    end

    for k, v in pairs(tNew) do
        if not pkeys[k] and tOld[k] ~= nil and tOld[k] ~= v then
            tUpdate[k] = v  -- 新的数据
        end
    end

    tUpdate["create_time"] = nil
    tUpdate["CreateTime" ] = nil

    if next(tWhere)  == nil then return nil end
    if next(tUpdate) == nil then return nil end

    if tOld["update_time"] then
        tUpdate.update_time = ngx.localtime()
    end

    if tOld["UpdateTime"] then
        tUpdate.UpdateTime  = ngx.localtime()
    end

    tWhere[1] = tUpdate

    return tUpdate, tWhere

end

return __
