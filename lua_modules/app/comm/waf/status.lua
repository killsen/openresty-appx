
local waf           = require "app.comm.waf"
local ngx_var       = ngx.var
local waf_status    = ngx.shared.waf_status
local _encode       = require "cjson.safe".encode

------------------------------------------------------
local __ = {}
__.ver   = "20.08.07"
__.name  = "服务器实时状态"
------------------------------------------------------

local NGX_INDEX    = 'I'

local NGX_INIT      = 'A'
local NGX_START     = 'B'

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

    local  ok = waf_status:add( NGX_INIT, true )
    if not ok then return end

    waf_status:set( NGX_START, ngx.time() )

    local servers = waf.server.load()

    for _, server in ipairs(servers) do
        local key = server.ip .. ":" .. server.port .. "/"
        for j = 1, KEY_COUNT do
            waf_status:set( key .. j , 0 )
        end
    end

end

function __.reset()

    waf_status:flush_all()

    __.init()

end

function __.update_index()

    waf_status:incr( NGX_INDEX , 1 , 0 )

end

function __.log()

    if "off" == ngx_var.waf_log then return end

    -- 过滤掉非 http(s) 请求
    local  uri = ngx_var.request_uri
    if not uri then return end

    local ip   = ngx.ctx.server_ip   or "127.0.0.1"
    local port = ngx.ctx.server_port or 80

    local key = ip .. ":" .. port .. "/"

    local  n = tonumber(ngx_var.status) or 0
    if     n < 200 then waf_status:incr( key .. KEY_1XX , 1, 0 )
    elseif n < 300 then waf_status:incr( key .. KEY_2XX , 1, 0 )
    elseif n < 400 then waf_status:incr( key .. KEY_3XX , 1, 0 )
    elseif n < 500 then waf_status:incr( key .. KEY_4XX , 1, 0 )
    else                waf_status:incr( key .. KEY_5XX , 1, 0 ) end

    waf_status:incr( key .. KEY_READ  , ngx_var.request_length , 0 )
    waf_status:incr( key .. KEY_WRITE , ngx_var.bytes_sent     , 0 )
    waf_status:incr( key .. KEY_TIME  , ngx_var.request_time   , 0 )

    __.update_index()

end


local function get_server_data(server)

    local key = server.ip .. ":" .. server.port .. "/"

    return {
            ip        = server.ip
        ,   port      = server.port

        ,   ["1xx"  ] = waf_status:get( key .. KEY_1XX   ) or 0
        ,   ["2xx"  ] = waf_status:get( key .. KEY_2XX   ) or 0
        ,   ["3xx"  ] = waf_status:get( key .. KEY_3XX   ) or 0
        ,   ["4xx"  ] = waf_status:get( key .. KEY_4XX   ) or 0
        ,   ["5xx"  ] = waf_status:get( key .. KEY_5XX   ) or 0

        ,   ["read" ] = waf_status:get( key .. KEY_READ  ) or 0
        ,   ["write"] = waf_status:get( key .. KEY_WRITE ) or 0
        ,   ["time" ] = waf_status:get( key .. KEY_TIME  ) or 0
    }

end

function __.get_data(index)

    local t = {
            start_time   = waf_status:get( NGX_START ) or 0
        ,   local_time   = ngx.now()
        ,   conn_active  = tonumber(ngx_var.connections_active ) or 0
        ,   conn_reading = tonumber(ngx_var.connections_reading) or 0
        ,   conn_writing = tonumber(ngx_var.connections_writing) or 0
        ,   conn_waiting = tonumber(ngx_var.connections_waiting) or 0
    }

    local ngx_index = waf_status:get( NGX_INDEX ) or 0

    if index and index == ngx_index then
        return _encode(t), ngx_index
    end

    local servers, serverx = waf.server.load()

    t.servers = {}

    for _, server in ipairs(servers) do
        local s = get_server_data(server)
        s.status = " "
        table.insert(t.servers, s)
    end

    for _, server in ipairs(serverx) do
        local s = get_server_data(server)
        s.status = "X"
        table.insert(t.servers, s)
    end

    table.sort(t.servers, function(a, b)
        if a.ip == b.ip then
            return a.port < b.port
        else
            return a.ip < b.ip
        end
    end)

    local s = get_server_data { ip = "127.0.0.1", port = 80 }
    s.status = " "
    table.insert(t.servers, s)

    return _encode(t), ngx_index

end

return __
