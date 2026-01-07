--[[
    MRP GAMEMODE - CLIENT MAIN
    ==========================
    Core client-side logic:
    - Player initialization
    - Data management
    - Basic player setup
    - Utility functions
]]

-- ============================================================================
-- GLOBAL VARIABLES
-- ============================================================================
MRP = MRP or {}
MRP.PlayerData = nil           -- Current character data
MRP.AllPlayers = {}            -- All online players data for nameplates/roster
MRP.IsLoaded = false           -- Has character been loaded
MRP.IsDead = false             -- Is player dead/downed

-- ============================================================================
-- RESOURCE START - Initialize
-- ============================================================================
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    Config.Print('========================================')
    Config.Print('MRP Gamemode - Client Starting')
    Config.Print('========================================')
    
    -- Wait for player to be fully loaded
    while not NetworkIsSessionStarted() do
        Wait(100)
    end
    
    -- Notify server that player has joined
    TriggerServerEvent('mrp:playerJoined')
    
    Config.Print('Client initialized - Waiting for character selection')
end)

-- ============================================================================
-- CHARACTER LOADED
-- ============================================================================
RegisterNetEvent('mrp:characterLoaded', function(characterData)
    MRP.PlayerData = characterData
    MRP.IsLoaded = true
    
    Config.Print('========================================')
    Config.Print('Character Loaded:')
    Config.Print('  Name:', characterData.name)
    Config.Print('  Faction:', characterData.factionName)
    Config.Print('  Rank:', characterData.rankName)
    Config.Print('  Whitelist:', characterData.whitelistName)
    Config.Print('  XP:', characterData.xp)
    Config.Print('  Money:', characterData.money)
    Config.Print('========================================')
    
    -- Setup player
    SetupPlayer()
    
    -- Show welcome notification
    lib.notify({
        title = 'Welcome',
        description = string.format('Playing as %s | %s %s', characterData.name, characterData.rankAbbr, characterData.factionName),
        type = 'success',
        duration = 5000
    })
end)

-- ============================================================================
-- PLAYER SETUP
-- ============================================================================
function SetupPlayer()
    local ped = PlayerPedId()
    
    -- Set player model based on whitelist
    SetPlayerModel()
    
    -- Wait for model to load
    Wait(500)
    ped = PlayerPedId()
    
    -- Spawn at faction base
    SpawnAtBase()
    
    -- Clear wanted level
    ClearPlayerWantedLevel(PlayerId())
    SetMaxWantedLevel(0)
    
    -- Reset health
    SetEntityHealth(ped, 200)
    
    -- Make sure player is visible
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    
    MRP.IsDead = false
    
    Config.Print('Player setup complete')
end

