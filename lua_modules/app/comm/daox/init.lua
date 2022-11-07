-- @@api : openresty-vsce

local __ = { __VERSION = "v1.0.0" }

__.init_dao__ = {
    "重新建表",
    req = {
        { "app_name"    , "APP名称"                 },
        { "dao_name"    , "DAO名称"                 },
        { "drop_nonce?" , "删表随机码"  , "number"  },
    },
    res = "boolean"
}
__.init_dao = function(t)
    local init_dao = require "app.comm.daox.init_dao"
    return init_dao(t.app_name, t.dao_name, t.drop_nonce)
end

__.init_daos__ = {
    "升级表结构",
    req = {
        { "app_name"    , "APP名称"                   },
        { "add_column?" , "是否要添加列"  , "boolean"  },
        { "drop_column?", "是否要删除列"  , "boolean"  },
    },
    res = "boolean"
}
__.init_daos = function(t)
    local init_daos = require "app.comm.daox.init_daos"
    return init_daos(t.app_name, t.add_column, t.drop_column)
end

-- 生成API模块
require "app.comm.apix".new(__)

return __
