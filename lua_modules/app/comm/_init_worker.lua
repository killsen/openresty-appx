
-- 由于在 windows 版本中 ngx.worker.id() 总数返回 0
-- 以下代码通过共享内存，重写函数 ngx.worker.id

local  my_index = ngx.shared.my_index
if not my_index then
    ngx.log(ngx.ERR, "ngx.shared.my_index not exist.")
    return
end

local  index, err = my_index:incr("ngx_worker_index", 1, 0)
if not index then
    ngx.log(ngx.ERR, "ngx_worker_index incr error: ", err)
    return
end

local ffi = require "ffi"
if ngx.worker.count() > 1 and ffi.os == 'Windows' then

    local id = index % ngx.worker.count()

    -- 重写函数 ngx.worker.id
    ngx.worker.id = function()
        return id
    end

end

ngx.log(ngx.ERR ,   ", index="  , index
                ,   ", count="  , ngx.worker.count()
                ,   ", id="     , ngx.worker.id()
                ,   ", pid="    , ngx.worker.pid()
)

-- 启动后台任务
local pok, err = pcall(require, "app.comm.run_tasks")
if not pok then
    ngx.log(ngx.ERR, err)
end

-- 动态加载证书
local pok, sslx = pcall(require, "app.comm.sslx")
if not pok then
    ngx.log(ngx.ERR, sslx)
else
    sslx.domain.run_tasks() -- 开启自动升级证书任务
    sslx.ocsp.run_tasks()   -- 开启自动更新OCSP任务
end

-- 服务器实时监控
local pok, waf = pcall(require, "app.comm.waf")
if not pok then
    ngx.log(ngx.ERR, waf)
else
    waf.init()
end
