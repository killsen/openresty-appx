
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

return __
