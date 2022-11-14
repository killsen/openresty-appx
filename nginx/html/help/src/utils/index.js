
import * as Notice from './notice.js'

// 获取域名源
function getOrigin() {
    return `${ location.protocol }//${ location.hostname }`
}

const Utils = window.$utils = {
    getOrigin,
    ...Notice
}

export default Utils
