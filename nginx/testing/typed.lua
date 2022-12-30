
local _M = { _VERSION = "1.0.1" }

-- 类型声明
_M.types = {
    TCate = {
        cate_id     = "string   //类别编码",
        cate_name   = "string   //类别名称",
    },
    TItem =  {
        item_id     = "string   //明细编码",
        item_name   = "string   //明细名称",
    },
    TCateWithItem = {
        "@TCate",   -- 继承类别数据
        item        = "@TItem  //明细数据",
    }
}

-- 合并数据
_M.merge = function(cate, item)
-- @cate    : @TCate            //类别参数
-- @item    : @TItem            //明细参数
-- @return  : @TCateWithItem    //返回类别含明细

    return {
        cate_id     = cate.cate_id,
        cate_name   = cate.cate_name,
        not_exist   = "------------",
        item        = {
            item_id     = item.item_id,
            item_name   = item.item_name,
            not_exist   = "------------",
        },
    }

end

-- 调试
_M._TESTING = function()

    local t = _M.merge({
        cate_id     = "cate_id",
        cate_name   = "cate_name",
        not_exist   = "not_exist",
    }, {
        item_id     = "item_id",
        item_name   = "item_name",
        not_exist   = "not_exist",
    })

    ngx.say ""
    ngx.say(t.cate_id)
    ngx.say(t.cate_name)
    ngx.say(t.not_exist)
    ngx.say ""
    ngx.say(t.item.item_id)
    ngx.say(t.item.item_name)
    ngx.say(t.item.not_exist)
    ngx.say ""

end

return _M
