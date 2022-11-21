
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

__.start = function()

    local ws = WS:new{
            timeout = 3 * 1000, -- 3秒超时
            max_payload_len = 65535
        }
    if not ws then return _html() end   -- 输出网页

    local data, index

    while true do
        local  msg = _wait(ws)
        if not msg then break end -- 等待消息

        if msg=="reset" then _reset() end

        data, index = waf.status.get_data(index)
        if not ws:send_text(data) then break end

        ngx.sleep(0.25)
    end

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
        elseif typ == "text"  then return data -- 字符串
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
