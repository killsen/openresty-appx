
-- 启动后台任务
local function run_tasks(premature, app_name)

    -- 定时器已过期
    if premature then return end

    -- 加载 app
    local appx = require "app.comm.appx"
    local app  = appx.new(app_name)
    if not app then return end

    -- 加载 tasks 文件
    local mod_name = "app." .. app_name .. ".tasks"
    local  ok, tasks = pcall(require, mod_name)
    if not ok then return end

    if type(tasks) == "table" then tasks = tasks.run end

    if type(tasks) == "function" then
        local  ok, err = pcall(tasks)
        if not ok then
            ngx.log(ngx.ERR, " [ ", app_name, " ] run tasks error: ", err)
        end
    end

end

local utils = require "app.comm.utils"
local files = utils.file_list("app")

for _, app_name in ipairs(files) do
    if string.sub(app_name, -5) ~= "-prod" then
        ngx.timer.at(0, run_tasks, app_name)
    end
end
