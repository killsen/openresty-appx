
-- 生成 api.d.ts v21.09.09

local utils             = require "app.comm.apix.gen_api_utils"
local load_path         = utils.load_path
local get_namex         = utils.get_namex
local get_max_key_len   = utils.get_max_key_len
local get_fun_keys      = utils.get_fun_keys
local sort_pairs        = utils.sort_pairs

local _width            = require "utf8".width
local _split            = require "ngx.re".split
local _insert           = table.insert
local _concat           = table.concat
local _sub              = string.sub
local _gsub             = ngx.re.gsub
local _find             = ngx.re.find

-- 生成父命名空间
local function gen_namespace(name, namespace_loaded)

    local names = _split(name, [[\.]])
    local pname = "$api"

    for i, n in ipairs(names) do
        pname = pname .. "." .. n

        if i<#names and not namespace_loaded[pname] then
            namespace_loaded[pname] = true
            ngx.say ("")
            ngx.say("declare namespace ", get_namex(pname), " {}")
        end
    end

end

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

    if type(t) ~= "table" then return args, extends end

    -- {    "$pos_bi_order", "//订单详情",
    --    { "items", "订单明细", "$pos_bi_item[]" },
    --       items = "$pos_bi_item[] //订单明细",
    -- }

    for k, v in sort_pairs(t) do

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
                -- p.type = _gsub(p.type, [==[\[\]]==], "")
                p.is_array = true
            end
        end

        -- 参数说明为空，默认使用参数名
        if type(p.desc) ~= "string" or p.desc == "" then
            p.desc = "扩展属性" -- p.name
        end

        -- 去掉冒号、换行后面的内容 v21.02.26
        local i = _find(p.desc, [[(：|\:|\r|\n)]])
        if i then
            p.desc = _sub(p.desc, 1, i-1)
        end

        if not p.required then p.name = p.name .. "?" end
        -- if p.is_array then p.type = p.type .. "[]" end

        -- if p.type == "object" then p.type = "table" end

        _insert(args, p)

::PROC_NEXT::
    end

    return args, extends, tdesc

end

-- 对齐字符串
local function align_text(t, ...)

    local maxt, keys = {}, {...}

    for _, k in ipairs(keys) do
        maxt[k] = 0
        for _, p in ipairs(t) do
            local w = _width(p[k])
            if w > maxt[k] then maxt[k] = w end
        end
        for _, p in ipairs(t) do
            p[k] = p[k] .. string.rep(" ", maxt[k] -  _width(p[k]))
        end
    end

end

-- 默认值 v20.10.26
local function gen_default(p)

    if type(p.def) == "string" then
        return "  // 默认值: " .. "'" .. p.def .. "'"

    elseif type(p.def) == "number" then
        return "  // 默认值: " .. tostring(p.def)

    elseif type(p.def) == "boolean" then
        return "  // 默认值: " .. tostring(p.def)
    end

end

-- 枚举值 v20.10.26
local function gen_enum(p)

    if type(p.enum) ~= "table" then return end

    local t, i = {}, 0

    for _, enum in ipairs(p.enum) do
        if type(enum) == "string" then
            i=i+1; t[i] = "'" .. enum .. "'"
        elseif type(enum) == "number" then
            i=i+1; t[i] = enum
        end
    end

    if i == 0 then return end

    return "  // 枚举值: " .. _concat(t, ", ")

end

-- 生成参数列表
local function gen_args(t, step)

    step = tonumber(step) or 1
    local print = function(...)  -- 打印缩进
        ngx.say(string.rep(" ", step*4), ...)
    end

    local args = load_args(t)
    local argx, argt = {}, {}

    for _, p in ipairs(args) do
        if type(p.type) == "string" then
            _insert(argx, p)
        elseif type(p.type) == "table" then
            _insert(argt, p)
        end
    end

    -- 对齐字符串
    align_text(argx, "name", "desc", "type")

    for _, p in ipairs(argx) do
        local def_val  = gen_default(p) or ""   -- 默认值 v20.10.26
        local enum_str = gen_enum(p)    or ""   -- 枚举值 v20.10.26
        print("/** " .. p.desc .. " */ ", p.name, " : ", p.type, " ;", def_val, enum_str)
    end

    for _, p in ipairs(argt) do
        print("")
        print("/** ", p.desc, " */")
        print(p.name, " : ", "{")

        gen_args(p.type, step + 1)  -- 生成子参数列表

        print("}", p.is_array and "[]" or "" , ";")
    end

end

