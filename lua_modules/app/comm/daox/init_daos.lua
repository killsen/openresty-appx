
-- 初始化数据库 v20.08.19

local file_list = require "app.comm.utils".file_list  -- lua文件列表
local _quote    = ngx.quote_sql_str

local function echo(...)
    ngx.say(...)
    ngx.flush()
end

-- 取得表结构
local function get_columns(app_name, dao_name)

    local app = require "app.comm.appx".new(app_name)
    local dao = app:load_dao(dao_name)

    app.db.master = true -- 只使用主库 v20.08.09

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

    local cols, err = app.db.execute(sql)
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
local function upgrade_table(app_name, dao_name, index, add_column, drop_column)

    local app = require "app.comm.appx".new(app_name)
    local dao = app:load_dao(dao_name)

    local res, err = dao.create()

    if res then
        echo("-- ", index, ". ", dao.table_name, " ( ", dao.table_desc, " )", "\t[创建表成功]")

        local res, err = dao.create_index() -- 创建索引
        if not res then
            echo("-- 创建索引失败：", err)
            echo("")
        end

        return true
    end

    local  cols, err = get_columns(app_name, dao_name)
    if not cols or #cols == 0 then
        echo("-- 读取表结构失败：", err)
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
                echo("")
                echo("-- ", index, ". ", dao.table_name, " ( ", dao.table_desc, " )")
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

                local  res, err = app.db.execute(sql)
                if not res then
                    echo("-- 创建列失败：", f.name, "；错误：", err)
                    return
                else
                    echo("-- 创建列成功：", f.name)
                end

            else
                echo("")
                echo("-- 手工创建列：", f.name)
                echo(sql)
            end

        end
    end

    -- 删除列
    for _, c in ipairs(cols) do
        if not _exist[c.name] then
            if is_the_same then
                echo("")
                echo("-- ", index, ". ", dao.table_name, " ( ", dao.table_desc, " )")
            end

            is_the_same = false

            local sql = " alter table " .. dao.table_name
                     .. " drop column " .. c.name  .. " ; "

            if drop_column then

                local  res, err = app.db.execute(sql)
                if not res then
                    echo("-- 删除列失败：", c.name, "；错误：", err)
                    return
                else
                    echo("-- 删除列成功：", c.name)
                end

            else
                echo("")
                echo("-- 手工删除列：", c.name)
                echo(sql)
            end

        end
    end

    if is_the_same then
        echo("-- ", index, ". ", dao.table_name, " ( ", dao.table_desc, " )", "\t[表结构一致]")
    else
        echo("")
    end

    return true

end

local function init_daos(app_name, add_column, drop_column)

    ngx.header['content-type'] = "text/plain"

    if "127.0.0.1" ~= ngx.var.remote_addr then
        echo "该操作只能在本机执行"
        return
    end

    local app = require "app.comm.appx".new(app_name)
    if not app then
        echo "加载APP失败"
        return
    end

    app_name = app.name

    local url = "http://" .. ngx.var.http_host .. "/" .. app_name .. "/initdaos"

    echo ""
    echo("-- 只添加新增列: ", url, "?add_column")
    echo("-- 只删除多余列: ", url, "?drop_column")
    echo("-- 添加及删除列: ", url, "?add_column&drop_column")
    echo ""

    if not app or not app.db_config or not app.db_config.database then
        echo("-- 数据库未定义")
        return
    end

    echo("-- 数据库名称：", app.db_config.database)

    local files = file_list("app/" .. app_name .. "/dao/") or {}
    echo("-- dao 文件数：", #files)
    echo("")

    for index, dao_name in ipairs(files) do
        local ok = upgrade_table(app_name, dao_name, index, add_column, drop_column)
        if not ok then return end
    end

    return true

end

return init_daos
