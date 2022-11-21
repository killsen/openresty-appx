
local ngx       = ngx
local waf       = require "app.comm.waf"
local balancer  = require "ngx.balancer"
local cjson     = require "cjson.safe"
local _clone    = require "table.clone"
local _clear    = require "table.clear"
local _insert   = table.insert
local _remove   = table.remove
local _sort     = table.sort
local _openx    = io.openx
local tonumber  = tonumber

local robin, chash
do
    local pok, mod
    pok, mod = pcall(require, "resty.roundrobin")    -- 轮询调度
    if pok then robin, chash = mod, mod end

    pok, mod = pcall(require, "resty.chash")         -- 一致性哈希
    if pok then chash = mod end
end

local __ = { _VERSION = "v21.07.05" }

----------------------------------------------------------------------------------------------------

local last_index = -1
local dict = ngx.shared.api_server_index
dict:add("api_server_index", 1)

----------------------------------------------------------------------------------------------------

local servers_tm    = {}    -- 全部服务器列表
local servers_up    = {}    -- 上游服务器列表
local servers_bk    = {}    -- 备用服务器列表
local server_map    = {}    -- 使用 ip:port 做 key

local robin_up, robin_bk    -- 一致性哈希
local chash_up, chash_bk    -- 轮询调度
local only_one_server       -- 只有一台服务器或者只有一台在线

----------------------------------------------------------------------------------------------------

-- 按ip地址、port端口排序
local function sort_servers(servers)

    _sort(servers, function(a, b)
        if a.ip == b.ip then
            return a.port < b.port
        else
            return a.ip < b.ip
        end
    end)

end

-- 读取json文件
local function load_json()

    local list

    local file = _openx("logs/api_server.json", "rb")

    if file then
        local json = file:read("*a"); file:close()
        list = cjson.decode(json)
    end

    if type(list) ~= "table" or #list == 0 then
        list = {
            { ip = "127.0.0.1", port = 88 },
        }
    end

    for _, d in ipairs(list) do
        d.down   = tonumber(d.down  ) or 0      -- 下线
        d.backup = tonumber(d.backup) or 0      -- 备用
        d.weight = tonumber(d.weight) or 1      -- 权重
        if d.weight < 1 then d.weight = 1 end
    end

    sort_servers(list)

    return list

end

-- 初始化服务器列表
local function init_servers(servers)

    _clear(server_map)
    _clear(servers_up)
    _clear(servers_bk)

    local servers_online = {}
    local nodes_up, nodes_bk = {}, {}

    for _, s in ipairs(servers) do

        local key = s.ip .. ":" .. s.port
        server_map[key] = s

        s.down      = tonumber(s.down  ) or 0   -- 下线
        s.backup    = tonumber(s.backup) or 0   -- 备用
        s.weight    = tonumber(s.weight) or 1   -- 权重
        if s.weight < 1 then s.weight = 1 end

        if s.down ~= 1 then
            _insert(servers_online, s)  -- 线上服务器
        end

        if s.backup == 1 then
            nodes_bk[key] = s.weight
            _insert(servers_bk, s)      -- 备用服务器
        else
            nodes_up[key] = s.weight
            _insert(servers_up, s)      -- 上游服务器
        end
    end

    only_one_server    = nil
    robin_up, robin_bk = nil, nil
    chash_up, chash_bk = nil, nil

    if #servers == 1 then
        only_one_server = servers[1]            -- 只有一台服务器

    elseif #servers_online == 1 then
        only_one_server = servers_online[1]     -- 只有一台服务器上线

    else
        if #servers_up > 1 then
            robin_up = robin and robin:new(nodes_up) or nil
            chash_up = chash and chash:new(nodes_up) or nil
        end

        if #servers_bk > 1 then
            robin_bk = robin and robin:new(nodes_bk) or nil
            chash_bk = chash and chash:new(nodes_bk) or nil
        end
    end

end

-- 加载服务器列表
local function load_servers()

    local curr_index = dict:get("api_server_index")
    curr_index = tonumber(curr_index) or 0

    -- 数据没有变化直接输出
    if last_index == curr_index then return servers_tm end

    last_index = curr_index
    servers_tm = load_json()
    init_servers(servers_tm)

    return servers_tm

end

load_servers()  --【自动加载服务器列表】--------------------------------------------------------------

-- 克隆服务器列表
local function clone_servers()

    local servers = load_servers()

    servers = _clone(servers)

    for i, s in ipairs(servers) do
        servers[i] = _clone(s)
    end

    return servers

