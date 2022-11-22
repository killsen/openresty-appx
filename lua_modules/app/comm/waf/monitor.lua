
local waf     = require "app.comm.waf"
local WS      = require "resty.websocket.server"
local _gsub   = string.gsub
local _openx  = io.openx

------------------------------------------------------
local __ = {}
__.ver   = "20.08.12"
__.name  = "服务器实时监控"
------------------------------------------------------

local _html, _wait, _save, _reset

local function send_data(ws)

    local data, index

    while true do
        if ngx.worker.exiting() then break end
        if ws.fatal then break end

        data, index = waf.status.get_data(index)
        if data and data ~= "" then
            if not ws:send_text(data) then break end
        end

        ngx.sleep(0.25)
    end

end

local function recv_data(ws)

    while true do
        if ngx.worker.exiting() then break end
        if ws.fatal then break end

        local  msg = _wait(ws)
        if not msg then break end -- 等待消息

        if msg == "reset" then _reset() end
    end

end


__.start = function()

    local ws = WS:new {
        timeout         = 10000,  -- 10 秒超时
        max_payload_len = 65535
    }
    if not ws then
        return _html()  -- 非 websocket 连接输出网页
    end

    local co_recv = ngx.thread.spawn(recv_data, ws)
    local co_send = ngx.thread.spawn(send_data, ws)

    ngx.thread.wait(co_recv, co_send)
    ngx.thread.kill(co_recv)
    ngx.thread.kill(co_send)

    ws:send_close()

end

-- 输出网页
function _html()

    local  html = waf.html("monitor.html")
    if not html then return ngx.exit(400) end

    local my_data = waf.status.get_data()

    html = _gsub(html, "{{ my_data }}" , my_data        )
    html = _gsub(html, "{{ app_ver }}" , ngx.now()*1000 )

    ngx.header["content-type"] = "text/html; charset=utf-8"
    ngx.print(html)

end

-- 等待消息
function _wait(ws)

    local bytes, data, typ, err

    while true do
        if ngx.worker.exiting() then return end

        data, typ, err = ws:recv_frame() -- 读取数据

        if ws.fatal then return end -- 出错啦

        if not data then -- 暂无数据
            bytes, err = ws:send_ping()
            if not bytes then return end

        elseif typ == "ping" then -- ping
            bytes, err = ws:send_pong()
            if not bytes then return end

    --  elseif typ == "pong"  then -- pong
        elseif typ == "close" then return -- 关闭连接
        elseif typ == "text"  then
            if data == "ping" then
                bytes, err = ws:send_text("pong")
                if not bytes then return end
            elseif data ~= "pong" and data ~= "" then
                return data
            end
        end

    end

end

function _reset()

    _save()

    waf.status.reset()
    waf.summary.reset()
    waf.access.reset()

end

function _save()

    local  time = ngx.localtime()
           time = time:gsub("-", "")
           time = time:gsub(":", "")
           time = time:gsub(" ", "_")

    local  file = _openx("logs/waf_" .. time .. ".log", "wb+")
    if not file then return end

    local function _write(data)
        return file:write(data) and file:write("\n")
    end

        _write ( "--------------- status ---------------" )
        _write ( waf.status.get_data() )
        _write ( "" )

    for _, log in ipairs {"url", "ip"} do

        _write ( "--------------- " .. log .. " ---------------" )
        _write ( waf.summary.get_head() )

        waf.summary.get_data(log, _write)

        _write ( "" )

    end

    file:close()

end


return __
