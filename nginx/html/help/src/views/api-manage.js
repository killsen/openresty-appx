/**
 * ACT 接口管理
 * v22.11.19
 */
import $utils from '../utils/index.js'

const template = `
<div class="container container-main">
    <app-table
        :cols="cols"
        :rows="rows$"
        :actions="actions"
        :actionsWidth="actionsWidth"
        @action-click="handleShowDialog"
    >
        <template #header-left>
            <div class="container-header__left">
                <el-radio-group v-model="curr_api_group">
                    <template v-for="item in api_groups" :key="item.id">
                        <el-radio-button :label="item.id">{{ item.name }}</el-radio-button>
                    </template>
                </el-radio-group>
            </div>
        </template>

        <template #header-search-left>
            <el-button text bg @click="handleShowDialog({ row: null })">
                查看完整类型
            </el-button>
            <el-button text bg :type="errorList$.length ? 'danger' : ''" @click="errDialog = true">
                查看错误日志
                ( <span>{{ errorList$.length }}条</span> )
            </el-button>
        </template>

        <template #name="{ row }">
            <div class="api-wrap">
                <div class="api-wrap__name">{{ row.name }}</div>
                <div v-if="row.actions.length" class="api-wrap__line"></div>
                <ul v-if="row.actions.length" class="api-wrap-actions">
                    <li v-for="(item, idx) in row.actions" :key="item">
                        <span class="api-wrap-actions__item-name">{{ item.name }} </span>
                        <span class="api-wrap-actions__item-desc" v-if="item.desc"> -- {{ item.desc }}</span>
                    </li>
                </ul>
            </div>
        </template>
    </app-table>

    <el-dialog
        v-if="iframeDialog.visible"
        v-model="iframeDialog.visible"
        :width="iframeDialog.width"
    >
        <template #header>
            <div class="dialog-header">
                <span>查看详情</span>
                <el-link type="primary" :href="iframeDialog.iframe" target="_bank">
                    {{ iframeDialog.iframe }}
                    ( 新窗口打开 )
                    <el-icon>
                        <icon-jump></icon-jump>
                    </el-icon>
                </el-link>
            </div>
        </template>

        <el-tabs v-model="iframeDialog.curr_tab" @tab-change="handleTabChange">
            <el-tab-pane v-if="iframeDialog.curr_row" label="验参代码" name="lua"></el-tab-pane>
            <el-tab-pane label="api.d.ts" name="ts"></el-tab-pane>
            <el-tab-pane label="api.js" name="js"></el-tab-pane>
        </el-tabs>

        <iframe class="code-iframe-wrap" :src="iframeDialog.iframe"></iframe>
    </el-dialog>

    <el-dialog
        v-if="errDialog"
        v-model="errDialog"
        width="900px"
        title="错误日志"
    >
        <app-table :show-tools="false" :cols="errCols" :rows="errorList$" style="height: 500px;"></app-table>
    </el-dialog>
</div>
`
export default {
    props: {
        g: { type: Object, required: true }
    },
    data() {
        return {
            serach: '',
            errDialog: false,
            iframeDialog: {
                visible: false,
                iframe : '',
                width  : '700px',
                curr_tab: '',
                curr_row: null,
            },
            errCols: [
                { id: 'name', name: '接口名称', align: 'left', showBackground: true, searchable: true, width: '300px' },
                { id: 'err' , name: '接口错误', align: 'left' },
            ],
            cols: [
                { id: 'name'    , name: '接口名称', align: 'left', searchable: true },
                { id: 'ver'     , name: '接口版本', width: '100px' },
                { id: 'err'     , name: '接口错误', width: '120px' },
            ],
            actions: [
                { id: 'lua', name: '验参代码' },
                { id: 'ts' , name: 'api.d.ts' },
                { id: 'js' , name: 'api.js' },
            ],
            actionsWidth: '200px',
            api_groups: [],
            curr_api_group: 'all',
        }
    },
    computed: {
        // 含有错误信息的接口
        errorList$() {
            return this.g.app_apis.filter(item => item.err)
        },
        // api 列表
        list$() {
            return this.g.app_apis.map(item => {
                return {
                    ...item,
                    actions: (Array.isArray(item.actions) ? item.actions : []).map(str => {
                        const [name, desc] = str.split(' ')
                        return { name, desc }
                    })
                }
            })
        },
        // 筛选列表
        rows$() {
            const curr_api_group = this.curr_api_group
            if (curr_api_group === 'all') {
                return this.list$
            } else {
                return this.list$.filter(item => item.name === curr_api_group || item.name.startsWith(`${ curr_api_group }.`))
            }
        },
    },
    created() {
        this.initApiGroups()
    },
    methods: {
        // 初始化 api 分组
        initApiGroups() {
            const groups = []
            this.g.app_apis.forEach(item => {
                const name = (item.name || '').split('.')[0].trim()
                if ( name && !groups.includes(name) ) {
                    groups.push(name)
                }
            })

            this.api_groups = [
                { id: 'all', name: '全部' },
                ...groups.map(item => ({ id: item, name: item }))
            ]
        },

        // 查看 api 验证参数
        handleShowDialog({ row, item }) {
            const dialog    = this.iframeDialog
            dialog.curr_tab = item ? item.id : 'ts'
            dialog.curr_row = row
            this.handleTabChange(dialog.curr_tab)
            dialog.visible  = true
        },

        // 详情弹窗 tab 点击
        handleTabChange(name) {
            const dialog   = this.iframeDialog
            const act_name = dialog.curr_row?.name || ''

            let act = ''
            if (name === 'lua') act = act_name ? `api?api=${ act_name }`      : 'api'
            if (name === 'ts' ) act = act_name ? `api.d.ts?api=${ act_name }` : 'api.d.ts'
            if (name === 'js' ) act = act_name ? `api.js?api=${ act_name }`   : 'api.js'

            dialog.iframe = `${ $utils.getOrigin() }/${ this.g.app_name }/${ act }`
        }
    },
    template
}
