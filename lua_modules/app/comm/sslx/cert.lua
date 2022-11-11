
-- 动态加载证书 v20.08.24

local ngx           = ngx
local ssl           = require "ngx.ssl"
local get_request   = require "resty.core.base".get_request
local prefix        = ngx.config.prefix()
local sslx          = require "app.comm.sslx"
local cache         = sslx.cache

local __ = {}

--------------------------------------------------------------------------------

-- 读取文件
local function read_file(file_name)

    if not file_name then return end

    local  file = io.open(prefix .. "/conf/cert/" .. file_name, "rb")
    if not file then return end

    local  data = file:read("*a")
                  file:close()
    if not data then return end

    return data

end

-- 取得证书
local function get_cert_der(domain_name)

    if not domain_name then return end

    local file_crt = domain_name .. "-crt.pem"
    local cert_pem = read_file(file_crt)
    if not cert_pem then
        ngx.log(ngx.ERR, "failed to get PEM cert: ", file_crt)
        return
    end

    local cert_der, err = ssl.cert_pem_to_der(cert_pem)
    if not cert_der then
        ngx.log(ngx.ERR, "failed to get DER cert: ", err)
        return
    end

    return cert_der

end

-- 取得秘钥
local function get_pkey_der(domain_name)

    if not domain_name then return end

    local file_key = domain_name .. "-key.pem"
    local pkey_pem = read_file(file_key)
    if not pkey_pem then
        ngx.log(ngx.ERR, "failed to get PEM cert: ", file_key)
        return
    end

    local pkey_der, err = ssl.priv_key_pem_to_der(pkey_pem)
    if not pkey_der then
        ngx.log(ngx.ERR, "failed to get DER pkey: ", err)
        return
    end

    return pkey_der

end

-- 加载证书及秘钥
__.load_cert = function (domain_name, reload)

    if not domain_name then return end

    local key = "cert/" .. domain_name
    if reload then cache.delete(key) end

    return cache.get(key, function()

        local cert_der = get_cert_der(domain_name)
        if not cert_der then return nil, nil, 10 end  -- 缓存 10 秒

        local pkey_der = get_pkey_der(domain_name)
        if not pkey_der then return nil, nil, 10 end  -- 缓存 10 秒

        return {
            cert_der = cert_der,
            pkey_der = pkey_der
        }, nil, 24 * 60 * 60  -- 缓存一天

    end)

end

local get_domain_name, set_ocsp_resp

-- 动态加载证书和秘钥以及OCSP
__.set_cert = function ()

    -- 检查请求
    local req = get_request()
    if not req then return end

    -- 请求的域名(可能是主域名、子域名、n级域名)
    local server_name = ssl.server_name()
    if not server_name then return end

    -- 获取子域名对应的主域名
    if not get_domain_name then get_domain_name = sslx.domain.get_domain_name end
    local domain_name = get_domain_name(server_name)
    if not domain_name then return end

    -- 取得证书及秘钥
    local cert = __.load_cert(domain_name)
    if not cert then return end

    local cert_der = cert.cert_der  -- 证书
    local pkey_der = cert.pkey_der  -- 秘钥

    -- 清除之前设置的证书和私钥
    local ok, err = ssl.clear_certs()
    if not ok then
        ngx.log(ngx.ERR, "failed to clear certs: ", err)
        return
    end

    -- 设置证书
    local ok, err = ssl.set_der_cert(cert_der)
    if not ok then
        ngx.log(ngx.ERR, "failed to set DER cert: ", err)
        return
    end

    -- 设置秘钥
    local ok, err = ssl.set_der_priv_key(pkey_der)
    if not ok then
        ngx.log(ngx.ERR, "failed to set DER pkey: ", err)
        return
    end

    -- OCSP回复
    if not set_ocsp_resp then set_ocsp_resp = sslx.ocsp.set_ocsp_resp end
    set_ocsp_resp(domain_name, cert_der)

end

--------------------------------------------------------------------------------
return __
