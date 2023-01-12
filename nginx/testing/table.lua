
local t = table.clone { 1, 2, 3 }

local s = table.concat(t, ", ")
ngx.say(s)  -- 1, 2, 3

local t = { 1, nil, 3 }

local n1 = #t
local n2 = table.getn(t)
local n3 = table.nkeys(t)
local n4 = table.maxn(t)
ngx.say(n1, ", ", n2, ", ", n3, ", ", n4)
--       1,        1,        2,        3

local t1, t2, t3 = table.unpack(t)
ngx.say(t1, ", ", t2, ", ", t3)
--       1,      nil,      nil

t1, t2, t3 = table.unpack(t, 1, 3)
ngx.say(t1, ", ", t2, ", ", t3)
--       1,      nil,        3

local t = table.pack(1, nil, 3)
t1, t2, t3 = table.unpack(t)
ngx.say("t.n = ", t.n)    -- 3
ngx.say(t1, ", ", t2, ", ", t3)
--       1,      nil,        3
