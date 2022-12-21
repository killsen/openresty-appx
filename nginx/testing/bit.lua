
local bit = require "bit"
-- https://bitop.luajit.org/api.html

local function print(...)
    ngx.say(...)
end

local function printx(x)
    ngx.say("0x"..bit.tohex(x))
end

print   "---------------------"
print   (0xffffffff)                        --> 4294967295
print   (bit.tobit(0xffffffff))             --> -1
printx  (bit.tobit(0xffffffff))             --> 0xffffffff
print   (bit.tobit(0xffffffff + 1))         --> 0
print   (bit.tobit(2^40 + 1234))            --> 1234
print   "---------------------"
print   (bit.tohex(1))                      --> 00000001
print   (bit.tohex(-1))                     --> ffffffff
print   (bit.tohex(0xffffffff))             --> ffffffff
print   (bit.tohex(-1, -8))                 --> FFFFFFFF
print   (bit.tohex(0x21, 4))                --> 0021
print   (bit.tohex(0x87654321, 4))          --> 4321
print   "---------------------"
print   (bit.bnot(0))                       --> -1
printx  (bit.bnot(0))                       --> 0xffffffff
print   (bit.bnot(-1))                      --> 0
print   (bit.bnot(0xffffffff))              --> 0
printx  (bit.bnot(0x12345678))              --> 0xedcba987
print   "---------------------"
print   (bit.bor(1, 2, 4, 8))               --> 15
printx  (bit.band(0x12345678, 0xff))        --> 0x00000078
printx  (bit.bxor(0xa5a5f0f0, 0xaa55ff00))  --> 0x0ff00ff0
print   "---------------------"
print   (bit.lshift(1, 0))                  --> 1
print   (bit.lshift(1, 8))                  --> 256
print   (bit.lshift(1, 40))                 --> 256
print   (bit.rshift(256, 8))                --> 1
print   (bit.rshift(-256, 8))               --> 16777215
print   (bit.arshift(256, 8))               --> 1
print   (bit.arshift(-256, 8))              --> -1
printx  (bit.lshift(0x87654321, 12))        --> 0x54321000
printx  (bit.rshift(0x87654321, 12))        --> 0x00087654
printx  (bit.arshift(0x87654321, 12))       --> 0xfff87654
print   "---------------------"
printx  (bit.rol(0x12345678, 12))           --> 0x45678123
printx  (bit.ror(0x12345678, 12))           --> 0x67812345
print   "---------------------"
printx  (bit.bswap(0x12345678))             --> 0x78563412
printx  (bit.bswap(0x78563412))             --> 0x12345678
print   "---------------------"
