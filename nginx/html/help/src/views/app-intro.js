/**
 * 项目介绍页
 * v22.11.16
 */

const template = `
<div class="container container-main">
    <el-scrollbar style="height: 100%">
        <div v-html="g.app_intro"></div>
    </el-scrollbar>
</div>
`

export default {
    props: {
        g: { type: Object, required: true }
    },
    template
}
