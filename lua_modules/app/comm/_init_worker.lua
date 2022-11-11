
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
pcall(require, "app.comm.run_tasks")

-- 动态加载证书
pcall(require, "app.comm.sslx")
