
local WS = require "resty.websocket.server"

------------------------------------------------------
local __ = {}
__.ver   = "19.07.01"
__.name  = "服务器实时监控"
------------------------------------------------------

local html

-- 等待客户端消息
local function ws_wait(ws)

    local bytes, data, typ, err

    while true do
        if ngx.worker.exiting() then return end

        data, typ, err = ws:recv_frame() -- 读取数据

        if ws.fatal then -- 出错啦
            ngx.log(ngx.ERR, "failed to receive frame: ", err)
            return
        end

        if not data then -- 暂无数据
            bytes, err = ws:send_ping()
            if not bytes then
                ngx.log(ngx.ERR, "failed to send ping: ", err)
                return
            end

        elseif typ == "ping" then -- ping
            bytes, err = ws:send_pong()
            if not bytes then
                ngx.log(ngx.ERR, "failed to send pong: ", err)
                return
            end

    --  elseif typ == "pong" then -- pong
    --      ngx.log(ngx.ERR, "client ponged")

        elseif typ == "close" then -- 关闭连接
    --      ngx.log(ngx.ERR, "client closed: ", err)
    --      bytes, err = ws:send_close()
    --      if not bytes then
    --          ngx.log(ngx.ERR, "failed to send close: ", err)
    --      end
            return

        elseif typ == "text" then -- 字符串

            return data

        end

    end

end

local mIndex  = 0

__.start = function()

    local ws = WS:new{
            timeout = 10 * 1000, -- 10秒超时
            max_payload_len = 65535
        }
    if not ws then
        ngx.header["content-type"] = "text/html; charset=utf-8"
        ngx.print(html)
        return
    end

    local host = ngx.var.host

    mIndex = mIndex + 1

    while true do
        ngx.sleep(0.25)

        if not ws_wait(ws) then break end

        local text = "Server  host  : " .. host              .. "\n"
                  .. "Server  time  : " .. ngx.localtime()   .. "\n"
                  .. "Update  time  : " .. ngx.now()*1000    .. "\n"
                  .. "Worker  pid   : " .. ngx.worker.pid()  .. "\n"
                  .. "Minitor count : " .. mIndex            .. "\n"
                  .. "-------------------------------------" .. "\n"
                  .. "Connection active  : " .. ngx.var.connections_active  .. "\n"
                  .. "Connection reading : " .. ngx.var.connections_reading .. "\n"
                  .. "Connection writing : " .. ngx.var.connections_writing .. "\n"
                  .. "Connection waiting : " .. ngx.var.connections_waiting .. "\n"

        if not ws:send_text(text) then break end
    end

    mIndex = mIndex - 1

    ws:send_close()
end

html = [[
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=0">
    <title>Monitor</title>
</head>
<body style="margin: 2em;">
    <h2>服务器实时监控</h2>
    <pre id="log" style="height:13em;"></pre>
    <button onclick="start_ws();">启动监控</button>
    <button onclick="close_ws();">停止监控</button>
</body>
</html>

<script>

    var url  = (location.protocol == "https:" ? "wss://" : "ws://")
             +  location.hostname + location.pathname;

    var $log = document.getElementById("log");
    var ws, timerId;

    start_ws();

    function start_ws(){
        close_ws();

        // 监控 WebSocket
        timerId = setInterval(function(){
            ws && ws.readyState==3 && start_ws();
        }, 3000);

        ws = new WebSocket(url);

        ws.onopen = function(e) {
            ws.send("start");
        };

        ws.onmessage = function(e) {
            $log.innerText=e.data;
            ws && ws.readyState==1 && ws.send("next");
        };

    }

    function close_ws(){

        timerId && clearInterval(timerId);
        timerId = null;

        ws && ws.readyState==1 && ws.close();
        ws = null;

    }

</script>
]]

return __
