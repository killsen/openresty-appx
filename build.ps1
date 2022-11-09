
$temp  = "./site/temp"
$nginx = "./site/nginx"

if (Test-Path $temp) {
    Remove-Item -Path $temp -Recurse -Force -ErrorAction Stop
}

New-Item -Path $temp                    -ItemType Directory | Out-Null
New-Item -Path $temp/lua_modules        -ItemType Directory | Out-Null
New-Item -Path $temp/lua_modules/app    -ItemType Directory | Out-Null
New-Item -Path $temp/lua_modules/resty  -ItemType Directory | Out-Null
New-Item -Path $temp/lua_modules/clib   -ItemType Directory | Out-Null
New-Item -Path $temp/lua_modules/lua    -ItemType Directory | Out-Null

Copy-Item -Path ./lua_modules/app/*     -Destination $temp/lua_modules/app/   -Force -Recurse
Copy-Item -Path ./lua_modules/resty/*   -Destination $temp/lua_modules/resty/ -Force -Recurse

New-Item -Path $temp/nginx              -ItemType Directory | Out-Null
New-Item -Path $temp/nginx/app          -ItemType Directory | Out-Null
New-Item -Path $temp/nginx/conf         -ItemType Directory | Out-Null
New-Item -Path $temp/nginx/html         -ItemType Directory | Out-Null
New-Item -Path $temp/nginx/logs         -ItemType Directory | Out-Null
New-Item -Path $temp/nginx/temp         -ItemType Directory | Out-Null

Copy-Item -Path ./nginx/app/*           -Destination $temp/nginx/app/  -Force -Recurse
Copy-Item -Path ./nginx/conf/*          -Destination $temp/nginx/conf/ -Force -Recurse
Copy-Item -Path ./nginx/html/*          -Destination $temp/nginx/html/ -Force -Recurse
Copy-Item -Path ./nginx/*.lua           -Destination $temp/nginx/      -Force

Copy-Item -Path $nginx/*                -Destination $temp/nginx/       -Force -Recurse

Compress-Archive -Path $temp/* -DestinationPath ./site/site.zip  -Force

Start-Process "site"