-- 生成 dao 接口
local function gen_dao(name, type_loaded)

    -- 举例：$pos_bi_order[]
    if type(name) ~= "string" then return end

    name = gen_type_desc(name)

    -- 必须以$开头
    if _sub(name, 1, 1) ~= "$" then return end

    -- 去掉结尾的[]
    if _sub(name, -2) == "[]" then
        name = _sub(name, 1, -3)
    end

    if type_loaded[name] then return end
       type_loaded[name] = true

    local dao = _load(name)
    if type(dao) ~= "table" then return end
    if type(dao.field_list) ~= "table" then return end

    local type_map = {
        varchar  = "string",
        date     = "string",
        datetime = "string",
        int      = "number",
        double   = "number",
        decimal  = "number",
        boolean  = "boolean",
    }

    local desc = dao.table_desc or ""
    local args = {}

    for i, f in ipairs(dao.field_list) do
        args[i] = {
            name = f.name,
            desc = f.desc,
            type = type_map[f.type] or "string",
        }
    end

    local step = 1
    local print = function(...)  -- 打印缩进
        ngx.say(string.rep(" ", step*4), ...)
    end

    print ("")
    print ("/** ", desc ," */")
    print ("interface ",  name, " {")

        gen_args(args, step+1)

    print ("}")

end

-- 生成模块中出现的全部 dao 接口
local function load_daos(mod, daos)

    if type(daos) ~= "table" then return end

    if type(mod) == "string" then

        -- 必须以$开头
        local name = gen_type_desc(mod)
        if _sub(name, 1, 1) ~= "$" then return end

        daos[name] = true

    elseif type(mod) == "table" then
        for _, v in pairs(mod) do
            load_daos(v, daos)
        end
    end

end

-- 生成自定义类型接口
local function gen_type(name, t, type_loaded)

    if type(name) ~= "string" then return end

    if type_loaded[name] then return end
       type_loaded[name] = true

    if type(t) == "string" then t = { t } end
    if type(t) ~= "table"  then return end

    -- 参数属性, 继承接口
    local args, extends, tdesc = load_args(t)

    if not tdesc then tdesc = name .. " (自定义类型)" end

    if #extends > 0 then
        extends = " extends " .. _concat(extends, ", ")
    else
        extends = ""
    end

    local step = 1
    local print = function(...)  -- 打印缩进
        ngx.say(string.rep(" ", step*4), ...)
    end

    print ("")
    print ("/** ", tdesc ," */")
    print ("interface ",  name, extends, " {")

        gen_args(args, step+1)

    print ("}")

end

-- 生成自定义类型接口
local function gen_types(types, type_loaded)

    if type(types) ~= "table" then return end

    for name, t in sort_pairs(types) do
        gen_type(name, t, type_loaded)
    end

end

-- 生成函数声明
local function gen_function(name, dt)

    local desc = dt.desc or dt[1] or ""
    local pv   = dt.pv   or dt[2]

    if type(pv) == "string" then  -- 权限
        desc = desc .. " [" .. pv .. "]"
    end

    local not_required = {
        ["store_id"     ] = true,   -- 门店编码（客户端可空）
        ["company_id"   ] = true,   -- 商户编码（客户端可空）
        ["CompanyID"    ] = true,   -- 商户编码（客户端可空）
        ["UserID"       ] = true,   -- 用户编码（客户端可空）
    }

    local space4 = string.rep(" ", 4)
    local args_required = false  -- 参数可空

    -- 请求参数
    local args = load_args(dt.req)

        for _, p in ipairs(args) do
            if not_required[p.name] then
                p.name = p.name .. "?"
                p.required = false
            end
            if p.required then
                args_required = true  -- 参数必填
            end
        end

    -- 返回类型
    local rets = load_args(dt.res)

    ngx.say ("")
    ngx.say (space4, "/** ", desc ," */")

    ngx.print (space4, "function ",  get_namex(name), " (")

    if type(dt.req) == "string" then
        local reqType = _gsub(dt.req, [[@]], "")  -- 清除 @ 符号 v22.04.05
        ngx.print("req : ", reqType)

    elseif #args > 0 then
        if args_required then
            ngx.print("req : {\n")  -- 参数必填
        else
            ngx.print("req?: {\n")  -- 参数可空
        end

        gen_args(args, 2)
        if #rets > 0  then ngx.say("") end
        ngx.print(space4, "}")
    else
        ngx.print("req?: object")
    end

    ngx.print (", opt?: Option): Response <")

    if type(dt.res) == "string" then
        local resType = _gsub(dt.res, [[@]], "")  -- 清除 @ 符号 v22.04.05
        ngx.print(resType)

    elseif #rets > 0 then
        ngx.print("{\n")
        gen_args(rets, 2)
        ngx.print(space4, "}")

    else
        ngx.print("any")
    end

    ngx.say(">;")

end


