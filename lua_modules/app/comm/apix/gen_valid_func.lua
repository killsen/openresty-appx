
-- 生成参数校验函数接口 v20.10.22

local type           = type
local pcall          = pcall
local loadstring     = loadstring
local mod_loaded     = setmetatable({}, {_mode = "k"})  -- 弱表

-- 为接口添加参数验证
local function gen_act(act_fun, valid_fun)
    return function(req)

        if type(req) ~= "table" then
            req = {}
            -- return nil, "参数不能为空"
        end

        local  pok, rok, err = pcall(valid_fun, req)
        if not pok then return nil, rok end
        if not rok then return nil, err end

        local  ok, r1, r2, r3 = pcall(act_fun, req)
        if not ok then return nil, r1 end

        return r1, r2, r3

    end
end

local gen_valid_code

return function (mod)

    if type(mod) ~= "table" then return end

    if mod_loaded[mod] then return end
       mod_loaded[mod] = true

    if not gen_valid_code then
        gen_valid_code = require "app.comm.apix".gen_valid_code
    end

    -- 生成参数验证函数代码
    local codes = gen_valid_code(mod)
    if type(codes) ~= "string" then return end

    -- 生成参数验证函数构造函数
    local ok, valid_make = pcall(loadstring, codes)
    if not ok or type(valid_make) ~= "function" then return end

    -- 生成参数验证函数
    local ok, valid_mod = pcall(valid_make)
    if not ok or type(valid_mod) ~= "table" then return end

    for act_name, act_fun in pairs(mod) do
        if type(act_name) == "string" and type(act_fun) == "function" then

            -- 生成参数验证函数
            local valid_fun = valid_mod[act_name]
            if type(valid_fun) == "function" then
                -- 注入参数验证函数
                mod[act_name] = gen_act(act_fun, valid_fun)
            end
        end
    end

end
