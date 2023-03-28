
-- 生成 api.js

local apix              = require "app.comm.apix"
local utils             = apix.gen_api_utils
local _split            = require "ngx.re".split

-- 生成父命名空间
local function _namespace(name, namespace_loaded)
-- @name             : string
-- @namespace_loaded : table
-- @return           : void

    local names = _split(name, [[\.]])
    local pname = "$api"

    for i, n in ipairs(names) do
        pname = pname .. "." .. n

        if i<#names and not namespace_loaded[pname] then
            namespace_loaded[pname] = true
            ngx.say ("")
            ngx.say(utils.get_namex(pname), " = {}")
        end
    end

end

-- 生成 api.js 代码
return function(app_name, base_name, api_name)
-- @app_name    : string
-- @base_name ? : string
-- @api_name  ? : string
-- @return      : void

    base_name = base_name or ngx.req.get_uri_args().base or ""
    api_name  = api_name  or ngx.req.get_uri_args().api  or nil

    local api_list, _, api_base = apix.load_apis(app_name, base_name)
    if not api_list then return ngx.exit(404) end

    if api_name then
        for _, t in ipairs(api_list) do
            if t.name == api_name then
                api_list = { t }
                break
            end
        end
    end

    ngx.header['content-type'] = "application/javascript"
    ngx.header['language'] = "typescript"

    local namespace_loaded = {}

    ngx.say ("")
    ngx.say ("const $api: any = {}")

    for _, api in ipairs(api_list) do

        local name = api.name
        local mod = utils.load_api_mod(api_base, name)

        if type(mod) == "table" then

            namespace_loaded["$api." .. name] = true
            _namespace(name, namespace_loaded)

            ngx.say ("")
            ngx.say ("$api.", utils.get_namex(name)," = {")

            local keys, max_len = utils.get_fun_keys(mod)

            max_len = max_len + 4
            if max_len < 12 then max_len = 12 end

            for _, key in ipairs(keys) do
                local keyx = utils.get_namex(key)
                ngx.say(string.rep(" ", max_len-#keyx), keyx, " : ['", name, "', '", key, "'],")
            end

            ngx.say("}")
        end
    end

    ngx.say("")
    ngx.say("export default $api;")

end
