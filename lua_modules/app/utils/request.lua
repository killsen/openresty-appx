
local resolver  = require "resty.dns.resolver"
local http      = require "resty.http"
local mlcache   = require "resty.mlcache"

local _concat   = table.concat
local _match    = ngx.re.match
local _find     = ngx.re.find

local conn_timeout = 1000 * 10  -- 连接超时：10秒
local send_timeout = 1000 * 90  -- 发送超时：90秒
local read_timeout = 1000 * 90  -- 读取超时：90秒

-- 多级缓存
local DNS_CACHE  = mlcache.new("DNS_CACHE", "my_dns", {
        lru_size = 300      -- 本地缓存300条
    ,   ttl      = 3600     -- 命中缓存1小时
    ,   neg_ttl  = 5        -- 未命中缓存5秒
})

-- 域名服务器
local NAME_SERVERS = {
        "119.29.29.29",     -- 腾讯
        "223.5.5.5",        -- 阿里
        "180.76.76.76",     -- 百度
--      "114.114.114.114",  -- 114
--      "8.8.8.8",          -- 谷歌
}

local USER_AGENT = [[Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36]]
local URL_REGEX  = [[^(?:(http[s]?):)?//((?:[^\[\]:/\?]+)|(?:\[.+\]))(?::(\d+))?([^\?]*)\??(.*)]]

-- 解析请求链接
local function _parse_url(url)

    if type(url) ~= "string" then return nil, "url is null" end

    local  m = _match(url, URL_REGEX, "jo")
    if not m then return nil, "invalid url" end

    local scheme, host, port, path, query = m[1], m[2], m[3], m[4], m[5]

    scheme = scheme or "http"
    port   = tonumber(port)

    if not port then port = ""
    elseif port == 80  and scheme == "http"  then port = ""
    elseif port == 443 and scheme == "https" then port = ""
    else   port = ":" .. port
    end

    if not path or path == "" then path = "/" end
    if query and  query ~= "" then path = path .. "?" ..query end

    return {
        scheme  = scheme,  -- http 或 https
        host    = host,    -- www.baidu.com 或 192.168.0.1
        port    = port,    -- :8080 或 :88 或空
        path    = path,    -- / 或 /a/b/c?p=1
    }

end

-- 是否IP地址
local function _is_addr(host)
    return _find(host, [[\d+?\.\d+?\.\d+?\.\d+$]], "jo")
end

-- 延时2秒返回错误信息
local function _err(err)
    ngx.sleep(2)
    return nil, err
end

-- 取得IP地址（子线程）
local function _get_addr_thread(server, host)

    local res, err  = resolver:new{
            nameservers = { server }    -- DNS服务器
        ,   retrans     = 5             -- 5次重发
        ,   timeout     = 2000          -- 2秒超时
    }

    if not res then return _err(err) end

    local answers, err = res:query(host, {qtype = res.TYPE_A})
    if not answers then return _err(err) end

    if answers.errcode then return _err(answers.errstr) end

    for _, ans in ipairs(answers) do
        if ans.address then return ans.address end
    end

    return _err("not founded")

end

-- 取得IP地址（多线程）
local function _get_addr_by_dns(host)

    local t = {}

    for i, server in ipairs(NAME_SERVERS) do
        t[i] = ngx.thread.spawn(_get_addr_thread, server, host)
    end

    local ok, res, err = ngx.thread.wait(unpack(t))

    for _, co in ipairs(t) do
        ngx.thread.kill(co)
    end

    if not ok then return nil, res end

    return res, err

end

local function _get_addr(host)
    if host == "localhost" then return "127.0.0.1" end
    return DNS_CACHE:get(host, nil, _get_addr_by_dns, host)
end

local function get_parts_body(parts)

    local body, i = {}, 0

    local boundary = '---------------' .. ngx.now()*1000 .. '---------------'

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

local function _request(url, opt)

    -- 如果第一个参数为table
    if type(url) == "table" then opt, url = url, url.url end

    -- 解析请求链接
    local  m, err = _parse_url(url)
    if not m then return nil, err end

    opt = opt or {}
    opt.headers = opt.headers or {}

    opt.headers["User-Agent"   ] = opt.headers["User-Agent"   ] or USER_AGENT
    opt.headers["Cache-Control"] = opt.headers["Cache-Control"] or "no-cache"
    opt.headers["Pragma"       ] = opt.headers["Pragma"       ] or "no-cache"

    -- multipart/form-data 表单处理
    local parts = opt.parts
    if type(parts) == "table" and #parts > 0 then
        local body, boundary = get_parts_body(parts)
        opt.headers["Content-Type"] = "multipart/form-data; boundary="..boundary
        opt.body = body
    end

    opt.method = opt.method or (opt.body and "POST") or "GET"

    local httpc = http.new()

    -- 超时设置
    httpc:set_timeouts(conn_timeout, send_timeout, read_timeout)

    -- 如果是IP地址直接请求
    if _is_addr(m.host) then return httpc:request_uri(url, opt) end

    -- 通过域名取得IP地址
    local  addr = _get_addr(m.host)
    if not addr then return httpc:request_uri(url, opt) end

    -- 替换域名为IP地址
    url = m.scheme .. "://" .. addr .. m.port .. m.path

    -- 保留域名到请求头
    opt.headers["Host"] = m.host .. m.port

    -- 保留SNI: 用于SSL域名验证
    if m.scheme == "https" then opt.ssl_server_name = m.host end

    return httpc:request_uri(url, opt)

end


return _request
