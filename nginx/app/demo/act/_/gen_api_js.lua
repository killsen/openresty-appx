
local gen_api_js = _load "#gen_api_js"

local __ = {}
__.ver   = "21.08.30"
__.name  = "生成 api.js"
__.host  = "127.0.0.1"
__.demo  = { base = "" }
------------------------------------------------------

__.actx = function()

    gen_api_js()

end

------------------------------------------------------
return __ -- 返回模块
