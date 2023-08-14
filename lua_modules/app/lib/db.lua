
--【升级说明】v22.08.06
-- 新增切换数据库接口: set_database

--【升级说明】v21.08.28
-- 优化事务处理过程

--【升级说明】v20.09.29
-- 并行批量查询如有错误，返回出错信息

--【升级说明】v20.08.08
-- 1) 新增支持自动创建数据库
-- 2) 新增支持主从库读写分离

--【升级说明】v20.08.09
-- 1) 新增支持是否只使用主库
-- 2) 断开连接时取消主库模式

--【升级说明】v20.08.29
-- 1) 创建库、表时，不指定字符集
-- 注意：需要在手工创建库时指定为 字符集为 utf8mb4, 排序规则为 utf8mb4_unicode_ci

--------------------------------------------------------------------------------

local mysql     = require "resty.mysql"
local _quote    = ngx.quote_sql_str
local _format   = string.format
local _join     = table.concat
local _match    = ngx.re.match
local _find     = ngx.re.find
local _clone    = require "table.clone"

local _spawn    = ngx.thread.spawn
local _wait     = ngx.thread.wait

local _M = { _VERSION = "v23.08.14" }
local mt = {}

--------------------------------------------------------------------------------
local STATE_CONNECTED  = 1         -- 已连接
local CONNECT_TIMEOUT  = 1000 * 10 -- 连接超时（10秒）
local MAX_IDLE_TIMEOUT = 1000 * 60 -- 最大空闲时间（60秒）
local POOL_SIZE        = 100       -- 连接池大小（100个）

local DB_CONFIG = {
    host     = "127.0.0.1",
    port     = 3306,
    database = "",
    user     = "root",
    password = "",
    max_packet_size = 1024 * 1024
}

local DB_MASTER     -- 主库（读写）
local DB_SLAVE      -- 从库（只读）

--------------------------------------------------------------------------------

-- 是否只使用主库 v20.08.09
local function is_master()

    if not DB_SLAVE    then return true  end
    if not ngx.ctx[mt] then return false end

    local  co = coroutine.running()
    return ngx.ctx[mt][co] == true

end

-- 设置只使用主库 v20.08.09
local function set_master(val)

    if not DB_SLAVE then return end

    local  co = coroutine.running()

    ngx.ctx[mt] = ngx.ctx[mt] or {}
    ngx.ctx[mt][co] = (val == true) or nil

end

mt.__index = function(_, key)
    if key == "master" then
        return is_master()
    end
end

mt.__newindex = function(_, key, val)
    if key == "master" then
        set_master(val)
    else
        rawset(_, key, val)
    end
end

--------------------------------------------------------------------------------

-- 自动创建数据库 v20.08.08
local function _create_db()

    local db, err = mysql:new()
    if not db then
        ngx.log(ngx.ERR, "create mysql fail: ", err)
        return false, err
    end

    db:set_timeout(CONNECT_TIMEOUT)

    -- 测试数据库连接
    local ok, err = db:connect(DB_CONFIG)
    if not ok then
        ngx.log(ngx.ERR, "connect database fail: ", err)
    else
        db:set_keepalive(MAX_IDLE_TIMEOUT, POOL_SIZE)
        return true  -- 数据库连接成功（OK）
    end

    local database, err = DB_CONFIG.database, "database name is empty"
    if type(database) ~= "string" or database == "" then
        ngx.log(ngx.ERR, err)
        return false, err
    end

    -- 不指定数据库名称
    local db_config = _clone(DB_CONFIG)
    db_config.database = ""

    -- 再次连接数据库
    local ok, err = db:connect(db_config)
    if not ok then
        ngx.log(ngx.ERR, "connect database fail: ", err)
        return false, err
    end

    -- 创建数据库
    local sql = " CREATE DATABASE `" .. database .. "` "
             .. " DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; "
    local res, err = db:query(sql)

    db:close() -- 关闭数据库连接

    if not res then
        ngx.log(ngx.ERR, "create database fail: ", err)
        return false, err
    else
        return true
    end

end


-- 载入设置
function _M.load(db_config, db_slave)

    if "table" ~= type(db_config) then return end

    for k, v in pairs(db_config) do
        DB_CONFIG[k] = v
    end

    -- 自动创建数据库 v20.08.08
    ngx.timer.at(0, _create_db)

    -- 主库（读写）
    DB_MASTER = DB_CONFIG

    -- 从库（只读）
    if type(db_slave) == "table" then
        DB_SLAVE = _clone(DB_CONFIG)
        for k, v in pairs(db_slave) do
            DB_SLAVE[k] = v
        end
    end

end

