
-- 重载模块 v18.01.06 by Killsen ------------------

local require   = require
local lfs       = require "lfs"                         -- LuaFileSystem
local file_name = require "app.comm.utils".file_name    -- 获取文件名
local exe_name  = require "app.comm.utils".exe_name     -- 获取扩展名

---------------------------------------------------

--重启模块
local function reload_file (modname)
-- @modname : string
-- @return  : void

    package.loaded [modname] = nil
    local ok, err = pcall(require, modname)
    if ok then
        ngx.say ("重启：", modname)
    else
        ngx.say ("")
        ngx.say ("重启：", modname)
        ngx.say ("错误：", err)
        ngx.say ("")
    end
end

--查询.lua文件
local function reload_path(path, name)
-- @path   : string
-- @name   : string
-- @return : void

    name = name or path

    for f in lfs.dir(path) do
        if f ~= "." and f ~= '..' and f ~= "_bk" then
            local p = path .. "/" .. f
            local t = lfs.attributes(p).mode
            if t == "directory" then
                reload_path(p, name .. "." .. f)
            elseif exe_name(f) == "lua" then
                reload_file(name .. "." .. file_name(f) )
            end
        end
    end

end

local function reload_app(app_name)
-- @app_name : string
-- @return   : void

    local app = require "app.comm.appx".new(app_name)
    if not app then return ngx.exit(404) end

    local path = "app/" .. app.name
    local name = "app." .. app.name

    ngx.header["content-type"] = "text/plain"

    ngx.say("")
    ngx.say("############## 热 重 启 ############################")
    ngx.say("")

    reload_file (name)
    reload_path (path, name)

end

return reload_app
