
return [=====[
<!DOCTYPE html>
<html>
    <head>
        <title>{{app_title}}</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=0">
        <style type="text/css">
            body {
                /* width: 65em;
                margin: 0 auto; */
                font-family: Tahoma, Verdana, Arial, sans-serif;
            }
            table {
                font-family: verdana,arial,sans-serif;
                font-size:11px;
                color:#333333;
                border-width: 1px;
                border-color: #666666;
                border-collapse: collapse;
            }
            table th {
                border-width: 1px;
                padding: 8px;
                border-style: solid;
                border-color: #666666;
                background-color: #dedede;
                text-align:left;
            }
            table td {
                border-width: 1px;
                padding: 8px;
                border-style: solid;
                border-color: #666666;
                background-color: #ffffff;
                text-align:left;
            }
            table tr:hover td {
                background: #DEDEDE;
            }
            * {
                margin: 0;
                padding: 0;
            }
            li {
                list-style: none;
            }
            html {
                overflow-y: hidden;
            }
            html, body {
                height: 100%;
            }
            body {
                overflow-y: auto;
                background-color: #f3f3f3;
            }
            .wrap {
                position: relative;
                width: 1200px;
                margin: 0 auto;
                height: 100%;
                padding: 100px 0 0;
            }
            .wrap-header {
                position: fixed;
                left: 0; right: 0; top:  0;
                z-index: 3;
                background-color: #fff;
                -webkit-box-shadow: 0 3px 10px 0 rgba(0,0,0,.2);
                box-shadow: 0 3px 10px 0 rgba(0,0,0,.2);
            }
            .wrap-header_content {
                display: flex;
                justify-content: space-between;
                align-items: center;
                width: 1200px;
                height: 70px;
                margin: 0 auto ;
            }
            .wrap-header_content-right > button {
                display: inline-block;
                line-height: 1;
                white-space: nowrap;
                cursor: pointer;
                background: #fff;
                border: 1px solid #dcdfe6;
                color: #606266;
                -webkit-appearance: none;
                text-align: center;
                box-sizing: border-box;
                outline: none;
                margin: 0;
                transition: .1s;
                font-weight: 500;
                -moz-user-select: none;
                -webkit-user-select: none;
                -ms-user-select: none;
                padding: 9px 15px;
                font-size: 12px;
                border-radius: 3px;
            }

            .wrap-header_content-right > button:hover {
                color: #409eff;
                border-color: #c6e2ff;
                background-color: #ecf5ff;
            }
            .wrap-content {
                margin-bottom: 100px;
            }

            #help > li {
                line-height: 24px;
                list-style-type: disc;
            }

            #dao, #detail {
                display: none;
            }

            .input-wrap {
                display: inline-block;
                width: 220px;
            }

            .input__inner {
                -webkit-appearance: none;
                background-color: #fff;
                background-image: none;
                border-radius: 4px;
                border: 1px solid #dcdfe6;
                box-sizing: border-box;
                color: #606266;
                display: inline-block;
                font-size: inherit;
                height: 32px;
                line-height: 32px;
                outline: none;
                padding: 0 15px;
                transition: border-color .2s cubic-bezier(.645,.045,.355,1);
                width: 100%;
                font-size: 13px;
            }
            .input__inner:focus {
                outline: none;
                border-color: #409eff;
            }

            .detail-wrap {
                display: flex;
            }
            .detail-left {
                flex:  1;
            }
            .detail-right {
                width: 200px;
            }

            #table {
                position: fixed;
                right:  100px; top: 90px; bottom: 20px;
                display: none;
                min-width: 200px;
                z-index: 2;
                padding: 10px 0;
                box-sizing: border-box;
                box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.1);
            }
            .table-wrap {
                height: 100%;
                overflow-y: auto;
            }
            .table-item {
                display: block;
                text-decoration: none;
                line-height: 40px;
                cursor: pointer;
                padding: 0 20px;
                color: #444;
            }
            .table-item:hover {
                background-color: rgba(0, 0, 0, 0.15);
            }

            ::-webkit-scrollbar {
                width: 7px;
                height: 7px;
                background-color: #F5F5F5;
            }
            ::-webkit-scrollbar-track {
                box-shadow: inset 0 0 6px rgba(0, 0, 0, 0.3);
                border-radius: 10px;
                background-color: #F5F5F5;
            }
            ::-webkit-scrollbar-thumb {
                border-radius: 10px;
                box-shadow: inset 0 0 6px rgba(0, 0, 0, 0.35);
                background-color: #c8c8c8;
            }
            ::-webkit-scrollbar-button {
                display: block;
                width: 1px;
                height: 1px;
            }
        </style>
    </head>
    <body>

        <div class="wrap">
            <div class="wrap-header">
                <div class="wrap-header_content">
                    <h2>
                        {{ app_title }}
                        {{ app_ver }}
                    </h2>
                    <div class="input-wrap">
                        <input
                            class="input__inner"
                            placeholder="输入名称或说明匹配过滤..."
                            id="inputFilter"
                        />
                    </div>
                    <div class="wrap-header_content-right">
                        <button id="reloadBtn">模块重载</button>
                        <button id="apiBtn">API接口声明</button>
                        <button id="actBtn">ACT接口管理</button>
                        <button id="daoBtn">数据库管理</button>
                        <button id="detailBtn">数据库表结构</button>
                        <button id="initdaosBtn">升级表结构</button>
                    </div>
                </div>

            </div>
            <div class="wrap-content">

                <div id="help">
                    {* help_html *}
                </div>

                <div id="act">
                    <h2 style="line-height: 50px;">{{app_name}}.act.* WEB接口对象</h2>

                    <table >
                        <thead>
                            <tr>
                                <th> 接口名称 </th>
                                <th> 说明 </th>
                                <th> 版本 </th>
                                <th> 授权 </th>
                                <th colspan="2"> 表单参数验证 </th>
                                <th colspan="4"> page 或 json 视图 </th>
                            </tr>
                        </thead>
                    {% for _, act in ipairs(app_acts) do %}
                        <tr>
                            <th> {{act.name}} </th>

                        {% if act.err then %}

                            <td colspan="9">{{ act.err }}</td>

                        {% else %}

                            {% if act.doc  then %}
                                <td><a target="_blank" href="{{act.doc }}"> {{act.text}} </a></td>
                            {% else %}
                                <td> {{act.text}} </td>
                            {% end %}

                            <td> {{act.ver }} </td>
                            <td> {*act.auth*} </td>

                            {% if act.lform then %}
                                <td><a target="_blank" href="{{act.name}}.lform">lform</a></td>
                                <td><a target="_blank" href="{{act.name}}.jform">jform</a></td>
                            {% else %}
                                <td> </td> <td> </td>
                            {% end %}

                            {% if act.resty then %}
                                <td> {% if act.add  then %} <a target="_blank" href="{{act.name}}.add">add</a> 增 {% end %}</td>
                                <td> {% if act.del  then %} <a target="_blank" href="{{act.name}}.del">del</a> 删 {% end %}</td>
                                <td> {% if act.set  then %} <a target="_blank" href="{{act.name}}.set">set</a> 改 {% end %}</td>
                                <td> {% if act.get  then %} <a target="_blank" href="{{act.name}}.get">get</a> 查 {% end %}</td>
                                {% if act.list then %} <th> <a target="_blank" href="{{act.name}}.list">list</a> 列表 </th> {% end %}
                            {% else %}
                                <td><a target="_blank" href="{{act.name}}.lpage">lpage</a></td>
                                <td><a target="_blank" href="{{act.name}}.ljson">ljson</a></td>
                                <td><a target="_blank" href="{{act.name}}.jsony">jsony</a></td>
                                <td><a target="_blank" href="{{act.name}}.jsonp">jsonp</a></td>
                            {% end %}

                            {% if act.demo then %}
                                <th><a target="_blank" href="{{act.demo}}">功能演示</a></th>
                            {% end %}

                        {% end %}
                        </tr>
                    {% end %}
                    </table>
                </div>

                <div id="dao">
                    <h2 style="line-height: 50px;">{{app_name}}.dao.* 数据访问对象</h2>

                    <table >
                        <thead>
                            <tr>
                                <th> 表名     </th>
                                <th> 说明     </th>
                                <th> 主键     </th>
                                <th> 接口说明 </th>
                                <th> 重新建表 </th>
                                <th> 结构详情 </th>
                            </tr>
                        </thead>
                        {% for _, dao in ipairs(app_daos) do %}
                        <tr>
                            <th> {{dao.table_name}} </th>
                            <td> {{dao.table_desc}} </td>
                            <td>
                                {% for _, f in ipairs(dao.field_list or {}) do %}
                                    {% if f.pk then %} <li><b>{{f.name}}</b> ( {{f.desc}} ) </li> {% end %}
                                {% end %}
                            </td>
                            <td> <a style="margin:15px" target="_blank" href="initdao?name={{dao.table_name}}&help">接口</a> </td>
                            <td> <a style="margin:15px" target="_blank" href="initdao?name={{dao.table_name}}&init">重建</a> </td>
                            <td> <a style="margin:15px" href="#{{dao.table_name}}">结构</a> </td>
                        </tr>
                        {% end %}
                    </table>
                </div>

                <div id="detail">
                    <div>
                        {% for _, dao in ipairs(app_daos) do %}
                            <div>
                                <h3 id="{{dao.table_name}}" style="line-height: 50px;">
                                    <span>{{dao.table_name}} </span>
                                    (<span>{{dao.table_desc}}</span>)
                                    <a target="_blank" href="initdao?name={{dao.table_name}}&help">接口说明</a> |
                                    <a target="_blank" href="initdao?name={{dao.table_name}}&init">重新建表</a>
                                </h3>

                                    <table id="{{dao.table_name}}">
                                        <tr>
                                            <th> 列名 </th>
                                            <th> 说明 </th>
                                            <th> 类型 </th>
                                            <th> 长度 </th>
                                            <th> 主键 </th>
                                            <th> 默认值 </th>

                                            {% local count = dao.demo_data and #dao.demo_data or 0
                                                if count>3 then count=3 end -- 最多只显示3条演示数据
                                                for i=1, count do %}
                                            <th> 演示数据{{i}} </th>
                                            {% end %}

                                        </tr>

                                    {% for _, f in ipairs(dao.field_list or {}) do %}
                                        <tr>
                                            <th> {{f.name}} </th>
                                            <td> {{f.desc}} </td>
                                            <td> {{f.type}} </td>
                                            <td> {{f.len }} </td>

                                            {% if f.pk then %} <th> 是 </th>
                                            {%         else %} <td>    </td> {% end %}

                                            {% local default = type(f.def)=="string" and "'" .. f.def .. "'" or f.def %}
                                            <td> {{default}} </td>

                                            {% for i=1, count do %}
                                            <td> {{ dao.demo_data[i][f.name] }} </td>
                                            {% end %}
                                        </tr>
                                    {% end %}
                                    </table>
                            </div>
                        {% end %}
                    </div>
                </div>

                <div id="table">
                    <div class="table-wrap">
                        {% for _, dao in ipairs(app_daos) do %}
                            <a class="table-item" href="#{{dao.table_name}}">
                                <span>{{dao.table_name}} </span>
                                <small>( {{dao.table_desc}} )</small>
                            </a>
                        {% end %}
                    </div>
                </div>
            </div>
        </div>

        <script>
            window.onload = function() {

                var clientWidth = document.body.clientWidth;

                var $actBtn     = document.getElementById('actBtn');
                var $daoBtn     = document.getElementById('daoBtn');
                var $detailBtn  = document.getElementById('detailBtn');
                var $reloadBtn  = document.getElementById('reloadBtn');
                var $initdaosBtn= document.getElementById('initdaosBtn');
                var $apiBtn     = document.getElementById('apiBtn');

                var $table      = document.getElementById('table');
                    $table.style.right = (clientWidth-1200) / 2 + 'px';

                var $filter     = document.getElementById('inputFilter');
                var $act        = window.$act = document.getElementById('act');
                var $dao        = document.getElementById('dao');
                var $detail     = document.getElementById('detail');

                var $currWrap    = $act; // 当前内容对象, 默认act;
                var $currContent = $act.querySelectorAll('table tbody tr');

                var listBtn = [$actBtn, $daoBtn, $detailBtn];
                var list    = [$act, $dao, $detail];

                // 输入过滤
                var timer = null;
                $filter.addEventListener('input', function(e) {
                    clearTimeout(timer);
                    timer = setTimeout(() => {

                        var val = e.target.value;

                        var  wrapId = $currWrap.id || '';
                        if (!wrapId) return clearTimeout(timer);

                        if (wrapId === 'act' || wrapId === 'dao') {

                            $currContent.forEach(item => {
                                if (val === '') {
                                    item.style.display = '';
                                } else {
                                    var name = item.children[0].innerHTML;
                                    var desc = item.children[1].innerHTML;

                                    if (name.indexOf(val) !== -1 || desc.indexOf(val) !== -1) {
                                        item.style.display = '';
                                    } else {
                                        item.style.display = 'none';
                                    }
                                }
                            });

                        } else {
                            $currContent.forEach(item => {
                                if (val === '') {
                                    item.parentNode.style.display = '';
                                } else {
                                    var name = item.children[0].innerHTML;
                                    var desc = item.children[1].innerHTML;

                                    if (name.indexOf(val) !== -1 || desc.indexOf(val) !== -1) {
                                        item.parentNode.style.display = '';
                                    } else {
                                        item.parentNode.style.display = 'none';
                                    }
                                }
                            });
                        }

                    }, 300);
                });

                // 处理顶部按钮点击事件
                listBtn.forEach((item, index) => {
                    item.addEventListener('click', function(e) {
                        // 点击当前对象, 不处理
                        if(list[index].id === $currWrap.id) return;

                        list.forEach(item => {
                            item.style.display = 'none';
                        });

                        list[index].style.display = 'block';
                        $currWrap = list[index];

                        if ($currWrap.id === 'act' || $currWrap.id === 'dao') {
                            $currContent = $currWrap.querySelectorAll('table tbody tr');
                            $table.style.display = 'none';
                        } else {
                            $currContent = $currWrap.querySelectorAll('div h3');
                            $table.style.display = 'block';
                        }

                        $filter.value = '';
                        document.body.scrollTop = 0;
                    });
                });

                // 重置模块
                $reloadBtn.addEventListener('click', function(e) {
                    // var isConfirm = window.confirm('是否重载此模块？')
                    // if (!isConfirm) return;

                    window.open('reload', '_blank');
                });

                // 升级表结构
                $initdaosBtn.addEventListener('click', function(e) {
                    window.open('initdaos', '_blank');
                });

                // API接口声明
                $apiBtn.addEventListener('click', function(e) {
                    window.open('api', '_blank');
                });

            }
        </script>
    </body>
</html>
]=====]
