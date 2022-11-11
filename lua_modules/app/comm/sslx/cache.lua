
local mlcache = require "resty.mlcache"

local cache = mlcache.new("sslx", "my_cache", {
        lru_size    = 100   -- 本地缓存数量: 100条
    ,   ttl         = 3600  -- 数据缓存时间: 60分钟
    ,   neg_ttl     = 10    -- 空值缓存时间: 10秒钟

    ,   shm_locks   = "my_locks"   -- 存储锁
    ,   shm_miss    = "my_miss"    -- 存储空值
    ,   ipc_shm     = "my_ipc"     -- 进程间通信
})

-- 每 5 秒自动更新缓存
ngx.timer.every(5, function(premature)
    if premature then return end
    cache:update()
end)

local __ = {}

__.get = function(key, cb, ...)
    return cache:get(key, nil, cb, ...)
end

__.peek = function(key, stale)
    return cache:peek(key, stale)
end

__.delete = function(key)
    return cache:delete(key)
end

return __
