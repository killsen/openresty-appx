
-- 新建dao v20.08.15 by Killsen ------------------------------------------------

--【升级说明】v20.08.15
-- 1) 修正检查是否有定义索引的bug v20.08.15

--【升级说明】v20.08.29
-- 1) 创建库、表时，不指定字符集
-- 注意：需要在手工创建库时指定为 字符集为 utf8mb4, 排序规则为 utf8mb4_unicode_ci

--------------------------------------------------------------------------------

local _sub          = string.sub
local _concat       = table.concat -- 合并数组
local _newt         = require "table.new"
local quote_sql_str = ngx.quote_sql_str
local tostring      = tostring

-- 合并数组
local function _join(t, sep, i, j)
    return _concat(t, sep or "", i, j)
end

-- 合并sql语句
local function _sql(t)
    return _concat(t, "")
end

-- 字符串单引号转义
local function _quote(v)

    if v == nil or v == ngx.null then
        return "null"

    elseif type(v) == "string" then
        return quote_sql_str(v)

    else
        return tostring(v)
    end

end

--- { uid="abc"         }
--> {"uid like '%abc%'" }
local function _like_list(data)

    local fv, i = {}, 0

        for f, v in pairs(data) do
            if type(v) ~= "table" and type(v) ~= "function"  then

                if type(f) == "number" and type(v)=="string" and v~="" then
                    i=i+1; fv[i] = v

                elseif type(f) == "string" and _sub(f,1,1) ~= "_" then
                    i=i+1; fv[i] = f .. " like " .. _quote("%".. tostring(v) .."%")

                end
            end
        end

    return fv

end

--- { uid="1000",   qty=123,  "1=1", {} }
--> {"uid='1000'", "qty=123", "1=1"     }
local function _eq_list(data)

    local fv, i = {}, 0

        for f, v in pairs(data) do
            if type(v) ~= "table" and type(v) ~= "function"  then

                if type(f) == "number" and type(v)=="string" and v~="" then
                    i=i+1; fv[i] = v

                elseif type(f) == "string" and _sub(f,1,1) ~= "_" then
                    i=i+1; fv[i] = f .. " = " .. _quote(v)

                end
            end
        end

    return fv

end

--- {  total="sum(qty*price)"   }
--> { "sum(qty*price) as total" }
local function _as_list(data)

    local fv, i = {}, 0

        for f, v in pairs(data) do
            if type(v) ~= "table" and type(v) ~= "function"  then

                if type(f) == "number" and type(v)=="string" and v~="" then
                    i=i+1; fv[i] = v

                elseif type(f) == "string" and _sub(f,1,1) ~= "_" then
                    i=i+1; fv[i] = tostring(v) .. " as " .. f

                end
            end
        end

    return fv

end

-- 删除表
local function _drop(table_name)
    return " drop table if exists " .. table_name .. " ; "
end

-- 创建表
local function _create(table_name, table_desc, field_list)

    local fi, i = {}, 0
    local pj, j = {}, 0

    for _, f in ipairs(field_list) do
        local _null = f.pk   and " not null"                   or "" -- 是否允许空
        local _def  = f.def  and " default '" .. f.def .. "'"  or "" -- 默认值
        local _len  = f.len  and         " (" .. f.len .. ")"  or "" -- 长度
        local _desc = f.desc and " comment '" .. f.desc .. "'" or "" -- 备注

        i=i+1; fi [i] =  "     "
            .. "`" .. f.name .. "`" .. " "    .. f.type
            .. _len   .. _null  .. _def    .. _desc

        if f.pk then j=j+1; pj[j] = f.name end -- 主键
    end

    local pk = j==0 and "" or
        ",\n   primary key (" .. _join(pj,", ") .. ") "

    return " create table " .. table_name .. " (  \n"
        ..   _join(fi, ", \n") .. pk
        .. "\n ) engine=InnoDB"
    --  ..     " default charset=utf8"
        ..     " comment=" .. _quote(table_desc)
        .. " ; "

end

