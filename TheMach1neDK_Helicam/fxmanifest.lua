fx_version 'cerulean'
 game 'gta5'

 lua54 'yes'

 name 'TheMach1neDK Helicam'
 author 'TheMach1neDK'
 version '1.0.0'

 ui_page 'html/index.html'

 shared_scripts {
     '@ox_lib/init.lua',
     'config.lua'
 }

 client_scripts {
     'client.lua'
 }

 server_scripts {
     '@oxmysql/lib/MySQL.lua',
     'server.lua'
 }

 files {
     'html/index.html',
     'html/style.css',
     'html/app.js'
 }

 dependency 'ox_lib'
 dependency 'oxmysql'
