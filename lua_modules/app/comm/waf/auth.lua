
local waf               = require "app.comm.waf"
local cjson             = require "cjson.safe"
local session           = require "resty.session"

local __ = {}

-- 指定 secret 以保证各 worker 一致
local secret = ngx.decode_base64("akwBCqG5zO8yovgN7rmUPW7YNe4X19K9OikzazGhj6s=")

local function get_session()
    return session.new {
        name    = "waf",
        secret  = secret,
        cookie  = { path = "/" }
    }
end

__.check = function()

    -- 本机访问无需认证
    if ngx.var.remote_addr == "127.0.0.1" then return true end

    local waf_admin_uid = ngx.var.waf_admin_uid or "admin"

    local sss = get_session()

    sss:open()

    if sss.data.uid == waf_admin_uid then
        -- 快到期前自动续期
        if sss.present and sss.expires - sss.now < sss.cookie.renew then
            sss:save()
        end
        return true
    end

    local  html = waf.html("login.html")
    if not html then ngx.exit(404) end

    ngx.header["Content-Type" ] = "text/html"
    ngx.header["Cache-control"] = "no-cache"

    ngx.print(html)

end

__.logout = function()

    local sss = get_session()
    sss:destroy()

    return ngx.exit(200)

end

__.login = function()

    if ngx.req.get_method() ~= "POST" then
        return ngx.exit(403)
    end

    ngx.req.read_body()
    local body = ngx.req.get_body_data()
    local args = cjson.decode(body)

    if type(args) ~= "table" then
        return ngx.exit(403)
    end

    local uid = ngx.var.waf_admin_uid or "admin"
    local psw = ngx.var.waf_admin_psw or "123456"

    psw = ngx.encode_base64(ngx.hmac_sha1(uid, psw))

    local sss = get_session()

    -- 登录/检查密码
    if args.uid == uid and args.psw == psw then
        sss:start()
        sss.data.uid = args.uid
        sss:save()
        return ngx.exit(200)
    else
        sss:destroy()
        return ngx.exit(403)
    end

end

------------------------------------------------------
return __ -- 返回模块