-- 注册卸载事件
function _M.unload()

    if ngx.ctx[_M] then
        for _, db in pairs(ngx.ctx[_M]) do
            --- db : res<mysql:new>

            -- 未关闭事务处理的，自动回滚并关闭连接 v21.08.28
            if db.__trans then
                db.__trans = false
                db:query("rollback;")    -- 事物处理回滚
                db:close()

            elseif db.state == STATE_CONNECTED then
                db:set_keepalive(MAX_IDLE_TIMEOUT, POOL_SIZE)
            else
                db:close()
            end
        end
    end

    ngx.ctx[_M] = nil
    ngx.ctx[mt] = nil

end

--------------------------------------------------------------------------------

-- 更换数据库 v22.08.06
function _M.set_database(database)

    _M.close()  -- 断开连接

    if type(database) == "string" and database ~= "" then
        ngx.ctx["DATABASE"] = database
    else
        ngx.ctx["DATABASE"] = nil
    end

end

-- 建立连接
local function _open(is_slave)

    -- 是否只使用主库
    if is_master() then is_slave = false end

    -- 是要使用过主库，之后都使用主库
    if not is_slave then set_master(true) end

    ngx.ctx[_M] = ngx.ctx[_M] or {}

    local  co = coroutine.running()
    local dbx = ngx.ctx[_M][co]

    if dbx then
        if dbx.state == STATE_CONNECTED then
            if dbx.is_master then
                return dbx  -- 主库（读写）

            elseif is_slave then
                return dbx  -- 从库（只读）

            else
                dbx:set_keepalive(MAX_IDLE_TIMEOUT, POOL_SIZE)
            end
        else
            ngx.ctx[_M][co] = nil
            dbx:close()
        end
    end

    local  db, err = mysql:new()
    if not db then return nil, err end

        db:set_timeout(CONNECT_TIMEOUT)

        db.is_slave  =     is_slave
        db.is_master = not is_slave

    local conf = is_slave and DB_SLAVE      -- 从库（只读）
                           or DB_MASTER     -- 主库（读写）

    -- 更换数据库 v22.08.06
    local database = ngx.ctx["DATABASE"]
    if database and database ~= conf.database then
        conf = _clone(conf)
        conf.database = database
    end

    local  ok, err = db:connect(conf)
    if not ok then return nil, err end

    ngx.ctx[_M] = ngx.ctx[_M] or {}
    ngx.ctx[_M][co] = db

    return db

end
_M.open = _open

-- 断开连接
local function _close()

    set_master(false)  -- 取消主库模式 v20.08.09

    if not ngx.ctx[_M] then return end

    local  co = coroutine.running()
    local  db = ngx.ctx[_M][co]  --> res<mysql:new>
    if not db then return end

        ngx.ctx[_M][co] = nil

    -- 未关闭事务处理的，自动回滚并关闭连接 v21.08.28
    if db.__trans then
        db.__trans = false
        db:query("rollback;")    -- 事物处理回滚
        db:close()
        return
    end

    if db.state == STATE_CONNECTED then
        db:set_keepalive(MAX_IDLE_TIMEOUT, POOL_SIZE)
    else
        db:close()
    end

end
_M.close = _close

--------------------------------------------------------------------------------

-- 检查是否 select 语句
local SELECT_REGX = [[^\s*select\s]]
local function _is_select(sql)
    local  res = _find(sql, SELECT_REGX, "joi")
    return res and true or false
end

-- 检查是否包含错误信息
local ERR_REGX = [[<ERR>\n(.+)\n</ERR>]]
local function _check_sql_err(sql)

    if type(sql) ~= "string" or sql == "" then
        return nil, "no sql"
    end

    local m = _match(sql, ERR_REGX, "joi")

    if m and m[1] then
        return nil, m[1]
    else
        return true
    end

end


-- 执行sql脚本
local function _execute(sql, nrows)

    -- 检查是否包含错误信息
    local ok, err = _check_sql_err(sql)
    if not ok then return nil, err end

    local is_slave = not  is_master()     -- 非主库
                     and _is_select(sql)  -- 是否 select 语句

    local db, err = _open(is_slave)
    if not db then return nil, err end

    -- 压缩模式（多维数组）
    db:set_compact_arrays(nrows==true)

    local res, err, errcode, sqlstate = db:query(sql)

    while err == "again" do -- 一定要读完全部返还的数据
        res, err, errcode, sqlstate = db:read_result()
    end

    if err and err~="again" then
        ngx.log( ngx.ERR, "\nsql_err:\n\n", err, "\n\n", sql, "\n\n" )
    end

    return res, err, errcode, sqlstate

end
_M.execute = _execute


