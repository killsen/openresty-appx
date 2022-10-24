
-- 初始化数据库 v20.08.19

local file_list = require "app.utils".file_list  -- lua文件列表
local _quote    = ngx.quote_sql_str

-- 取得表结构
local function _columns(app, dao)

    local db = app.load "%db"

    db.master = true -- 只使用主库 v20.08.09

    local table_schema = dao.table_schema or app.db_config.database
    local table_name   = dao.table_name

    local sql = [[
select `column_name`    as `name`,
       `column_comment` as `desc`,
       `column_default` as `def` ,
       `column_type`    as `type`,
       `column_key`     as `key`
  from information_schema.columns
 where table_schema = ]] .. _quote(table_schema) ..  [[
   and table_name   = ]] .. _quote(table_name  ) ..  [[
order by ordinal_position
;
]]

    local cols, err = db.execute(sql)
    if not cols then return nil, err end

    for _, col in ipairs(cols) do
        if col.key == "PRI" then
            col.pk = true
        end

        if col.def == ngx.null then
            col.def = nil
        end
    end

    return cols

end

-- 升级表结构
local function _upgrade(app, dao, index, add_column, drop_column)

    local db = app.load "%db"

    local res, err = dao.create()

    if res then
        ngx.say("-- ", index, ". ", dao.table_name, " ( ", dao.table_desc, " )", "\t[创建表成功]")

        local res, err = dao.create_index() -- 创建索引
        if not res then
            ngx.say("-- 创建索引失败：", err)
            ngx.say("")
        end

        return true
    end

    local  cols, err = _columns(app, dao)
    if not cols or #cols == 0 then
        ngx.say("-- 读取表结构失败：", err)
        return
    end

    local colx, _exist, is_the_same = {}, {}, true

    for _, c in ipairs(cols) do
        colx[c.name] = c
    end

    for _, f in ipairs(dao.field_list) do
        local c = colx[f.name]
        if c then
            _exist[f.name] = true
            -- 比较列机构【待改】
        end
    end

    -- 创建列
    for i, f in ipairs(dao.field_list) do
        if not _exist[f.name] then
            if is_the_same then
                ngx.say("")
                ngx.say("-- ", index, ". ", dao.table_name, " ( ", dao.table_desc, " )")
            end

            is_the_same = false

            local _null = f.pk   and " not null"                   or "" -- 是否允许空
            local _def  = f.def  and " default '" .. f.def .. "'"  or "" -- 默认值
            local _len  = f.len  and         " (" .. f.len .. ")"  or "" -- 长度
            local _desc = f.desc and " comment '" .. f.desc .. "'" or "" -- 备注

            local after = ""
            if i > 1 then  -- 创建在前一个列的后面 v20.08.19
                after = " after `"    .. dao.field_list[i-1].name .. "` "
            end

            local sql = " alter table " .. dao.table_name
                     .. " add column "
                     .. "`"    .. f.name .. "`"
                     .. " "    .. f.type .. _len
                     .. _null  .. _def   .. _desc
                     .. after  .. " ; "

            if add_column then

                local  res, err = db.execute(sql)
                if not res then
                    ngx.say("-- 创建列失败：", f.name, "；错误：", err)
                    return
                else
                    ngx.say("-- 创建列成功：", f.name)
                end

            else
                ngx.say("")
                ngx.say("-- 手工创建列：", f.name)
                ngx.say(sql)
            end

        end
    end

    -- 删除列
    for _, c in ipairs(cols) do
        if not _exist[c.name] then
            if is_the_same then
                ngx.say("")
                ngx.say("-- ", index, ". ", dao.table_name, " ( ", dao.table_desc, " )")
            end

            is_the_same = false

            local sql = " alter table " .. dao.table_name
                     .. " drop column " .. c.name  .. " ; "

            if drop_column then

                local  res, err = db.execute(sql)
                if not res then
                    ngx.say("-- 删除列失败：", c.name, "；错误：", err)
                    return
                else
                    ngx.say("-- 删除列成功：", c.name)
                end

            else
                ngx.say("")
                ngx.say("-- 手工删除列：", c.name)
                ngx.say(sql)
            end

        end
    end

    if is_the_same then
        ngx.say("-- ", index, ". ", dao.table_name, " ( ", dao.table_desc, " )", "\t[表结构一致]")
    else
        ngx.say("")
    end

    return true

end


return function(app)

    -- 只能本机执行
    if "127.0.0.1" ~= ngx.var.remote_addr then
        ngx.exit(404)
        return
    end

    local args = ngx.req.get_uri_args()
    local add_column  = args.add_column     -- 是否要添加列
    local drop_column = args.drop_column    -- 是否要删除列

    ngx.header['content-type'] = "text/plain"

    local url = "http://" .. ngx.var.http_host .. "/" .. app.name .. "/initdaos"

    ngx.say ""
    ngx.say("-- 只添加新增列: ", url, "?add_column")
    ngx.say("-- 只删除多余列: ", url, "?drop_column")
    ngx.say("-- 添加及删除列: ", url, "?add_column&drop_column")
    ngx.say ""

    if not app or not app.db_config or not app.db_config.database then
        ngx.say("-- 数据库未定义")
        return
    end

    ngx.say("-- 数据库名称：", app.db_config.database)

    local files = file_list("app/" .. app.name .. "/dao/") or {}
    ngx.say("-- dao 文件数：", #files)
    ngx.say("")

    for index, file in ipairs(files) do

        local dao = app.load("$" .. file)

        if type(dao) ~= "table" then
            ngx.say("-- 加载 dao 失败：" .. file)
            return
        end

        local res, err = _upgrade(app, dao, index, add_column, drop_column)
        if not res then return end
    end

end
