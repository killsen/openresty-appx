
local app = {}
---------------------------------------------------

app.name       = "demo"
app.title      = "演示项目"
app.ver        = "v22.10.24"

-- 数据库的连接配置（db库）------------------------
app.db_config  = {
    host       = "127.0.0.1"    -- 服务器IP
,   port       = 3306           -- 服务器端口
,   user       = "root"         -- 登录账号
,   password   = "sumdoo"       -- 登录密码
,   database   = "demo_db"      -- 默认数据库
}

--- 帮助文档 --------------------------------------
app.help_html  = [[
]]

--- 帮助文档配置 ----------------------------------
app.help_config = {
    template = 'help/index.html', -- help 网页模板所在地址：远程地址、本地地址
    links    = {                  -- 顶部右侧链接配置（数组配置: { text, link }, 对象配置: { text: '', link: '' }）
        { "代码仓库", "https://github.com/killsen/openresty-appx" },
    },
}

---------------------------------------------------
return app