-- 用于子协程执行
local function _query_by_thread(sql, nrow)
    local res, err = _execute(sql, nrow)
        _close() -- 关闭连接
    return res, err
end

-- 并行批量查询
local function _mquery(sqlx, nrow)
-- @return : sqlx

    local t, r, e = {}, {}, nil

    for k, sql in pairs(sqlx) do
        t[k] = _spawn(_query_by_thread, sql, nrow) -- 创建子协程
    end

    for k, thr in pairs(t) do
        local ok, res, err = _wait(thr) -- 等待返回值

        if not ok then
            e = res
        elseif not res and err then
            e = err
        end

        r[k] = ok and res or {}
    end

    return r, e -- 出错信息 v20.09.29

end
_M.mquery = _mquery


-- 读取执行结果
local function _read()

    local  co = coroutine.running()
    local  db = ngx.ctx[_M] and ngx.ctx[_M][co]  --> res<mysql:new>
    if not db then return end

    local res, err, errcode, sqlstate = db:read_result()
    return res, err, errcode, sqlstate

end
_M.read = _read

-- 事务处理
local function _trans(sql)

    if type(sql)=="table" then sql = _join(sql, "\n") end
    if type(sql)~="string" or sql=="" then return nil, "no sql" end

    -- 检查是否包含错误信息
    local ok, err = _check_sql_err(sql)
    if not ok then return nil, err end

    -- 主库（读写）
    local db, err = _open(false)
    if not db then return nil, err end

    local i, r = 0, {}

    if db.__trans then
        i=i+1; r[i] = {}  -- 已开启事务了 v21.08.27
    else
        sql = _join({" begin; ", sql, " commit; "}, "\n")
    end

    local res, err, errcode, sqlstate = db:query(sql)
    i=i+1; r[i] = {res=res, err=err, errcode=errcode, sqlstate=sqlstate}

    while err == "again" do
        res, err, errcode, sqlstate = db:read_result()
        i=i+1; r[i] = {res=res, err=err, errcode=errcode, sqlstate=sqlstate}
    end

    if err and err~="again" then
        db:query("rollback;") -- 事物回滚

        ngx.log( ngx.ERR, "\nsql_err:\n\n", err, "\n\n", sql, "\n\n" )

        return nil, err, errcode, sqlstate
    end

    return r

end
_M.trans = _trans


-- 事务处理
local function _tranx(sql)

    if type(sql)=="table" then sql = _join(sql, "\n") end
    if type(sql)~="string" or sql=="" then return nil, "no sql" end

    -- 检查是否包含错误信息
    local ok, err = _check_sql_err(sql)
    if not ok then return nil, err end

    -- 主库（读写）
    local db, err = _open(false)
    if not db then return nil, err end

    local r, i = {}, 0

    if db.__trans then
        i=i+1; r[i] = {}  -- 已开启事务了 v21.08.27
    else
        sql = _join({" begin; ", sql, " commit; "}, "\n")
    end

    local  res, err = db:query(sql) -- begin;
    if not res then return nil, err end

    while err == "again" do
        res, err = db:read_result()
        if not res then
            db:query("rollback;")   -- rollback;

            ngx.log( ngx.ERR, "\nsql_err:\n\n", err, "\n\n", sql, "\n\n" )

            return nil, err
        end
        i=i+1; r[i] = res
    end

    r[i] = nil                      -- commit;

    return r

end
_M.tranx = _tranx


function _M.begin()

    -- 主库（读写）
    local db, err = _open(false)
    if not db then return nil, err end

    db.__trans = true

    return db:query("begin;")     -- 事物处理开始

end

function _M.commit()

    local db, err = _open()
    if not db then return nil, err end

    db.__trans = false

    return db:query("commit;")      -- 事物处理提交

end

function _M.rollback()

    local db, err = _open()
    if not db then return nil, err end

    db.__trans = false

    return db:query("rollback;")    -- 事物处理回滚

end

-- 创建表
function _M.create(table_name, field_list)

    local fields, primary

    for _, f in ipairs(field_list) do
        local notnull = f.primary and " NOT NULL " or ""
        local default = f.default and " DEFAULT '" .. f.default .. "'" or ""
        local flen    = f.len     and " (" .. f.len .. ")"
        local desc    = f.desc    and " COMMENT '" .. f.desc .. "' " or ""
        local fld = f.name .. " " .. f.type .. flen .. " " .. notnull .. default .. desc
        fields =  ( fields and (fields .. ", ") or "" ) .. fld

        if f.primary then
            primary = ( primary and (primary .. ",") or "" ) .. f.name
        end
    end

    primary = primary and " , PRIMARY KEY (" .. primary .. ") " or ""

    local sql = " CREATE TABLE " .. table_name .. " (  "
             ..   fields .. primary
             .. " ) ENGINE=InnoDB" -- .. " DEFAULT CHARSET=utf8 "

    return _execute(sql)

