
-- 创建dao表 v20.07.30 by Killsen ------------------

local require   = require
local cjson     = require "cjson.safe"
local _encode   = cjson.encode

---------------------------------------------------

-- 为了避免误删除表，删除表需要提供 drop 参数的值
local LAST_DROP_NONCE = ngx.now() * 1000

local function echo(...)
    ngx.say(...)
    ngx.flush()
end

-- 创建表
local function init_dao(app_name, dao_name, drop_nonce)

    -- 只能本机执行
    if "127.0.0.1" ~= ngx.var.remote_addr then
        ngx.exit(404)
        return
    end

    local app = require "app.comm.appx".new(app_name)
    if not app then return ngx.exit(404) end

    local args = ngx.req.get_uri_args()

    dao_name    = dao_name or args.name
    drop_nonce  = tonumber(drop_nonce or args.drop)

    local to_drop_table = drop_nonce == LAST_DROP_NONCE
    LAST_DROP_NONCE = ngx.now() * 1000

    if type(dao_name) ~= "string" or dao_name == "" then
        return ngx.exit(404)
    end

    local db   = app.db
    local dao  = app:load_dao(dao_name)

    dao.demo_data = dao.demo_data or {}

    echo ( dao.table_name, "(", dao.table_desc, ")" )
    echo ( "----------------------------------------------------------------------------------" )

    echo ("")
    if type(dao.field_list)~="table" or #dao.field_list==0 then
        echo ( "尚未定义列" )
        return
    end

    echo ( "共有 ", #dao.field_list, " 列：" )
    echo ( "----------------------------------------------------------------------------------" )
    for _, d in ipairs(dao.field_list) do
        echo ( "    ", _encode(d) )
    end

    echo ("")
    echo ( "共有 ", #dao.demo_data, " 行演示数据：" )
    echo ( "----------------------------------------------------------------------------------" )
    for _, d in ipairs(dao.demo_data) do
        echo ( "    ", _encode(d) )
    end

    local rows, err -- 历史数据

    if to_drop_table then

        rows, err = dao.list { "1=1", _limit = 10001 }

        if not rows then
            echo ("读取数据失败：", err)
            return
        end

        if #rows > 10000 then
            echo ("表数据已超过 10000 行，请手工升级表结构")
            return
        end

        if #rows > 0 then
            local field_exists = {}
            for _, f in ipairs(dao.field_list) do
                field_exists[f.name] = true
            end

            for _, row in ipairs(rows) do
                for k in pairs(row) do
                    if not field_exists[k] then
                        row[k] = nil
                    end
                end
            end

            local table_name    = dao.table_name
            local table_name_bk = dao.table_name .. "_bk_" .. ngx.time()
            local res, err = db.execute("rename table " .. table_name .. " to " .. table_name_bk)
            if not res then
                echo("修改表名称失败：", err)
                return
            end

        else
            rows = nil
            dao.drop()  -- 删除表
        end

    end

    echo ("")
    local res, err = dao.create()
    if res then
        echo ( "创建表成功！")
    else
        echo ( "创建表失败：", err)
        echo ("")
        echo ( "如果要删除表，请添加drop参数：", "&drop=", LAST_DROP_NONCE)
        return
    end

    if type(dao.table_index)=="table" then
        echo ("")
        for name, fields in pairs(dao.table_index) do
            local sql = " alter table " .. dao.table_name
                     .. "   add index " .. name
                     .. " ( " .. table.concat(fields, ", ") .. " );"
            local res, err = db.execute(sql)
            if res then
                echo ( "创建索引成功：", name, " ( " , table.concat(fields, ", ") , " ) " )
            else
                echo ( "创建索引失败：", name, "；错误：", err )
            end
        end
    end

    rows = rows or dao.demo_data or {}

    if #rows > 0 then
        echo ("")
        echo ( "共有 ", #rows, " 行数据：" )
        echo ( "----------------------------------------------------------------------------------" )

        local trans = {
        --  " begin;  -- 事务处理开始"    ,
            dao:del { "1=1" }           ,
            dao:add(rows)      ,
        --  " commit; -- 事务处理提交"    ,
        }

        local sql = table.concat(trans,"\n")
        echo(sql)

        echo ( "----------------------------------------------------------------------------------" )

        local t = db.trans(sql)
        for i, r in ipairs(t) do
            echo (i, ") ", _encode (r) )
        end

        echo ( "----------------------------------------------------------------------------------" )

    end

    db.close()

end

return init_dao
