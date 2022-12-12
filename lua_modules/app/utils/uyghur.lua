
-- 维吾尔语，哈萨克语，柯尔克孜语基本区和扩展区转换函数类库
-- https://gitee.com/kerindax/UyghurCharUtils

-- Lua字符串和Lua正则
-- https://www.junmajinlong.com/lua/lua_str_regex/

-- Lua UTF8 库
-- https://github.com/starwing/luautf8

local ngx   = ngx
local utf8  = require "lua-utf8"
local u     = utf8.escape

local __ = { _VERSION = "v21.04.10 "}

local BASIC = 1  -- 基本区形式  A
local ALONE = 2  -- 单独形式    A
local HEAD  = 3  -- 头部形式    A_
local CENTR = 4  -- 中部形式   _A_
local REAR  = 5  -- 后部形式   _A

local CHARS = {
--    基本 ,  单独  ,  头部 ,  中部  ,  后部
--  {   A  ,   A   ,   A_  ,  _A_  ,   _A   }
    { 0x626, 0xfe8b, 0xfe8b, 0xfe8c, 0xfe8c }, -- 1 --- 00-Hemze
    { 0x627, 0xfe8d, 0xfe8d, 0xfe8e, 0xfe8e }, -- 0 --- 01-a
    { 0x6d5, 0xfee9, 0xfee9, 0xfeea, 0xfeea }, -- 0 --- 02-:e
    { 0x628, 0xfe8f, 0xfe91, 0xfe92, 0xfe90 }, -- 1 --- 03-b
    { 0x67e, 0xfb56, 0xfb58, 0xfb59, 0xfb57 }, -- 1 --- 04-p
    { 0x62a, 0xfe95, 0xfe97, 0xfe98, 0xfe96 }, -- 1 --- 05-t
    { 0x62c, 0xfe9d, 0xfe9f, 0xfea0, 0xfe9e }, -- 1 --- 06-j
    { 0x686, 0xfb7a, 0xfb7c, 0xfb7d, 0xfb7b }, -- 1 --- 07-q
    { 0x62e, 0xfea5, 0xfea7, 0xfea8, 0xfea6 }, -- 1 --- 08-h
    { 0x62f, 0xfea9, 0xfea9, 0xfeaa, 0xfeaa }, -- 0 --- 09-d
    { 0x631, 0xfead, 0xfead, 0xfeae, 0xfeae }, -- 0 --- 10-r
    { 0x632, 0xfeaf, 0xfeaf, 0xfeb0, 0xfeb0 }, -- 0 --- 11-z
    { 0x698, 0xfb8a, 0xfb8a, 0xfb8b, 0xfb8b }, -- 0 --- 12-:zh
    { 0x633, 0xfeb1, 0xfeb3, 0xfeb4, 0xfeb2 }, -- 1 --- 13-s
    { 0x634, 0xfeb5, 0xfeb7, 0xfeb8, 0xfeb6 }, -- 1 --- 14-x
    { 0x63a, 0xfecd, 0xfecf, 0xfed0, 0xfece }, -- 1 --- 15-:gh
    { 0x641, 0xfed1, 0xfed3, 0xfed4, 0xfed2 }, -- 1 --- 16-f
    { 0x642, 0xfed5, 0xfed7, 0xfed8, 0xfed6 }, -- 1 --- 17-:k
    { 0x643, 0xfed9, 0xfedb, 0xfedc, 0xfeda }, -- 1 --- 18-k
    { 0x6af, 0xfb92, 0xfb94, 0xfb95, 0xfb93 }, -- 1 --- 19-g
    { 0x6ad, 0xfbd3, 0xfbd5, 0xfbd6, 0xfbd4 }, -- 1 --- 20-:ng
    { 0x644, 0xfedd, 0xfedf, 0xfee0, 0xfede }, -- 1 --- 21-l
    { 0x645, 0xfee1, 0xfee3, 0xfee4, 0xfee2 }, -- 1 --- 22-m
    { 0x646, 0xfee5, 0xfee7, 0xfee8, 0xfee6 }, -- 1 --- 23-n
    { 0x6be, 0xfbaa, 0xfbac, 0xfbad, 0xfbab }, -- 1 --- 24-:h
    { 0x648, 0xfeed, 0xfeed, 0xfeee, 0xfeee }, -- 0 --- 25-o
    { 0x6c7, 0xfbd7, 0xfbd7, 0xfbd8, 0xfbd8 }, -- 0 --- 26-u
    { 0x6c6, 0xfbd9, 0xfbd9, 0xfbda, 0xfbda }, -- 0 --- 27-:o
    { 0x6c8, 0xfbdb, 0xfbdb, 0xfbdc, 0xfbdc }, -- 0 --- 28-v
    { 0x6cb, 0xfbde, 0xfbde, 0xfbdf, 0xfbdf }, -- 0 --- 29-w
    { 0x6d0, 0xfbe4, 0xfbe6, 0xfbe7, 0xfbe5 }, -- 1 --- 30-e
    { 0x649, 0xfeef, 0xfbe8, 0xfbe9, 0xfef0 }, -- 1 --- 31-i
    { 0x64a, 0xfef1, 0xfef3, 0xfef4, 0xfef2 }, -- 1 --- 32-y

    { 0x6c5, 0xfbe0, 0xfbe0, 0xfbe1, 0xfbe1 }, -- 0 --- kz o_
    { 0x6c9, 0xfbe2, 0xfbe2, 0xfbe3, 0xfbe3 }, -- 0 --- kz o^
    { 0x62d, 0xfea1, 0xfea3, 0xfea4, 0xfea2 }, -- 1 --- kz h
    { 0x639, 0xfec9, 0xfecb, 0xfecc, 0xfeca }, -- 1 --- kz c
}

