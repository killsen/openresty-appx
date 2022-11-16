import AppLayout     from './layout/index.js'     // 应用布局
import AppIcons      from './icons/index.js'      // 应用图标
import AppComponents from './components/index.js' // 应用组件
import AppViews      from './views/index.js'      // 应用页面

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
        name : 'App',
        render: () => Vue.h(Vue.defineComponent(AppLayout))
    })

    // 安装插件
    app.use(ElementPlus)
    app.use(AppIcons     , { Vue })
    app.use(AppComponents, { Vue })
    app.use(AppViews     , { Vue })

    // 挂载应用
    app.mount('#app')
}
