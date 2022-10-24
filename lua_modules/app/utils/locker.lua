
local Lock = require "resty.lock"

local __ = { _VERSION = "20.09.01" }

local LOCK_SHM = "my_locks"
local LOCK_KEY = "#locker:"

-- 加锁
__.lock = function(key, timeout)

    if type(key) ~= "string" or key == "" then
        return nil, "lock key is empty"
    end

    local opt = {
        timeout = tonumber(timeout) or 5  -- 默认5秒超时
    }

    local lock, err = Lock:new(LOCK_SHM, opt)
    if not lock then return nil, err end

    local elapsed, err = lock:lock(LOCK_KEY .. key)
    if not elapsed then return nil, err end

    return lock

end

-- 解锁
__.unlock = function(lock)

    if not lock then return true end

    local ok, err = lock:unlock()
    if not ok and err ~= "unlocked" then
        return nil, err
    end

    return true

end

-- 加锁运行
__.run = function(key, timeout, fun, ...)

    if type(key) ~= "string" or key == "" then
        return nil, "lock key is empty"
    end

    local has_p1, p1

    -- 兼容参数 (key, fun, ...)
    if type(timeout) == "function" then
        has_p1 = true
        p1, fun, timeout = fun, timeout, nil
    end

    -- 回调函数
    if type(fun) ~= "function" then
        return nil, "callback is not function"
    end

    -- 加锁
    local lock, lerr = __.lock(key, timeout)
    if not lock then return nil, lerr end

    local ok, res, err

    if has_p1 then
        ok, res, err = pcall(fun, p1, ...)
    else
        ok, res, err = pcall(fun, ...)
    end

    -- 解锁
    __.unlock(lock)

    if not ok then
        return nil, res  -- 回调错误
    else
        return res, err  -- 回调成功
    end

end

return __
