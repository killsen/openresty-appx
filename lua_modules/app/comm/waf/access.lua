
local waf     = require "app.comm.waf"
local WS      = require "resty.websocket.server"
local ngx_var = ngx.var
local _concat = table.concat
local _gsub   = string.gsub

local dict    = ngx.shared.waf_access

------------------------------------------------------
local __ = {}
__.ver   = "20.08.12"
__.name  = "服务器实时日志"
------------------------------------------------------

local KEY_INDEX = "X"

local log_head = {
    "remote_addr", "remote_user", "time_local",
    "request", "request_time", "request_length",
    "status", "body_bytes_sent", "http_referer",
    "http_user_agent", "server_ip", "server_port",
    "connection", "connection_requests"
}

function __.init()

end

function __.reset()

    dict:flush_all()

end

function __.log()

    if "waf" == ngx_var.log_type then return end

    -- 过滤掉非 http(s) 请求
    local  uri = ngx_var.request_uri
    if not uri then return end

    local ip   = ngx.ctx.server_ip   or "127.0.0.1"
    local port = ngx.ctx.server_port or 80

    local index = dict:incr( KEY_INDEX , 1 , 0 )
    if not index then return end

    local t = {}

    for i, k in ipairs(log_head) do
        if k == "server_ip" then
            t[i] = ip
        elseif k == "server_port" then
            t[i] = port
        else
            t[i] = ngx_var[k] or ""
        end
    end

    dict:set(index, _concat(t, "\t"))

end

function __.get_head()
    return "#\t" .. _concat(log_head, "\t")
end

function __.get_data(index, page_size)

    local min = tonumber(index) or 0
    if min < 0 then min = 0 end

    local max = dict:get( KEY_INDEX ) or 0
    if max <= 0 then return "", 0 end

       page_size = tonumber (page_size) or  100
    if page_size <   10 then page_size   =   10 end
    if page_size > 1000 then page_size   = 1000 end

    if min < max - page_size then
       min = max - page_size
    end

    local rows, j = {}, 0

    for i = min+1, max do
        local row = dict:get(i)
        if row then
            j=j+1; rows[j] = i .. "\t" .. row
        end
    end

    return _concat(rows, "\n"), max

end

--------------------------------------------------------------------------------

local _html, _wait

local function send_data(ws)

    local data, index

    while true do
        if ngx.worker.exiting() then break end
        if ws.fatal then break end

        data, index = __.get_data(index)
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
    end

end

-- 启动监控
__.start = function()

    local args = ngx.req.get_uri_args()
    local ip   = args.ip
    local port = tonumber(args.port) or 0

    local ws = WS:new {
        timeout         = 10000,  -- 10 秒超时
        max_payload_len = 65535
    }
    if not ws then
        return _html(ip, port)  -- 非 websocket 连接输出网页
    end

    local co_recv = ngx.thread.spawn(recv_data, ws)
    local co_send = ngx.thread.spawn(send_data, ws)

    ngx.thread.wait(co_recv, co_send)
    ngx.thread.kill(co_recv)
    ngx.thread.kill(co_send)

    ws:send_close()

end

-- 输出网页
function _html(ip, port)

    local  html = waf.html("access.html")
    if not html then return ngx.exit(400) end

    local my_title

    if ip and port then
        if port == 80 then
            my_title = "访问日志 ( " .. ip .. " )"
        else
            my_title = "访问日志 ( " .. ip .. ":" .. port .. " )"
        end
    else
        my_title = "访问日志"
    end

    html = _gsub(html, "{{ my_head }}" , __.get_head()  )
    html = _gsub(html, "{{ my_title }}", my_title       )
    html = _gsub(html, "{{ app_ver }}" , ngx.now()*1000 )
    html = _gsub(html, "{{ server_ip }}" , ip or ""     )
    html = _gsub(html, "{{ server_port }}" , port or 0  )

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

return __