end

-- 通知服务器监控更新数据
local function update_index()
    waf.status.update_index()
end

-- 保存服务器列表
local function save_servers(servers)

    if type(servers) ~= "table" then return end

    -- 最少需要一台服务器
    if #servers == 0 then return end

    sort_servers(servers)

    local  file, err = _openx("logs/api_server.json", "wb")
    if not file then
        ngx.log(ngx.ERR, "open file error: ", err)
        return
    end

    local json = cjson.encode(servers)

    file:write(json)
    file:close()

    -- 永久缓存
    dict:incr("api_server_index", 1, 0)

    load_servers()
    update_index()

end

----------------------------------------------------------------------------------------------------

-- 取得下一个服务器
local function get_next(ctx, obj, k, index, count)

    local size = tonumber(obj.size) or count
    local map  = {};  map[k] = true
    local reties = 1

    for _ = 1, size do
        k, index = obj:next(index)
        if not map[k] then
            local s = server_map[k]
            if not s then return nil end
            if s.down ~= 1 and not ctx[k] then return s end

            map[k] = true; reties = reties + 1
            if reties > count then return nil end
        end
    end

end

-- 取得上游服务器
local function get_server_up(ctx, hash_key, again_next)

    -- 只有一台服务器或者只有一台在线
    if only_one_server then return only_one_server end

    local count = #servers_up
    if count == 0 then return nil end

    local s, k, index

    if count == 1 then
        s = servers_up[1]
        if not s then return nil end
        k = s.ip .. ":" .. s.port
        if s.down ~= 1 and not ctx[k] then return s end
        return nil  -- 退出
    end

    local  obj = hash_key and chash_up or robin_up
    if not obj then return nil end

    k, index = obj:find(hash_key)
    s = server_map[k]
    if not s then return nil end
    if s.down ~= 1 and not ctx[k] then return s end

    if not again_next then return nil end  -- 退出

    -- 取得下一个服务器
    return get_next(ctx, obj, k, index, count)

end

-- 取得备用服务器
local function get_server_bk(ctx, hash_key)

    -- 只有一台服务器或者只有一台在线
    if only_one_server then return only_one_server end

    local count = #servers_bk
    if count == 0 then return nil end

    local s, k, index

    if count == 1 then
        s = servers_bk[1]
        if not s then return nil end
        k = s.ip .. ":" .. s.port
        if s.down ~= 1 and not ctx[k] then return s end
        return nil  -- 退出
    end

    local  obj = hash_key and chash_bk or robin_bk
    if not obj then return nil end

    k, index = obj:find(hash_key)
    s = server_map[k]
    if not s then return nil end
    if s.down ~= 1 and not ctx[k] then return s end

    -- 取得下一个服务器
    return get_next(ctx, obj, k, index, count)

end

-- 30秒内超过5次失败自动下线
local function set_server_down(ip, port)

    local key   = "fails/" .. ip .. ":" .. port
    local fails = 1

    -- 累加服务器失败次数
    if not dict:add(key, fails, 30) then
        fails = dict:incr(key, 1,  0) or fails
    end

    if fails < 5 then return end

    local servers = clone_servers()     -- 克隆

    for _, s in ipairs(servers) do
        if s.ip == ip and s.port == port and s.down ~= 1 then
            s.down = 1
            save_servers(servers)
            return
        end
    end

end

-- 取得服务器
local function get_server(ctx)

    local servers = load_servers()

    -- 只有一台服务器或者只有一台在线
    if only_one_server then return only_one_server end

    if #servers == 0 then return nil end
    if #servers == 1 then return servers[1] end

    local ip, port = ctx.server_ip, ctx.server_port

    local hash_key = ngx.header["store_id"] or
                     ngx.req.get_uri_args()["store_id"] or
                     ngx.var.remote_addr

    local server

    if ip and port then
        -- 30秒内超过5次失败自动下线
        set_server_down(ip, port)

        server = get_server_bk(ctx, hash_key) or
                 get_server_up(ctx, hash_key, true)

    else
        server = get_server_up(ctx, hash_key) or
                 get_server_bk(ctx, hash_key) or
                 get_server_up(ctx, hash_key, true)

    end

    return server

end

----------------------------------------------------------------------------------------------------

