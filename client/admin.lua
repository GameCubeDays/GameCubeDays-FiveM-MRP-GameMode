--[[
    MRP GAMEMODE - CLIENT ADMIN
    ===========================
    Client-side admin functionality:
    - Teleport handling
    - Spectate mode
    - Admin warnings
    - Admin menu
    - Heal
]]

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================
local isSpectating = false
local spectateTarget = nil
local originalCoords = nil

-- ============================================================================
-- TELEPORT
-- ============================================================================
RegisterNetEvent('mrp:teleport', function(x, y, z)
    local ped = PlayerPedId()
    
    -- Fade out
    DoScreenFadeOut(250)
    Wait(250)
    
    -- Teleport
    SetEntityCoords(ped, x, y, z, false, false, false, false)
    
    -- Wait for collision to load
    Wait(500)
    
    -- Fade in
    DoScreenFadeIn(250)
end)

-- ============================================================================
-- SPECTATE
-- ============================================================================
RegisterNetEvent('mrp:spectate', function(targetId)
    local ped = PlayerPedId()
    
    if targetId and not isSpectating then
        -- Start spectating
        local targetPlayer = GetPlayerFromServerId(targetId)
        
        if targetPlayer == -1 then
            lib.notify({ type = 'error', description = 'Player not found' })
            return
        end
        
        local targetPed = GetPlayerPed(targetPlayer)
        
        if not targetPed or not DoesEntityExist(targetPed) then
            lib.notify({ type = 'error', description = 'Cannot spectate this player' })
            return
        end
        
        -- Store original position
        originalCoords = GetEntityCoords(ped)
        
        -- Setup spectate
        isSpectating = true
        spectateTarget = targetId
        
        -- Make invisible and disable collision
        SetEntityVisible(ped, false, false)
        SetEntityCollision(ped, false, false)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        
        -- Teleport to target
        local targetCoords = GetEntityCoords(targetPed)
        SetEntityCoords(ped, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, false)
        
        -- Start spectate camera
        NetworkSetInSpectatorMode(true, targetPed)
        
        lib.notify({ type = 'info', description = 'Spectating ' .. GetPlayerName(targetPlayer) .. ' - Use /spectate to stop' })
        
        -- Follow target
        CreateThread(function()
            while isSpectating do
                Wait(0)
                
                if spectateTarget then
                    local tPlayer = GetPlayerFromServerId(spectateTarget)
                    if tPlayer ~= -1 then
                        local tPed = GetPlayerPed(tPlayer)
                        if tPed and DoesEntityExist(tPed) then
                            local tCoords = GetEntityCoords(tPed)
                            SetEntityCoords(PlayerPedId(), tCoords.x, tCoords.y, tCoords.z, false, false, false, false)
                        end
                    end
                end
            end
        end)
        
    elseif isSpectating then
        -- Stop spectating
        isSpectating = false
        spectateTarget = nil
        
        -- Reset player state
        SetEntityVisible(ped, true, false)
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, false)
        SetEntityInvincible(ped, false)
        
        -- Exit spectate mode
        NetworkSetInSpectatorMode(false, ped)
        
        -- Teleport back
        if originalCoords then
            SetEntityCoords(ped, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, false)
            originalCoords = nil
        end
        
        lib.notify({ type = 'info', description = 'Stopped spectating' })
    else
        lib.notify({ type = 'error', description = 'Usage: /spectate [id] or /spectate to stop' })
    end
end)

-- ============================================================================
-- ADMIN WARNING
-- ============================================================================
RegisterNetEvent('mrp:adminWarning', function(reason, adminName)
    -- Big warning notification
    lib.notify({
        title = '⚠️ ADMIN WARNING ⚠️',
        description = reason .. '\n\nWarned by: ' .. adminName,
        type = 'error',
        duration = 15000
    })
    
    -- Play warning sound
    PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
    
    -- Flash screen
    StartScreenEffect('DeathFailMPIn', 0, true)
    Wait(2000)
    StopScreenEffect('DeathFailMPIn')
end)

-- ============================================================================
-- HEAL
-- ============================================================================
RegisterNetEvent('mrp:heal', function()
    local ped = PlayerPedId()
    
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
    ClearPedBloodDamage(ped)
    
    lib.notify({ type = 'success', description = 'Healed' })
end)

