local _M = { _VERSION = "1.6.1" }

-- 类型声明
_M.types = {
    TCate = {
        cate_id     = "number   //类别编码",
        cate_name   = "string   //类别名称",
    },
    TDish =  {
        dish_id     = "number   //菜品编码",
        dish_name   = "string   //菜品名称",
        dish_price  = "number   //菜品价格",
    },
    TCateWithDishs  = {
        "@TCate",   -- 继承
        dish_count  = "number   //菜品数量",
        dishs       = "@TDish[] //菜品数据",
    }
}

-- 合并数据
_M.merge = function(cate, dishs)
-- @cate    : @TCate            //类别参数
-- @dishs   : @TDish[]          //菜品参数
-- @return  : @TCateWithDishs   //返回类别含菜品

    return {
        cate_id     = cate.cate_id,
        cate_name   = cate.cate_name,
        dish_count  = #dishs,
        not_exist   = "字段未定义",
        dishs       = {
            {
                dish_id     = dishs[1].dish_id,
                dish_name   = dishs[1].dish_name,
                dish_price  = dishs[1].dish_price,
                not_exist_1 = dishs[1].not_exist_1,  -- 字段未定义
            },{
                dish_id     = dishs[2].dish_id,
                dish_name   = dishs[2].dish_name,
                dish_price  = dishs[2].dish_price,
                not_exist_2 = dishs[2].not_exist_2,  -- 字段未定义
            },
        },
    }

end

-- 调试
_M._TESTING = function()

    -- @dishs : @TDish[]
    local dishs = {
        { dish_id = 1011, dish_name = "牛肉炒芥兰", dish_price = 100 },
        { dish_id = 1012, dish_name = "红烧狮子头", dish_price = 200 },
    }

    local c = _M.merge({ cate_id = 10, cate_name = "热菜" }, dishs)

        ngx.say("cate_id    : ", c.cate_id)
        ngx.say("cate_name  : ", c.cate_name)
        ngx.say("dish_count : ", c.dish_count)
        ngx.say("not_exist  : ", c.not_exist)  -- 字段未定义

    for i, d in ipairs(c.dishs) do
        ngx.say ""
        ngx.say("-------- [ ", i, " ] --------")
        ngx.say ""
        ngx.say("dish_id    : ", d.dish_id)
        ngx.say("dish_name  : ", d.dish_name)
        ngx.say("dish_price : ", d.dish_price)
    end

end

return _M
