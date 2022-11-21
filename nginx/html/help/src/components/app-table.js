/**
 * 表格组件
 * v22.11.13
 */

const template = `
<div class="app-table">
    <div v-if="showTools" class="app-table-tools">
        <div>
            <slot name="header-left"></slot>
            <span style="margin-left: 8px;">
                (共 {{ rows$.length }} 项)
            </span>
        </div>
        <div>
            <slot name="header-search-left"></slot>
            <app-search
                :placeholder="placeholder"
                :disabled="!searchColIds$.length"
                style="width: 300px"
                @change="onSearchChange"
            ></app-search>
            <slot name="header-search-right"></slot>
        </div>
    </div>
    <div v-if="showHeader" class="app-table-header">
        <table cellspacing="0" cellpadding="0" border="0" style="width: 100%">
            <thead>
                <tr class="app-table-header__row">
                    <template v-for="c in internalCols" :key="c.id">
                        <th class="app-table-header__col" :style="[{ width: c.width, minWidth: c.minWidth }]">
                            <div class="app-table-cell"
                                :class="{ ['is-' + c.align]: true }"
                            >
                                {{ c.name }}
                            </div>
                        </th>
                    </template>

                    <th v-if="actions.length" class="app-table-header__col" :style="{ width: actionsWidth }">
                        <div class="app-table-cell is-center">
                            操作
                        </div>
                    </th>
                </tr>
            </thead>
        </table>
    </div>
    <div class="app-table-body">
        <el-scrollbar v-if="rows$.length" max-height="100%" ref="scrollRef">
            <table cellspacing="0" cellpadding="0" border="0" style="width: 100%">
                <tbody>
                    <tr class="app-table-body__row"  v-for="(r, rIdx) in rows$" :key="rIdx">
                        <template v-for="c in internalCols" :key="c.id">
                            <td class="app-table-body__col"
                                :class="{ ['app-table-body__col--background']: c.showBackground }"
                                :style="[{ width: c.width, minWidth: c.minWidth }]"
                            >
                                <div class="app-table-cell" :class="{ ['is-' + c.align]: true  }">
                                    <template v-if="c.render">
                                        <component :is="c.render" v-bind="{ row: r, col: c, cellValue: r[c.id]  }"></component>
                                    </template>
                                    <template v-else-if="c.type === 'demo'">
                                        <el-link type="primary" v-if="r[c.id]" :href="r[c.id]" target="_bank">
                                            <span>演示</span>
                                            <el-icon>
                                                <icon-jump></icon-jump>
                                            </el-icon>
                                        </el-link>
                                    </template>
                                    <template v-else-if="c.link">
                                        <el-link type="primary" v-if="r[c.link]" :href="r[c.link]" target="_bank">
                                            <span>{{ r[c.id] }}</span>
                                            <el-icon>
                                                <icon-jump></icon-jump>
                                            </el-icon>
                                        </el-link>
                                        <template v-else>{{ r[c.id] }}</template>
                                    </template>
                                    <template v-else-if="$slots[c.id]">
                                        <component :is="$slots[c.id]" v-bind="{ row: r, col: c, cellValue: r[c.id]  }"></component>
                                    </template>
                                    <template v-else>
                                        {{
                                            c.formatter
                                                ? c.formatter({ row: r, col: c, cellValue: r[c.id] })
                                                : r[c.id]
                                        }}
                                    </template>
                                </div>
                            </td>
                        </template>

                        <td v-if="actions.length" class="app-table-body__col" :style="{ width: actionsWidth }">
                            <div class="app-table-cell is-center">
                                <template v-for="item in actions" :key="item.id">
                                    <span
                                        class="app-table-action-item"
                                        text
                                        type="primary"
                                        @click="handleActionClick(item, r, c)"
                                    >
                                        {{ item.name }}
                                    </span>
                                </template>
                            </div>
                        </td>
                    </tr>
                </tbody>
            </table>
        </el-scrollbar>
        <el-empty v-else :description="emptyDescription$" style="height: 100%;"></el-empty>
    </div>
    <div v-if="showFooter" class="app-table-footer">
        共 {{ rows$.length }} 项
    </div>
</div>
`

