-- @@api : openresty-vsce

local __ = { _VERSION = "v1.0.0" }

-- 生成API模块
require "app.comm.apix".new(__)

return __
