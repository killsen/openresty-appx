--[[
_load "%timer"                      -> timer
timer.at   (delay, callback, ...)   -> ok, err  -- 延时执行一次
timer.every(delay, callback, ...)   -> ok, err  -- 定时执行多次
timer.running_count()               -> count    -- 返回正在执行的定时器数量
timer.pending_count()               -> count    -- 返回等待执行的定时器数量
--]]

local timer_at      = ngx.timer.at
local timer_every   = ngx.timer.every
local pcall         = pcall

-- 定时器文档：
-- https://github.com/iresty/nginx-lua-module-zh-wiki/blob/master/README.md#ngxtimerat

-- 延时执行一次（单位秒）
local function _at(delay, callback, ...)

    local app_name   = ngx.ctx.app_name   -- 原环境
    local _load      = _load
    local is_running = false

    local ok, err = timer_at(delay, function(premature, ...)

        if premature then return end    -- 定时器已过期

        if is_running then return end   -- 运行中
           is_running = true

        ngx.ctx.app_name = app_name     -- 新环境

            local  ok, err = pcall(callback, ...)
            if not ok then ngx.log(ngx.ERR, "timer.at callback error: \n", err) end

            _load() -- 清理相关资源（调用 app.unload）

            is_running = false

    end, ...)

    if not ok then
        ngx.log(ngx.ERR, "failed to create timer: ", err)
    end

    return ok, err

end

-- 定时执行多次（单位秒）
local function _every(delay, callback, ...)

    local app_name   = ngx.ctx.app_name   -- 原环境
    local _load      = _load
    local is_running = false

    local ok, err = timer_every(delay, function(premature, ...)

        if premature then return end    -- 定时器已过期

        if is_running then return end   -- 运行中
           is_running = true

        ngx.ctx.app_name = app_name     -- 新环境

            local  ok, err = pcall(callback, ...)
            if not ok then ngx.log(ngx.ERR, "timer.every callback error: \n", err) end

            _load() -- 清理相关资源（调用 app.unload）

            is_running = false

    end, ...)

    if not ok then
        ngx.log(ngx.ERR, "failed to create timer: ", err)
    end

    return ok, err

end

return {
        at              = _at
    ,   every           = _every
    ,   running_count   = ngx.timer.running_count -- 返回正在执行的定时器数量
    ,   pending_count   = ngx.timer.pending_count -- 返回等待执行的定时器数量
}
