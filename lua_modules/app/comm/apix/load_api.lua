
-- 加载 api 信息

local apix = require "app.comm.apix"

local function load_api(api)

    local t = {
        name    = api,
        ver     = "",
        ok      = false,
        err     = "",
        codes   = "",
        actions = {},
    }

    local mod = _load("api." .. api)
    if not mod then
        t.err = "api不存在"
        return t
    end

    if type(mod) ~= "table" then
        t.err = "不是对象"
        return t
    end

    local ver = mod._VERSION or mod.version or mod.ver or mod._ver
    if type(ver) ~= "string" then
        t.ver = ""
    else
        t.ver = "v" .. ver:gsub("v", "")
    end

    for k, v in pairs(mod) do
        if type(k) == "string" and type(v) == "function" then
            local r = mod[k .. "__"]
            if type(r) == "table" and type(r[1]) == "string" then
                k = k .. " " .. r[1]
            end

            table.insert(t.actions, k)
        end
    end

    local codes = apix.gen_valid_code(mod)
    if not codes then
        t.err = "未声明参数定义"
        return t
    end

    t.codes = codes

    -- 生成参数验证函数构造函数
    local ok, valid_make, err = pcall(loadstring, codes)
    if not ok or type(valid_make) ~= "function" then
        t.err = err
        return t
    end

    -- 生成参数验证函数
    local ok, valid_mod = pcall(valid_make)
    if not ok or type(valid_mod) ~= "table" then
        t.err = valid_mod or "未返回模块（table）"
        return t
    end

    t.ok = true

    return t

end

return load_api