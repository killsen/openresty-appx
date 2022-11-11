
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
-- @return : table

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

-- 记录列表
-- https://docs.dnspod.cn/api/record-list/
__.record_list = function (domain, login_token)
-- @return : table

    local url  = "https://dnsapi.cn/Record.List"
    local args = {
        login_token = login_token,
        format      = "json",
        domain      = domain,
        sub_domain  = "_acme-challenge",
        record_type = "TXT",
    }

    -- 返回值 1   : 操作成功
    -- 返回值 10  : 记录列表为空
    local res, err = _post(url, args, 10)
    if not res then return nil, err end

    return res.records or {}

end

-- 添加记录
-- https://docs.dnspod.cn/api/add-record/
__.record_create = function (domain, value, login_token)
-- @return : boolean

    local url  = "https://dnsapi.cn/Record.Create"
    local args = {
        login_token = login_token,
        format      = "json",
        domain      = domain,
        sub_domain  = "_acme-challenge",
        record_type = "TXT",
        value       = value,
        record_line = "默认",
    }

    -- 返回值 1   : 操作成功
    -- 返回值 104 : 记录已存在无需添加
    local res, err = _post(url, args, 104)
    if not res then return nil, err end

    return true

end

-- 删除记录
-- https://docs.dnspod.cn/api/delete-record/
__.record_remove = function (domain, record_id, login_token)
-- @return : boolean

    local url  = "https://dnsapi.cn/Record.Remove"
    local args = {
        login_token = login_token,
        format      = "json",
        domain      = domain,
        record_id   = record_id,
    }

    -- 返回值 1   : 操作成功
    -- 返回值 8   : 记录不存在或已删除
    local res, err = _post(url, args, 8)
    if not res then return nil, err end

    return true

end

-- 删除记录（按值）
-- https://docs.dnspod.cn/api/delete-record/
__.record_remove_by_value = function (domain, value, login_token)
-- @return : boolean

    local  records, err = __.record_list(domain, login_token)
    if not records then return nil, err end

    for _, record in ipairs(records) do
        if record.value == value then
            local ok, err = __.record_remove(domain, record.id, login_token)
            if not ok then return nil, err end
        end
    end

    return true

end

return __