-- ============================================================================
-- SET PLAYER MODEL
-- ============================================================================
function SetPlayerModel()
    if not MRP.PlayerData then return end
    
    local whitelist = MRP.PlayerData.whitelist
    local models = Config.PlayerModels[whitelist]
    
    if not models or #models == 0 then
        Config.Print('WARNING: No models found for whitelist:', whitelist)
        models = { 'mp_m_freemode_01' }
    end
    
    -- Select random model from whitelist options
    local selectedModel = models[math.random(#models)]
    local modelHash = GetHashKey(selectedModel)
    
    Config.Print('Setting player model:', selectedModel)
    
    -- Request and load model
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Wait(100)
        timeout = timeout + 1
    end
    
    if HasModelLoaded(modelHash) then
        SetPlayerModel(PlayerId(), modelHash)
        SetModelAsNoLongerNeeded(modelHash)
        Config.Print('Player model set successfully')
    else
        Config.Print('ERROR: Failed to load model:', selectedModel)
    end
end

-- ============================================================================
-- SPAWN AT BASE
-- ============================================================================
function SpawnAtBase()
    if not MRP.PlayerData then return end
    
    local faction = MRP.PlayerData.faction
    local base = Config.Bases[faction]
    
    -- Civilians use random spawns
    if faction == 3 then
        local spawns = Config.CivilianSpawns
        local spawn = spawns[math.random(#spawns)]
        
        SetEntityCoords(PlayerPedId(), spawn.x, spawn.y, spawn.z, false, false, false, false)
        SetEntityHeading(PlayerPedId(), spawn.w)
        
        Config.Print('Spawned at civilian location')
        return
    end
    
    if not base then
        Config.Print('ERROR: No base found for faction:', faction)
        return
    end
    
    -- Select random spawn point
    local spawnPoints = base.spawnPoints
    local spawn = spawnPoints[math.random(#spawnPoints)]
    
    -- Teleport player
    local ped = PlayerPedId()
    SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
    SetEntityHeading(ped, spawn.w)
    
    -- Camera fade effect
    DoScreenFadeOut(500)
    Wait(500)
    DoScreenFadeIn(500)
    
    Config.Print('Spawned at', base.name)
end

-- ============================================================================
-- UPDATE STATS FROM SERVER
-- ============================================================================
RegisterNetEvent('mrp:updateStats', function(stats)
    if not MRP.PlayerData then return end
    
    -- Update local data
    for key, value in pairs(stats) do
        MRP.PlayerData[key] = value
    end
    
    Config.Print('Stats updated')
end)

-- ============================================================================
-- RANK CHANGED
-- ============================================================================
RegisterNetEvent('mrp:rankChanged', function(newRank)
    if not MRP.PlayerData then return end
    
    MRP.PlayerData.rankId = newRank.id
    MRP.PlayerData.rankName = newRank.name
    MRP.PlayerData.rankAbbr = newRank.abbr
    
    lib.notify({
        title = 'Rank Changed',
        description = 'You are now ' .. newRank.name,
        type = 'info',
        duration = 5000
    })
    
    -- Play sound
    PlaySoundFrontend(-1, 'RANK_UP', 'HUD_AWARDS', true)
end)

-- ============================================================================
-- WHITELIST CHANGED
-- ============================================================================
RegisterNetEvent('mrp:whitelistChanged', function(whitelistId, whitelistName)
    if not MRP.PlayerData then return end
    
    MRP.PlayerData.whitelist = whitelistId
    MRP.PlayerData.whitelistName = whitelistName
    
    lib.notify({
        title = 'Whitelist Changed',
        description = 'You are now ' .. whitelistName,
        type = 'info',
        duration = 5000
    })
    
    -- Update player model
    SetPlayerModel()
end)

-- ============================================================================
-- SYNC ALL PLAYERS (for nameplates/roster)
-- ============================================================================
RegisterNetEvent('mrp:syncAllPlayers', function(playersData)
    MRP.AllPlayers = playersData
end)

RegisterNetEvent('mrp:playerLeft', function(playerId)
    MRP.AllPlayers[playerId] = nil
end)

-- ============================================================================
-- DISABLE UNWANTED GTA FEATURES
-- ============================================================================
CreateThread(function()
    while true do
        Wait(0)
        
        -- Disable wanted level
        ClearPlayerWantedLevel(PlayerId())
        SetPlayerWantedLevel(PlayerId(), 0, false)
        SetPlayerWantedLevelNow(PlayerId(), false)
        
        -- Disable idle camera
        InvalidateIdleCam()
        InvalidateVehicleIdleCam()
    end
end)

-- Disable police and emergency services
CreateThread(function()
    while true do
        Wait(1000)
        
        -- Disable dispatch services
        for i = 1, 15 do
            EnableDispatchService(i, false)
        end
        
        -- Remove police from map
        SetMaxWantedLevel(0)
    end
end)

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================
function GetPlayerData()
    return MRP.PlayerData
end

function IsPlayerLoaded()
    return MRP.IsLoaded
end

function GetAllPlayers()
    return MRP.AllPlayers
end

function GetPlayerFaction()
    return MRP.PlayerData and MRP.PlayerData.faction or 0
end

function GetPlayerRank()
    return MRP.PlayerData and MRP.PlayerData.rankId or 1
end

function GetPlayerMoney()
    return MRP.PlayerData and MRP.PlayerData.money or 0
end

function GetPlayerXP()
    return MRP.PlayerData and MRP.PlayerData.xp or 0
end

-- Export functions
exports('GetPlayerData', GetPlayerData)
exports('IsPlayerLoaded', IsPlayerLoaded)
exports('GetAllPlayers', GetAllPlayers)
exports('GetPlayerFaction', GetPlayerFaction)

-- ============================================================================
-- COMMANDS
-- ============================================================================

-- Switch character
RegisterCommand('switchchar', function()
    if not MRP.IsLoaded then return end
    
    -- Confirm with dialog
    local confirm = lib.alertDialog({
        header = 'Switch Character',
        content = 'Are you sure you want to switch characters?',
        centered = true,
        cancel = true
    })
    
    if confirm == 'confirm' then
        MRP.IsLoaded = false
        MRP.PlayerData = nil
        TriggerServerEvent('mrp:switchCharacter')
    end
end, false)

-- Debug command
RegisterCommand('mrpdebug', function()
    if MRP.PlayerData then
        print('=== MRP Debug Info ===')
        print('Name:', MRP.PlayerData.name)
        print('Faction:', MRP.PlayerData.faction, '-', MRP.PlayerData.factionName)
        print('Rank:', MRP.PlayerData.rankId, '-', MRP.PlayerData.rankName)
        print('Whitelist:', MRP.PlayerData.whitelist, '-', MRP.PlayerData.whitelistName)
        print('XP:', MRP.PlayerData.xp)
        print('Money:', MRP.PlayerData.money)
        print('K/D:', MRP.PlayerData.kills, '/', MRP.PlayerData.deaths)
        print('=====================')
    else
        print('No player data loaded')
    end
end, false)

-- Manual respawn command (for testing)
RegisterCommand('respawn', function()
    if not MRP.IsLoaded then return end
    SpawnAtBase()
end, false)

Config.Print('client/main.lua loaded')
