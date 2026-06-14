fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name        'rde_carhud'
author      'Red Dragon Elite | SerpentsByte'
description 'RDE Vehicle Cockpit — HUD + Engine Control + WheelDamage + Nitro + RepairKit'
version     '1.0.0-beta'

dependencies {
    '/server:7290',
    'oxmysql',
    'ox_lib',
    'ox_core',
    'ox_inventory',
}

shared_scripts {
    '@ox_lib/init.lua',
    '@ox_core/lib/init.lua',
    'config.lua',
    'locales/*.lua',
}

client_scripts {
    'data/items.lua',
    'client/main.lua',
    'client/engine.lua',
    'client/nitrocl.lua',
    'client/repairkitcl.lua',
    'client/wheeldmgcl.lua',
    'client/vehiclefailurecl.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/nitrosrv.lua',
    'server/repairkitsrv.lua',
    'server/wheeldmgsrv.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/assets/css/*.css',
    'nui/assets/js/*.js',
    'nui/assets/images/*',
    'nui/assets/sounds/*',
    'nui/img/*',
}

provide {
    'carhud',
    'vehicle_hud',
    'speedometer',
    'realcardamage',
    'wheeldamage',
}