-- 负载均衡入口
__.run = function()

    local ctx = ngx.ctx

    local  server = get_server(ctx)
    if not server then return ngx.exit(500) end

    local ip, port = server.ip, server.port
    local key = ip .. ":" .. port

    ctx[key]        = true
    ctx.server_ip   = ip
    ctx.server_port = port

    if not only_one_server then
        balancer.set_more_tries(1)
        balancer.set_timeouts(1)
    end

    local ok, err = balancer.set_current_peer(ip, port)

    if not ok then
        ngx.log(ngx.ERR, "failed to set the current peer: ", err)
        return ngx.exit(500)
    end

end

----------------------------------------------------------------------------------------------------

-- 输出在线、下线服务器列表
__.load = function()

    local list    = clone_servers()
    local servers = {}  -- 已上线服务器
    local serverx = {}  -- 已下线服务器

    for _, t in ipairs(list) do
        if t.down == 1 then
            _insert(serverx, t)
        else
            _insert(servers, t)
        end
    end

    return servers, serverx

end

local templ = require "resty.template"

-- 列表页面
__.list = function()

    local  html = waf.html("api_server.html")
    if not html then return ngx.exit(400) end

    ngx.header["content-type"] = "text/html"

    local list    = clone_servers()
    local servers = {}  -- 上游服务器
    local serverx = {}  -- 备份服务器

    for _, t in ipairs(list) do
        if t.backup == 1 then
            _insert(serverx, t)
        else
            _insert(servers, t)
        end
    end

    templ.render(html, { servers=servers, serverx=serverx } )

end

-- IP地址正则表达式
local ip_regx = [[^((2[0-4]\d|25[0-5]|[01]?\d\d?)\.){3}(2[0-4]\d|25[0-5]|[01]?\d\d?)$]]

local function strip_ip(s)

    if type(s) ~= "string" or s == "" then
        return nil
    end

    local ip = (s:gsub("%s", ""))
    if ip == "" then return nil end

    local  m = ngx.re.match(ip, ip_regx)
    if not m then return nil end

    return ip

end

-- 添加
__.add = function()

    local args = ngx.req.get_uri_args()

    local t = {
        ip        = strip_ip(args.ip    ),
        port      = tonumber(args.port  ) or 80,
        weight    = tonumber(args.weight) or 1,
        down      = tonumber(args.down  ) or 0,
        backup    = tonumber(args.backup) or 0,
    }

    local ip, port = t.ip, t.port

    if not ip or port < 80 then
        return ngx.redirect("/waf/server")
    end

    if ip == "127.0.0.1" and port == 80 then
        return ngx.redirect("/waf/server")
    end

    if t.weight < 1 then t.weight = 1 end  -- 权重

    local key = "fails/" .. ip .. ":" .. port
    dict:delete(key)  -- 重置服务器失败次数

    local servers = clone_servers()     -- 克隆

    for i, s in ipairs(servers) do
        if s.ip == ip and s.port == port then
            _remove(servers, i)         -- 删除
            break
        end
    end

    _insert(servers, t)                 -- 插入
    save_servers(servers)               -- 保存

    ngx.redirect("/waf/server")

end

-- 删除
__.del = function()

    local args  = ngx.req.get_uri_args()
    local ip    = strip_ip(args.ip)
    local port  = tonumber(args.port) or 80

    if not ip then
        return ngx.redirect("/waf/server")
    end

    local key = "fails/" .. ip .. ":" .. port
    dict:delete(key)  -- 重置服务器失败次数

    local servers = clone_servers()     -- 克隆

    for i, s in ipairs(servers) do
        if s.ip == ip and s.port == port then
            _remove(servers, i)         -- 删除
            save_servers(servers)       -- 保存
            break
        end
    end

    ngx.redirect("/waf/server")

end

-- 修改
__.set = function()

    local args  = ngx.req.get_uri_args()
    local ip    = strip_ip(args.ip)
    local port  = tonumber(args.port) or 80

    if not ip then
        return ngx.redirect("/waf/server")
    end

    local key = "fails/" .. ip .. ":" .. port
    dict:delete(key)  -- 重置服务器失败次数

    local servers = clone_servers()     -- 克隆

    for _, s in ipairs(servers) do
        if s.ip == ip and s.port == port then

            s.down   = tonumber(args.down  ) or s.down      -- 下线
            s.backup = tonumber(args.backup) or s.backup    -- 备用
            s.weight = tonumber(args.weight) or s.weight    -- 权重

            if s.weight < 1 then s.weight = 1 end

            save_servers(servers)       -- 保存
            break
        end
    end

    ngx.redirect("/waf/server")

end

----------------------------------------------------------------------------------------------------

return __
