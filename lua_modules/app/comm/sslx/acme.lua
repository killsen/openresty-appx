
-- 详解 ACME V2 (RFC 8555) 协议，你是如何从Let's Encrypt 申请到证书的
-- https://zhuanlan.zhihu.com/p/75032510

-- lua-resty-acme: ACMEv2客户端和Let’s Encrypt证书的自动化管理
-- https://yooooo.us/2019/lua-resty-acme

-- letsencrypt的ACME规范开发折腾记
-- https://zhuanlan.zhihu.com/p/73981808
-- https://github.com/publishlab/node-acme-client

local util              = require "resty.acme.util"
local openssl           = require "resty.acme.openssl"
local sslx              = require "app.comm.sslx"
local request           = require "app.utils.request"
local cjson             = require "cjson.safe"

local _T = {}
local __ = { _VERSION = '22.03.08', types = _T }
local mt = { __index  = __         }


_T.Identifier =  {
    type            = "//验证类型",
    value           = "//验证域名",
}

_T.Order =  {
    Location        = "//订单链接",
    order_url       = "//订单链接",
    expires         = "//失效时间",
    status          = "//订单状态: 包含 pending valid invalid ready",
    authorizations  = "string[]         //验证链接列表",
    identifiers     = "@Identifier[]    //验证标识列表",
    finalize        = "//证书签发链接",
    certificate     = "//证书下载链接",
}

_T.ValidationRecord = {
    hostname        = "//通过验证的域名",
}

_T.Challenge = {
    status          = "//验证状态: 包含 pending valid invalid ready",
    token           = "//验证凭据",
    type            = "//验证类型: 包含 http-01 dns-01 tls-alpn-01",
    url             = "//验证请求的地址",
    validated       = "//通过验证的时间",
    validationRecord= "@ValidationRecord[] //通过验证的域名列表",
}

_T.Authorization = {
    expires         = "//失效时间",
    status          = "//验证状态: 包含 pending valid invalid ready",
    wildcard        = "boolean          //是否泛域名",
    challenges      = "@Challenge[]     //验证列表",
    identifier      = "@Identifier      //验证标识",
}


local function _base64(s)
-- @return : string

    if type(s) == "table"  then s = cjson.encode(s) end
    if type(s) ~= "string" then return "" end

    return util.encode_base64url(s)

end

local function read_file(filename)
-- @return : string

    local file = io.open(filename, "rb")
    if not file then return end

    local data = file:read("a"); file:close()
    return data

end

local function write_file(filename, data)
-- @return : boolean

    local file = io.open(filename, "wb+")
    if not file then return end

    local ok, err = file:write(data); file:close()
    return ok, err

end


local function create_pkey_pem(file)
-- @return : string

    local data = read_file(file)

    if not data then
        data = util.create_pkey()
        write_file(file, data)
    end

    return data

end

