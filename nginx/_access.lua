
local waf = require "app.comm.waf"

local ok, err = pcall(waf.check.access_by_lua)
if not ok then
    ngx.log(ngx.ERR, err)
end
