import $utils        from './utils/index.js'      // 工具函数
import AppIcons      from './icons/index.js'      // 应用图标
import AppComponents from './components/index.js' // 应用组件
import AppViews      from './views/index.js'      // 应用页面

// 左侧导航菜单
const navs = [
    { id: 'api-manage'  , name: 'API 接口'  , icon: 'icon-menu-api' },
    { id: 'act-manage'  , name: 'ACT 接口'  , icon: 'icon-menu-act' },
    { id: 'db-manage'   , name: '数据库管理', icon: 'icon-menu-db'  },
    { id: 'db-structure', name: '数据库结构', icon: 'icon-menu-db'  },
]

// 程序加载完成
window.onload = function() {
    bootstarp()
}

// 启动应用
function bootstarp() {
    const Vue         = window.Vue
    const ElementPlus = window.ElementPlus
    if ( !Vue || !ElementPlus) return

    // 创建应用
    const app = window.$app = Vue.createApp({
        data() {
            const G           = window.G      || {}
            const help_config = G.help_config || {}

            // 初始化链接配置、过滤为空的配置
            const links = (help_config.links || []).filter(item => {
                if (Array.isArray(item) && item[0] && item[1]) return true // 数组配置 [text, link]
                if ('text' in item && 'link' in item         ) return true // 对象配置 { text: '', link: '' }
                return false
            }).map(item => {
                return Array.isArray(item) ? { text: item[0], link: item[1] } : item
            })

            return {
                // 注入数据
                g: {
                    app_name : G.app_name  || '',
                    app_title: G.app_title || '',
                    app_ver  : G.app_ver   || '',
                    app_apis : G.app_apis  || [],
                    app_acts : G.app_acts  || [],
                    app_daos : G.app_daos  || [],
                    app_daox : null,
                    help_config: {
                        ...help_config,
                        links
                    },
                },

                // 程序数据
                navs                 ,
                curr_nav             : location.hash.replace(/^#/, '') || navs[0].id, // 当前导航菜单
                visible_reload_dialog: false, // 应用重载弹窗
            }
        },
        methods: {
            // 模块重载
            async handleReload() {
                const confirm = await $utils.showConfirm('是否重载模块')
                if ( !confirm ) return

                this.g.visible_reload_dialog = true
            },

            // 跳转链接
            handleLinkClick(item) {
                window.open(item.link, '_blank')
            },
        },
    })

    // 安装插件
    app.use(ElementPlus)
    app.use(AppIcons     , { Vue })
    app.use(AppComponents, { Vue })
    app.use(AppViews     , { Vue })

    // 挂载应用
    app.mount('#app')
}
