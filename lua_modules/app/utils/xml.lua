
local _concat = table.concat
local _find   = ngx.re.find
local _sub    = string.sub

local __ = {}

--  <key><![CDATA[val]]></key>
--  <(\w+) > <! [CDATA [(.+) ] ] > </\1 >
-- \<(\w+)\>\<!\[CDATA\[(.+)\]\]\>\</\1\>
local regx = [==[\<(\w+)\>([\s\S]*)\</\1\>]==]
local regy = [==[^\s*\<!\[CDATA\[([\s\S]*)\]\]\>\s*$]==]

--xml转成table
 __.from_xml = function (xml, root)

    if type(xml)~="string" or xml=="" then return nil end

    -- j : 启用JIT编译; o : 仅编译一次; i : 大小写不敏感
    local  it, err = ngx.re.gmatch(xml, regx, "jo")
    if not it then return nil, err end

    local t

    while true do
        local m, err2 = it()
        if err2 then return nil, err2 end
        if not m then break end

        local k, v = m[1], m[2]
            local m2 = ngx.re.match(v, regy, "jo")
            v = m2 and m2[1] or __.from_xml(v, false) or v
        t = t or {}; t[k] = v
    end

    if root == nil then root = "xml" end
    return t and root and t[root] or t

end

local function get_key (key)

    local  from = _find(key, "(\\s+)", "jo")    -- 出现第一个空格（xml的属性）
    return from and _sub(key, 1, from-1) or key

end

local function get_val (val)

    if type(val) ~= "string" then
        return tostring(val)

    elseif _find(val, "<", "jo") then  -- 包含 <
        return "<![CDATA[" .. val .. "]]>"

    else
        return val
    end

end

--table转成xml
__.to_xml = function (t, root)

    root = root or "xml"

    local xml, i = {}, 0

    i=i+1; xml[i] = "<".. root ..">"
        for k, v in pairs(t) do
            if type(v)=="table" then
                i=i+1; xml[i] = __.to_xml(v, k)
            else
                i=i+1; xml[i] = "<"  .. k          ..   ">"
                                     .. get_val(v) ..
                                "</" .. get_key(k) ..   ">"
            end
        end
    i=i+1; xml[i] = "</".. get_key(root) ..">"

    return _concat(xml, "\n")

end

return __
