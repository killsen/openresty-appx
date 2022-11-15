
-- 加载 api 列表

local apix          = require "app.comm.apix"
local load_path     = apix.gen_api_utils.load_path
local _insert       = table.insert
local _sort         = table.sort

local function load_apis (app_name, base_path, base_name)

    local apis = {}

    local app = require "app.comm.appx".new(app_name)
    if not app then return apis end

    app_name = app.name

    base_path = base_path or ("app/" .. app_name .. "/api/")
    base_name = base_name or  ""

    local list  = {}
    load_path(list, base_path, base_name)
    _sort(list)

    for _, name in ipairs(list) do
        local api = apix.load_api(name)
        _insert(apis, api)
    end

    return apis

end

return load_apis

