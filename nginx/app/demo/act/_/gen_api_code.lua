
local gen_api_code = _load "#gen_api_code"

local __ = {}
__.ver   = "21.08.30"
__.name  = "生成参数校验函数代码"
__.host  = "127.0.0.1"
__.demo  = { base = "" }
------------------------------------------------------

__.actx = function()

    gen_api_code()

end

------------------------------------------------------
return __ -- 返回模块
