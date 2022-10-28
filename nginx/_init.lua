
local prefix = ngx.config.prefix()

-- lua 模块检索路径
local path = {
    prefix .. "/?.lua",
    prefix .. "/?/init.lua",
    prefix .. "/lua/?.lua",
    prefix .. "/lua/?/init.lua",
    prefix .. "/lualib/?.lua",
    prefix .. "/lualib/?/init.lua",
    --------------------------------
    prefix .. "/../lua_modules/?.lua",
    prefix .. "/../lua_modules/?/init.lua",
    prefix .. "/../lua_modules/lua/?.lua",
    prefix .. "/../lua_modules/lua/?/init.lua",
    prefix .. "/../lua_modules/lualib/?.lua",
    prefix .. "/../lua_modules/lualib/?/init.lua",
    -----------------------------------------------
    ";"
}

-- clib 模块检索路径
local cpath = {
    prefix .. "/?.dll",
    prefix .. "/clib/?.dll",
    prefix .. "/clib/?/?.dll",
    prefix .. "/lualib/?.dll",
    prefix .. "/lualib/?/?.dll",
    prefix .. "/../lua_modules/clib/?.dll",
    prefix .. "/../lua_modules/clib/?/?.dll",
    prefix .. "/../lua_modules/lualib/?.dll",
    prefix .. "/../lua_modules/lualib/?/?.dll",
    -------------------------------------------
    prefix .. "/?.so",
    prefix .. "/clib/?.so",
    prefix .. "/clib/?/?.so",
    prefix .. "/lualib/?.so",
    prefix .. "/lualib/?/?.so",
    prefix .. "/../lua_modules/clib/?.so",
    prefix .. "/../lua_modules/clib/?/?.so",
    prefix .. "/../lua_modules/lualib/?.so",
    prefix .. "/../lua_modules/lualib/?/?.so",
    -------------------------------------------
    ";"
}

package.path = table.concat(path, ";")
package.cpath = table.concat(cpath, ";")

local pok, err = pcall(require, "app.comm._init")
if not pok then
    ngx.log(ngx.ERR, err)
    return
end

local pok, app = pcall(require, "app")
if not pok then
    ngx.log(ngx.ERR, app)
    return
end

rawset(_G, "_app_main"      , app.main)
rawset(_G, "_app_auth"      , app.auth)
rawset(_G, "_app_help"      , app.help)
rawset(_G, "_app_monitor"   , app.monitor)
rawset(_G, "_app_info"      , app.info)
rawset(_G, "_app_debug"     , app.debug)
