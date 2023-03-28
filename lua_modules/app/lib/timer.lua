
local _G            = _G
local ngx           = ngx
local timer_at      = ngx.timer.at
local timer_every   = ngx.timer.every
local pcall         = pcall
local rawget        = rawget

local __ = { _VERSION = "v23.03.28" }

__._README = [[
[OpenResty定时器](https://github.com/iresty/nginx-lua-module-zh-wiki/blob/master/README.md#ngxtimerat)
]]

__.running_count = ngx.timer.running_count -- 返回正在执行的定时器数量
__.pending_count = ngx.timer.pending_count -- 返回等待执行的定时器数量

-- 延时执行一次（单位秒）
__.at = function(delay, callback, ...)
-- @delay       : number
-- @callback    : function*
-- @return      : hdl?: number, err?: string

    local app_name   = ngx.ctx.app_name   -- 原环境
    local _unload    = app_name and rawget(_G, "_unload")  --> function
    local is_running = false

    local hdl, err = timer_at(delay, function(premature, ...)

        if premature then return end    -- 定时器已过期

        if is_running then return end   -- 运行中
           is_running = true

        ngx.ctx.app_name = app_name     -- 新环境

            local  ok, err = pcall(callback, ...)
            if not ok then ngx.log(ngx.ERR, "timer.at callback error: \n", err) end

            -- 清理相关资源（调用 app:unload）
            if type(_unload) == "function" then pcall(_unload) end

            is_running = false

    end, ...)

    if not hdl then
        ngx.log(ngx.ERR, "failed to create timer: ", err)
    end

    return hdl, err

end

-- 定时执行多次（单位秒）
__.every = function(delay, callback, ...)
-- @delay       : number
-- @callback    : function*
-- @return      : hdl?: number, err?: string

    local app_name   = ngx.ctx.app_name   -- 原环境
    local _unload    = app_name and rawget(_G, "_unload")  --> function
    local is_running = false

    local hdl, err = timer_every(delay, function(premature, ...)

        if premature then return end    -- 定时器已过期

        if is_running then return end   -- 运行中
           is_running = true

        ngx.ctx.app_name = app_name     -- 新环境

            local  ok, err = pcall(callback, ...)
            if not ok then ngx.log(ngx.ERR, "timer.every callback error: \n", err) end

            -- 清理相关资源（调用 app:unload）
            if type(_unload) == "function" then pcall(_unload) end

            is_running = false

    end, ...)

    if not hdl then
        ngx.log(ngx.ERR, "failed to create timer: ", err)
    end

    return hdl, err

end

-- 测试
__._TESTING = function()

    local function run_in_timer(abc, xyz)
    -- @abc : string
    -- @xyz : number
        ngx.sleep(1)
        ngx.log(ngx.ERR, "abc: ", abc)
        ngx.sleep(1)
        ngx.log(ngx.ERR, "xyz: ", xyz)
        ngx.sleep(1)
    end

    ngx.say("running: ", __.running_count())
    ngx.say("pending: ", __.pending_count())
    ngx.flush()

    local hdl, err = __.at(1, run_in_timer, "abc", 123)
    ngx.say("hdl: ", hdl, ", err: ", err)

    for _ = 1, 5 do
        ngx.say("running: ", __.running_count())
        ngx.say("pending: ", __.pending_count())
        ngx.flush()
        ngx.sleep(1)
    end

end

return __