end

-- 删除表
function _M.drop(table_name)
    return _execute("drop table " .. table_name)
end


-- 取得条件
local function _get_where(where, ...)
    if type(where)~="string" or where=="" then return "" end
    if ... then where = _format(where, ...) end
    return " where " .. where
end

-- 查
function _M.select(table_name, where, ...)
    local sql = " select * from " .. table_name
              .. _get_where(where, ...)
    return _execute(sql)
end

-- 删
function _M.delete(table_name, where, ...)
    local sql = " delete from " .. table_name
              .. _get_where(where, ...)
    return _execute(sql)
end

-- 增
function _M.insert(table_name, data)

    local fields, values

    for f, v in pairs(data) do
        if type(v) == "string" then v = _quote(v) end
        if not fields then
            fields = "" .. f
            values = "" .. v
        else
            fields = fields .. "," .. f
            values = values .. "," .. v
        end
    end

    local sql  =  " insert into " .. table_name
               .. "        ( "  .. fields .. " ) "
               .. " values ( "  .. values .. " ) "

    return _execute(sql)

end


-- 插入多条数据
function _M.insertx(self, opt)

    opt = opt or self

    if type(opt)~="table" or opt==_M then return nil, "参数不能为空" end

    local name = opt.name or opt.target or opt.table_name
    local cols = opt.cols or opt.fields
    local rows = opt.rows or opt.data

    if type(name)~="string" or #name==0 then return nil, "表名不能为空" end
    if type(rows)~="table"  or #rows==0 then return nil, "数据不能为空" end

    if type(cols)~="table"  or #cols==0 then
        cols = {}; local i = 0
        for key in pairs(rows[1]) do
            i=i+1; cols[i] = key -- 取出第一行的所有列
        end
    end

    local list, d = {}, {}
    for i, row in ipairs(rows) do
        for j, col in ipairs(cols) do
            local v = row[col] or row[j]
                  v = type(v)=="string"  and _quote(v)
                        or v == nil      and "null"
                        or v == ngx.null and "null"
                        or tostring(v)
            d[j] = v
        end
        list[i] = "(" .. _join(d, ",") .. ")"
    end

    local sql = "insert into "   .. name   .. " ( "
             .. "\n" .. _join(cols, ", " )
             .. "\n" .. ") values "
             .. "\n" .. _join(list, ",\n") .. " ; "

    return self==_M and sql or _execute(sql)

end


-- 删除多条数据
function _M.deletex(self, opt)

    opt = opt or self

    if type(opt)~="table" or opt==_M then return nil, "参数不能为空" end

    local name = opt.name or opt.target or opt.table_name
    local keys = opt.keys or opt.pk     or opt.pk_fields
    local rows = opt.rows or opt.data

    if type(name)~="string" or #name==0 then return nil, "表名不能为空" end
    if type(rows)~="table"  or #rows==0 then return nil, "数据不能为空" end
    if type(keys)~="table"  or #keys==0 then return nil, "主键不能为空" end

    local map, wh, i = {}, {}, 0

    for _, row in ipairs(rows) do
        for j, col in ipairs(keys) do
            local v = row[col] or row[j]
                  v = type(v)=="string"  and _quote(v)
                        or v == nil      and "null"
                        or v == ngx.null and "null"
                        or tostring(v)
            if v == "null" then
                wh[j] = col .. " is null"
            else
                wh[j] = col .. "=" .. v
            end
        end

        local s = "(" .. _join(wh, " and ") .. ")"

        if not map[s] then
            map[s] = true
            i=i+1; map[i] = s
        end
    end

    local sql = " delete from " .. name .. " where \n"
             .. "    " .. _join(map, "\n or ") .. " ; "

    return self==_M and sql or _execute(sql)

end



-- 改
function _M.update(table_name, data, where, ...)

    local fields

    for f, v in pairs(data) do
        if type(v) == "string" then v = _quote(v) end
        if not fields then
            fields = " " .. f .. " = " .. v .. " "
        else
            fields = fields .. ", " .. f .. " = " .. v .. " "
        end
    end

    local sql  =  " update " .. table_name
              ..  "    set " .. fields
              .. _get_where(where, ...)

    return _execute(sql)

end

-- 执行sql语句
function _M.query(sql, ...)
    if ... then sql = _format(sql, ...) end
    return _execute(sql)
end

----------------------------------------------------------
return setmetatable(_M, mt) -- 返回模块