-- 创建索引
local function _create_index(table_name, table_index)

    local sql, i = {}, 0

    for index_name, index_fields in pairs(table_index) do
        i=i+1; sql[i] = " alter table " .. table_name .. " \n"
                     .. "   add index " .. index_name .. " \n "
                     .. " ( " .. _join(index_fields, ", ") .. " );"
    end

    return _join(sql, "\n")

end

-- 清空表
local function _clear(table_name)
    return " truncate table " .. table_name .. " ; "
--  return " delete from "    .. table_name .. " ; "
end

-- 返回key数组
local function _keys(t)

    local keys, i = {}, 0

    for k, v in pairs(t) do
        if type(v) ~= "table"  and type(v) ~= "function" and
           type(k) == "string" and _sub(k,1,1) ~= "_"   then
            i=i+1; keys[i]= k
        end
    end

    return keys

end

-- 删除数据（批量）
local function _delete_rows(table_name, field_list, data)

    local cols, rows, i = {}, {}, 0
    local keys, k = nil, 0

    for _, d in pairs(data) do

        -- 取出主键
        if not keys then
            if field_list then
                keys = {}
                for _, f in ipairs(field_list) do
                    if f.pk then
                        k=k+1; keys[k]=f.name
                    end
                end
            else
                keys = _keys(d)
            end
        end

        for j, key in ipairs(keys) do
            cols[j] = key .. " = " .. _quote ( d[key] )
        end

        i=i+1; rows[i] = " ( " .. _join(cols, " and ") .. " ) "
    end

    if i==0 then return "" end -- 没有数据返回空sql语句

    return _sql {
        " delete "                                  , "\n" ,
        "   from "  , table_name                    , "\n" ,
        "  where "  , _join(rows, "\n     or ")     , "\n",
        " ; "
    }

end

-- 检查字段名
local function _check_fields(field_list)

    if type(field_list) ~= "table" or #field_list == 0 then
        return nil, "字段不能为空"
    end

    for _, f in ipairs(field_list) do

        local name = type(f) == "table"  and f.name
                  or type(f) == "string" and f
                  or nil

        if type(name) ~= "string" then
            return nil, "字段名称必须是字符串"
        end

        if name == "" then
            return nil, "字段名称不能为空"
        end
    end

    return true

end