-- 创建客户端
function __.new(req)
-- @@ 这是一个构造函数

    if type(req) ~= "table" then return nil, "req must be a table" end

    local dnspod_token  = req.dnspod_token
    local domain_name   = req.domain_name
    local domain_list   = req.domain_list
    local account_email = req.account_email
    local debug_mode    = req.debug_mode
    local cert_path     = req.cert_path

    if type(dnspod_token)  ~= "string" or dnspod_token  == "" then return nil, "dnspod_token required" end
    if type(domain_name)   ~= "string" or domain_name   == "" then return nil, "domain_name required"  end
    if type(cert_path)     ~= "string" or cert_path     == "" then return nil, "cert_path required"    end

    if type(domain_list) ~= "table"  or #domain_list  == 0  then
        domain_list = { "*." .. domain_name, domain_name }
    end

    if type(account_email) ~= "string" or account_email == "" then
        account_email = "acme@" .. domain_name
    end

    local domain_pkey_pem = create_pkey_pem(cert_path .. "/" .. domain_name .. "-key.pem")
    local  domain_pkey, err = openssl.pkey.new(domain_pkey_pem)
    if not domain_pkey then return nil, err end

    local account_pkey_pem = create_pkey_pem(cert_path .. "/" .. domain_name .. "-acc.pem")
    local  account_pkey, err = openssl.pkey.new(account_pkey_pem)
    if not account_pkey then return nil, err end

    local  params, err = account_pkey:get_parameters()
    if not params then return nil, err end

    -- JSON Web Key (JWK)
    -- https://datatracker.ietf.org/doc/html/rfc7517

    local account_jwk = {
        e = _base64(params.e:to_binary()),
        kty = "RSA",
        n = _base64(params.n:to_binary()),
    }

    local account_jwk_str = string.format (
        '{"e":"%s","kty":"%s","n":"%s"}',
        _base64(params.e:to_binary()),
        "RSA",
        _base64(params.n:to_binary())
    )

    local t = {
        cert_path       = cert_path,
        dnspod_token    = dnspod_token,

        domain_name     = domain_name,
        domain_list     = domain_list,
        domain_pkey     = domain_pkey,

        account_email   = account_email,    -- 账户邮箱
        account_pkey    = account_pkey,     -- 账户秘钥(openssl.pkey对象)
        account_kid     = nil,              -- 账户路径(通过newAccount注册获取)
        account_jwk     = account_jwk,      -- JWK密钥(table)
        account_jwk_str = account_jwk_str,  -- JWK密钥(string)

        inited          = false,            -- 是否已经初始化
        order_url       = nil,              -- 最后创建的订单链接
        replay_nonce    = nil,              -- 随机码(上次请求headers返回)

        debug_mode      = debug_mode,
        directory_url   = debug_mode  -- 请求接口路径
                      and "https://acme-staging-v02.api.letsencrypt.org/directory"  -- 测试接口
                       or "https://acme-v02.api.letsencrypt.org/directory",         -- 正式接口

        URL = {
            keyChange   = "https://acme-v02.api.letsencrypt.org/acme/key-change",
            newAccount  = "https://acme-v02.api.letsencrypt.org/acme/new-acct",
            newNonce    = "https://acme-v02.api.letsencrypt.org/acme/new-nonce",
            newOrder    = "https://acme-v02.api.letsencrypt.org/acme/new-order",
            revokeCert  = "https://acme-v02.api.letsencrypt.org/acme/revoke-cert",
        },
    }

    return setmetatable(t, mt)

end

-- 初始化
function __:init()
-- @return : boolean

    if self.inited then return true end

    local URL = self.URL

    local  res, err = request(self.directory_url)
    if not res then return nil, err end
    if res.status ~= 200 then return nil, "request fail: " .. res.status end

    local obj = cjson.decode(res.body)

    for k in pairs(URL) do
        URL[k] = obj[k] or URL[k]
    end

    -- 注册获取账户路径
    local account_kid, err = self:new_account()
    if not account_kid then return nil, err end

    self.account_kid = account_kid
    self.inited = true

    return true

end

-- POST请求
function __:post(url, payload, use_account_jwk)
-- @return : string | table

    local nonce, err

    if type(url) ~= "string" or url == "" then
        return nil, "url is empty"
    end

    if self.replay_nonce then
        nonce = self.replay_nonce
        self.replay_nonce = nil
    else
        nonce, err = self:new_nonce()
        if not nonce then return nil, err end
    end

    local protected = {
        alg     = "RS256",
        nonce   = nonce,
        url     = url,
    }

    if use_account_jwk then
        protected.jwk = self.account_jwk    -- 注册账户接口(newAccount)使用jwk
    else
        protected.kid = self.account_kid    -- 其它接口使用kid
    end

    protected = _base64(protected)
    payload   = _base64(payload)

    local digest = openssl.digest.new("SHA256")
    digest:update(protected .. "." .. payload)
    local signature = self.account_pkey:sign(digest)

    signature = _base64(signature)

    local body = cjson.encode {
        protected   = protected,
        payload     = payload,
        signature   = signature,
    }

    local headers = {
        ["Content-Type"] = "application/jose+json"
    }

    local res, err = request(url, {
        method  = "POST",
        headers = headers,
        body    = body,
    })
    if not res then return nil, err end

    self.replay_nonce = res.headers["Replay-Nonce"]
    local content_type = res.headers["Content-Type"]

    if content_type:sub(1, 16) == "application/json" then
        local data = cjson.decode(res.body)
        data["Location"] = res.headers["Location"]
        return data

    elseif content_type:sub(1, 24) == "application/problem+json" then
        local data = cjson.decode(res.body)
        return nil, data["detail"]

    else
        return res.body
    end

end

-- HEAD请求获取随机码
function __:new_nonce()
-- @return : string

    local  url = self.URL.newNonce
    local  res, err = request(url, { method = "HEAD" })
    if not res then return nil, err end
    if res.status ~= 200 then return nil, "request fail: " .. res.status end

    local nonce = res.headers["Replay-Nonce"]
    -- ngx.say("new_nonce: ", nonce)

    return nonce

end