-- 生成未定义接口声明的模块（兼容处理）
local function gen_functions_undefined(mod, func_loaded)

    local max_len = get_max_key_len(mod) + 1
    local keys    = get_fun_keys(mod)

    for _, key in ipairs(keys) do
        if not func_loaded[key] then
            local keyx = get_namex(key)
            keyx = keyx .. string.rep(" ", max_len - #keyx)
            ngx.say("    function ", keyx ," (req?: object, opt?: Option): Response <any>;")
        end
    end

end

-- 生成只有一个函数的命名空间
local function gen_function_only(name, func)

    ngx.say ("")
    ngx.say ("declare namespace ", get_namex(name) ," {")
    ngx.say("    function ", func ," (req?: object, opt?: Option): Response <any>;")
    ngx.say ("}")

end

return function(app_name, base_path, base_name, args)

    local app = require "app.comm.appx".new(app_name)
    if not app then return ngx.exit(404) end

    app_name = app.name

    base_path = base_path or ("app/" .. app_name .. "/api/")
    base_name = base_name or  "api."

    ngx.header['content-type'] = "application/javascript"
    ngx.header['language'] = "typescript"

    local list = {}
    local namespace_loaded = {}  -- 已加载的命名空间
    local dao_loaded       = {}  -- 已加载的dao接口

    args = args or ngx.req.get_uri_args()

    if type(args.base) == "string" and args.base ~= "" then
        base_path = base_path .. args.base .. "/"
        base_name = base_name .. args.base .. "."
    end

    if type(args.api) == "string" and args.api ~= "" then
        _insert(list, args.api)
    else
        load_path (list, base_path, "")

        -- 不输出 demo 演示接口
        for i, name in ipairs(list) do
            if name == "demo" then
                table.remove(list, i)
                break
            end
        end

        table.sort(list)
    end

    ngx.say ("")
    ngx.say ("declare namespace $api {")
    ngx.say ("")

    ngx.say [[

    /** 返回类型 */
    type Response <T> = Promise <{
        /** 调用成功     */ ok          : boolean ;
        /** 错误信息     */ err         : string  ;
        /** 返回数据     */ data        : T       ;
        /** 服务器日期   */ server_date : string  ;
        /** 服务器时间戳 */ server_time : number  ;
    }>

    /** 请求设置 */
    interface Option {
        /** 显示加载中   */ showLoading? : boolean ;
        /** 显示错误信息 */ showError?   : boolean ; // 出错时显示错误信息，不返回结果
        /** 延时加载中   */ delay?       : boolean | number;
        /** 其它设置     */ [key: string]: any  ;
    }
]]

    -- 生成模块中出现的全部 dao 接口
    local daos = {}
    for _, name in ipairs(list) do
        local mod = _load (base_name .. name)
        load_daos(mod, daos)
    end
    for name in sort_pairs(daos) do
        gen_dao(name, dao_loaded)
    end

    ngx.say ("")
    ngx.say ("}")

    for _, name in ipairs(list) do

        local mod = _load (base_name .. name)

        -- 函数类接口
        if type(mod) == "function" then

            local t = _split(name, [[\.]])

            if #t > 1 then
                local n1 = table.concat(t, ".", 1, #t-1)
                local n2 = t[#t]

                namespace_loaded["$api." .. n1] = true
                gen_namespace(n1, namespace_loaded)

                gen_function_only("$api."..n1, n2)
            else
                gen_function_only("$api", name)
            end

        end

        -- 对象类接口
        if type(mod) == "table" then

            namespace_loaded["$api." .. name] = true
            gen_namespace(name, namespace_loaded)

            local ver = mod._VERSION and ("  // " .. mod._VERSION) or ""

            ngx.say ("")
            ngx.say ("declare namespace $api.", get_namex(name) ," {",  ver)

            local type_loaded = {}      -- 已加载的接口声明
            local func_loaded = {}      -- 已加载的函数声明
            local __defined__ = false   -- 是否已定义接口声明

            -- 生成模块中出现的全部 dao 接口
            -- gen_daos(mod, type_loaded)

            -- 自定义类型【模块级】
            gen_types(mod.types, type_loaded)

            for k, t in sort_pairs(mod) do

                local s = _sub(k, -2)
                if s == "__" and type(t) == "table" then

                    -- 自定义类型【接口级】
                    gen_types(t.types, type_loaded)

                    local act = _sub(k, 1, -3)
                    if type(mod[act]) == "function" then
                        __defined__ = true
                        func_loaded[act] = true
                        gen_function(act, t)  -- 生成函数声明
                    end
                end

            end

            if __defined__ then ngx.say ("") end

            -- 生成未定义接口声明的模块（兼容处理）
            gen_functions_undefined(mod, func_loaded)

            ngx.say ("}")
        end
    end


end
