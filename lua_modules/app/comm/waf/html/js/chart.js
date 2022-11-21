
Highcharts.setOptions({
    global: {
        useUTC: false
    }
});


var reset_conn = false;
//---------------------------------------------
initChart('chart-conn', '在线连接数', function(){

    var now = new Date();
    var val = g.total_conn;

    if (now - g.sync_time > 1000 || !g.is_started) {
        val = -1; reset_conn = true;  // 超过1秒没有同步数据
    }else if(reset_conn) {
        val = -1; reset_conn = false;
    }

    return val;

});

var reset_traf = false;
var  last_traf = g.total_traf;
//---------------------------------------------
initChart('chart-traf', '流量监控', function(){

    var now = new Date();
    var val = g.total_traf - last_traf;

        last_traf = g.total_traf;

    if (now - g.sync_time > 1000 || !g.is_started) {
        val = -1; reset_traf = true;  // 超过1秒没有同步数据
    }else if(reset_traf) {
        val = -1; reset_traf = false;
    }

    return val;

});

var reset_reqs = false;
var  last_reqs = g.total_reqs;
//---------------------------------------------
initChart('chart-qps', 'QPS', function(){

    var now = new Date();
    var val = g.total_reqs - last_reqs;

        last_reqs = g.total_reqs;

    if (now - g.sync_time > 1000 || !g.is_started) {
        val = -1; reset_reqs = true;  // 超过1秒没有同步数据
    }else if(reset_reqs) {
        val = -1; reset_reqs = false;
    }

    return val;

});


function initChart(id, title, getData) {

    var chart = Highcharts.chart(id, {

        title   : { text   : title    },
        credits : { enabled: false    },
        legend  : { enabled: false    },

        chart: {
            type: 'spline',
            marginRight: 10,
            events: {
                load: function () {
                    var series = this.series[0],
                        chart = this;

                    setInterval(function () {

                        var x = (new Date()).getTime(), // 当前时间
                            y = getData() || 0;
                        if (y>=0) series.addPoint([x, y], true, true);

                    }, 1000);
                }
            }
        },
        xAxis: {
            type: 'datetime',
            tickPixelInterval: 150
        },
        yAxis: {
            title: {
                text: null
            }
        },
        tooltip: {
            formatter: function () {
                return '<b>' + this.series.name + '：' +
                    Highcharts.numberFormat(this.y, 0) + '</b><br/>' +
                    Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) ;
            }
        },
        series: [{
            name: title,
            marker:{ enabled:false }, //去掉节点
            data: (function () {
                // 生成随机值
                var data = [];
                var time = (new Date()).getTime();
                for (var i = -60; i <= 0; i++) {
                    data.push({
                        x: time + i * 1000,
                        y: 0
                    });
                }
                return data;
            }())
        }]
    });

}