-- 注册账户返回 kid
function __:new_account()
-- @return : string

    local  url = self.URL.newAccount

    local payload = {
        contact = { "mailto:" .. self.account_email },
        termsOfServiceAgreed = true,
    }

    local use_account_jwk = true

    local  res, err = self:post(url, payload, use_account_jwk)
    if not res then return nil, err end

    return res["Location"]

end

-- 创建订单
function __:new_order()
-- @return : @Order

    local  ok, err = self:init()
    if not ok then return nil, err end

    local  url = self.URL.newOrder

    local identifiers = {}
    for i, domain in ipairs(self.domain_list) do
        identifiers[i] = { type = "dns", value = domain }
    end

    local payload = {
        identifiers = identifiers
    }

    local  res, err = self:post(url, payload)
    if not res then return nil, err end

    local order_url = res["Location"]
    res["order_url"] = order_url
    -- ngx.say("new_order: ", order_url)

    self.order_url = order_url

    return res

end

-- 订单查询
function __:query_order(order_url)
-- @return : @Order

    local  ok, err = self:init()
    if not ok then return nil, err end

    order_url = order_url or self.order_url

    local  res, err = self:post(order_url)
    if not res then return nil, err end

    res["order_url"] = order_url
    -- ngx.say("query_order: ", res["order_url"])

    return res

end

-- 查询验证链接
function __:query_authz(authz_url)
-- @return : @Authorization

    local  ok, err = self:init()
    if not ok then return nil, err end

    return self:post(authz_url)

end

-- 挑战验证链接
function __:challenge_authz(authz_url)
-- @return : @Authorization

    local  authz, err = self:query_authz(authz_url)
    if not authz then return nil, err end

    for _, c in ipairs(authz.challenges) do
        if c.type == "dns-01" and c.status == "pending" then
            local  res, err = self:post(c.url, "{}")
            if not res then return nil, err end
            ngx.sleep(1)
        end
    end

    return self:query_authz(authz_url)

end

-- 生成 jwk_token
function __:gen_jwk_token(token)
-- @return : string

    local jwk = self.account_jwk_str

    local digest = openssl.digest.new("SHA256")
    local thumbecho = _base64( digest:final(jwk) )
    local result = token .. "." .. thumbecho

    digest = openssl.digest.new("SHA256")
    local value = _base64( digest:final(result) )

    return value

end

-- 创建域名TXT记录
function __:make_dns_record(authz_url)
-- @return : @Authorization

    local  authz, err = self:query_authz(authz_url)
    if not authz then return nil, err end

    local domain = authz.identifier.value

    for _, c in ipairs(authz.challenges) do
        if c.type == "dns-01" and c.status == "pending" then
            local ok, err = sslx.dnsapi.record_create {
                domain      = domain,
                value       = c.token,
                login_token = self.dnspod_token
            }
            if not ok then return nil, err end

            local ok, err = sslx.dnsapi.record_create {
                domain      = domain,
                value       = self:gen_jwk_token(c.token),
                login_token = self.dnspod_token
            }
            if not ok then return nil, err end
        end
    end

    return authz

end

-- 删除域名TXT记录
function __:remove_dns_record(authz_url)
-- @return : boolean

    local  authz, err = self:query_authz(authz_url)
    if not authz then return nil, err end

    local values = {}

    for _, c in ipairs(authz.challenges) do
        if c.type == "dns-01" then
            values[c.token] = true
            values[self:gen_jwk_token(c.token)] = true
        end
    end

    return sslx.dnsapi.record_remove_by_values {
        domain      = authz.identifier.value,
        values      = values,
        login_token = self.dnspod_token,
    }

end

-- 提交证书签名申请
function __:finalize_order(finalize_url)
-- @return : @Order

    local domain_pkey = self.domain_pkey
    local domain_list = self.domain_list

    local csr, err = util.create_csr(domain_pkey, unpack(domain_list))
    if not csr then return nil, err end

    local payload = {
        csr = _base64(csr)
    }

    local  res, err = self:post(finalize_url, payload)
    if not res then return nil, err end

    -- ngx.say("certificate_url: ", res.certificate)

    return res

end

-- 下载证书
function __:download_certificate(certificate_url)
-- @return : string

    local  ok, err = self:init()
    if not ok then return nil, err end

    local  cert, err = self:post(certificate_url)
    if not cert then return nil, err end

    local filename

    if self.debug_mode then
        filename = self.cert_path .. "/" .. self.domain_name .. "-tmp.pem"  -- 测试证书
    else
        filename = self.cert_path .. "/" .. self.domain_name .. "-crt.pem"  -- 正式证书
    end

    write_file(filename, cert)

    return cert

end

return __
