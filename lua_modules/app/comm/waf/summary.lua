
local waf     = require "app.comm.waf"
local WS      = require "resty.websocket.server"
local ngx_var = ngx.var
local _concat = table.concat
local _gsub   = string.gsub
local _sub    = string.sub
local _find   = string.find

local dict_url = ngx.shared.waf_summary_url
local dict_ip  = ngx.shared.waf_summary_ip

------------------------------------------------------
local __ = {}
__.ver   = "20.08.12"
__.name  = "服务器访问统计"
------------------------------------------------------

local KEY_1XX       = "1"
local KEY_2XX       = '2'
local KEY_3XX       = '3'
local KEY_4XX       = '4'
local KEY_5XX       = '5'
local KEY_READ      = '6'
local KEY_WRITE     = '7'
local KEY_TIME      = '8'
-------------------------
local KEY_COUNT     =  8


function __.init()

end

function __.reset()

    dict_url:flush_all()
    dict_ip :flush_all()

end

local function _log(dict, key)

    if not dict then return end

    local  n = tonumber(ngx_var.status) or 0
    if     n < 200 then dict:incr( key .. KEY_1XX , 1, 0 )
    elseif n < 300 then dict:incr( key .. KEY_2XX , 1, 0 )
    elseif n < 400 then dict:incr( key .. KEY_3XX , 1, 0 )
    elseif n < 500 then dict:incr( key .. KEY_4XX , 1, 0 )
    else                dict:incr( key .. KEY_5XX , 1, 0 ) end

    dict:incr( key .. KEY_READ  , ngx_var.request_length , 0 )
    dict:incr( key .. KEY_WRITE , ngx_var.body_bytes_sent, 0 )
    dict:incr( key .. KEY_TIME  , ngx_var.request_time   , 0 )

end

function __.log()

    if "waf" == ngx_var.log_type then return end

    -- 过滤掉非 http(s) 请求
    local  uri = ngx_var.request_uri
    if not uri then return end

    local index = _find( uri, '?' )
    if index then uri = _sub( uri, 1 , index - 1 ) end

    _log(dict_url, uri)
    _log(dict_ip, ngx_var.remote_addr )

end

function __.get_head()

    local t, i = {}, 0;

        i=i+1; t[i] = "url"
        i=i+1; t[i] = "1xx"
        i=i+1; t[i] = "2xx"
        i=i+1; t[i] = "3xx"
        i=i+1; t[i] = "4xx"
        i=i+1; t[i] = "5xx"
        i=i+1; t[i] = "read"
        i=i+1; t[i] = "write"
        i=i+1; t[i] = "time"

    return _concat(t, "\t")

end

function __.get_data(log, cb)

    -- 回调函数
    if type(cb)~="function" then return end

    local dict = log == "url" and dict_url
              or log == "ip"  and dict_ip
              or nil
    if not dict then return end

    local  keys = dict:get_keys(0)
    if not keys then return end

    local rows, t, exist, i = {}, {}, {}, 0

    for _, key in ipairs(keys) do

        local uri = _sub(key, 1, -2)

        if not exist[uri] then
            exist[uri] = true

            t[1] = uri
            for j=1, KEY_COUNT do
                t[j+1] = dict:get(uri .. j) or 0
            end

            i=i+1; rows[i] = _concat(t, "\t")

            if i==100 then  -- 满100条数据输出
                local  ok = cb(_concat(rows, "\n", 1, i))
                if not ok then return end
                i=0; ngx.sleep(0)
            end
        end
    end

    if i>0 then -- 未满100条数据输出
        cb(_concat(rows, "\n", 1, i))
    end

end

--------------------------------------------------------------------------------

local _html

-- 启动监控
__.start = function()

    local  args = ngx.req.get_uri_args()
    local  log  = args.log or "url"

    local dict = log == "url" and dict_url
              or log == "ip"  and dict_ip
              or nil
    if not dict then return ngx.exit(400) end

    local ws = WS:new{
            timeout = 3 * 1000, -- 3秒超时
            max_payload_len = 65535
        }
    if not ws then return _html(log) end   -- 输出网页

    local function _send(data)
        return ws:send_text(data)
    end

    __.get_data(log, _send)

    ws:send_close()

end

-- 输出网页
function _html(log)

    local  html = waf.html("summary.html")
    if not html then return ngx.exit(400) end

    html = _gsub(html, "{{ my_head }}" , __.get_head()  )
    html = _gsub(html, "{{ log_type }}", log:upper()    )
    html = _gsub(html, "{{ app_ver }}" , ngx.now()*1000 )

    ngx.header["content-type"] = "text/html; charset=utf-8"
    ngx.print(html)

end

return __
