import AppTable     from './app-table.js'
import AppTypeList  from './app-type-list.js'
import AppSerach    from './app-search.js'

export default {
    install(app) {
        if (!app || !app.component) return

        app.component('app-search'   , Vue.defineComponent(AppSerach)  )
        app.component('app-table'    , Vue.defineComponent(AppTable)   )
        app.component('app-type-list', Vue.defineComponent(AppTypeList))
    }
}
