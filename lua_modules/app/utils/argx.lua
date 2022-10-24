
-- 验证参数 v16.10.01 by Killsen ------------------

local _json     = require("cjson").decode
local _md5      = ngx.md5
local _crc32    = ngx.crc32_short
local _find     = ngx.re.find
local _gsub     = string.gsub
local _upper    = string.upper
local _lower    = string.lower
local _len      = string.len
local _num      = tonumber
local _str      = tostring

local function _trim  (s) return _gsub(s, "^%s*(.-)%s*$", "%1") end -- 清除两边的空格
local function _ltrim (s) return _gsub(s, "^%s*(.-)",     "%1") end -- 清除左边的空格
local function _rtrim (s) return _gsub(s,     "(.-)%s*$", "%1") end -- 清除右边的空格

-- 是否存在列表中
local function _enum(v1, ...)
    for _, v2 in ipairs({...}) do
        if type(v2) == "number" then
            if _num(v1) == v2 then return v2 end
        elseif type(v2) == "string" then
            if _str(v1) == v2 then return v2 end
        end
    end
end

-- 不能存在列表中
local function _notin(v1, ...)
    for _, v2 in ipairs({...}) do
        if type(v2) == "number" then
            if _num(v1) == v2 then return false end
        elseif type(v2) == "string" then
            if _str(v1) == v2 then return false end
        end
    end
    return true
end

-- 正则表达式或验证函数映射
local _MAPX_    = { _

    -- 预定义的正则表达式
    ,   email   = --[[电子邮件]]    [[^\w+([-+.]\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*$]]
    ,   ip      = --[[IP地址  ]]  [[^((2[0-4]\d|25[0-5]|[01]?\d\d?)\.){3}(2[0-4]\d|25[0-5]|[01]?\d\d?)$]]
    ,   phone   = --[[电话号码]]    [[^(\d{4}-|\d{3}-)?(\d{8}|\d{7})$]]
    ,   mobile  = --[[手机号码]]    [[^1\d{10}$]]         -- 1开头(11位数字)
    ,   qq      = --[[腾讯QQ号]]   [[^[1-9][0-9]{4,8}$]] -- 从10000开始(5-9位数字)

    ,  ["="  ]  = function(a, b)    return a or b end -- 默认值
    ,  ["==" ]  = function(a, b)    return a == b end -- 值相等
    ,  ["~=" ]  = function(a, b)    return a ~= b end -- 值不等

    -- 数字加减乘除
    ,  ["+"  ]  = function(a, b)    return _num(a) +  _num(b) end -- 加法
    ,  ["-"  ]  = function(a, b)    return _num(a) -  _num(b) end -- 减法
    ,  ["*"  ]  = function(a, b)    return _num(a) *  _num(b) end -- 乘法
    ,  ["/"  ]  = function(a, b)    return _num(a) /  _num(b) end -- 除法

    -- 数字大小验证函数
    ,  [">"  ]  = function(a, b)    return _num(a) >  _num(b) and _num(a) end
    ,  [">=" ]  = function(a, b)    return _num(a) >= _num(b) and _num(a) end
    ,  ["<"  ]  = function(a, b)    return _num(a) <  _num(b) and _num(a) end
    ,  ["<=" ]  = function(a, b)    return _num(a) <= _num(b) and _num(a) end

    -- 连接字符串
    ,  [".." ]  = function(a, b)    return a and a .. b      or nil end
    ,  ["..."]  = function(a, b, c) return a and b .. a .. c or nil end

    -- 字符串长度验证函数
    ,  ["#"  ]  = function(a, b, c) return _len(a) >= _num(b) and
                                           _len(a) <= _num(c) end
    ,  ["#=" ]  = function(a, b)    return _len(a) == _num(b) end
    ,  ["#>" ]  = function(a, b)    return _len(a) >  _num(b) end
    ,  ["#>="]  = function(a, b)    return _len(a) >= _num(b) end
    ,  ["#<" ]  = function(a, b)    return _len(a) <  _num(b) end
    ,  ["#<="]  = function(a, b)    return _len(a) <= _num(b) end

    ,  ["#A" ]  = _upper,   upper = _upper -- 转大写
    ,  ["#a" ]  = _lower,   lower = _lower -- 转小写

    ,  ["{}"  ] = _enum,    enum  = _enum  -- 是否存在列表中
    ,  ["}{" ]  = _notin,   notin = _notin -- 不能存在列表中

    ,   trim    = _trim     -- 清除两边的空格
    ,   ltrim   = _ltrim    -- 清除左边的空格
    ,   rtrim   = _rtrim    -- 清除右边的空格

    ,   md5     = _md5      -- 计算md5码
    ,   crc32   = _crc32    -- 计算crc32码
    ,   json    = _json     -- json字符串 -> table
}

-- 验证参数
local function _valx(v, x)

    -- v = "abcde"
    -- x = {"#", {2, 8}, "参数2~8位"}

    local ok, err, k = true, "参数错误", #x

    if k > 1 and type(x[k])=="string" then
        err = x[k]~="" and x[k] or err -- 取最后一位做为错误信息
        k = k - 1
    end

    for i=1, k do
        local f, p, r = x[i], x[i+1], nil

            f = type(f) == "string" and _MAPX_[f] or f  --> "#"
            p = type(p) == "table"  and p or {}         --> {2, 8}

            if type(f) == "string" then
                if type(v) == "string" then
                    ok = _find(v, f) -- 验证正则表达式
                else
                    ok = false
                end
            elseif type(f) == "function" then
                ok, r = pcall(f, v, unpack(p)) -- 执行验证函数
                if not ok then
                --  err = err .. r  -- 验证程序出错：输出错误信息
                elseif not r then
                    ok = false      -- 验证不通过
                elseif r~=true then
                    v = r           -- 验证通过，并返回新的值
                end
            end

        if not ok then break end
    end

    return ok, v, err

end

-- 验证参数列表
local function _argx(argx, args)

    local resx, errs = {}, {}
    local null_exist = false

    for i, f in ipairs(argx) do
        -- { name="uid", text="账号", type="text", vali={ "len", {2,8}, "账号2-8位" } }

        if not f.name then null_exist = true end --> 出现空表后：不验证参数 v16.10.01

        local k = f.name
        local v = args[k]
        local x = not null_exist and f.vali

        if type(x)=="table" then
            local ok, res, err = _valx(v, x) -- 验证参数
            if ok and res then v = res end
            if not ok then errs[k] = err end

        elseif type(x)=="function" then
            local ok, res = pcall(x, v) -- 直接通过函数取值
            if ok and res then v = res
            else errs[k] = "参数错误" end

        elseif type(x)=="string" then -- 直接检查是否存在参数
            if v==nil or v=="" then errs[k] = x end
        end

        resx[i] = v
    end

    if not next(errs) then errs = nil end
    return resx, errs

end

return _argx
