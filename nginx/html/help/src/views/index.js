import AppIntro    from './app-intro.js'     // 项目介绍页
import ApiManage   from './api-manage.js'    // API 接口管理页面
import ActManage   from './act-manage.js'    // ACT 接口管理页面
import DbManage    from './db-manage.js'     // 数据库管理
import DbStructure from './db-structure.js'  // 数据库结构

export default {
    install(app, { Vue }) {
        if (!app || !app.component) return

        app.component('app-intro'   , Vue.defineComponent(AppIntro))
        app.component('api-manage'  , Vue.defineComponent(ApiManage))
        app.component('act-manage'  , Vue.defineComponent(ActManage))
        app.component('db-manage'   , Vue.defineComponent(DbManage))
        app.component('db-structure', Vue.defineComponent(DbStructure))
    }
}
