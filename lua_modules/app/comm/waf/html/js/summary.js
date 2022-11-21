
var g = {
        my_head     : my_head.split("\t")
    ,   my_data     : []
    ,   log_type    : log_type.toLowerCase()

    ,   page_index  : 1
    ,   page_total  : 0
    ,   page_size   : 100

    ,   loading     : true
};

var mData = {}
    mData.url = [];
    mData.ip  = [];

function $rows(){

    var offset = (g.page_index - 1) * g.page_size;

    return (offset + g.page_size >= g.my_data.length)
        && g.my_data.slice(offset, g.my_data.length)
        || g.my_data.slice(offset, offset + g.page_size);

}

var ws;

         _load();
function _load(){

    g.my_data    = mData[g.log_type];
    g.page_total = g.my_data.length;

    var url  = (location.protocol == "https:" ? "wss://" : "ws://")
             +  location.hostname + location.pathname
             +  "?log=" + g.log_type;

    ws && ws.readyState==1 && ws.close();
    ws = new WebSocket(url);

    ws.onopen = function(e){
        g.my_data.splice(0);
    }

    ws.onclose = function(e){
        g.my_data.sort((d1,d2)=>{
            return (d1.url>d2.url && 1) || (d1.url<d2.url && -1) || 0
        });
    }

    ws.onmessage = function(e) {

        if (!e.data) return;

        var rows = e.data.split("\n");

        rows.forEach(load_data);

        g.page_total = g.my_data.length;

    };

}

function load_data(row){

    if (!row) return;

    var d = {};
    var cols = row.split("\t");

    g.my_head.forEach( (k,i)=>{
        d[k] = cols[i] || 0;
        if(i>0) d[k] = parseFloat(d[k]);
    });

    d.reads  = get_bytes(d.read);
    d.writes = get_bytes(d.write);

    d.success = d["1xx"]  + d["2xx"] + d["3xx"]
    d.count   = d.success + d["4xx"] + d["5xx"]

    d.success = _percent(d.success, d.count);
    d.time    = _avgtime(d.time   , d.count);

    g.my_data.push(d);

}

function _percent(num, total) {
    num   = parseFloat(num)   || 0;
    total = parseFloat(total) || 0;
    if (!total) return "-";
    return Math.round(num / total * 10000) / 100.00 + "%";
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

new Vue({
        el          : '#app'
    ,   data        : { g       }
    ,   computed    : { $rows   }
    ,   methods     : { _load   }
})
