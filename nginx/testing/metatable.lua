
local _M = { ver = "1.0.0" }

local mt = { __index = _M }

function _M.new(...)
    local name, desc = ...
    return setmetatable({
        name = name,
        desc = desc,
    }, mt)
end

function _M:get_ver()
    -- return self.ver
    return rawget(self, "ver")
end

function _M:get_name()
    -- return self.name
    return rawget(self, "name")
end

function _M.set_name(self, name)
    -- self.name = name
    rawset(self, "name", name)
end

_M._TESTING = function()

    local t = _M("名称", "描述")

    ngx.say(t.name)
    ngx.say(t.desc)
    ngx.say(t.ver)

    local name = t:get_name()
    ngx.say(name)

    t.name = "名称1";           ngx.say(t.name)
    t.set_name(t, "名称2");     ngx.say(t.name)
    t:set_name("名称3");        ngx.say(t.name)
    _M.set_name(t, "名称4");    ngx.say(t.name)

    local mt_of_M = getmetatable(_M)
    ngx.say(type(mt_of_M.__call))

    local mt_of_t = getmetatable(t)
    ngx.say(mt_of_t.__index.ver)

end

setmetatable(_M, {
    __call = function(_, ...)
        return _M.new(...)
    end,
})

return _M

