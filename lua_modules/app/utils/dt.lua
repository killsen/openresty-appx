
-- LuaDate v2
-- https://github.com/Tieske/date
-- http://tieske.github.io/date/
-- https://github.com/iorichina/dateModuleForOpenresty

local Date      = require "resty.date"

local tonumber  = tonumber
local tostring  = tostring
local _find     = ngx.re.find
local _match    = ngx.re.match
local _floor    = math.floor    -- 取整数

local dt = {
        _VERSION        = "21.05.14"
    ,   today           = ngx.today             -- 2017-12-22
    ,   localtime       = ngx.localtime         -- 2017-12-22 13:22:19
    ,   utctime         = ngx.utctime           -- 2017-12-22 05:22:19
    ,   now             = ngx.now               -- 1513920139.812
    ,   time            = ngx.time              -- 1513920139
    ,   cookie_time     = ngx.cookie_time       -- Fri, 22-Dec-17 05:22:19 GMT
    ,   http_time       = ngx.http_time         -- Fri, 22 Dec 2017 05:22:19 GMT
    ,   parse_http_time = ngx.parse_http_time   -- 1513920139
}

local exp_vali = [[(\d+)[-/.](\d+)[-/.](\d+)((.*)\s(\d+)\:(\d+)\:(\d+))?]] -- yyyy-mm-dd
local exp_date = [[\d{4}-(0\d|1[0-2])-([0-2]\d|3[01])]] -- yyyy-mm-dd
local exp_time = [[([01]\d|2[0-3])\:[0-5]\d\:[0-5]\d]]  -- HH:MM:SS
local exp_date_time = "^" .. exp_date .. "( " .. exp_time .. ")?$"
--    exp_date_time = [[^\d{4}-\d{2}-\d{2}( \d{2}:\d{2}:\d{2})?$]]

-- 转换日期格式
function dt.vali_date(s)

    if type(s) ~= "string" then return nil end

    if dt.is_date(s) then return s end

    local  t = _match(s, exp_vali, "jo")
    if not t then return nil end

    local yy, mm, dd = t[1], t[2], t[3]
    local PM         = t[5]
    local HH, MM, SS = t[6], t[7], t[8]

        if #yy==2 then yy = "20" .. yy end
        if #mm==1 then mm =  "0" .. mm end
        if #dd==1 then dd =  "0" .. dd end

        s = yy .. "-" .. mm .. "-" .. dd

    if HH and MM and SS then

        if PM and _find(PM, "下午|PM", "joi") then
            HH = tostring(tonumber(HH) + 12)
        end

        if #HH==1 then HH =  "0" .. HH end
        if #MM==1 then MM =  "0" .. MM end
        if #SS==1 then SS =  "0" .. SS end

        s = s .. " " .. HH .. ":" .. MM .. ":" .. SS
    end

    if not dt.is_date(s) then return nil end

    return s

end

-- 检查是否日期格式
function dt.is_date(s)
    return _find(s, exp_date_time, "jo") and true or false
end

-- rfc3339格式
function dt.rfc3339(s)

    if type(s) ~= "string" or s == "" then
        s = ngx.localtime()
    end

    local  d = Date(s)
    if not d then return end

    return d:fmt("${iso}") .. ".000+08:00"

end

-- 日期格式化
function dt.format(n, format)

    local  d = Date(n)
    if not d then return end

    if type(n) == "number" then
        d = d:tolocal()
    end

    if type(format) == "string" and format ~= "" then
        return d:fmt(format)
    end

    local fdate = d:fmt("%Y-%m-%d")
    local ftime = d:fmt("%H:%M:%S")

    if ftime == "00:00:00" then
        return fdate
    else
        return fdate .. " " .. ftime
    end

end

-- 将数字转成字符串
function dt.to_date(n, format)
    return dt.format(n, format)
end

-- 将字符串转成数字
function dt.to_time(s)
    local bias = Date("1970-01-01"):tolocal()
    return dt.diff_sec(s, bias)
end

-- 两个日期相差天数（只比较日期部分）
function dt.diff_day(s1, s2)

    local d1 = Date(s1)
    local d2 = Date(s2)

    if not d1 or not d2 then return end

    d1:sethours(0, 0, 0, 0)
    d2:sethours(0, 0, 0, 0)

    local  d = Date.diff(d1, d2)
    if not d then return end

    return _floor(d:spandays())

end

-- 两个时间相差小时数（不比较分钟部分）
function dt.diff_hour(s1, s2)

    local d1 = Date(s1)
    local d2 = Date(s2)

    if not d1 or not d2 then return end

    d1:setminutes(0, 0, 0)
    d2:setminutes(0, 0, 0)

    local  d = Date.diff(d1, d2)
    if not d then return end

    return _floor(d:spanhours())

end

