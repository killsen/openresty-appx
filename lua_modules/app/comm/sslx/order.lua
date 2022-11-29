
-- 详解 ACME V2 (RFC 8555) 协议，你是如何从Let's Encrypt 申请到证书的
-- https://zhuanlan.zhihu.com/p/75032510

-- 域名基础知识
-- https://support.google.com/a/answer/2573637

local ngx           = ngx
local prefix        = ngx.config.prefix()
local cert_path     = prefix .. "/conf/cert/"
local sslx          = require "app.comm.sslx"
local dt            = require "app.utils.dt"
local x509          = require "resty.openssl.x509"

local __ = { }

-- 实时输出
local function _echo(...)
    ngx.say(...)
    ngx.flush()
end

-- 稍等几秒
local function _wait(msg, seconds)
    ngx.print(msg)
    for _=1, seconds do
        ngx.print(".")
        ngx.flush()
        ngx.sleep(1)
    end
    ngx.say("")
    ngx.flush()
end

-- 申请证书
__.order_certs = function(debug_mode)

    ngx.header["content-type"] = "text/plain"

    local domains = sslx.domain.load_domains()

    if #domains == 0 then
        _echo("尚未定义域名: 请在 conf/cert/domains.json 定义")
        return
    end

    _echo("共有 ", #domains, " 个域名需要申请证书")

    for _, d in ipairs(domains) do
        _echo("-------------------------------------")
        __.order_cert {
            domain_name     = d.domain_name,
            dnspod_token    = d.dnspod_token,
            debug_mode      = (debug_mode ~= false),
            retry_times     = 10,
            echo            = _echo,
            wait            = _wait,
        }
    end

end

__.order_cert__ = {
    "申请证书",
    req = {
        { "domain_name"     , "待申请证书域名"              },
        { "dnspod_token"    , "dnspod登录凭证"              },
        { "debug_mode"      , "测试模式"    , "boolean"     },
        { "retry_times?"    , "重试几次"    , "number"      },
        { "echo?"           , "输出函数"    , "function"    },
        { "wait?"           , "等待函数"    , "function"    },
    },
    res = {
        { "cert_pem"        , "证书文件"                    },
        { "issuance_time"   , "证书颁发日期"    , "number"  },
        { "expires_time"    , "证书截止日期"    , "number"  },
    }
}
__.order_cert = function(t)

    local domain_name   = t.domain_name
    local dnspod_token  = t.dnspod_token
    local debug_mode    = t.debug_mode
    local retry_times   = tonumber(t.retry_times) or 10
    local echo          = t.echo
    local wait          = t.wait

    if not echo then echo = _echo end
    if not wait then wait = _wait end

    echo("")
    echo("待申请证书域名: ", domain_name)
    echo("dnspod登录凭证: ", dnspod_token)
    echo("")

    local acme, err = sslx.acme.new {
        domain_name     = domain_name,
        dnspod_token    = dnspod_token,
        cert_path       = cert_path,
        debug_mode      = debug_mode,
    }

    if not acme then return echo(err) end

    if debug_mode then
        echo("测试接口: ", acme.directory_url)
    else
        echo("正式接口: ", acme.directory_url)
    end

    local  ok, err = acme:init()
    if not ok then return echo("初始化acme失败: ", err) end

    echo("账户地址: ", acme.account_kid)

    local order, err = acme:new_order()
    if not order then return echo("创建订单失败: ", err) end

    local order_url  = order.order_url

    echo("订单地址: ", order_url)
    echo("截止时间: ", order.expires)
    echo("")

    local certificate_url

    for _ = 1, retry_times do

        ngx.sleep(1)
        order, err = acme:query_order(order_url)
        if not order then echo("查询订单失败: ", err) end

        -- pending/ready/processing/valid/invalid
        echo("订单状态: ", order.status)
        echo("-----------------------")

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
            certificate_url = order.certificate  -- 证书下载链接
            break

        elseif order.status == "ready" then
            local  finalize_url = order.finalize
            echo("证书申请链接: ", finalize_url)
            local  res, err = acme:finalize_order (finalize_url)
            if not res then return echo("证书申请失败: ", err) end

            certificate_url = res.certificate  -- 证书下载链接
            break
        end

    end

    if type(certificate_url) ~= "string" or certificate_url == "" then
        echo("证书下载失败")
        return
    end

    echo("证书下载链接: ", certificate_url)

    local  cert_pem, err = acme:download_certificate(certificate_url)
    if not cert_pem then return echo("证书下载失败: ", err) end

    local cert = x509.new(cert_pem)
    local issuance_time = cert:get_not_before()
    local expires_time  = cert:get_not_after()

    echo("证书颁发日期: ", dt.to_date(issuance_time))
    echo("证书截止日期: ", dt.to_date(expires_time))
    echo("")

    echo("删除域名TXT记录")
    for _, authz_url in ipairs(order.authorizations) do
        local  res, err = acme:remove_dns_record(authz_url)
        if not res then echo("删除域名TXT记录失败: ", err) end
    end
    echo("证书下载成功")
    echo("")

    return {
        cert_pem        = cert_pem,
        issuance_time   = issuance_time,
        expires_time    = expires_time,
    }

end

return __
