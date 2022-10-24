
-- 加载 dao 列表 v17.07.27 by Killsen ------------------

local require     = require
local file_list   = require "app.utils".file_list   -- lua文件列表
local err_log     = require "app.utils".err_log     -- 错误日志输出
local init_fields = require "app.comm.init_fields"  -- 初始化列定义

---------------------------------------------------

-- 载入dao模块
local function load_daos (app_name)

    local app_daos = {}
    local dao_path = "app/" .. app_name .. "/dao/"
    local mod_name = "app." .. app_name .. ".dao."

    local files = file_list (dao_path) -- lua文件列表

    for _, file in ipairs(files) do

        local name = mod_name .. file -- 载入dao模块
        local ok, dao = xpcall(require, err_log, name)

        if ok and type(dao) == "table" then
            init_fields(dao.field_list) -- 初始化列定义
            table.insert(app_daos, dao)
        end
    end

    return app_daos

end

return load_daos
