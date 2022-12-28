
local to_hex = require "resty.string".to_hex
local my_md5 = require "resty.md5":new()

local function _md5(...)
    my_md5:reset()
    for _, s in ipairs {...} do
        my_md5:update(s)
    end
    local s = my_md5:final()
    return to_hex(s)
end

ngx.say(_md5("a", "b", "c"))
ngx.say(_md5("a".."b".."c"))
ngx.say(ngx.md5("a".."b".."c"))
