
-- 生成 api.js v21.09.09

local utils             = require "app.comm.apix.gen_api_utils"
local load_path         = utils.load_path
local get_namex         = utils.get_namex
local get_max_key_len   = utils.get_max_key_len
local get_fun_keys      = utils.get_fun_keys

local _split    = require "ngx.re".split
local _insert   = table.insert

-- 生成父命名空间
local function _namespace(name, namespace_loaded)

    local names = _split(name, [[\.]])
    local pname = "$api"

    for i, n in ipairs(names) do
        pname = pname .. "." .. n

        if i<#names and not namespace_loaded[pname] then
            namespace_loaded[pname] = true
            ngx.say ("")
            ngx.say(get_namex(pname), " = {}")
        end
    end

end

return function(app_name, base_path, base_name, args)

    local app = require "app.comm.appx".new(app_name)
    if not app then return ngx.exit(404) end

    app_name = app.name

    base_path = base_path or ("app/" .. app_name .. "/api/")
    base_name = base_name or  "api."

    ngx.header['content-type'] = "application/javascript"
    ngx.header['language'] = "typescript"

    local list = {}
    local namespace_loaded = {}

    args = args or ngx.req.get_uri_args()

    if type(args.base) == "string" and args.base ~= "" then
        base_path = base_path .. args.base .. "/"
        base_name = base_name .. args.base .. "."
    end

    if type(args.api) == "string" and args.api ~= "" then
        _insert(list, args.api)
    else
        load_path (list, base_path, "")

        -- 不输出 demo 演示接口
        for i, name in ipairs(list) do
            if name == "demo" then
                table.remove(list, i)
                break
            end
        end

        table.sort(list)
    end

    ngx.say ("")
    ngx.say ("const $api: any = {}")

    for _, name in ipairs(list) do

        local mod = _load (base_name .. name)

        if type(mod) == "function" then

            _namespace(name, namespace_loaded)
            ngx.say ("")
            ngx.say("$api.", get_namex(name) ," = ['", name, "']")

        end

        if type(mod) == "table" then

            namespace_loaded["$api." .. name] = true
            _namespace(name, namespace_loaded)

            ngx.say ("")
            ngx.say ("$api.", get_namex(name)," = {")

            local max_len = get_max_key_len(mod) + 4
            if max_len < 12 then max_len = 12 end

            local keys = get_fun_keys(mod)

            for _, key in ipairs(keys) do
                local keyx = get_namex(key)
                ngx.say(string.rep(" ", max_len-#keyx), keyx, " : ['", name, "', '", key, "'],")
            end

            ngx.say("}")
        end
    end

    ngx.say("")
    ngx.say("export default $api;")

end
