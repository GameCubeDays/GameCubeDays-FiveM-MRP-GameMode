fx_version 'cerulean'
game 'gta5'

name 'mrp_gamemode'
description 'Military Roleplay Gamemode - Faction-based warfare with capture points, ranks, and progression'
author 'GameCubeDays'
version '1.0.0'

-- Dependencies
dependencies {
    'oxmysql',
    'ox_lib'
}

-- Shared scripts (loaded on both client and server)
shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua'
}

-- Server-side scripts
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/characters.lua',
    'server/progression.lua',
    'server/combat.lua',
    'server/economy.lua',
    'server/capturepoints.lua',
    'server/vehicles.lua',
    'server/admin.lua',
    'server/logging.lua'
}

-- Client-side scripts
client_scripts {
    'client/main.lua',
    'client/characters.lua',
    'client/hud.lua',
    'client/nametags.lua',
    'client/capturepoints.lua',
    'client/combat.lua',
    'client/armory.lua',
    'client/vehicles.lua',
    'client/skills.lua',
    'client/roster.lua'
}

-- NUI (HTML/CSS/JS interface)
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

-- Lua runtime
lua54 'yes'
