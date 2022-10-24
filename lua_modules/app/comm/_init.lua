
-- 初始化 v22.05.01 by Killsen ------------------

local lfs   = require "lfs"
local pcall = pcall

-- nginx 运行目录
local prefix = ngx.config.prefix()
do
    if not prefix or prefix == "./" or prefix == "" then
        prefix = lfs.currentdir()
    end
    prefix = string.gsub(prefix, [[%\]], "/")
    if string.sub(prefix, -1) ~= "/" then
        prefix = prefix .. "/"
    end
end

do
    -- 兼容处理 Windows 下 ffi.load 路径问题
    local ffi = require "ffi"
    if ffi.os == "Windows" then
        local ffi_load = ffi.load
        ffi.load = function(filename)
            local pok, clib

            pok, clib = pcall(ffi_load, filename)
            if pok then return clib end

            pok, clib = pcall(ffi_load, prefix .. filename)
            if pok then return clib end
        end
    end

end

do
    local io_open = io.open
    _G.openx = function(filename, mode)
        return io_open(prefix .. filename, mode)
    end
    rawset(io, "openx", _G.openx)
end

do
    local dofile = dofile
    _G.dofilex = function(filename)
        return dofile(prefix .. filename)
    end
end

do
    local lfs_dir = lfs.dir
    lfs.lfs_dir = lfs_dir
    lfs.dir = function(path)
        if type(path) ~= "string" then return function() end end
        -- 兼容 linux 目录不存在时出错的 bug
        local pok, f, a, b = pcall(lfs_dir, prefix .. path)
        if pok then
            return f, a, b
        else
            return function() end
        end
    end
end

do
    local lfs_mkdir = lfs.mkdir
    lfs.lfs_mkdir = lfs_mkdir
    lfs.mkdir = function(path)
        if type(path) ~= "string" then return nil, "path is null" end
        local  pok, res, err = pcall(lfs_mkdir, prefix .. path)
        if not pok then return nil, res end
        return res, err
    end
end

do
    local lfs_rmdir = lfs.rmdir
    lfs.lfs_rmdir = lfs_rmdir
    lfs.rmdir = function(path)
        if type(path) ~= "string" then return nil, "path is null" end
        local  pok, res, err = pcall(lfs_rmdir, prefix .. path)
        if not pok then return nil, res end
        return res, err
    end
end

do
    local lfs_attributes = lfs.attributes
    lfs.lfs_attributes = lfs_attributes
    lfs.attributes = function(path, aname)
        if type(path) ~= "string" then return nil, "path is null" end
        local  pok, res, err = pcall(lfs_attributes, prefix .. path, aname)
        if not pok then return nil, res end
        return res, err
    end
end
