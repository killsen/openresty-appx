
-- 生成参数校验函数代码 v21.02.26

local _insert = table.insert
local _concat = table.concat
local _sub    = string.sub
local _gsub   = ngx.re.gsub
local _find   = ngx.re.find

-- 支持的类型转换
local TYPE_MAP = {
    string  = "string",
    number  = "number",
    boolean = "boolean",
    table   = "table",
    object  = "table",
    any     = "any",
}

-- 生成参数类型、描述
local function gen_type_desc(s)

    local name, desc = s, ""
    local i, j = _find(s, [[\s*//\s*]])

    if i and j then
        name = _sub(s, 1, i-1)
        desc = _sub(s, j+1)
    end

    name = _gsub(name, [[\s]], "")
    return name, desc

end

local function load_arg(k , v)

    local p = {
        name     = k,
        required = true ,   -- 是否必填
        is_array = false,   -- 是否数组
    }

    -- 特殊值：? * # []
    if type(v) == "string" then

        v, p.desc = gen_type_desc(v)

        if v == "" then
            p.type = "string";  p.required = true

        elseif v == "?" then
            p.type = "string";  p.required = false

        elseif v == "*" then
            p.type = "string";  p.required = true

        elseif v == "[]" then
            p.type = "string[]";  p.is_array = true

        else
            p.type = v  -- 其它类型
        end

    -- 数字类型
    elseif type(v) == "number"  then
        p.type = "number"
        p.required = (v~=0)

    -- 布尔类型
    elseif type(v) == "boolean" then
        p.type = "boolean"
        p.required = v

    -- 自定义类型
    elseif type(v) == "table"   then
        p.type = v
        if type(v[1]) == "string" then
            local i, j = _find(v[1], [[//]])
            if i and j then
                local pt = string.sub(v[1], 1, i-1)
                pt = _gsub(pt, [[\s]], "")
                p.is_array = pt == "[]"
                p.desc = string.sub(v[1], j+1)
            end
        end

    else
        return
    end

    return p

end

-- 加载参数属性
local function load_args(t)

    local extends = {}  -- 继承接口
    local args    = {}  -- 参数属性
    local tdesc         -- 描述说明

    local name_loaded = {}

    if type(t) ~= "table" then return end
    if next(t) == nil then return end

    -- {    "$pos_bi_order", "//订单详情",
    --    { "items", "订单明细", "$pos_bi_item[]" },
    --       items = "$pos_bi_item[] //订单明细",
    -- }

    for k, v in pairs(t) do

        local p

        -- 以非空字符串做 key
        if type(k) == "string" and k ~= "" then
            p = load_arg(k, v)

        elseif type(k) == "number" and type(v) == "table" then
            p = {   name     =  v.name or v[1]              -- 名称
                ,   desc     =  v.desc or v[2]              -- 描述
                ,   type     =  v.type or v[3] or "string"  -- 类型
                ,   enum     =  v.enum                      -- 枚举值
                ,   def      =  v.def                       -- 默认值
                ,   required = (v.required ~= false)        -- 必填
                ,   is_array = (v.is_array == true )        -- 数组
            }

            -- 指定默认值后：可空
            if p.def ~= nil then p.required = false end

        -- 继承接口
        elseif type(k) == "number" and type(v) == "string" then
            local i, j = _find(v, [[//]])
            if i and j then
                tdesc = string.sub(v, j+1)
            else
                v = _gsub(v, [[@]], "")  -- 清除 @ 符号 v22.04.05
                _insert(extends, v)
            end

            goto PROC_NEXT
        end

        if not p then goto PROC_NEXT end

        -- 参数类型必须是字符串或者表
        if type(p.type) ~= "string" and type(p.type) ~= "table" then
            goto PROC_NEXT
        end

        -- 参数名不能为空
        if type(p.name) ~= "string" or p.name == "" then
            goto PROC_NEXT
        end

        -- 是否含有问号
        if _find(p.name, [==[\?]==]) then
            p.name = _gsub(p.name, [==[\?]==], "")
            p.required = false
        end

        -- 避免重名
        if name_loaded[p.name] then goto PROC_NEXT end
           name_loaded[p.name] = true

        if type(p.type) == "string" then

            p.type = _gsub(p.type, [[@]], "")  -- 清除 @ 符号 v22.04.05

            -- 是否含有问号
            if _find(p.type, [==[\?]==]) then
                p.type = _gsub(p.type, [==[\?]==], "")
                p.required = false
            end

            -- 是否含有[]
            if _find(p.type, [==[\[\]]==]) then
                p.type = _gsub(p.type, [==[\[\]]==], "")
                p.is_array = true
            end

            if p.type == "object" then
                p.type = "table"
            elseif _sub(p.type, 1, 1) == "$" then
                p.type = "table"
            end
        end

        -- 参数说明为空，默认使用参数名
        if type(p.desc) ~= "string" or p.desc == "" then
            p.desc = p.name
        end

        -- 去掉冒号、换行后面的内容 v21.02.26
        local i = _find(p.desc, [[(：|\:|\r|\n)]])
        if i then
            p.desc = _sub(p.desc, 1, i-1)
        end

        -- if not p.required then p.name = p.name .. "?" end
        -- if p.is_array then p.type = p.type .. "[]" end

        _insert(args, p)

::PROC_NEXT::
    end

    return args, extends, tdesc

end

local function _quote(s)
    return " [====[" .. tostring(s) .. "]====] "
end

-- 默认值 v20.10.26
local function gen_default(p)

    if type(p.def) == "string" then
        return _quote(p.def)
    elseif type(p.def) == "number" then
        return tostring(p.def)
    elseif type(p.def) == "boolean" then
        return tostring(p.def)
    end

end

-- 枚举值 v20.10.26
local function gen_enum(p)

    if type(p.enum) ~= "table" then return end

    local i, t = 0, {}

    for _, enum in ipairs(p.enum) do
        if type(enum) == "string" then
            i=i+1; t[i] = "[ " .. _quote(enum) .. " ] = true"
        elseif type(enum) == "number" then
            i=i+1; t[i] = "[ " .. enum .. " ] = true"
        end
    end

    if i == 0 then return end

    return _concat(t, ", ")

end

-- 生成参数校验函数代码
local function gen_codes(codes, types, args, extends, arg_step)

    arg_step = tonumber(arg_step) or 0
    if arg_step > 10 then return end

    local P = function(num)
        return "P" .. (arg_step + (tonumber(num) or 0))
    end

    local _p = function(...)
        if type(codes) ~= "table" then return end
        local sp = string.rep(" ", arg_step * 4)
        _insert(codes, _concat({ "  ", sp, ... }, ""))
    end

    _p("")
    _p("if type(", P(0) ,") ~= 'table' then return nil, '参数不能为空' end")

    -- 继承检查
    if type(extends) == "table" then
        for _, name in ipairs(extends) do
            local t = types[name]
            if t then
                t.required = true  -- 需要用到的类型
                _p("")
                _p("do")
                _p("    ---------- 继承检查 -------------- ")
                _p("    local  ok, err = _T.", name, "(", P(0),")")
                _p("    if not ok then return nil, err end")
                _p("end")
            end
        end
    end

    for _, p in ipairs(args) do

        local user_type = types[p.type]
        local is_table  = type(p.type) == "table"

        if user_type then
            -- 类型已被引用
            user_type.required = true

        elseif type(p.type) == "string" then
            -- 不支持的类型转换为 any
            p.type = TYPE_MAP[p.type] or "any"
        end

        local ptype = (p.is_array or user_type or is_table) and "table" or p.type

        _p("")
        _p("do  -- ", p.desc, " ---------")

        -- 默认值 v20.10.26
        if p.def ~= nil and ptype ~= "table" then
            local DEFAULT = gen_default(p)
            if DEFAULT then
                _p("  if ", P(0) ,"['", p.name, "'] == nil then ", P(0) ,"['", p.name, "'] = ", DEFAULT, " end" )
            end
        end

        -- 数字类型转换 v20.10.19
        if ptype == "number" then
            _p("  ", P(0) ,"['", p.name, "'] = tonumber(", P(0) ,"['", p.name, "'])  -- 【转数字】" )
        end

        _p("  local ", P(1) ," = ", P(0) ,"['", p.name, "']")

        if p.required then
            _p("  if ", P(1) ," == nil then return nil, ",
                        _quote(p.desc .. "不能为空"), " end")
        end

        _p("  if ", P(1) ," ~= nil then")

        if ptype ~= "any" then
        _p("    if type(", P(1) ,") ~= '", ptype, "' then return nil, ",
                        _quote(p.desc .. "参数类型错误"), " end")
        end

        if p.required and ptype == "string" then
            _p("    if ", P(1) ," == '' then return nil, ",
                        _quote(p.desc .. "不能为空"), " end")
        end

        -- 枚举值 v20.10.26
        local ENUM = gen_enum(p)
        if ENUM then
            _p("    local ENUM = { ", ENUM, " } ")

            if not p.is_array then
                _p("    if not ENUM[", P(1) ,"] then return nil, ",
                            _quote(p.desc .. "不在枚举值范围内"), " end")
            end
        end

        -- 数组
        if p.is_array and (p.type ~= "any" or ENUM) then
            _p("    for _, ", P(2) ," in ipairs(", P(1) ,") do")

            -- 子表类型
            if is_table then
                gen_codes(codes, types, load_args(p.type), nil, arg_step + 2)

            -- 自定义类型
            elseif user_type then

                _p("      ---------- 自定义类型检查 -------------- ")
                _p("      local  ok, err = _T.", p.type, "(", P(2),")")
                _p("      if not ok then return nil, err end")

            -- 枚举值 v20.10.26
            elseif ENUM then
                _p("      if not ENUM[", P(2) ,"] then return nil, ",
                                _quote(p.desc .. "不在枚举值范围内"), " end")

            else
                _p("      if type(", P(2) ,") ~= '", p.type, "' then return nil, ",
                                _quote(p.desc .. "参数类型错误"), " end")
            end
            _p("    end")

        -- 子表类型
        elseif is_table then
            gen_codes(codes, types, load_args(p.type), nil, arg_step + 1)

        -- 自定义类型
        elseif user_type then

            _p("    ---------- 自定义类型检查 -------------- ")
            _p("    local  ok, err = _T.", p.type, "(", P(1),")")
            _p("    if not ok then return nil, err end")

        end

        _p("  end")
        _p("end")
    end

end

-- 加载自定义类型
local function load_type(name, t)

    if type(name) ~= "string" or name == "" then return end
    if type(t) ~= "table" or next(t) == nil then return end

    local args, extends, desc = load_args(t)
    if not args then return end

    return {
        name    = name,
        desc    = desc or name,
        args    = args,
        extends = extends,
        loaded  = false,
        required= false,
    }

end

-- 加载全部自定义类型
local function load_types(mod)

    local types = {}

    if type(mod.types) == "table" then
        for k, v in pairs(mod.types) do
            types[k] = load_type(k, v)
        end
    end

    for _, t in pairs(mod) do
        if type(t) == "table" and type(t.types) == "table" then
            for k, v in pairs(t.types) do
                types[k] = types[k] or load_type(k, v)
            end
        end
    end

    return types

end

-- 生成参数校验函数代码
local function gen_valid_code(types, args, extends)

    local codes = {}

    _insert(codes, "function(P0)")

    gen_codes(codes, types, args, extends)

    _insert(codes, "")
    _insert(codes, "  return true")
    _insert(codes, "")
    _insert(codes, "end")

    return _concat(codes, "\n")

end

return function(mod)
-- @mod    : any
-- @return : void

    if type(mod) ~= "table" then return end

    local codes, types

    local _p = function(...)
        if not codes then return end
        for _, s in ipairs({...}) do
            _insert(codes, s)
        end
        _insert(codes, "\n")
    end

    for k, v in pairs(mod) do
        if type(k) ~= "string"   then goto PROC_NEXT end
        if type(v) ~= "function" then goto PROC_NEXT end

        local def = mod[k .. "__"]
        if type(def) ~= "table" then goto PROC_NEXT end

        local desc = def["desc"] or def[1] or ""
        local req =  def.req
        if type(req) == "string" then req = { req } end  -- 自定义类型参数 v22.04.05
        if type(req) ~= "table" then goto PROC_NEXT end

        local  args, extends = load_args(req)
        if not args then goto PROC_NEXT end

        if not codes then

            codes  = {}
            types  = load_types(mod)

            _p ("")
            _p ("local _M = {}  -- 参数检查")
            _p ("local _T = {}  -- 类型检查")
            _p ("")

        end

        local code = gen_valid_code(types, args, extends)
        _p ("-- ", desc)
        _p ("_M.", k, " = ", code)
        _p ("")

::PROC_NEXT::
    end

    if not codes then return end

    -- 只生成被引用到的自定义类型检查
    while true do
        local load_more = false

        for name, t in pairs(types) do
            if t.required and not t.loaded then
                load_more, t.loaded  = true, true

                local code = gen_valid_code(types, t.args, t.extends)
                _p ("-- ", t.desc or name)
                _p ("_T.", name, " = ", code)
                _p ("")
            end
        end

        if not load_more then break end
    end

    _p ("-- 返回模块")
    _p ("return _M")
    _p ("")

    return _concat(codes, "")

end

