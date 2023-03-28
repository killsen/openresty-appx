
local __ = {}

-- 清除字符串的头尾空白符
__.trim = function (s)
-- @s       : string
-- @return  : string

    if type(s) ~= "string" or s == "" then
        return ""
    end

    return (s:gsub("^%s*(.-)%s*$", "%1"))

end

-- 清除字符串的左边空白符
__.ltrim = function (s)
-- @s       : string
-- @return  : string

    if type(s) ~= "string" or s == "" then
        return ""
    end

    return (s:gsub("^%s+", ""))

end

-- 清除字符串的右边空白符
__.rtrim = function (s)
-- @s       : string
-- @return  : string

    if type(s) ~= "string" or s == "" then
        return ""
    end

    return (s:gsub("%s+$", ""))

end

-- 清除字符串头尾及中间的空白符，如果结果是空字符串则返回 nil
__.strip = function (s)
-- @s       : string
-- @return  : string?

    if type(s) ~= "string" or s == "" then
        return nil
    end

    local res = (s:gsub("%s", ""))
    if res == "" then return nil end

    return res

end

-- 检查是否以指定字符串开头 v22.11.15 by 朱国华
__.startsWith = function (str, startStr)
-- @str         : string
-- @startStr    : string
-- @return      : boolean

    if type(str)      ~= 'string' then return false end
    if type(startStr) ~= 'string' then return false end

    return startStr == string.sub(str, 1, string.len(startStr))
end

-- 检查是否以指定字符串结尾 v22.11.15 by 朱国华
__.endsWith = function (str, endStr)
-- @str         : string
-- @endStr      : string
-- @return      : boolean

    if type(str)    ~= 'string' then return false end
    if type(endStr) ~= 'string' then return false end

    return endStr == string.sub(str, string.len(endStr) * -1)
end

return __
