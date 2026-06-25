
-- 初始化列定义 v26.06.25 by Killsen ------------------

-- 字段类型对应的默认值
local DEFAULTS = {

    -- 数值类型
    tinyint     = 0,
    smallint    = 0,
    mediumint   = 0,
    int         = 0,
    bigint      = 0,
    float       = 0,
    double      = 0,
    decimal     = 0,

    -- 字符串类型
    char        = "",
    varchar     = "",
    tinytext    = "",
    text        = "",
    mediumtext  = "",
    longtext    = "",

    -- 日期时间类型
    date        = "1900-01-01",
    time        = "00:00:00",
    datetime    = "1900-01-01 00:00:00",

}

-- 初始化列定义
local function init_fields(field_list)

    if type(field_list)~="table" then return end

    for _, f in ipairs(field_list) do

        f.name = f.name or f[1]
        f.desc = f.desc or f[2]
        f.type = f.type or f[3] or "varchar"

        -- 货币类型转换成 decimal(19,4)
        if f.type=="money" or f.type=="currency" then
            f.type = "decimal"
            f.len  = "19,4"
        end

        f.len  = f.len  or (f.type=="varchar" and 100) or nil
        f.def  = f.def  or DEFAULTS[f.type]
    --  f.pk   = (f.pk == true)

        f[1]=nil; f[2]=nil; f[3]=nil
    end

end

return init_fields
