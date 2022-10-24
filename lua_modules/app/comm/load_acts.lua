
-- 加载 action v17.12.01 by Killsen ------------------

local require   = require
local _insert   = table.insert

local file_list = require "app.utils".file_list  -- 文件列表
local path_list = require "app.utils".path_list  -- 目录列表

---------------------------------------------------

local function load_path (list, path, name)

    -- 文件列表
    local flist = file_list (path)
        for _, f in ipairs(flist) do
            _insert(list, name .. f)
        end

    -- 目录列表
    local plist = path_list (path)
        for _, p in ipairs(plist) do
            load_path(list, path .. p .. "/",
                            name .. p .. ".")
        end

end


local function load_acts (app_name)

    local list = {}
    local path = "app/" .. app_name .. "/act/"
    local name = "app." .. app_name .. ".act."

    load_path (list, path, "")

    for i, f in ipairs(list) do

        package.loaded[name .. f] = nil
        local ok, mod = pcall(require, name .. f)
        package.loaded[name .. f] = nil

        if not ok then
            list[i] = {name=f, err=mod}
        elseif type(mod)=="table" then
            list[i] = { name  = f, text = mod.name, ver = mod.ver,

                        doc   = mod.doc,
                        demo  = type(mod.demo)=="table" and (f .. ".jsony?" .. ngx.encode_args(mod.demo))
                              or mod.demo,

                        lform = type(mod.argx)=="table",

                        auth  = mod.auth==true and "需登录"
                              or type(mod.auth)=="string"   and mod.auth
                              or type(mod.auth)=="function" and "自定义"
                              or mod.host=="127.0.0.1"      and "需本机"
                              or mod.host=="192.168.0.0/16" and "局域网"
                              or type(mod.host)=="table"    and table.concat(mod.host,"<br>")
                              or mod.host or nil,

                        resty = type(mod.actx)=="table",
                          add = type(mod.actx)=="table"    and type(mod.actx.add) =="function",
                          del = type(mod.actx)=="table"    and type(mod.actx.del) =="function",
                          set = type(mod.actx)=="table"    and type(mod.actx.set) =="function",
                          get = type(mod.actx)=="table"    and type(mod.actx.get) =="function",
                         list = type(mod.actx)=="table"    and type(mod.actx.list)=="function",

                        err   = type(mod.actx)~="function" and
                                type(mod.actx)~="table"    and
                                "未指定actx函数" or nil
                    }
        elseif type(mod)=="function" then
            list[i] = {name=f}
        else
            list[i] = {name=f, err="非action模块：" .. type(mod) }
        end
    end

    return list

end

return load_acts