for i, row in ipairs(CHARS) do
    for j, c in ipairs(row) do
        local s = utf8.char(c)
        CHARS[i][j] = s
        CHARS[s] = CHARS[i]
    end
end

-- 双目字列表，转换扩展区的时候需要替换
local SPECIAL = {
    { basic = u "%x0644%x0627", extend = u "%xfefc", link = u "%xfee0%xfe8e" },  --  LA
    { basic = u "%x0644%x0627", extend = u "%xfefb", link = u "%xfedf%xfe8e" },  -- _LA
}

-- 转换范围；不包含哈语的0x0621字母,问号,双引号和Unicode区域的符号
local convertRang   = u "[%x0622-%x064a%x0675-%x06d5]+"

-- 分割范围，有后尾的字符表达式
local suffixRang    = u "[^%x0627%x062F-%x0632%x0648%x0688-%x0699%x06C0-%x06CB%x06D5]"

-- 扩展区范围；FB50-FDFF ->区域A    FE70-FEFF -> 区域B
local extendRang    = u "[%xfb50-%xfdff%xfe70-%xfeff]"
local extendWords   = extendRang .. ".*" .. extendRang

-- 不包含扩展区中部包含空格字符集；FB50-FDFF ->区域A    FE70-FEFF -> 区域B
-- local rang = u "%xfb50-%xfdff%xfe70-%xfeff"
-- local notExtendRang = "[^" .. rang .. "%s]+(%s[^" .. rang .. "%s]+)*"
local notExtendRang = u "[^%xfb50-%xfdff%xfe70-%xfeff]+"

local symbolRang = "[}{><»«)([%]]"
local symbolList = {
    [')'] = '(',
    ['('] = ')',
    [']'] = '[',
    ['['] = ']',
    ['}'] = '{',
    ['{'] = '}',
    ['>'] = '<',
    ['<'] = '>',
    ['»'] = '«',
    ['«'] = '»',
}

-- 获取对应字母
local function getChar(ch, index)
    local c = CHARS[ch]
    return c and c[index] or ch
end

-- Ascii区反转
__.reverseAscii = function(source)

    local result = utf8.gsub(source, notExtendRang, function (word)
        word = utf8.reverse(word)

        return utf8.gsub(word, symbolRang, function (ch)
            return symbolList[ch] or ch;
        end)
    end)

    return result

end

-- 对象反转
__.reverseSubject = function(source)

    local result = utf8.gsub(source, ".+", function (word)
        return utf8.reverse(word)
    end)

    return result

end

-- 基本区 --转换-> 打印机（只反转维文）
__.basic2Printer = function(source)

    local result = __.basic2Extend(source)

    result = utf8.gsub(result, extendWords, function(words)
        words = utf8.reverse(words)     -- 先全部反转

        words = utf8.gsub(words, notExtendRang, function(other)
            return utf8.reverse(other)  -- 非维文再反转（还原）
        end)

        return words
    end)

    return result

end

-- 基本区 --转换-> 扩展区
__.basic2Extend = function(source)

    return utf8.gsub(source, convertRang, function(word)

        word = utf8.gsub(word, suffixRang,
            function(ch) return ch .. "  " end)

        word = utf8.gsub(word, "^%s*(.-)%s*$", "%1")

        word = ngx.re.gsub(word, [[(?<=^|\S\S)(\S\S)(?=$|\S\S)]],
            function(m) return getChar(m[1], ALONE) end)

        word = ngx.re.gsub(word, [[(?<=\S\S|^)(\S\S)\s]],
            function(m) return getChar(m[1], HEAD) end)

        word = ngx.re.gsub(word, [[\s(\S\S)\s]],
            function(m) return getChar(m[1], CENTR) end)

        word = ngx.re.gsub(word, [[\s(\S\S)(?=\S\S|$)]],
            function(m) return getChar(m[1], REAR) end)

        for _, sp in ipairs(SPECIAL) do
            word = utf8.gsub(word, sp.link, sp.extend)
        end

        return word

    end)

end

-- 扩展区 --转换-> 基本区
__.extend2Basic = function(source)

    for _, sp in ipairs(SPECIAL) do
        source = utf8.gsub(source, sp.extend, sp.basic)
    end

    return utf8.gsub(source, extendRang, function(ch)
        return getChar(ch, BASIC)
    end)

end

-- 基本区 --转换-> 反向扩展区
__.basic2RExtend = function(source)

    local result = __.basic2Extend(source)
          result = __.reverseSubject(result)
          result = __.reverseAscii(result)
    return result

end

-- 反向扩展区 --转换-> 基本区
__.rextend2Basic = function(source)

    local result = __.reverseAscii(source)
          result = __.reverseSubject(result)
          result = __.extend2Basic(result)
    return result

end

-- 测试
__.test = function ()

    ngx.header["content-type"] = "text/plain"

    local source  = "[中国>abc[جۇسەي.تۇخۇم]123<新疆]"
    local extend  = __.basic2Extend(source)
    local basic   = __.extend2Basic(extend)
    local rextend = __.basic2RExtend(source)
    local rbasic  = __.rextend2Basic(rextend)

    ngx.say("source  : ", source)   -- [中国>abc[جۇسەي.تۇخۇم]123<新疆]
    ngx.say("extend  : ", extend)   -- [中国>abc[ﺟﯘﺳﻪﻱ.ﺗﯘﺧﯘﻡ]123<新疆]
    ngx.say("rextend : ", rextend)  -- [123>新疆[ﻡﯘﺧﯘﺗ.ﻱﻪﺳﯘﺟ]中国<abc]

    ngx.say(source == basic)        -- true
    ngx.say(source == rbasic)       -- true

end

return __
