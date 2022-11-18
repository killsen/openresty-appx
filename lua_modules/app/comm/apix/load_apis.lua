
-- 加载 api 列表

local apix          = require "app.comm.apix"
local utils         = apix.gen_api_utils
local lfs           = require "lfs"
local _dir          = lfs.lfs_dir           -- 使用绝对路径
local _attr         = lfs.lfs_attributes    -- 使用绝对路径
local _insert       = table.insert
local _sort         = table.sort
local _sub          = string.sub

local MAX_LEVEL     = 5

-- lua文件列表
local function file_list(path)

    local list, index = {}, 0

    for f in _dir(path) do
        if f ~= "." and f ~= '..' then
            local p = path .. "/" .. f
            if _attr(p).mode == "file" and _sub(f, -4) == ".lua" then
                index = index + 1
                list[index] = _sub(f, 1, -5)
            end
        end
    end

    return list

end

-- 子目录列表
local function path_list(path)

    local list, index = {}, 0

    for f in _dir(path) do
        if f ~= "." and f ~= '..' then
            local p = path .. "/" .. f
            if _attr(p).mode == "directory" then
                index = index + 1
                list[index] = f
            end
        end
    end

    return list

end



-- 加载 api 目录及其子目录下全部 lua 文件
local function load_path(path)

    local list = {}

    -- 文件列表
    for _, name in ipairs(file_list(path)) do
        if name ~= "init" and _sub(name, 1, 1) ~= "_" then
            _insert(list, name)
        end
    end

    -- 目录列表
    for _, name in ipairs(path_list(path)) do
        if name ~= "init" and _sub(name, 1, 1) ~= "_" then
            _insert(list, name)
        end
    end

    _sort(list)
    return list

end

local function init_apis(api, level)

    level = tonumber(level) or 0
    if level > MAX_LEVEL then return end

    if type(api) ~= "table" then return end

    local keys = utils.get_tbl_keys(api)
    for _, key in ipairs(keys) do
        keys[key] = true
        init_apis(api[key], level+1)
    end

    local path = rawget(api, "__apipath")
    if type(path) ~= "string" or path == "" then return end

    local list = load_path(path)

    for _, name in ipairs(list) do
        if not keys[name] then
            init_apis(api[name], level+1)
        end
    end

end

local function load_apis(apis, base_api, base_name, level)

    level = tonumber(level) or 0
    if level > MAX_LEVEL then return end

    if type(base_api) ~= "table" then return end

    local keys = apix.gen_api_utils.get_fun_keys(base_api)
    if #keys > 0 then
        local api = apix.load_api(base_api, base_name)
        _insert(apis, api)
    end

    local names = apix.gen_api_utils.get_tbl_keys(base_api)
    for _, name in ipairs(names) do
        local api_name = base_name .. (base_name ~= "" and "." or "") .. name
        load_apis(apis, base_api[name], api_name, level+1)
    end

end

return function(app_name, base_name)

    local app = require "app.comm.appx".new(app_name)
    if not app then return end

    local api_root = app:load_mod("api")
    if type(api_root) ~= "table" then return end

    init_apis(api_root)

    local base_list = utils.get_tbl_keys(api_root)

    local base_api = utils.load_api_mod(api_root, base_name)
    if not base_api then return end

    local api_list = {}

    load_apis(api_list, base_api, "")

    return api_list, base_list, base_api

end
