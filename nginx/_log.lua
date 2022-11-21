
local waf = require "app.comm.waf"

local ok, err = pcall(waf.log)
if not ok then
    ngx.log(ngx.ERR, err)
end
