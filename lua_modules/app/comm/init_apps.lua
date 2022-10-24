
-- 初始化 apps v20.08.30

local load_app  = require "app.comm.load_app"
local file_list = require "app.utils".file_list
local timer_at  = ngx.timer.at

-- 初始化 app
local function init_app(premature, app_name)

    -- 定时器已过期
    if premature then return end

    ngx.ctx.app_name = app_name

    -- 加载 app
    local  app = load_app()
    if not app then return end

    -- ngx.log(ngx.ERR, "load app success: ", app_name)

    -- 加载 init 文件
    local mod_name = "app." .. app_name .. ".init"
    local  ok, init = pcall(require, mod_name)
    if not ok then return end

    if type(init) == "function" then
        local  ok, err = pcall(init)
        if not ok then
            ngx.log(ngx.ERR, " [ ", app_name, " ] init error: ", err)
        end
    end

end

-- 初始化 apps
return function()

    local files = file_list("app")

    for _, app_name in ipairs(files) do
        timer_at(0, init_app, app_name)
    end

end




