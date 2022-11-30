
local __ = { }

-- 域名证书管理
__.index = function()

    local sslx  = require "app.comm.sslx"
    local waf   = require "app.comm.waf"
    local cjson = require "cjson.safe"
    local dt    = require "app.utils.dt"

    local  html = waf.html("domain.html")
    if not html then ngx.exit(404) end

    local list = sslx.domain.load_domains()

    local domains = {}
    for _, d in ipairs(list) do

        local s = d.dnspod_token
        if type(s) == "string" and #s > 31 then
            -- 替换部分 token
            s = string.sub(s, 1, 15) .. string.rep("*", 16) .. string.sub(s, 32)
        end

        table.insert(domains, {
            domain_name   = d.domain_name,
            dnspod_token  = s,
            issuance_time = d.issuance_time > 0 and dt.to_date(d.issuance_time) or "",
            expires_time  = d.expires_time  > 0 and dt.to_date(d.expires_time ) or "",
        })
    end

    local g = cjson.encode {
        domains = domains,
    }

    html = string.gsub(html, "{ G }", g)

    ngx.header["content-type"] = "text/html"
    ngx.print(html)

end

-- 申请测试证书或正式证书
__.certs = function()

    local sslx = require "app.comm.sslx"

    local args = ngx.req.get_uri_args()

    local debug_mode = (args.mode == "debug")

    sslx.order.order_certs(debug_mode)

end

return __
