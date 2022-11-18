/**
 * 应用布局组件
 * v22.11.16
 */
import $utils from '../utils/index.js'      // 工具函数

const template = `
<div class="layout">

    <div class="layout-header">
        <div class="layout-header__logo">
            <el-icon :size="16">
                <icon-app></icon-app>
            </el-icon>
            <span style="font-size: 16px; font-weight: bold;" v-cloak>{{ g.app_title }}</span>
        </div>
        <span style="margin: 0 5px;">当前版本:</span>
            <el-tag type="primary" disable-transitions  v-cloak>{{ g.app_ver }}</el-tag>
        <div class="layout-header__right">
            <el-button text @click="handleReload">
                <template #icon>
                    <el-icon>
                        <icon-refresh></icon-refresh>
                    </el-icon>
                </template>
                重载模块
            </el-button>
            <template v-for="item in g.help_config.links">
                <el-button text @click="handleLinkClick(item)">
                    {{ item.text }}
                    <icon-jump></icon-jump>
                </el-button>
            </template>
        </div>
    </div>

    <div class="layout-aside">
        <template v-for="item in navs" :key="item.id">
            <a  class="nav-item"
                :class="{ 'is-active': item.id === curr_nav }"
                :href="'#' + item.id"
                @click="curr_nav = item.id"
            >
                <el-icon>
                    <icon-menu-intro v-if="item.icon === 'icon-menu-intro'"></icon-menu-intro>
                    <icon-menu-api   v-if="item.icon === 'icon-menu-api'"  ></icon-menu-api>
                    <icon-menu-act   v-if="item.icon === 'icon-menu-act'"  ></icon-menu-act>
                    <icon-menu-db    v-if="item.icon === 'icon-menu-db'"   ></icon-menu-db>
                </el-icon>
                <span>
                    {{ item.name }}
                </span>
            </a>
        </template>
    </div>

    <div class="layout-main">
        <!-- 项目介绍 -->
        <app-intro v-if="curr_nav === 'app-intro'" :g="g"></app-intro>
        <!-- API 接口管理 -->
        <api-manage v-if="curr_nav === 'api-manage'" :g="g"></api-manage>
        <!-- ACT 接口管理 -->
        <act-manage v-if="curr_nav === 'act-manage'" :g="g"></act-manage>
        <!-- 数据库管理 -->
        <db-manage v-if="curr_nav === 'db-manage'" :g="g"></db-manage>
        <!-- 数据库结构 -->
        <db-structure v-if="curr_nav === 'db-structure'" :g="g"></db-structure>
    </div>

    <el-dialog v-if="g.visible_reload_dialog" v-model="g.visible_reload_dialog" title="应用重载">
        <iframe src="./reload" class="code-iframe-wrap"></iframe>
    </el-dialog>
</div>
`


export default {
    data() {
        const G           = window.G      || {}
        const help_config = G.help_config || {}

        // 左侧导航菜单
        const navs = [
            { id: 'app-intro'   , name: '项目介绍'  , icon: 'icon-menu-intro', show: !!G.help_html },
            { id: 'api-manage'  , name: 'API 接口'  , icon: 'icon-menu-api'   },
            { id: 'act-manage'  , name: 'ACT 接口'  , icon: 'icon-menu-act'   },
            { id: 'db-manage'   , name: '数据库管理', icon: 'icon-menu-db'    },
            { id: 'db-structure', name: '数据库结构', icon: 'icon-menu-db'    },
        ].filter(item => item.show !== false)

        // 初始化链接配置、过滤为空的配置
        const links = (Array.isArray(help_config.links) ? help_config.links : []).filter(item => {
            if (Array.isArray(item) && item[0] && item[1]) return true // 数组配置 [text, link]
            if ('text' in item && 'link' in item         ) return true // 对象配置 { text: '', link: '' }
            return false
        }).map(item => {
            return Array.isArray(item) ? { text: item[0], link: item[1] } : item
        })

        return {
            // 注入数据
            g: {
                app_name   : G.app_name  || '',
                app_title  : G.app_title || '',
                app_ver    : G.app_ver   || '',
                app_apis   : Array.isArray(G.app_apis) ? G.app_apis : [],
                app_acts   : Array.isArray(G.app_acts) ? G.app_acts : [],
                app_daos   : Array.isArray(G.app_daos) ? G.app_daos : [],
                app_daox   : null,
                app_intro  : G.help_html || '', // 项目介绍内容
                help_config: { ...help_config, links },
            },

            // 程序数据
            navs                 ,
            curr_nav             : location.hash.replace(/^#/, '') || navs[0].id, // 当前导航菜单
            visible_reload_dialog: false, // 应用重载弹窗
        }
    },
    methods: {
        // 模块重载
        async handleReload() {
            const confirm = await $utils.showConfirm('是否重载模块')
            if ( !confirm ) return

            this.g.visible_reload_dialog = true
        },

        // 跳转链接
        handleLinkClick(item) {
            window.open(item.link, '_blank')
        },
    },
    template
}
