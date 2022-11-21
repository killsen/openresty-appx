
var g = {
        total_conn  : 0             // 总连接数
    ,   total_traf  : 0             // 总流量数
    ,   total_reqs  : 0             // 总请求数
    ,   sync_count  : 0             // 同步次数
    ,   sync_time   : new Date()    // 同步时间

    ,   is_started  : false         // 是否启动
    ,   servers     : []
    ,   total       : {}

    ,   server_time : ""
    ,   connections : ""

};

var ws, timerId;
var url  = (location.protocol == "https:" ? "wss://" : "ws://")
         +  location.hostname + location.pathname + location.search;

show_data();
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

    ws.onopen = function(e) {
        g.is_started = true; // 已启动
        ws.send("start");
    };

    ws.onmessage = function(e) {
        my_data = JSON.parse(e.data);
        show_data();
        ws && ws.readyState==1 && ws.send("next");
    };

}

function close_ws(){

    g.is_started = false; // 已关闭

    timerId && clearInterval(timerId);
    timerId = null;

    ws && ws.readyState==1 && ws.close();
    ws = null;

}

function update_data(t){

    t["reads"  ] = get_bytes(t["read"  ]);
    t["writes" ] = get_bytes(t["write" ]);

    t["count"  ] = t["1xx"] + t["2xx"] + t["3xx"] + t["4xx"] + t["5xx"];
    t["success"] = t["1xx"] + t["2xx"] + t["3xx"];

    t["success"] = _percent(t["success"], t["count"  ]);
    t["times"  ] = _avgtime(t.time, t.count);

}

function update_servers(servers){

    if (!servers || !servers.forEach) return;

    g.total_traf = 0;
    g.total_reqs = 0;

    g.total = {
        "read"  : 0,
        "write" : 0,
        "time"  : 0,

        "1xx"   : 0,
        "2xx"   : 0,
        "3xx"   : 0,
        "4xx"   : 0,
        "5xx"   : 0,
    }

    servers.forEach(function(t){

        g.total.read   += t.read;
        g.total.write  += t.write;
        g.total.time   += t.time;

        g.total["1xx"] += t["1xx"];
        g.total["2xx"] += t["2xx"];
        g.total["3xx"] += t["3xx"];
        g.total["4xx"] += t["4xx"];
        g.total["5xx"] += t["5xx"];

        update_data(t)

        g.total_traf += t.read + t.write;
        g.total_reqs += t.count;

        for (var k in t) {
            t[k] = t[k] || "-";
        }
    });

    update_data(g.total)

    for (var k in g.total) {
        g.total[k] = g.total[k] || "-";
    }

    g.servers = servers;

}

function show_data(){

    var d = my_data;

    var time = d["local_time"] - d["start_time"];
    g["server_time"] = _time(time);

    g["connections"] = ( d["conn_reading"]
                       + d["conn_writing"] )
                       + " / "
                       + d["conn_active" ] ;

    g.total_conn = d["conn_active"];

    update_servers(d.servers);

    g.sync_count ++;                // 同步次数
    g.sync_time  = new Date();      // 同步时间

    for (var k in d) {
        d[k] = d[k] || "-";
    }

}


function _percent(num, total) {
    num   = parseFloat(num)   || 0;
    total = parseFloat(total) || 0;
    if (!total) return "-";
    return Math.round(num / total * 10000) / 100.00 + "%";
}

function _time(n) {

    n = n && parseInt(n) || 0;
    if (!n) return " - ";

    var dd = parseInt(60*60*24);
    var mm = parseInt(60*60);
    var ss = parseInt(60);

    var t = "";

    if (n>=dd) {
        t += parseInt(n / dd) + " 天 ";
        n  = n % dd
    }

    if (n>=60*60) {
        t += parseInt(n / mm) + " 小时 ";
        n  = n % mm
    }

    if (n>=ss) {
        t += parseInt(n / ss) + " 分钟 ";
        n  = n % ss
    }

    if (n>0) {
        t += n + " 秒 ";
    }

    return t;


}

function _avgtime(num, total) {
    num   = parseFloat(num)   || 0;
    total = parseFloat(total) || 0;
    if (!total) return "-";
    return Math.round(num / total * 1000) + " ms";
}

function get_bytes(b) {

    if (!b) return "-";

    if (b<1024) return b.toFixed(0) + " B";

    b = b / 1024
    if (b<1024) return b.toFixed(1) + " KB";

    b = b / 1024
    if (b<1024) return b.toFixed(2) + " MB";

    b = b / 1024
    return b.toFixed(3) + " GB";

}

function _reset(){

    this.$confirm('确定要重置监控数据吗?', '提示', {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
    }).then(() => {
        ws && ws.readyState==1 && ws.send("reset");
    });

}

new Vue({
  el: '#app',
  data: { g },
  methods: { start_ws, close_ws, _reset }
})