-- 插入数据（批量）
local function _insert_rows(table_name, field_list, data)

    if type(table_name) ~= "string" or table_name == "" then
        return nil, "表名称不能为空"
    end

    if type(data) ~= "table" or type(data[1]) ~= "table" then
        return nil, "数据不能为空"
    end

    -- 检查字段名
    field_list = field_list or _keys(data[1])
    local ok, err = _check_fields(field_list)
    if not ok then return nil, err end

    local cols = _newt(#field_list, 0)
    local rows = _newt(#data, 0)

    for i, d in ipairs(data) do
        if type(d) ~= "table" or next(d) == nil then
            return nil, "数据不能为空"
        end

        for j, f in ipairs(field_list) do
            if type(f) == "table" then
                local v = d[f.name]
                if v == nil or v == ngx.null then
                    v = f.def -- 默认值
                end

                cols[j] = _quote ( v    )
            else
                cols[j] = _quote ( d[f] )
            end
        end

        rows[i] = " ( " .. _join(cols, ", ") .. " ) "
    end

    for j, f in ipairs(field_list) do
        cols[j] = type(f) == "table" and f.name or f
    end

    return _sql {
        " insert "                          , "\n" ,
        "   into ", table_name              , "\n" ,
        " ( ", _join(cols, ", "), " ) "     , "\n" ,
        " values "                          , "\n" ,
            _join(rows, ",\n")              , "\n" ,
        " ; "
    }

end

local function _insert(table_name, field_list, data)

    if type(data) ~= "table" then
        return nil, "数据不能为空"
    end

    if type(data[1]) == "table" then
        return _insert_rows(table_name, field_list,  data )
    else
        return _insert_rows(table_name, field_list, {data})
    end

end

-- 修改数据
local function _update(table_name, data)

    local fv, wh = {}, _eq_list(data)

        for _, t in ipairs(data) do
            if type(t) == "table" then
                fv = _eq_list(t)
                break
            end
        end

    return _sql {
        " update "  , table_name                    , "\n" ,
        "    set "  , _join(fv, " ,\n        ")     , "\n" ,
        "  where "  , _join(wh, "  \n    and ")     , "\n" ,
        " ; "
    }

end

-- 删除数据
local function _delete(table_name, data)

    local wh = _eq_list(data)

    return _sql {
        " delete "                                  , "\n" ,
        "   from "  , table_name                    , "\n" ,
        "  where "  , _join(wh, "\n    and ")       , "\n" ,
        " ; "
    }

end

-- 查询数据
local function _select(table_name, data, limit, is_like)

    local fields = "*"
    ----------------------------------------------------------------------------
        for _, t in ipairs(data) do
            if type(t) == "table" then
                fields = _join ( _as_list(t), ", " )
                break
            end
        end

    local group_by  = data._group_by
    ----------------------------------------------------------------------------
        if type(group_by) == "string" and group_by ~= "" then
            group_by = "\n  group by " .. group_by
        else
            group_by = ""
        end

    local order_by = data._order_by
    ----------------------------------------------------------------------------
        if type(order_by) == "string" and order_by ~= "" then
            order_by = "\n  order by " .. order_by
        else
            order_by = ""
        end

    local where = is_like and _like_list(data) or _eq_list(data)
    ----------------------------------------------------------------------------
        if type(where) == "table" and #where > 0  then
            where = "\n  where " .. _join(where, "\n    and ")
        else
            where = ""
        end

    limit = limit or data._limit
    ----------------------------------------------------------------------------
        if type(limit) == "number" and limit > 0  then
            limit = "\n  limit " .. limit
        elseif type(limit) == "string" and limit ~= "" then
            limit = "\n  limit " .. limit
        else
            limit = ""
        end

    return _sql {
        " select "  , fields        ,  "\n" ,
        "   from "  , table_name    ,
            where   ,
         group_by   ,
         order_by   ,
            limit   ,
        "\n ; "
    }

end

-- 转换成 cols、rows v18.4.13
local function _loadsets(data)

    local cols, rows, i, j= {}, {}, 0, 0

    if #data==0 then return nil end

    -- 构造col
    for k in pairs(data[1]) do
        i=i+1; cols[i] = k
    end

    -- 构造ros
    for _, row in ipairs(data) do
        j=j+1; rows[j] = {}
        for k, col in ipairs(cols) do

            local val = row[col]

            if val == ngx.null then
               val = type(val)=="number" and 0 or type(val)=="string" and "" or ""
            end

            rows[j][k]=val
        end
    end

    return cols, rows

end

-- 初始化列定义
local init_fields = require "app.comm.daox.init_fields"

-- 创建dao对象
local function new_dao (mod, db_execute)

    if type(mod) ~= "table" then return end

    local dao = {
        table_schema = mod.table_schema ,  -- 数据库
        table_name   = mod.table_name   ,  -- 表名
        table_desc   = mod.table_desc   ,  -- 描述
        field_list   = mod.field_list   ,  -- 列头定义
        table_index  = mod.table_index  ,  -- 索引
        demo_data    = mod.demo_data    ,  -- 演示数据
    }

    local table_schema = dao.table_schema
    local table_name   = dao.table_name
    local table_desc   = dao.table_desc or ""
    local field_list   = dao.field_list
    local table_index  = dao.table_index

    if type(table_name) ~= "string" or table_name == "" then return dao end

    if type(table_schema) == "string" and table_schema ~= "" then
        table_name = table_schema .. "." .. table_name
    end

    ---------------------------------------------------

    -- 是否定义列
    if type(field_list) ~= "table" or #field_list == 0 then
        field_list = nil
    end

    -- 只有定义了列：才能创建表、删除表、清空表
    if field_list then

        -- 初始化列定义 v17.07.27
        init_fields(field_list)

        -- 创建表
        function dao.create(self, name)

            if dao ~= self then name = self end
            name = name and (table_name .. "_" .. name) or table_name

             local sql = _create (name, table_desc, field_list)
                if dao == self then return sql end
            return db_execute (sql)
        end

        -- 创建索引
        function dao.create_index(self, name)

            -- 未定义索引               -- 修正检查是否有定义索引的bug v20.08.15
            if type(table_index) ~= "table" or next(table_index) == nil then
                if dao == self then
                    return ""   -- 直接返回空字符串
                else
                    return true -- 直接返回成功
                end
            end

            if dao ~= self then name = self end
            name = name and (table_name .. "_" .. name) or table_name

             local sql = _create_index (name, table_index)
                if dao == self then return sql end
            return db_execute (sql)
        end

        -- 删除表
        function dao.drop(self, name)

            if dao ~= self then name = self end
            name = name and (table_name .. "_" .. name) or table_name

             local sql = _drop (name)
                if dao == self then return sql end
            return db_execute (sql)
        end

        -- 清空表
        function dao.clear(self, name)

            if dao ~= self then name = self end
            name = name and (table_name .. "_" .. name) or table_name

             local sql = _clear (name)
                if dao == self then return sql end
            return db_execute (sql)
        end

    end

    -- 创建数据
    function dao.new(data)

        if not field_list then return {} end

        local t = {}
        local d = type(data) == "table" and data or {}

        for _, f in ipairs(field_list) do
            local v = d[f.name]
            if v == nil then v = f.def end
            t[f.name] = v
        end

        return t

    end

    -- 增
    function dao.add(self, data, name)

        if dao ~= self then data, name = self, data end
        name = name and (table_name .. "_" .. name) or table_name

        local sql, err = _insert (name, field_list, data)

        if dao == self then
            -- 如果出错，构造一个错误的 insert 语句
            return sql or _sql { "<ERR>\n", err or "未知错误", "\n</ERR>" }

        elseif sql then
            return db_execute (sql)

        else
            return nil, err or "未知错误"
        end

    end

    -- 增（批量）
    dao.add_rows = dao.add

    -- 删
    function dao.del(self, data, name)

        if dao ~= self then data, name = self, data end
        name = name and (table_name .. "_" .. name) or table_name

        local  sql = _delete (name, data)
            if dao == self then return sql end
        return db_execute (sql)
    end

    -- 删（批量）
    function dao.del_rows(self, data, name)

        if dao ~= self then data, name = self, data end
        name = name and (table_name .. "_" .. name) or table_name

        local  sql = _delete_rows (name, field_list, data)
            if dao == self then return sql end
        return db_execute (sql)
    end

    -- 改
    function dao.set(self, data, name)

        if dao ~= self then data, name = self, data end
        name = name and (table_name .. "_" .. name) or table_name

        local  sql = _update (name, data)
            if dao == self then return sql end
        return db_execute (sql)
    end

    -- 查（一行）
    function dao.get(self, data, name)

        if dao ~= self then data, name = self, data end
        name = name and (table_name .. "_" .. name) or table_name

        local  sql = _select (name, data, 1)
            if dao == self then return sql end
         local res, err = db_execute (sql)
        if not res then return nil, err end
        return res[1]
    end

    -- 查（多行）
    function dao.list(self, data, name)

        if dao ~= self then data, name = self, data end
        name = name and (table_name .. "_" .. name) or table_name

        local  sql = _select (name, data)
            if dao == self then return sql end
        return db_execute (sql)
    end

    -- 查（多行，返回 cols、rows）
    function dao.loadsets(self, data, name)

        if dao ~= self then data, name = self, data end
        name = name and (table_name .. "_" .. name) or table_name

        local  sql = _select (name, data)
        local  res, err = db_execute (sql)
        if not res then return nil, err end

        local  cols, rows = _loadsets(res)
        return cols, rows
    end

    -- 查（迭代）
    function dao.ilist(self, data, name)

        if dao ~= self then data, name = self, data end

         local rows = dao.list(data, name) or {}
        return ipairs(rows)
    end

    -- 模糊查询 v16.10.01
    function dao.like(self, data, name)

        if dao ~= self then data, name = self, data end
        name = name and (table_name .. "_" .. name) or table_name

        local  sql = _select (name, data, nil, true)
            if dao == self then return sql end
        return db_execute (sql)
    end

    ---------------------------------------------------
    return dao

end

-------------------------------------------------------
return new_dao
