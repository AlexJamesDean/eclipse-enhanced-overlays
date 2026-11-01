fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Kakarot'
description 'Allows players to select a spawn point from a list of available locations'
version '1.5.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config.lua',
    '@qb-apartments/config.lua',
}

client_script 'client.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

ui_page 'html/index.html'

-- Aurora reskin 30 Jul 2026: vue.js/reset.css are the superseded stock UI,
-- left on disk but no longer loaded (index.html doesn't reference them).
files {
    'html/index.html',
    'html/style.css',
    'html/fonts.css',
    'html/app.js',
    'html/fonts/CormorantGaramond.woff2',
    'html/fonts/Montserrat.woff2',
}
