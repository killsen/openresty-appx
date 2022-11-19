/**
 * 数据库管理
 * v22.11.13
 */
 const template = `
<div class="container container-main">
    <app-table
        :cols="cols"
        :rows="rows$"
        :actions="actions"
        @reconstruction="handleReconstruction"
        @view="handleView"
        @info="handleInfo"
    >
        <template #header-left>
            <span class="container-header__title">
                数据库管理
            </span>
        </template>

        <template #header-search-left>
            <el-button text bg @click="handleUpdateDaos">
                升级表结构
            </el-button>
        </template>

        <template #field_list="{ cellValue }">
            <ul v-if="cellValue.length" style="padding-left: 15px;">
                <li v-for="(item, idx) in cellValue" class="ul-list-item" :key="item">
                    <span>{{ item.name }} :</span>
                    <span>{{ item.desc }}</span>
                </li>
            </ul>
        </template>
    </app-table>

    <el-dialog
        v-if="iframeDialog.visible"
        v-model="iframeDialog.visible"
        :width="iframeDialog.width"
    >
        <template #header>
            <div class="dialog-header">
                <span>{{ iframeDialog.title }}</span>
                <el-link type="primary" :href="iframeDialog.iframe" target="_bank">
                    {{ iframeDialog.iframe }}
                    ( 新窗口打开 )
                    <el-icon>
                        <icon-jump></icon-jump>
                    </el-icon>
                </el-link>
            </div>
        </template>

        <iframe class="code-iframe-wrap" :src="iframeDialog.iframe"></iframe>
    </el-dialog>

    <el-dialog
        v-if="detailDialog.visible"
        v-model="detailDialog.visible"
        :title="detailDialog.title"
        width="900px"
    >
        <div style="height: 400px;">
            <db-structure :g="g" :table-name="detailDialog.table_name" show-detail ></db-structure>
        </div>
    </el-dialog>
</div>
`

export default {
    props: {
        g: { type: Object, required: true }
    },
    data() {
        return {
            searchVal: '',
            cols: [
                { id: 'table_name', name: '表名', align: 'left', showBackground: true, searchable: true },
                { id: 'table_desc', name: '说明', align: 'left', searchable: true },
                { id: 'field_list', name: '主键', align: 'left' },
            ],
            actions: [
                { id: 'reconstruction', name: '重建表'   },
                { id: 'view'          , name: '表结构'   },
            ],
            iframeDialog: {
                visible: false,
                iframe : '',
                title  : '',
                width  : '700px',
            },
            detailDialog: {
                visible: false,
                table_name: '',
                title: ''
            }
        }
    },
    computed: {
        rows$() {
            return this.g.app_daos.map(item => {
                return {
                    ...item,
                    field_list: item.field_list.filter(item => item.pk),
                }
            })
        },
    },
    methods: {
        // 升级表结构
        handleUpdateDaos() {
            const dialog   = this.iframeDialog
            dialog.title   = '升级表结构'
            dialog.iframe  = `${ $utils.getOrigin() }/${ this.g.app_name }/initdaos`
            dialog.visible = true
        },
        // 重新建表
        handleReconstruction({ row }) {
            const dialog   = this.iframeDialog
            dialog.title   = '重新建表'
            dialog.iframe  = `${ $utils.getOrigin() }/${ this.g.app_name }/initdao?name=${ row.table_name }&init`
            dialog.visible = true
        },
        // 删除表
        async handleDel({ row }) {
            $utils.showAlert('正在开发中...', { confirmButtonText: '我知道了' })
            // const message = `是否删除当前表: ${ row.table_name }`
            // const confirm = await $utils.showConfirm(message)
            // if ( !confirm ) return
        },
        // 查看结构
        handleView({ row }) {
            const dialog      = this.detailDialog
            dialog.table_name = row.table_name
            dialog.title      = `查看表结构 - ${ row.table_name }`
            dialog.visible    = true
        },
    },
    template
}