-- ============================================================================
-- ADMIN MENU
-- ============================================================================
RegisterNetEvent('mrp:showAdminMenu', function(adminLevel)
    local options = {}
    
    -- Basic mod options (level 1+)
    table.insert(options, {
        title = 'Player List',
        description = 'View online players',
        icon = 'users',
        onSelect = function()
            ExecuteCommand('players')
        end
    })
    
    if adminLevel >= 1 then
        table.insert(options, {
            title = 'Spectate Player',
            icon = 'eye',
            onSelect = function()
                local input = lib.inputDialog('Spectate', {
                    { type = 'number', label = 'Player ID', required = true }
                })
                if input then
                    ExecuteCommand('spectate ' .. input[1])
                end
            end
        })
    end
    
    -- Mod options (level 2+)
    if adminLevel >= 2 then
        table.insert(options, {
            title = 'Teleport',
            icon = 'location-arrow',
            onSelect = function()
                OpenTeleportMenu()
            end
        })
        
        table.insert(options, {
            title = 'Kick Player',
            icon = 'user-slash',
            onSelect = function()
                local input = lib.inputDialog('Kick Player', {
                    { type = 'number', label = 'Player ID', required = true },
                    { type = 'input', label = 'Reason', required = true }
                })
                if input then
                    ExecuteCommand('kick ' .. input[1] .. ' ' .. input[2])
                end
            end
        })
        
        table.insert(options, {
            title = 'Temp Ban Player',
            icon = 'gavel',
            onSelect = function()
                local input = lib.inputDialog('Temporary Ban', {
                    { type = 'number', label = 'Player ID', required = true },
                    { type = 'number', label = 'Hours', required = true },
                    { type = 'input', label = 'Reason', required = true }
                })
                if input then
                    ExecuteCommand('tempban ' .. input[1] .. ' ' .. input[2] .. ' ' .. input[3])
                end
            end
        })
    end
    
    -- Admin options (level 3+)
    if adminLevel >= 3 then
        table.insert(options, {
            title = 'Announce',
            icon = 'bullhorn',
            onSelect = function()
                local input = lib.inputDialog('Server Announcement', {
                    { type = 'input', label = 'Message', required = true }
                })
                if input then
                    ExecuteCommand('announce ' .. input[1])
                end
            end
        })
        
        table.insert(options, {
            title = 'Heal Player',
            icon = 'heart',
            onSelect = function()
                local input = lib.inputDialog('Heal Player', {
                    { type = 'number', label = 'Player ID (blank for self)' }
                })
                if input and input[1] then
                    ExecuteCommand('heal ' .. input[1])
                else
                    ExecuteCommand('heal')
                end
            end
        })
    end
    
    -- Head Admin options (level 4+)
    if adminLevel >= 4 then
        table.insert(options, {
            title = 'Permanent Ban',
            icon = 'ban',
            iconColor = '#ff0000',
            onSelect = function()
                local input = lib.inputDialog('Permanent Ban', {
                    { type = 'number', label = 'Player ID', required = true },
                    { type = 'input', label = 'Reason', required = true }
                })
                if input then
                    local confirm = lib.alertDialog({
                        header = 'Confirm Permanent Ban',
                        content = 'Are you sure you want to permanently ban this player?',
                        centered = true,
                        cancel = true
                    })
                    if confirm == 'confirm' then
                        ExecuteCommand('permban ' .. input[1] .. ' ' .. input[2])
                    end
                end
            end
        })
        
        table.insert(options, {
            title = 'Set Money',
            icon = 'dollar-sign',
            onSelect = function()
                local input = lib.inputDialog('Set Money', {
                    { type = 'number', label = 'Player ID', required = true },
                    { type = 'number', label = 'Amount', required = true }
                })
                if input then
                    ExecuteCommand('setmoney ' .. input[1] .. ' ' .. input[2])
                end
            end
        })
        
        table.insert(options, {
            title = 'Set XP',
            icon = 'star',
            onSelect = function()
                local input = lib.inputDialog('Set XP', {
                    { type = 'number', label = 'Player ID', required = true },
                    { type = 'number', label = 'Amount', required = true }
                })
                if input then
                    ExecuteCommand('setxp ' .. input[1] .. ' ' .. input[2])
                end
            end
        })
    end
    
    lib.registerContext({
        id = 'mrp_admin_menu',
        title = 'Admin Menu',
        options = options
    })
    
    lib.showContext('mrp_admin_menu')
end)

