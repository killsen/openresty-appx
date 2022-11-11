
-- 详解 ACME V2 (RFC 8555) 协议，你是如何从Let's Encrypt 申请到证书的
-- https://zhuanlan.zhihu.com/p/75032510

local ACME              = require "app.comm.sslx.acme"
local cjson             = require "cjson.safe"

local cert_path = ngx.config.prefix() .. "/conf/cert/"

local file = io.open(cert_path .. "/domain.json", "rb")
if not file then return end

local text = file:read("a"); file:close()
local domains = cjson.decode(text)
if type(domains) ~= "table" then return end

local domain
if type(domains[1]) == "table" then
    domain = domains[1]
else
    domain = domains
end

local domain_name = domain.domain_name
local dnspod_token = domain.dnspod_token

local function echo(...)
    ngx.say(...)
    ngx.flush()
end

local acme, err = ACME.new {
    domain_name     = domain_name,
    dnspod_token    = dnspod_token,
    cert_path       = cert_path,
--  directory_url   = "https://acme-staging-v02.api.letsencrypt.org/directory",
}

if not acme then return echo(err) end

local  ok, err = acme:init()
if not ok then return echo("init acme client error: ", err) end

echo("account_kid = ", acme.account_kid)

local order, err, order_url

order, err = acme:new_order()
if not order then return echo("new_order error: ", err) end

order_url  = order.order_url
echo("order_url  = [[", order_url, "]]")
echo("")

echo("订单截止时间: ", order.expires)

ngx.sleep(1)

order, err = acme:query_order(order_url)
if not order then return echo("query_order error: ", err) end

echo("order status = ", order.status)
echo("")

for i, authz_url in ipairs(order.authorizations) do
    local res, err = acme:query_authz(authz_url)
    if not res then return echo("query_authz error: ", err) end
    echo(i, ") ", res.status, "\t",
        res.identifier.value, "\t",
        res.wildcard and "wildcard" or "")
end
echo("")

if order.status == "pending" then

    for _, authz_url in ipairs(order.authorizations) do
        local  res, err = acme:make_dns_record(authz_url)
        if not res then echo("make_dns_record error: ", err) end
    end

    for _=1, 20 do
        ngx.sleep(0.5)
        ngx.print(".")
        ngx.flush()
    end

    ngx.say ""
    ngx.say ""

    for i, authz_url in ipairs(order.authorizations) do
        local  res, err = acme:challenge_authz(authz_url)
        if not res then return echo("challenge_authz error: ", err) end
        echo(i, ") ", res.status, "\t",
            res.identifier.value, "\t",
            res.wildcard and "wildcard" or "")
    end
    echo("")

elseif order.status == "invalid" then
    -- break

elseif order.status == "valid" then

    local  certificate_url = order.certificate
    echo("certificate_url  = [[", certificate_url, "]]")
    echo("")

    local  cert_pem, err = acme:download_certificate(certificate_url)
    if not cert_pem then return echo("download_certificate error: ", err) end

    local dt   = require "app.utils.dt"
    local x509 = require "resty.openssl.x509"
    local cert = x509.new(cert_pem)

    echo("颁发日期: ", dt.to_date(cert:get_not_before()))
    echo("截止日期: ", dt.to_date(cert:get_not_after()))

    -- write_file(acme.domain_name, ".crt", res)

    echo("")

    -- break

elseif order.status == "ready" then

    local  finalize_url = order.finalize
    echo("finalize_url  = [[", finalize_url, "]]")
    echo("")

    local  res, err = acme:finalize_order (finalize_url)
    if not res then return echo("finalize_order error: ", err) end

    local  certificate_url = res.certificate
    echo("certificate_url  = [[", certificate_url, "]]")
    echo("")

    local  cert_pem, err = acme:download_certificate(certificate_url)
    if not cert_pem then return echo("download_certificate error: ", err) end

    local dt   = require "app.utils.dt"
    local x509 = require "resty.openssl.x509"
    local cert = x509.new(cert_pem)

    echo("颁发日期: ", dt.to_date(cert:get_not_before()))
    echo("截止日期: ", dt.to_date(cert:get_not_after()))

    -- write_file(acme.domain_name .. ".crt", res)

    echo("")

    -- break

else
    -- break

end

-- for _, authz_url in ipairs(order.authorizations) do
--     local  res, err = acme:remove_dns_record(authz_url)
--     if not res then return echo("remove_dns_record error: ", err) end
-- end
