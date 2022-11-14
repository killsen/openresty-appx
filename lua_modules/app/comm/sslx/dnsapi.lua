
local request           = require "app.utils.request"
local cjson             = require "cjson.safe"

local __ = { _VERSION = "v22.03.08" }

-- 腾讯云 API 3.0
-- https://docs.dnspod.cn/api/api3/

-- 腾讯云 API 密钥
-- https://docs.dnspod.cn/account/dnspod-token/

local headers = {
    ["Content-Type"] = "application/x-www-form-urlencoded;charset=utf-8",
}

-- POST请求
-- https://docs.dnspod.cn/api/api-public-request/
local function _post(url, args, succ_code)

    local res, err = request(url, {
        method  = "POST",
        body    = ngx.encode_args(args),
        headers = headers
    })
    if not res then return nil, err end
    if res.status ~= 200 then return nil, "request fail: " .. res.status end

    local obj  = cjson.decode(res.body) or {}
    obj.status = obj.status  or {}
    local code = tonumber(obj.status.code)

    -- 返回值 1   : 操作成功
    if code and (code == 1 or code == succ_code) then
        return obj
    else
        return nil, obj.status.message or "未知错误"
    end

end

__.types = {
    DnsRecord = {
        id                  = "//记录ID编号",
        name                = "//子域名(主机记录)",
        line                = "//解析记录的线路",
        line_id             = "//解析记录的线路ID",
        type                = "//记录类型",
        ttl                 = "//记录的 TTL 值",
        value               = "//记录值",
        mx                  = "//记录的 MX 记录值, 非 MX 记录类型，默认为 0",
        enabled             = "//记录状态: 0 禁用 1 启用",
        monitor_status      = "//监控状态: '' 未开启D监控 Ok 正常 Warn 报警 Down 宕机",
        remark              = "//记录备注",
        updated_on          = "//记录最后更新时间",
        use_aqb             = "//是否开通网站安全中心: yes 已经开启 no 未开启",
    }
}

__.record_list__ = {
    "记录列表",
    doc = "https://docs.dnspod.cn/api/record-list/",
    req = {
        { "domain"          , "域名"     },
        { "login_token"     , "登录凭证" },
        { "sub_domain?"     , "主机记录: 这里默认为 '_acme-challenge'" },
        { "record_type?"    , "记录类型: 这里默认为 'TXT'"  },
        { "record_line?"    , "记录线路: 这里默认为 '默认'" },
    },
    res = "@DnsRecord[]"
}
__.record_list = function (t)

    local url  = "https://dnsapi.cn/Record.List"
    local args = {
        format      = "json",
        domain      = t.domain,
        login_token = t.login_token,
        sub_domain  = t.sub_domain  or "_acme-challenge",
        record_type = t.record_type or "TXT",
        record_line = t.record_line or "默认",
    }

    -- 返回值 1   : 操作成功
    -- 返回值 10  : 记录列表为空
    local res, err = _post(url, args, 10)
    if not res then return nil, err end

    return res.records or {}

end

__.record_create__ = {
    "添加记录",
    doc = "https://docs.dnspod.cn/api/add-record/",
    req = {
        { "domain"          , "域名"     },
        { "value"           , "记录值"   },
        { "login_token"     , "登录凭证" },
        { "sub_domain?"     , "主机记录: 这里默认为 '_acme-challenge'" },
        { "record_type?"    , "记录类型: 这里默认为 'TXT'"  },
        { "record_line?"    , "记录线路: 这里默认为 '默认'" },
    },
    res = "boolean"
}
__.record_create = function (t)

    local url  = "https://dnsapi.cn/Record.Create"
    local args = {
        format      = "json",
        domain      = t.domain,
        value       = t.value,
        login_token = t.login_token,
        sub_domain  = t.sub_domain  or "_acme-challenge",
        record_type = t.record_type or "TXT",
        record_line = t.record_line or "默认",
    }

    -- 返回值 1   : 操作成功
    -- 返回值 104 : 记录已存在无需添加
    local res, err = _post(url, args, 104)
    if not res then return nil, err end

    return true

end

__.record_remove__ = {
    "删除记录",
    doc = "https://docs.dnspod.cn/api/delete-record/",
    req = {
        { "domain"          , "域名"     },
        { "record_id"       , "记录编号" },
        { "login_token"     , "登录凭证" },
    },
    res = "boolean"
}
__.record_remove = function (t)

    local url  = "https://dnsapi.cn/Record.Remove"
    local args = {
        format      = "json",
        domain      = t.domain,
        record_id   = t.record_id,
        login_token = t.login_token,
    }

    -- 返回值 1   : 操作成功
    -- 返回值 8   : 记录不存在或已删除
    local res, err = _post(url, args, 8)
    if not res then return nil, err end

    return true

end

__.record_remove_by_values__ = {
    "删除记录（按值）",
    req = {
        { "domain"          , "域名"                    },
        { "values"          , "记录值列表"  , "table"   },
        { "login_token"     , "登录凭证"                },
    },
    res = "boolean"
}
__.record_remove_by_values = function (t)

    if next(t.values) == nil then return true end

    local  records, err = __.record_list(t)
    if not records then return nil, err end

    local ok, err = true, nil

    for _, record in ipairs(records) do
        if t.values[record.value] then
            local ok2, err2 = __.record_remove {
                domain      = t.domain,
                record_id   = record.id,
                login_token = t.login_token,
            }
            if not ok2 then
                ok, err = ok2, err2
            end
        end
    end

    return ok, err

end

return __
