
local __ = {}

__.trim = function (s)

    if type(s) ~= "string" or s == "" then
        return ""
    end

    return (s:gsub("^%s*(.-)%s*$", "%1"))

end

__.ltrim = function (s)

    if type(s) ~= "string" or s == "" then
        return ""
    end

    return (s:gsub("^%s+", ""))

end

__.rtrim = function (s)

    if type(s) ~= "string" or s == "" then
        return ""
    end

    return (s:gsub("%s+$", ""))

end

__.strip = function (s)

    if type(s) ~= "string" or s == "" then
        return nil
    end

    local res = (s:gsub("%s", ""))
    if res == "" then return nil end

    return res

end

-- 检查是否以指定字符串开头 v22.11.15 by 朱国华
__.startsWith = function (str, startStr)
    if type(str)      ~= 'string' then return false end
    if type(startStr) ~= 'string' then return false end

    return startStr == string.sub(str, 1, string.len(startStr))
end

-- 检查是否以指定字符串结尾 v22.11.15 by 朱国华
__.endsWith = function (str, endStr)
    if type(str)    ~= 'string' then return false end
    if type(endStr) ~= 'string' then return false end

    return endStr == string.sub(str, string.len(endStr) * -1)
end

return __
