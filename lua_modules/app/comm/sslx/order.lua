
-- 详解 ACME V2 (RFC 8555) 协议，你是如何从Let's Encrypt 申请到证书的
-- https://zhuanlan.zhihu.com/p/75032510

local sslx = require "app.comm.sslx"
local dt   = require "app.utils.dt"
local x509 = require "resty.openssl.x509"

local function echo(...)
    ngx.say(...)
    ngx.flush()
end

local function wait(msg, seconds)
    ngx.print(msg)
    for _=1, seconds do
        ngx.print(".")
        ngx.flush()
        ngx.sleep(1)
    end
    ngx.say("")
    ngx.flush()
end

local cert_path = ngx.config.prefix() .. "/conf/cert/"

local domains = sslx.domain.load_domains()
if #domains == 0 then
    echo("尚未配置域名")
    return
end

local domain_name = domains[1].domain_name
local dnspod_token = domains[1].dnspod_token

echo("")
echo("待申请证书域名: ", domain_name)
echo("dnspod登录凭证: ", dnspod_token)
echo("")

local acme, err = sslx.acme.new {
    domain_name     = domain_name,
    dnspod_token    = dnspod_token,
    cert_path       = cert_path,
    directory_url   = "https://acme-staging-v02.api.letsencrypt.org/directory",
}

if not acme then return echo(err) end

local  ok, err = acme:init()
if not ok then return echo("初始化acme失败: ", err) end

local order, err = acme:new_order()
if not order then return echo("创建订单失败: ", err) end

local order_url  = order.order_url

echo("订单地址: ", order_url)
echo("截止时间: ", order.expires)
echo("")

for _ = 1, 10 do

    ngx.sleep(1)
    order, err = acme:query_order(order_url)
    if not order then return echo("查询订单失败: ", err) end

    echo("订单状态: ", order.status)  -- pending/ready/processing/valid/invalid
    echo("------------------------------------")

    for i, authz_url in ipairs(order.authorizations) do
        local res, err = acme:query_authz(authz_url)
        if not res then return echo("查询验证结果失败: ", err) end
        echo(i, ") ", res.status, "\t",
                    res.wildcard and "*." or "",
                    res.identifier.value
                )
    end
    echo("")

    if order.status == "pending" then

        for _, authz_url in ipairs(order.authorizations) do
            local  ok, err = acme:make_dns_record(authz_url)
            if not ok then return echo("创建域名TXT记录失败: ", err) end
        end

        wait("请稍等10秒钟 ", 10)
        echo("")

        for i, authz_url in ipairs(order.authorizations) do
            local  res, err = acme:challenge_authz(authz_url)
            if not res then return echo("域名验证失败: ", err) end
            echo(i, ") ", res.status, "\t",
                    res.wildcard and "*." or "",
                    res.identifier.value
                )
        end
        echo("")

    elseif order.status == "invalid" then
        break

    elseif order.status == "valid" then

        local  certificate_url = order.certificate
        echo("证书下载链接: ", certificate_url)
        local  cert_pem, err = acme:download_certificate(certificate_url)
        if not cert_pem then return echo("证书下载失败: ", err) end

        local cert = x509.new(cert_pem)

        echo("证书颁发日期: ", dt.to_date(cert:get_not_before()))
        echo("证书截止日期: ", dt.to_date(cert:get_not_after()))
        echo("")

        break

    elseif order.status == "ready" then

        local  finalize_url = order.finalize
        echo("证书申请链接: ", finalize_url)
        local  res, err = acme:finalize_order (finalize_url)
        if not res then return echo("证书申请失败: ", err) end

        local  certificate_url = res.certificate
        echo("证书下载链接: ", certificate_url)
        local  cert_pem, err = acme:download_certificate(certificate_url)
        if not cert_pem then return echo("证书下载失败: ", err) end

        local cert = x509.new(cert_pem)

        echo("证书颁发日期: ", dt.to_date(cert:get_not_before()))
        echo("证书截止日期: ", dt.to_date(cert:get_not_after()))
        echo("")

        break
    else
        break
    end

end

echo("删除域名TXT记录")

for _, authz_url in ipairs(order.authorizations) do
    local  res, err = acme:remove_dns_record(authz_url)
    if not res then return echo("删除域名TXT记录失败: ", err) end
end
