
-- 动态加载证书

local ngx                   = ngx
local ngx_ssl               = require "ngx.ssl"
local ngx_ocsp              = require "ngx.ocsp"
local get_request           = require "resty.core.base".get_request
local sslx                  = require "app.comm.sslx"

local get_server_name       = ngx_ssl.server_name
local clear_certs           = ngx_ssl.clear_certs
local set_der_cert          = ngx_ssl.set_der_cert
local set_der_priv_key      = ngx_ssl.set_der_priv_key
local set_ocsp_status_resp  = ngx_ocsp.set_ocsp_status_resp

local __ = {}

--------------------------------------------------------------------------------

local get_domain

-- 动态加载证书和秘钥以及OCSP
__.set_cert = function ()

    -- 检查请求
    local req = get_request()
    if not req then return end

    -- 请求的域名(可能是主域名、子域名、n级域名)
    local server_name = get_server_name()
    if not server_name then return end

    -- 获取域名证书
    if not get_domain then get_domain = sslx.domain.get_domain end
    local domain = get_domain(server_name)
    if not domain then return end

    local cert_der  = domain.cert_der  -- 证书DER
    local pkey_der  = domain.pkey_der  -- 秘钥DER
    local ocsp_resp = domain.ocsp_resp -- 证书状态

    if not cert_der then return end
    if not pkey_der then return end

    -- 清除之前设置的证书和私钥
    local ok, err = clear_certs()
    if not ok then
        ngx.log(ngx.ERR, "failed to clear certs: ", err)
        return
    end

    -- 设置证书
    local ok, err = set_der_cert(cert_der)
    if not ok then
        ngx.log(ngx.ERR, "failed to set DER cert: ", err)
        return
    end

    -- 设置秘钥
    local ok, err = set_der_priv_key(pkey_der)
    if not ok then
        ngx.log(ngx.ERR, "failed to set DER pkey: ", err)
        return
    end

    if not ocsp_resp then return end

    -- OCSP回复
    local ok, err = set_ocsp_status_resp(ocsp_resp)
    if not ok then
        ngx.log(ngx.ERR, "failed to set ocsp status response: ", err)
        return
    end

end

--------------------------------------------------------------------------------
return __
