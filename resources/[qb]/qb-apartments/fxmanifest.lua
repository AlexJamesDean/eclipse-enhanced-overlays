fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Kakarot'
description 'Provides players with a flat on server join'
version '2.2.1'

shared_scripts {
    'config.lua',
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua',
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/CircleZone.lua',
}

dependencies {
    'qb-core',
    'qb-interior',
    -- clothing is consumed via runtime events only; a manifest dependency on
    -- ajd-clothing ([ajd], loads after [qb]) breaks CLIENT-side loading of
    -- this whole resource ("not found") - 29 Jul incident, do not re-add
    'qb-weathersync',
}
