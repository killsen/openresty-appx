/**
 * 类型列表容器
 * v22.11.16
 */
//  <el-input
//  v-model="search"
//  placeholder="搜索表..."
//  prefix-icon="icon-search"
// ></el-input>

const template = `
<div class="app-type-list">
    <div v-if="showHeader" class="app-type-list-header">
        <app-search
            placeholder="搜索表..."
            @change="onSearchChange"
        ></app-search>
        <span class="app-type-list-header__len">共 {{ data.length }} 项</span>
    </div>
    <div class="app-type-list-body">
        <el-scrollbar style="height: 100%">
            <template v-if="data$.length">
                <template v-for="item in data$">
                    <div class="app-type-list__item"
                        :class="{ 'is-active': internalValue$ && internalValue$[props.id] === item[props.id] }"
                        @click="handleItemClick(item)"
                    >
                        <span>{{ item[props.title] }}</span>
                        <span v-if="item[props.subTitle]">{{ item[props.subTitle] }}</span>
                    </div>
                </template>
                <div style="height: 50px;"></div>
            </template>
            <el-empty v-else :description="emptyDescription$"></el-empty>
        </el-scrollbar>
    </div>
    <div v-if="showFooter" class="app-type-list-footer">
        共 {{ data.length }} 项
    </div>
</div>
`

export default {
    name: 'app-type-list',
    props: {
        modelValue: { type: Object , default: null },
        data      : { type: Array  , default: () => [] },
        showHeader: { type: Boolean, default: true },
        showFooter: { type: Boolean, default: false },
        emptyText : { type: String , default: '暂无数据' },
        props: {
            type: Object,
            default: () => {
                return {
                    id      : 'id',
                    title   : 'title',
                    subTitle: 'subTitle',
                }
            }
        }
    },
    data() {
        return {
            searchVal: '',
            curr_item: this.modelValue,
        }
    },
    computed: {
        data$() {
            const searchVals = this.searchVal.split(' ').filter(val => !!val)
            if ( !searchVals.length ) return this.data

            const props = this.props
            const data  = this.data || []
            return data.filter(item => {
                return searchVals.every(val => {
                    const title    = item[props.title] || ''
                    const subTitle = item[props.subTitle] || ''
                    return title.includes(val) || subTitle.includes(val)
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

        // 内部激活值
        internalValue$: {
            get() {
                return this.modelValue
            },
            set(val) {
                this.$emit('update:modelValue', val)
            }
        }
    },
    created() {
        if (!this.modelValue && this.data.length) {
            this.internalValue$ = this.data[0]
        }
    },
    methods: {
        handleItemClick(item) {
            this.internalValue$ = item
        },

        onSearchChange(value) {
            this.searchVal = value.trim()
        }
    },
    template,
}