-- Teleport submenu
function OpenTeleportMenu()
    local options = {
        {
            title = 'Go to Player',
            icon = 'arrow-right',
            onSelect = function()
                local input = lib.inputDialog('Go to Player', {
                    { type = 'number', label = 'Player ID', required = true }
                })
                if input then
                    ExecuteCommand('goto ' .. input[1])
                end
            end
        },
        {
            title = 'Bring Player',
            icon = 'arrow-left',
            onSelect = function()
                local input = lib.inputDialog('Bring Player', {
                    { type = 'number', label = 'Player ID', required = true }
                })
                if input then
                    ExecuteCommand('bring ' .. input[1])
                end
            end
        },
        {
            title = 'Teleport to Coords',
            icon = 'map-pin',
            onSelect = function()
                local input = lib.inputDialog('Teleport to Coordinates', {
                    { type = 'number', label = 'X', required = true },
                    { type = 'number', label = 'Y', required = true },
                    { type = 'number', label = 'Z', required = true }
                })
                if input then
                    ExecuteCommand('tpc ' .. input[1] .. ' ' .. input[2] .. ' ' .. input[3])
                end
            end
        },
        {
            title = 'Teleport to Waypoint',
            icon = 'location-dot',
            onSelect = function()
                TeleportToWaypoint()
            end
        }
    }
    
    lib.registerContext({
        id = 'mrp_teleport_menu',
        title = 'Teleport',
        menu = 'mrp_admin_menu',
        options = options
    })
    
    lib.showContext('mrp_teleport_menu')
end

-- Teleport to waypoint
function TeleportToWaypoint()
    local waypoint = GetFirstBlipInfoId(8)
    
    if not DoesBlipExist(waypoint) then
        lib.notify({ type = 'error', description = 'No waypoint set' })
        return
    end
    
    local coords = GetBlipCoords(waypoint)
    local ped = PlayerPedId()
    
    DoScreenFadeOut(250)
    Wait(250)
    
    -- Find ground Z
    local groundFound, groundZ = false, coords.z
    for i = 1, 1000 do
        SetEntityCoords(ped, coords.x, coords.y, i + 0.0, false, false, false, false)
        Wait(0)
        groundFound, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, i + 0.0, false)
        if groundFound then
            break
        end
    end
    
    SetEntityCoords(ped, coords.x, coords.y, groundZ + 1.0, false, false, false, false)
    
    DoScreenFadeIn(250)
    lib.notify({ type = 'success', description = 'Teleported to waypoint' })
end

-- ============================================================================
-- SHOW LOGS / BANS (from server)
-- ============================================================================
RegisterNetEvent('mrp:showLogs', function(logs)
    if not logs or #logs == 0 then
        lib.notify({ type = 'info', description = 'No logs found' })
        return
    end
    
    local options = {}
    
    for _, log in ipairs(logs) do
        table.insert(options, {
            title = log.event_type,
            description = (log.player_name or 'N/A') .. ' -> ' .. (log.target_name or 'N/A'),
            metadata = {
                { label = 'Time', value = log.created_at },
                { label = 'Data', value = log.data or 'N/A' }
            }
        })
    end
    
    lib.registerContext({
        id = 'mrp_logs_view',
        title = 'Logs',
        options = options
    })
    
    lib.showContext('mrp_logs_view')
end)

RegisterNetEvent('mrp:showBans', function(bans)
    if not bans or #bans == 0 then
        lib.notify({ type = 'info', description = 'No active bans' })
        return
    end
    
    local options = {}
    
    for _, ban in ipairs(bans) do
        local expiry = ban.expires_at or 'PERMANENT'
        table.insert(options, {
            title = ban.license:sub(1, 30) .. '...',
            description = ban.reason,
            metadata = {
                { label = 'By', value = ban.admin_name },
                { label = 'Expires', value = expiry },
                { label = 'Date', value = ban.created_at }
            }
        })
    end
    
    lib.registerContext({
        id = 'mrp_bans_view',
        title = 'Active Bans',
        options = options
    })
    
    lib.showContext('mrp_bans_view')
end)

RegisterNetEvent('mrp:showPlayerList', function(players)
    local options = {}
    
    for _, line in ipairs(players) do
        table.insert(options, {
            title = line,
            disabled = true
        })
    end
    
    lib.registerContext({
        id = 'mrp_player_list',
        title = 'Online Players',
        options = options
    })
    
    lib.showContext('mrp_player_list')
end)

-- ============================================================================
-- ADMIN COMMAND
-- ============================================================================
RegisterCommand('admin', function()
    if not MRP.IsLoaded then return end
    TriggerServerEvent('mrp:openAdminMenu')
end, false)

RegisterKeyMapping('admin', 'Open Admin Menu', 'keyboard', 'F7')

Config.Print('client/admin.lua loaded')
