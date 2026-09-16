fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ox_stashcreator'
author 'Thendra'
description 'Dynamic prop stash creation and management system for ox_inventory'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory'
}
