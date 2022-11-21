
var g = {
        sync_count  : 0             // 同步次数
    ,   sync_time   : new Date()    // 同步时间
    ,   is_started  : false         // 是否启动
    ,   is_paused   : false
    ,   max_id      : 0
    ,   my_head     : my_head
    ,   my_data     : []
    ,   all_data    : []
    ,   ip_list     : []
    ,   request     : ""
    ,   request_input : ""
    ,   server_ip   : server_ip
    ,   server_port : server_port
};

var ws, timerId;
var url  = (location.protocol == "https:" ? "wss://" : "ws://")
         +  location.hostname + location.pathname + location.search;

start_ws();

function start_ws(){

    // 监控 WebSocket
    timerId && clearInterval(timerId);
    timerId = setInterval(function(){
        var now = new Date();
        if (now - g.sync_time > 3000){
            start_ws();  // 超过3秒没有同步数据：重启
        }
    }, 1000);

    // 创建 WebSocket
    ws && ws.readyState==1 && ws.close();
    ws = new WebSocket(url);

    g.is_started = true;  // 已启动
    g.is_paused  = false; // 已继续

    ws.onopen = function(e) {
        g.max_id  = 0;
        ws.send("start");
    };

    ws.onmessage = function(e) {

        g.sync_time  = new Date();
        g.sync_count ++ ;

        if(g.max_id==0) g.my_data=[];
        show_data(e.data);

        ws && ws.readyState==1 && ws.send("next");
    };

}

function close_ws(){

    g.is_started = false; // 已关闭
    g.is_paused  = false; // 已继续

    timerId && clearInterval(timerId);
    timerId = null;

    ws && ws.readyState==1 && ws.close();
    ws = null;

}

function show_data(data){

    if (!data) return;

    var rows = data.split("\n");

    for(var i=0; i<rows.length; i++) {

        var d = load_data(rows[i]);
        if(!d) continue;

        if (g.max_id >= d.id) continue;
            g.max_id  = d.id;

        g.all_data.unshift(d);
        if (g.all_data.length>1000){
            g.all_data.splice(1000);
        }

        if(g.is_paused || !_filter(d)) continue;

        g.my_data.unshift(d);
        if (g.my_data.length>100){
            g.my_data.splice(100);
        }
    }

}

function load_data(row){

    if (!row) return;

    var d = {};
    var cols = row.split("\t");

    g.my_head.forEach( (k,i)=>{
        d[k] = cols[i] || "";
    });

    if (g.server_ip && g.server_port) {
        if (d.server_ip != g.server_ip || d.server_port != g.server_port) return;
    }

    d.id = parseInt(cols[0]);
    d.ip = d.remote_addr;

    d.status = parseInt(d.status);

    d.request_length  = get_bytes(d.request_length);
    d.body_bytes_sent = get_bytes(d.body_bytes_sent);

    if (d.server_port == 80){
        d.server_name = d.server_ip;
    }else{
        d.server_name = d.server_ip + ":" + d.server_port;
    }

    return d

}

function get_bytes(b) {

    if (!b) return "-";

    b = parseInt(b);

    if (b<1024) return b.toFixed(0) + " B";

    b = b / 1024
    if (b<1024) return b.toFixed(1) + " KB";

    b = b / 1024
    if (b<1024) return b.toFixed(2) + " MB";

    b = b / 1024
    return b.toFixed(3) + " GB";

}

function add_ip(ip){

    if(!ip) return;

    for (var i=g.ip_list.length-1; i>=0; i--) {
        if (g.ip_list[i] == ip) {
            g.ip_list.splice(i, 1);
            _filterData();
            return;
        }
    }

    g.ip_list.push(ip);
    _filterData();

}

function _filter(d){
    return _filter_ip(d)
        && _filter_request(d);
}

function _filter_request(d){
    if (!g.request) return true;
    return d.request.search(g.request) > -1;
}

function _filter_ip(d){
    if (!g.ip_list.length) return true;
    for (var i=0; i<g.ip_list.length; i++) {
        if (d.ip == g.ip_list[i]) return true;
    }
    return false;
}

function _filterData(){

    g.request = g.request_input.trim();

    var list = [];

    for (var i=0; i<g.all_data.length; i++){
        var d = g.all_data[i];
        if(!_filter(d)) continue;
        list.push(d);
        if(list.length==100) break;
    }

    g.my_data = list;

}

function _filterClear(){
    g.request_input = "";
    _filterData();
}

function _pause(){
    g.is_paused = true;
    _filterData();
}

function _resume(){
    g.is_paused = false;
    _filterData();
}

new Vue({
        el      : '#app'
    ,   data    : { g }
    ,   methods : {
                start_ws, close_ws
            ,   _pause, _resume
            ,   _filterData, _filterClear
            ,   add_ip
        }
});
