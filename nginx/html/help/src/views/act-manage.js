/**
 * API 接口管理
 * v22.11.14
 */
const template = `
<div class="container container-main">
    <app-table
        :cols="cols"
        :rows="rows$"
        :actions="actions"
        :actionsWidth="actionsWidth"
        @view="handleViewClick"
    >
        <template #header-left>
            <span class="container-header__title">
                ACT 接口
            </span>
        </template>

        <template #header-search-left>
            <el-button text bg :type="errorList$.length ? 'danger' : ''" @click="errDialog = true">
                查看错误日志
                ( <span>{{ errorList$.length }}条</span> )
            </el-button>
        </template>
    </app-table>

    <el-dialog
        v-if="iframeDialog.visible"
        v-model="iframeDialog.visible"
        :width="iframeDialog.width"
    >
        <template #header>
            <div class="dialog-header">
                <span>查看返回值</span>
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
            <el-tab-pane label="lpage" name="lpage"></el-tab-pane>
            <el-tab-pane label="ljson" name="ljson"></el-tab-pane>
            <el-tab-pane label="jsony" name="jsony"></el-tab-pane>
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
            cols: [
                { id: 'name' , name: '接口名称', align: 'left', showBackground: true, searchable: true },
                { id: 'text' , name: '接口说明', align: 'left', searchable: true, link: 'doc'  },
                { id: 'ver'  , name: '接口版本', width: '120px', formatter: 'formatVersion' },
                { id: 'auth' , name: '接口授权', width: '120px' },
                { id: 'err'  , name: '接口错误', width: '120px' },
                { id: 'demo' , name: '功能演示', width: '120px', type: 'demo' },
            ],
            actions: [
                { id: 'view' , name: '查看返回值'    },
            ],
            actionsWidth: '120px',
            errDialog: false,
            iframeDialog: {
                visible: false,
                iframe : '',
                width  : '700px',
                curr_tab: 'lpage',
                curr_row: null,
            },
        }
    },
    computed: {
        // 含有错误信息的接口
        errorList$() {
            return this.g.app_acts.filter(item => item.err)
        },
        rows$() {
            return this.g.app_acts
        }
    },
    methods: {
        // 查看返回值
        handleViewClick({ row }) {
            const dialog = this.iframeDialog
            dialog.curr_row = row
            this.handleTabChange('lpage')
            dialog.visible  = true
        },

        handleTabChange(format_name) {
            const dialog   = this.iframeDialog
            const act_name = dialog.curr_row.name
            if ( !act_name ) return

            dialog.iframe  = `${ $utils.getOrigin() }/${ this.g.app_name }/${ act_name }.${ format_name }`
        }
    },
    template
}
