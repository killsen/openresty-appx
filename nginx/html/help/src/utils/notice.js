/**
 * ElementPlus 界面交互
 * v22.11.14
 * https://element-plus.gitee.io/zh-CN/component/message-box.html
 *
 * Tip: element-plus 默认使用英文语言包，中文使用不多因此自定义部分文字替换
 */

const ElMessageBox = ElementPlus.ElMessageBox
const ElLoading    = ElementPlus.ElLoading
const ElMessage    = ElementPlus.ElMessage

const TITLE  = '提示'
const CONFIG = {
    confirmButtonText: '确认',
    cancelButtonText : '取消',
    type: 'warning'
}

// 成功提示
export function successMsg(message) {
    if (!message) return
    ElMessage.success(typeof message === 'string' ? { message } : message)
}

// 警告提示
export function warningMsg(message) {
    if (!message) return
    ElMessage.warning(typeof message === 'string' ? { message } : message)
}

// 错误提示
export function errorMsg(message) {
    if (!message) return
    ElMessage.error(typeof message === 'string' ? { message } : message)
}

// 显示提示框
export function showAlert(message, title = TITLE, options) {
    return new Promise((resolve) => {
        ElMessageBox.alert(message, title, { ...CONFIG, ...options })
            .then(() => { resolve(true) })
            .catch(() => { resolve(true) })
    })
}

// 显示确认框
export function showConfirm(message, title = TITLE, options) {
    return new Promise((resolve) => {
        ElMessageBox.confirm(message, title, { ...CONFIG, ...options })
            .then(() => { resolve(true) })
            .catch(() => { resolve(false) })
    })
}

// 显示 Loading
let $loading = null
export function showLoading(message = '加载中...', options) {
    const opt = options?.fullscreen
        ? options
        : {
                text      : message,
                background: 'transparent',
                spinner   : `
                    <path fill="currentColor" d="M512 64a32 32 0 0 1 32 32v192a32 32 0 0 1-64 0V96a32 32 0 0 1 32-32zm0 640a32 32 0 0 1 32 32v192a32 32 0 1 1-64 0V736a32 32 0 0 1 32-32zm448-192a32 32 0 0 1-32 32H736a32 32 0 1 1 0-64h192a32 32 0 0 1 32 32zm-640 0a32 32 0 0 1-32 32H96a32 32 0 0 1 0-64h192a32 32 0 0 1 32 32zM195.2 195.2a32 32 0 0 1 45.248 0L376.32 331.008a32 32 0 0 1-45.248 45.248L195.2 240.448a32 32 0 0 1 0-45.248zm452.544 452.544a32 32 0 0 1 45.248 0L828.8 783.552a32 32 0 0 1-45.248 45.248L647.744 692.992a32 32 0 0 1 0-45.248zM828.8 195.264a32 32 0 0 1 0 45.184L692.992 376.32a32 32 0 0 1-45.248-45.248l135.808-135.808a32 32 0 0 1 45.248 0zm-452.544 452.48a32 32 0 0 1 0 45.248L240.448 828.8a32 32 0 0 1-45.248-45.248l135.808-135.808a32 32 0 0 1 45.248 0z"></path>
                `,
                svgViewBox : '0 0 1024 1024',
                customClass: 'help-loading',
                ...options,
            }

    $loading = ElLoading.service(opt)
    return $loading
}

// 隐藏 loading
export function hideLoading() {
    $loading && $loading.close()
    $loading = null
}
