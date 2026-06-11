
-- Http请求 v26.04.02

local ngx       = ngx
local type      = type
local ipairs    = ipairs

local http      = require "resty.http"

local _newt     = table.new
local _concat   = table.concat

local conn_timeout = 1000 * 10  -- 连接超时 10 秒
local send_timeout = 1000 * 90  -- 发送超时 90 秒
local read_timeout = 1000 * 90  -- 读取超时 90 秒

local USER_AGENT = [[Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36]]

-- 类型声明
--- HttpPart    : { name, mime?, type?, body?, data?, file? }
--- HttpOption  : { url?, method?, body?, query?, headers?: map<string> }
--- HttpOption  & { parts?: @HttpPart[], ssl_server_name?, ssl_verify?: boolean }
--- HttpOption  & { ssl_client_cert?: cdata, ssl_client_priv_key?: cdata }
--- HttpRespons : { status: number, reason, headers: map<string>, has_body: boolean, body }

-- 生成表单数据
local function gen_multipart_form(parts)
-- @parts   : @HttpPart[]
-- @return  : body: string, boundary: string

    local i    = 0
    local body = _newt(#parts * 5, 0)
    local md5  = ngx.md5("boundary" .. ngx.now()*1000)

    local boundary = '--boundary--' .. md5 .. '--boundary--'

        i=i+1; body[i] = '--' .. boundary

    for _, p in ipairs(parts) do

        if type(p.name) ~= "string" or p.name == "" then
            return nil, nil, "name is null"
        end

        p.mime = p.mime or p.type or
                 p.file and 'application/octet-stream'
                        or  'text/plain'

        p.body = p.body or p.data or ""
        p.file = p.file or ""

        i=i+1; body[i] = 'Content-Disposition: form-data; name="'..p.name..'"; filename="'..p.file..'"'
        i=i+1; body[i] = 'Content-Type: ' .. p.mime
        i=i+1; body[i] = ''
        i=i+1; body[i] = p.body
        i=i+1; body[i] = '--' .. boundary .. '--'

    end

    return _concat(body,"\r\n"), boundary

end

-- Http请求
local function _request(url, opt)
-- @url     : @HttpOption | string      // 请求链接或参数
-- @opt   ? : @HttpOption               // 请求参数
-- @return  : res?: @HttpRespons, err?: string

    -- 如果第一个参数为table
    if type(url) == "table" then opt, url = url, url.url end

    --- url : string        // 类型改为字符串
    --- opt : @HttpOption

    opt = opt or {}
    opt.headers = opt.headers or {}

    opt.headers["User-Agent"   ] = opt.headers["User-Agent"   ] or USER_AGENT
    opt.headers["Cache-Control"] = opt.headers["Cache-Control"] or "no-cache"
    opt.headers["Pragma"       ] = opt.headers["Pragma"       ] or "no-cache"

    -- multipart/form-data 表单处理
    local parts = opt.parts
    if type(parts) == "table" and #parts > 0 then
        local body, boundary, err = gen_multipart_form(parts)
        if not body then return nil, err end
        opt.headers["Content-Type"] = "multipart/form-data; boundary=" .. boundary
        opt.body = body
    end

    opt.method = opt.method or (opt.body and "POST") or "GET"

    local res, err

    for _ = 1, 3 do
        local httpc = http.new()
        httpc:set_timeouts(conn_timeout, send_timeout, read_timeout)

        res, err = httpc:request_uri(url, opt)
        if res then break end

        -- 输出错误日志
        ngx.log(ngx.ERR, "request fail: ", err, "\n url:", url)

        if err ~= "closed" then break end
    end

    return res, err

end

return _request
