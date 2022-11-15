/**
 * 搜索组件：默认 300ms 节流处理，并展示输入 Loading
 * v22.11.13
 */

const template = `
<el-input
    v-model="internalValue"
    :disabled="disabled"
    :placeholder="placeholder"
    class="app-search"
    clearable
    @input="handleInput"
>
    <template #prefix>
        <el-icon :class="{ 'is-loading': loading }">
            <icon-loading v-if="loading"></icon-loading>
            <icon-search v-else></icon-search>
        </el-icon>
    </template>
</el-input>
`

export default {
    props: {
        modelValue : { type: String, defalut: '' },
        placeholder: { type: String, default: '快速搜索...' },
        disabled   : { type: Boolean, default: false }
    },
    data() {
        this.timer = null
        return {
            internalValue: this.modelValue,
            loading: false,
        }
    },
    watch: {
        modelValue(val) {
            this.internalValue = val
        }
    },
    methods: {
        handleInput(value) {
            this.$emit('update:modelValue', value)

            this.loading = true
            clearTimeout(this.timer)
            this.timer = setTimeout(() => {
                this.loading = false
                this.$emit('change', value)
            }, 300);
        }
    },
    unmounted() {
        this.timer && clearTimeout(this.timer)
    },
    template
}
