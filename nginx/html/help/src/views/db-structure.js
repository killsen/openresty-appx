/**
 * 数据库结构
 * v22.11.13
 */
 const template = `
<div class="container is-horizontal">
    <app-type-list
        v-if="!showDetail"
        class="container-left"
        v-model="curr_table"
        :data="g.app_daos"
        :props="{
            id      : 'table_name',
            title   : 'table_name',
            subTitle: 'table_desc',
        }"
    ></app-type-list>

    <div :class="!showDetail ? 'container-right container-main' : ''">
        <app-table
            :cols="cols$"
            :rows="rows$"
            :actions="actions"
            :show-footer="false"
        >
            <template #header-left>
                <el-radio-group v-model="curr_mode">
                    <el-radio-button label="field">表结构</el-radio-button>
                    <el-radio-button label="index">表索引</el-radio-button>
                </el-radio-group>
            </template>

            <template #pk="{ cellValue }">
                <el-tag v-if="cellValue" disable-transitions>
                    是
                </el-tag>
                <template v-else> - </template>
            </template>

            <template #column_info="{ cellValue }">
                <template v-for="(text, idx) in cellValue" :key="text">
                    {{ text }}
                    <el-divider v-if="idx < cellValue.length - 1" direction="vertical"></el-divider>
                </template>
            </template>
        </app-table>
    </div>
</div>
`

export default {
    props: {
        g         : { type: Object, required: true  },
        showDetail: { type: Boolean, default: false }, // 详情模式
        tableName : { type: String , default: ''    },
    },
    data() {
        const app_daos   = this.g.app_daos
        const app_daox   = this.initDaox(app_daos)
        const table_name = this.tableName || app_daos[0]?.table_name || ''
        const curr_table = app_daox[table_name]
        return {
            serach: '',
            curr_table,
            app_daox  ,
            curr_mode : 'field',
        }
    },
    computed: {
        cols$() {
            if (this.curr_mode === 'field') {
                return [
                    { id: 'name' , name: '列名'   , align: 'left', showBackground: true, searchable: true },
                    { id: 'desc' , name: '说明'   , align: 'left', showBackground: true, searchable: true },
                    { id: 'type' , name: '类型'   , width: '120px' },
                    { id: 'len'  , name: '长度'   , width: '120px', formatter: 'formatEmpty' },
                    { id: 'pk'   , name: '主键'   , width: '120px' },
                    { id: 'def'  , name: '默认值' , width: '150px', formatter: 'formatEmpty' },
                ]
            } else {
                return [
                    { id: 'name'       , name: '名称'    , align: 'left', width: '180px', showBackground: true, searchable: true },
                    { id: 'column_info', name: '索引列'  , align: 'left' },
                    { id: '_index_type', name: '索引类型', width: '120px' },
                    { id: '_index_mode', name: '索引方式', width: '120px' },
                ]
            }
        },
        rows$() {
            if (this.curr_mode === 'field') {
                return this.curr_table?.field_list || []
            } else {
                const list        = []
                const table_index = this.curr_table?.table_index || {}
                Object.keys(table_index).forEach(key => {
                    list.push({
                        name       : key,
                        column_info: table_index[key] || [],
                        _index_type: 'Normal',
                        _index_mode: 'BTREE'
                    })
                })
                return list
            }
        }
    },
    methods: {
        // 初始化数据库表映射
        initDaox(daos) {
            if (this.g.daox) return this.g.daox

            const map = {}
            daos.forEach(item => {
                map[item.table_name] = item
            })

            this.g.daox = map
            return map
        }
    },
    template
}

