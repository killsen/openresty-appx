
local template  = require "resty.template.safe"
local _render   = template.render

-- 错误页面模板
local err_html = [[
<!DOCTYPE html>
<html>
<head>
    <title>抱歉，出错了</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=0">
    <link rel="stylesheet" type="text/css"
        href="https://res.wx.qq.com/connect/zh_CN/htmledition/style/wap_err1a9853.css">
</head>
<body>
    <div class="page_msg">
        <div class="inner">
            <span class="msg_icon_wrp"><i class="icon80_smile"></i></span>
            <div class="msg_content">
                <h4>{* message *}</h4>
            </div>
        </div>
    </div>
</body>
</html>
]]

-- 输出错误信息
return function (message)
-- @message : string

    if type(message) ~= "string" or message == "" then
        message = "未知错误"
    end

    ngx.header['Content-Type' ] = "text/html;charset=utf-8"
    ngx.header['Cache-Control'] = "no-store"  -- 不缓存

    _render(err_html, { message = message })

end
