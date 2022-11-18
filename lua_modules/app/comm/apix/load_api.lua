
-- 加载 api 信息

local apix      = require "app.comm.apix"
local _insert   = table.insert
local _gsub     = string.gsub

local function load_api(mod, name)

    local t = {
        name    = name,
        ver     = "",
        ok      = false,
        err     = "",
        codes   = "",
        actions = {},
    }

    if type(mod) ~= "table" then
        t.err = "加载失败"
        return t
    end

    local ver = mod._VERSION or mod.version or mod.ver or mod._ver
    if type(ver) ~= "string" then
        t.ver = ""
    else
        t.ver = "v" .. _gsub(ver, "v", "")
    end

    local keys = apix.gen_api_utils.get_fun_keys(mod)

    for _, k in ipairs(keys) do
        local r = mod[k .. "__"]
        if type(r) == "table" and type(r[1]) == "string" then
            k = k .. " " .. _gsub(r[1], " ", "")
        end
        _insert(t.actions, k)
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
