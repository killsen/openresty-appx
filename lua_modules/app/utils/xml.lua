
local _concat = table.concat
local _find   = ngx.re.find
local _sub    = string.sub

local __ = { _VERSION = "v1.0.0" }

__._README = [==[
# app.utils.xml

一个非常简单的 xml 与 table 转换的工具

```lua
local utils = require "app.utils"
local obj   = utils.xml.from_xml(xml)   -- xml 转成 table
local xml   = utils.xml.to_xml(obj)     -- table 转成 xml
```
]==]

__._TESTING = function()

    local utils = require "app.utils"

    -- xml 转成 table
    local obj = utils.xml.from_xml [[
    <xml>
        <name>OpenResty</name>
        <website>https://openresty.org/</website>
    </xml>
    ]]

    -- table 转成 xml
    local xml = utils.xml.to_xml {
        name    = "OpenResty",
        website = "https://openresty.org/",
    }

    -- ngx.say(xml)

    assert(xml == utils.xml.to_xml(obj))

    return obj

end

--  <key><![CDATA[val]]></key>
--  <(\w+) > <! [CDATA [(.+) ] ] > </\1 >
-- \<(\w+)\>\<!\[CDATA\[(.+)\]\]\>\</\1\>
local regx = [==[\<(\w+)\>([\s\S]*)\</\1\>]==]
local regy = [==[^\s*\<!\[CDATA\[([\s\S]*)\]\]\>\s*$]==]

-- xml 字符串转成 table 对象
 __.from_xml = function (xml, root)
-- @xml     : string
-- @root    : string
-- @return  : table

    if type(xml)~="string" or xml=="" then return nil end

    -- j : 启用JIT编译; o : 仅编译一次; i : 大小写不敏感
    local  it, err = ngx.re.gmatch(xml, regx, "jo")
    if not it then return nil, err end

    local obj

    while true do
        local m, err2 = it()
        if err2 then return nil, err2 end
        if not m then break end

        local k, v = m[1], m[2]
            local m2 = ngx.re.match(v, regy, "jo")
            v = m2 and m2[1] or __.from_xml(v, false) or v
        obj = obj or {}; obj[k] = v
    end

    if root == nil then root = "xml" end
    return obj and root and obj[root] or obj

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

-- table 对象转成 xml 字符串
__.to_xml = function (obj, root)
-- @obj     : table
-- @root    : string
-- @return  : string

    root = root or "xml"

    local xml, i = {}, 0

    i=i+1; xml[i] = "<".. root ..">"
        for k, v in pairs(obj) do
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
