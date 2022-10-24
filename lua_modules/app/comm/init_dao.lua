
-- 创建dao表 v20.07.30 by Killsen ------------------

local require   = require
local templ     = require "resty.template"
local cjson     = require "cjson.safe"
local _render   = templ.render
local _encode   = cjson.encode

---------------------------------------------------

local help_html = [==[

local _load = require("app.{{app_name}}").load
local {{table_name}} = _load("${{table_name}}")  -- {{table_desc}}


----------------- 执行 sql 语句 -----------------

{{table_name}}.create()        -- 创建表
{{table_name}}.drop()          -- 删除表
{{table_name}}.clear()         -- 清空表

{{table_name}}.add  {...}      -- 增
{{table_name}}.del  {...}      -- 删
{{table_name}}.set  {...}      -- 改
{{table_name}}.get  {...}      -- 查询一条数据
{{table_name}}.list {...}      -- 查询多条数据


----------------- 生成 sql 语句 -----------------

{{table_name}}:create()        -- 创建表
{{table_name}}:drop()          -- 删除表
{{table_name}}:clear()         -- 清空表

{{table_name}}:add  {...}      -- 增
{{table_name}}:del  {...}      -- 删
{{table_name}}:set  {...}      -- 改
{{table_name}}:get  {...}      -- 查询一条数据
{{table_name}}:list {...}      -- 查询多条数据


]==]


-- 帮助
local function show_help(app, dao)
    _render(help_html,{
        app_name = app.name,
        table_name = dao.table_name,
        table_desc = dao.table_desc,
        first_fld = dao.field_list[1] and dao.field_list[1].name,
        field_list = dao.field_list
    })
end

local __drop -- 为了避免误删除表，删除表需要提供 drop 参数的值

-- 创建dao表
local function init_dao(app, dao)

    if "127.0.0.1" ~= ngx.var.remote_addr then
        ngx.exit(404)
        return
    end

    local db = app.load("%db")

    dao.demo_data = dao.demo_data or {}

    ngx.say ( dao.table_name, "(", dao.table_desc, ")" )
    ngx.say ( "----------------------------------------------------------------------------------" )

    ngx.say ("")
    if type(dao.field_list)~="table" or #dao.field_list==0 then
        ngx.say ( "尚未定义列" )
        return
    end

    ngx.say ( "共有 ", #dao.field_list, " 列：" )
    ngx.say ( "----------------------------------------------------------------------------------" )
    for _, d in ipairs(dao.field_list) do
        ngx.say ( "    ", _encode(d) )
    end

    ngx.say ("")
    ngx.say ( "共有 ", #dao.demo_data, " 行演示数据：" )
    ngx.say ( "----------------------------------------------------------------------------------" )
    for _, d in ipairs(dao.demo_data) do
        ngx.say ( "    ", _encode(d) )
    end

    local rows, err -- 历史数据

    if __drop and __drop == ngx.req.get_uri_args().drop then

        rows, err = dao.list { "1=1", _limit = 10001 }

        if not rows then
            ngx.say ("读取数据失败：", err)
            return
        end

        if #rows > 10000 then
            ngx.say ("表数据已超过 10000 行，请手工升级表结构")
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
                ngx.say("修改表名称失败：", err)
                return
            end

        else
            rows = nil
            dao.drop()  -- 删除表
        end

    end

    __drop = nil

    ngx.say ("")
    local res, err = dao.create()
    if res then
        ngx.say ( "创建表成功！")
    else
        ngx.say ( "创建表失败：", err)

        __drop = tostring(ngx.now()*1000)

        ngx.say ("")
        ngx.say ( "如果要删除表，请添加drop参数：", "&drop=", __drop)
        return
    end

    if type(dao.table_index)=="table" then
        ngx.say ("")
        for name, fields in pairs(dao.table_index) do
            local sql = " alter table " .. dao.table_name
                     .. "   add index " .. name
                     .. " ( " .. table.concat(fields, ", ") .. " );"
            local res, err = db.execute(sql)
            if res then
                ngx.say ( "创建索引成功：", name, " ( " , table.concat(fields, ", ") , " ) " )
            else
                ngx.say ( "创建索引失败：", name, "；错误：", err )
            end
        end
    end

    rows = rows or dao.demo_data or {}

    if #rows > 0 then
        ngx.say ("")
        ngx.say ( "共有 ", #rows, " 行数据：" )
        ngx.say ( "----------------------------------------------------------------------------------" )

        local trans = {
        --  " begin;  -- 事务处理开始"    ,
            dao:del { "1=1" }           ,
            dao:add(rows)      ,
        --  " commit; -- 事务处理提交"    ,
        }

        local sql = table.concat(trans,"\n")
        ngx.say(sql)

        ngx.say ( "----------------------------------------------------------------------------------" )

        local t = db.trans(sql)
        for i, r in ipairs(t) do
            ngx.say (i, ") ", _encode (r) )
        end

        ngx.say ( "----------------------------------------------------------------------------------" )

    end

    db.close()

end

return function(app)

    ngx.header["content-type"] = "text/plain; charset=utf-8"

    local args = ngx.req.get_uri_args()
    local name, init, help = args.name, args.init, args.help

    if type(name)~="string" or name == "" then
        ngx.say ("dao名称不能为空！")
        return
    end

    local dao = app.load("$" .. name)
    if not dao then
        ngx.say ("dao对象不存在：", name)
        return
    end

    if help then show_help(app, dao) end
    if init then init_dao (app, dao) end

end

