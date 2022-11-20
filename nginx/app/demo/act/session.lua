
local __ = {}
__.ver   = "v3.10"
__.name  = "lua-resty-session"
__.doc   = "https://github.com/bungle/lua-resty-session"
------------------------------------------------------

local USERS = {
    { uid = "admin", psw = "123456", name = "管理员"   },
    { uid = "jack" , psw = "123456", name = "杰克"     },
    { uid = "tom"  , psw = "123456", name = "汤姆"     },
}

for _, u in ipairs(USERS) do
    USERS[u.uid] = u
end

local function print_table(t, level)

    level = tonumber(level) or 0
    if level > 5 then return end

    if type(t) ~= "table" then return end

    ngx.say "<ul>"

    for k, v in pairs(t) do
        if type(v) ~= "table" then
            if k == "id" or k == "secret" then
                v = "<i>" .. ngx.encode_base64(v) .. "</i>"
            end
            ngx.say("<li>", tostring(k), " = ", tostring(v), "</li>")
        end
    end

    for k, v in pairs(t) do
        if type(v) == "table" then
            ngx.say("<li>", tostring(k), " = ", tostring(v), "</li>")
            print_table(v, level+1)
        end
    end
    ngx.say "</ul>"

end

local session = require "resty.session"
local secret  = ngx.decode_base64("LXnL4FVKDiWRrZ2y27zF7xfBMoGjKC4FYxTJy+fgl24=")

__.actx = function()

    local sss = session.new {
        name            = "session",        -- 名称: 默认 session
        secret          = secret,           -- 秘钥: 建议 32 位

        identifier      = "random",         -- ID生成器: 默认 random (随机生成16位)
        strategy        = "default",        -- 安全策略: 默认 default
        storage         = "cookie",         -- 存储方式: 默认 cookie
        serializer      = "json",           -- 序列化器: 默认 json
        compressor      = "none",           -- 压缩方式: 默认 none
        encoder         = "base64",         -- 编码方式: 默认 base64
        cipher          = "aes",            -- 加密算法: 默认 aes
        hmac            = "sha1",           -- 哈希算法: 默认 sha1

        cookie  = {
            path        = "/demo/",         -- 路径: 默认根目录 /
            domain      = nil,              -- 域名: 默认不指定
            samesite    = "Lax",            -- 同站策略: 默认 Lax
            secure      = nil,              -- 开启安全模式: 默认自动
            httponly    = true,             -- 只允许http访问: 默认 true 即 不允许 js 访问
            persistent  = false,            -- 是否持久化: 默认 false 即 session
            discard     = 10,               -- 丢弃时间: 默认 10 秒
            renew       = 600,              -- 自动续期时间: 默认到期前 600 秒自动续期
            lifetime    = 3600,             -- 有效期: 默认 3600 秒
            idletime    = 0,                -- 最大空闲连接时间: 默认 0 即 永久
            maxsize     = 4000,             -- 最大长度: 默认 4000
        },

        check = {
            ssi         = false,            -- 是否检查 ssl session id: 默认 false
            ua          = true,             -- 是否检查客户端代理(ua): 默认 true
            scheme      = true,             -- 是否检查http(s)协议: 默认 true
            addr        = false,            -- 是否检查客户端IP地址: 默认 false
        }
    }

    local args, err

    if ngx.req.get_method() == "POST" then
        ngx.req.read_body()
        args = ngx.req.get_post_args()

        -- 登录/检查密码
        local u = USERS[args.uid]
        if u and u.psw == args.psw then
            sss:start()
            sss.data.uid = args.uid
            sss:save()
            return ngx.redirect(ngx.var.uri)
        else
            sss:destroy()
            err = "账号/密码错误，请重新录入："
        end
    else
        -- 退出/注销
        args = ngx.req.get_uri_args()
        if args.logout then
            sss:destroy()
            return ngx.redirect(ngx.var.uri)
        end
    end

    sss:open()

    local u = USERS[sss.data.uid]

    -- 快到期前自动续期
    if u and sss.present and sss.expires - sss.now < sss.cookie.renew then
        sss:save()
    end

    ngx.say "<html>"
    ngx.say "<body>"

    if u then
        ngx.say("<h3>", "当前用户已登录成功：", "</h3>")
        ngx.say("账号：", u.uid, "<br>")
        ngx.say("姓名：", u.name, "<br>")
        ngx.say ([[<a href="?logout">退出</a>]])
    else
        if err then
            ngx.say("<h3>", err, "</h3>")
        else
            ngx.say("<h3>", "请输入账号/密码登录：", "</h3>")
        end
        ngx.say ([[
            <form method="post">
                账号: <input type="text" name="uid" value="]], args.uid or "admin"  ,[["><br/>
                密码: <input type="text" name="psw" value="]], args.psw or "123456" ,[["><br/>
                <input type="submit" value="登录">
            </from>
        ]])
    end

    ngx.say [[
    <h3>
        <a href="https://github.com/bungle/lua-resty-session"
        target="_blank">bungle/lua-resty-session</a>
        is a secure, and flexible session library for OpenResty.
    </h3>
    ]]

    print_table(sss)

    ngx.say "</body>"
    ngx.say "</html>"

end

------------------------------------------------------
return __ -- 返回模块