/**
 * inteface cols {
 *      id            : string   列 Id
 *      name          : string   列 名称
 *      showBackground: boolean  当前列是否显示背景色
 *      align         : 'left' | 'center' | 'right' 内容排版
 *      width        ?: String
 *      minWidth     ?: String
 *      searchable   ?: boolean  是否可搜索
 *      type         ?: 'link' | 'demo'
 *      link         ?: string
 *      formatter    ?: string | ({ row, col }) => string
 *      render       ?: ({ row, col }) => VNode | VNode[] | string
 * }
 */

// 格式化函数配置
const FORMAT_CONIFG = {
    formatEmpty  : ({ cellValue }) => cellValue ? cellValue : '-',
    formatVersion: ({ cellValue }) => {
        if (!cellValue) return '-'
        return cellValue.startsWith('v') ? cellValue : `v${ cellValue }`
    },
}

function getFormatter(formatter) {
    if (typeof formatter === 'function') return formatter
    if (typeof formatter === 'string'  ) return FORMAT_CONIFG[formatter]
    return undefined
}

export default {
    name: 'app-table',
    props: {
        cols        : { type: Array, default: () => [] },
        rows        : { type: Array, default: () => [] },
        actions     : { type: Array, default: () => [] },
        actionsWidth: { type: String  },
        placeholder : { type: String, default: '快速搜索...' },
        emptyText   : { type: String, default: '暂无数据'    },
        showTools   : { type: Boolean, default: true  },
        showHeader  : { type: Boolean, default: true  },
        showFooter  : { type: Boolean, default: false },
    },
    data() {
        return {
            hasScroll   : false, // 监听当前的内容是否超出容器，最后一行是否补充下边框线
            searchVal   : ''   , // 检索值
            internalCols: []   , // 内部初始化后的列配置
        }
    },
    computed: {
        // 取得可检索的列编码
        searchColIds$() {
            return this.cols.filter(c => !!c.searchable).map(c => c.id)
        },

        // 支持列表过滤
        rows$() {
            const ids = this.searchColIds$
            if ( !ids.length ) return this.rows

            const searchVals = this.searchVal.split(' ').filter(val => !!val)
            if ( !searchVals.length ) return this.rows

            return this.rows.filter(item => {
                return searchVals.every(val => {
                    return ids.some(id => {
                        return `${ item[id] }`.includes(val)
                    })
                })
            })
        },

        // 为空提示
        emptyDescription$() {
            if (!this.searchVal) {
                return this.emptyText
            } else {
                return '抱歉，未搜索到相关数据！'
            }
        },
    },

    watch: {
        // 监听列配置，重新初始化列
        cols(value) {
            this.initColumns(value)
        },

        rows$() {
            this.scrollToTop()
        }
    },

    created() {
        this.initColumns(this.cols)
    },

    methods: {
        // 处理操作点击
        handleActionClick(item, row, col) {
            this.$emit(item.id, { row, col })
            this.$emit('action-click', { item, row, col })
        },

        // 搜索值变化
        onSearchChange(value) {
            this.searchVal = value.trim()
        },

        // 初始化列
        initColumns(cols) {
            this.internalCols = cols.map(c => {
                return {
                    id            : c.id,
                    name          : c.name,
                    showBackground: !!c.showBackground,
                    searchable    : !!c.searchable,
                    align         : c.align || 'center',
                    width         : c.width,
                    minWidth      : c.minWidth,
                    type          : c.type || 'string',
                    link          : c.link || '',
                    formatter     : getFormatter(c.formatter),
                    render        : typeof c.render === 'function' ? c.render : undefined,
                }
            })
        },

        scrollToTop() {
            this.$nextTick(() => {
                const $scroll = this.$refs.scrollRef
                if ( !$scroll ) return

                $scroll.scrollTo(0, 0)
            })
        }
    },
    template,
}

