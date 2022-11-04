
-- 初始化列定义 v18.6.15 by Killsen ------------------

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

        f.len  = f.len  or ( f.type=="varchar"  and 100             )
                        or nil

        f.def  = f.def  or ( f.type=="varchar"  and ""              )
                        or ( f.type=="date"     and "1900-01-01"    )
                        or ( f.type=="datetime" and "1900-01-01"    )
                        or ( f.type=="int"      and 0               )
                        or ( f.type=="double"   and 0               )
                        or ( f.type=="decimal"  and 0               )
                        or ( f.type=="boolean"  and 0               )
                        or nil

    --  f.pk   = (f.pk == true)

        f[1]=nil; f[2]=nil; f[3]=nil
    end

end

return init_fields
