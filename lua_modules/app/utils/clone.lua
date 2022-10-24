
local table_clone = require "table.clone"

-- 深度克隆对象 v20.08.19
local function _clone(t, max_level, cur_level)

    t = table_clone(t)

    if cur_level >= max_level then return t end

    for k, v in pairs(t) do
        if type(v) == "table" then
            t[k] = _clone(v, max_level, cur_level+1)
        end
    end

    return t

end

return function(t, max_level)

    if type(t) ~= "table" then return t end

    -- 最多克隆5层：避免死循环
    max_level = tonumber(max_level) or 5

    return _clone(t, max_level, 1)

end