-- 两个时间相差分钟数（不比较秒部分）
function dt.diff_min(s1, s2)

    local d1 = Date(s1)
    local d2 = Date(s2)

    if not d1 or not d2 then return end

    d1:setseconds(0, 0)
    d2:setseconds(0, 0)

    local  d = Date.diff(d1, d2)
    if not d then return end

    return _floor(d:spanminutes())

end

-- 两个时间相差秒数
function dt.diff_sec(s1, s2)

    local d1 = Date(s1)
    local d2 = Date(s2)

    if not d1 or not d2 then return end

    d1:setticks(0)
    d2:setticks(0)

    local  d = Date.diff(d1, d2)
    if not d then return end

    return _floor(d:spanseconds())

end

-- 上年同日
function dt.prev_year(s)
    return dt.add_year(s, -1)
end

-- 下年同日
function dt.next_year(s)
    return dt.add_year(s, 1)
end

-- 添加年
function dt.add_year(s, n)
    return dt.add_month(s, n*12)
end

-- 上月同日
function dt.prev_month(s)
    return dt.add_month(s, -1)
end

-- 下月同日
function dt.next_month(s)
    return dt.add_month(s, 1)
end

-- 添加月
function dt.add_month(s, n)

    local  d = Date(s)
    if not d then return end

    local day = d:getday()

    -- 下个月最后一天
    d:setmonth(d:getmonth()+n+1, 0)

    if d:getday() > day then
        d:setday(day)
    end

    return d:fmt("%Y-%m-%d")

end

-- 上日
function dt.prev_date(s)
    return dt.add_day(s, -1)
end

-- 下日
function dt.next_date(s)
    return dt.add_day(s, 1)
end

-- 添加天
function dt.add_day(s, n)
    local  d = Date(s)
    if not d then return end
    return d:adddays(n):fmt("%Y-%m-%d")
end

-- 添加小时
function dt.add_hour(s, n)
    local  d = Date(s)
    if not d then return end
    return d:addhours(n):fmt("%Y-%m-%d %H:%M:%S")
end

-- 添加分钟
function dt.add_min(s, n)
    local  d = Date(s)
    if not d then return end
    return d:addminutes(n):fmt("%Y-%m-%d %H:%M:%S")
end

-- 添加秒
function dt.add_sec(s, n)
    local  d = Date(s)
    if not d then return end
    return d:addseconds(n):fmt("%Y-%m-%d %H:%M:%S")
end

-- 年月日
function dt.yyyymmdd(s)
    local  d = Date(s)
    if not d then return end
    return d:fmt("%Y"), d:fmt("%m"), d:fmt("%d")
end

-- 时分秒
function dt.hhmmss(s)
    local  d = Date(s)
    if not d then return end
    return d:fmt("%H"), d:fmt("%M"), d:fmt("%S")
end

-- 年
function dt.year(s)
    local  d = Date(s)
    if not d then return end
    return d:getyear()
end

-- 月
function dt.month(s)
    local  d = Date(s)
    if not d then return end
    return d:getmonth()
end

-- 日
function dt.day(s)
    local  d = Date(s)
    if not d then return end
    return d:getday()
end

-- 时
function dt.hour(s)
    local  d = Date(s)
    if not d then return end
    return d:gethours()
end

-- 分
function dt.min(s)
    local  d = Date(s)
    if not d then return end
    return d:getminutes()
end

-- 秒
function dt.sec(s)
    local  d = Date(s)
    if not d then return end
    return d:getseconds()
end

-- 取得星期几: 星期一返回1, 星期天返回7
function dt.wday(s)
    local  d = Date(s)
    if not d then return end
    return d:getisoweekday()
end

-- 取得一年的第几天
function dt.yday(s)
    local  d = Date(s)
    if not d then return end
    return d:getyearday()
end

-- 月头
function dt.first_of_month(s)
    local  d = Date(s)
    if not d then return end
    return d:setday(1):fmt("%Y-%m-%d")
end

-- 月底
function dt.end_of_month(s)
    local  d = Date(s)
    if not d then return end
    return d:setmonth(d:getmonth()+1, 0):fmt("%Y-%m-%d")
end

-- 年头
function dt.first_of_year(s)
    local  d = Date(s)
    if not d then return end
    return d:setmonth(1, 1):fmt("%Y-%m-%d")
end

-- 年底
function dt.end_of_year(s)
    local  d = Date(s)
    if not d then return end
    return d:setmonth(12, 31):fmt("%Y-%m-%d")
end

-- 星期一
function dt.first_of_week(s)
    local  d = Date(s)
    if not d then return end
    return d:setisoweekday(1):fmt("%Y-%m-%d")
end

-- 星期天
function dt.end_of_week(s)
    local  d = Date(s)
    if not d then return end
    return d:setisoweekday(7):fmt("%Y-%m-%d")
end

-- 月天数
function dt.month_days(s)
    local  d = Date(s)
    if not d then return end
    return d:setmonth(d:getmonth()+1, 0):getday()
end

return dt
