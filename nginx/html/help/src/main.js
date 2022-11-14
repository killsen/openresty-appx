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
            const G = window.G || {}
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
                        gitee: '',
                        ...G.help_config
                    },
                },

                // 程序数据
                navs                 ,
                curr_nav             : location.hash.replace(/^#/, '') || navs[0].id, // 当前导航菜单
                visible_reload_dialog: false, // 应用重载弹窗
                reload_url           : `${ $utils.getOrigin() }/${ G.app_name }/reload`, // 应用重载地址
            }
        },
        methods: {
            // 模块重载
            async handleReload() {
                const confirm = await $utils.showConfirm('是否重载模块')
                if ( !confirm ) return

                this.g.visible_reload_dialog = true
            },

            // 跳转测试服务器
            handleToTestServer() {
                const dev_url = this.g.help_config.dev_url
                if ( !dev_url ) {
                    $utils.showAlert('当前项目尚未配置 “测服访问地址”', '提示', { confirmButtonText: '我知道了' })
                    return
                }

                window.open(dev_url, '_blank')
            },

            // 跳转 Gitee 工作台
            handleToGitee() {
                const gitee_url = this.g.help_config.gitee
                if ( !gitee_url ) {
                    $utils.showAlert('当前项目尚未配置 “Gitee仓库地址”', '提示', { confirmButtonText: '我知道了' })
                    return
                }

                window.open(gitee_url, '_blank')
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
