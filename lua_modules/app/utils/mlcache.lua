
-- 多级缓存工具类 v21.03.24

local mlcache = require "resty.mlcache"
local _insert = table.insert
local _sleep  = ngx.sleep
local _lower  = string.lower
local ipairs  = ipairs
local pairs   = pairs

--------------------------------------------------------------------------------

-- 是否多 worker 模式
local multi_workers = ngx.worker.count() > 1

local OPTS = {
        lru_size    = 1000  -- 本地缓存数量: 1000条 (默认100)
    ,   ttl         = 3600  -- 数据缓存时间: 60分钟 (默认30秒)
    ,   neg_ttl     = 10    -- 空值缓存时间: 10秒钟 (默认5秒)

    ,   shm_locks   = "my_locks"    -- 存储锁
    ,   shm_miss    = "my_miss"     -- 存储空值
}

if multi_workers then
    OPTS.ipc_shm    = "my_ipc"      -- 进程间通信

else
    OPTS.ipc = {  -- 伪造一个进程间通信对象 ----
            register_listeners  = function() end
        ,   broadcast           = function() end
        ,   poll                = function() end
    }
end

--------------------------------------------------------------------------------

local OBJ_MAP   = {}  -- 对象索引（按名称）
local ML_CACHES = {}  -- 全部 mlcache 对象
local MY_MISS   = {}  -- 共用数据缓存的 mlcache 对象
local MY_CACHE  = {}  -- 共用空值缓存的 mlcache 对象

-- 每秒钟自动更新
if multi_workers then

    local function _update()
        for _, cache in ipairs(ML_CACHES) do
            cache:update()
            _sleep(0.001)
        end
    end

    ngx.timer.every(1, _update)

end

local function _cache(shm, shm_miss, cache)

    -- 共用数据缓存的 mlcache 对象
    if shm then
        MY_CACHE[shm] = MY_CACHE[shm] or {}
        _insert(MY_CACHE[shm], cache)
    end

    -- 共用空值缓存的 mlcache 对象
    if shm_miss then
        MY_MISS[shm_miss] = MY_MISS[shm_miss] or {}
        _insert(MY_MISS[shm_miss], cache)
    end

end

-- 清除缓存
local function _purge(shm, shm_miss)

    local map = {}

    -- 共用数据缓存的 mlcache 对象
    for _, cache in ipairs(MY_CACHE[shm] or {}) do
        map[cache] = true
    end

    -- 共用空值缓存的 mlcache 对象
    for _, cache in ipairs(MY_MISS[shm_miss] or {}) do
        map[cache] = true
    end

    -- 清除缓存
    local ok, err
    for cache in pairs(map) do
        ok, err = cache:purge()
    end

    return ok, err

end

--------------------------------------------------------------------------------

-- 构造函数
local function _new(name, shm, opts)

    -- 第一个参数是对象
    if type(name) == "table" then
        local t = name
        name, shm, opts = t.name, t.shm, t

    -- 第二个参数是对象
    elseif type(shm) == "table" then
        local t = shm
        shm, opts = t.shm, t
    end

    -- 默认命名空间
    if type(name) ~= "string" or name == "" then
        name = "#"
    else
        name = "/" .. _lower(name) .. "/"
    end

    -- 默认共享内存
    if type(shm) ~= "string" or shm == "" then
        shm = "my_cache"
    end

    -- 命名空间相同：直接返回对象
    if OBJ_MAP[name] then return OBJ_MAP[name] end

    -- 参数对象
    if type(opts) ~= "table" then opts = {} end

    -- 单进程模式
    if not multi_workers then
        opts.ipc_shm = nil
        opts.ipc     = OPTS.ipc
    end

    -- 初始化默认参数
    for k, v in pairs(OPTS) do
        if opts[k] == nil then
            opts[k] = v
        end
    end

    -- 创建 mlcache 对象
    local cache = mlcache.new(name, shm, opts)

        _insert(ML_CACHES, cache)
        _cache(shm, opts.shm_miss, cache)


    local obj = {};  OBJ_MAP[name] = obj  -- 对象索引（按名称）
    ----------------------------------------------------------------------------

        -->> { new, purge, get, load, del, set }
        obj.new = _new

        -->> ok, err
        obj.purge = function ()
            _purge(shm, opts.shm_miss)
        end

        -->> val, err, hit_level
        obj.get = function (key, fun, ...)

            key = _lower(key) -- 统一小写 v22.03.24

            -- 多 worker 模式下：自动更新
            if multi_workers then cache:update() end

            if type(fun) ~= "function" then
                local ttl, err, val = cache:peek(key)
                return val, err, ttl
            else
                local val, err, hit_level = cache:get(key, nil, fun, ...)
                return val, err, hit_level
            end

        end

        -->> val, err, hit_level
        obj.load = function (key, fun, ttl)

            key = _lower(key) -- 统一小写 v22.03.24

            -- 多 worker 模式下：自动更新
            if multi_workers then cache:update() end

            return cache:get(key, {ttl=ttl}, fun)

        end

        -->> ok, err
        obj.del = function (key)
            key = _lower(key) -- 统一小写 v22.03.24
            return cache:delete(key)
        end

        -->> ok, err
        obj.set = function (key, val, ttl)
            key = _lower(key) -- 统一小写 v22.03.24
            return cache:set(key, {ttl=ttl}, val)
        end

    ----------------------------------------------------------------------------
    return setmetatable(obj, {
        __call = function (_, ...)
            return _new(...)
        end
    })

end

return _new()
