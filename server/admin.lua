--[[
    MRP GAMEMODE - SERVER ADMIN
    ===========================
    Complete admin system:
    - Permission-based commands
    - Kick, ban, tempban
    - Teleport, bring, goto
    - Player management
    - Resource controls
]]

-- ============================================================================
-- PERMISSION CHECK
-- ============================================================================
function HasPermission(src, permission)
    local player = MRP.Players[src]
    if not player then return false end
    
    local adminLevel = player.adminLevel or 0
    if adminLevel == 0 then return false end
    
    -- Super admin has all permissions
    if adminLevel >= 5 then return true end
    
    -- Check specific permission
    local perms = Config.Admin.permissions[adminLevel]
    if not perms then return false end
    
    for _, perm in ipairs(perms) do
        if perm == '*' or perm == permission then
            return true
        end
    end
    
    return false
end

function GetAdminLevelName(level)
    return Config.Admin.levels[level] or 'Unknown'
end

exports('HasPermission', HasPermission)

-- ============================================================================
-- KICK COMMAND
-- ============================================================================
RegisterCommand('kick', function(source, args)
    local src = source
    
    if not HasPermission(src, 'kick') then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission' })
        return
    end
    
    local targetId = tonumber(args[1])
    if not targetId then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Usage: /kick [id] [reason]' })
        return
    end
    
    local reason = table.concat(args, ' ', 2) or 'No reason specified'
    
    local targetName = GetPlayerName(targetId)
    if not targetName then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Player not found' })
        return
    end
    
    -- Log action
    local adminName = MRP.Characters[src] and MRP.Characters[src].name or GetPlayerName(src)
    LogAction('kick', MRP.Players[src].visibleid, adminName, GetPlayerIdentifierByType(targetId, 'license'), targetName, {
        reason = reason
    })
    
    -- Kick player
    DropPlayer(targetId, 'Kicked by admin: ' .. reason)
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Kicked ' .. targetName })
    TriggerClientEvent('ox_lib:notify', -1, { type = 'info', description = targetName .. ' was kicked by an admin' })
end, false)

-- ============================================================================
-- BAN COMMANDS
-- ============================================================================

-- Temporary ban
RegisterCommand('tempban', function(source, args)
    local src = source
    
    if not HasPermission(src, 'tempban') then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission' })
        return
    end
    
    local targetId = tonumber(args[1])
    local duration = tonumber(args[2]) -- In hours
    
    if not targetId or not duration then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Usage: /tempban [id] [hours] [reason]' })
        return
    end
    
    local reason = table.concat(args, ' ', 3) or 'No reason specified'
    
    local targetName = GetPlayerName(targetId)
    if not targetName then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Player not found' })
        return
    end
    
    local license = GetPlayerIdentifierByType(targetId, 'license')
    local discord = GetPlayerIdentifierByType(targetId, 'discord')
    local ip = GetPlayerIdentifierByType(targetId, 'ip')
    
    local expiry = os.time() + (duration * 3600)
    local adminName = MRP.Characters[src] and MRP.Characters[src].name or GetPlayerName(src)
    
    -- Insert ban
    MySQL.insert([[
        INSERT INTO mrp_bans (license, discord, ip, reason, admin_name, expires_at)
        VALUES (?, ?, ?, ?, ?, FROM_UNIXTIME(?))
    ]], { license, discord, ip, reason, adminName, expiry })
    
    -- Log action
    LogAction('tempban', MRP.Players[src].visibleid, adminName, license, targetName, {
        reason = reason,
        duration = duration .. ' hours',
        expiry = os.date('%Y-%m-%d %H:%M:%S', expiry)
    })
    
    -- Kick player
    DropPlayer(targetId, 'Temporarily banned: ' .. reason .. '\nExpires: ' .. os.date('%Y-%m-%d %H:%M', expiry))
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Banned ' .. targetName .. ' for ' .. duration .. ' hours' })
end, false)

-- Permanent ban
RegisterCommand('permban', function(source, args)
    local src = source
    
    if not HasPermission(src, 'permban') then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission' })
        return
    end
    
    local targetId = tonumber(args[1])
    
    if not targetId then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Usage: /permban [id] [reason]' })
        return
    end
    
    local reason = table.concat(args, ' ', 2) or 'No reason specified'
    
    local targetName = GetPlayerName(targetId)
    if not targetName then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Player not found' })
        return
    end
    
    local license = GetPlayerIdentifierByType(targetId, 'license')
    local discord = GetPlayerIdentifierByType(targetId, 'discord')
    local ip = GetPlayerIdentifierByType(targetId, 'ip')
    
    local adminName = MRP.Characters[src] and MRP.Characters[src].name or GetPlayerName(src)
    
    -- Insert permanent ban (no expiry)
    MySQL.insert([[
        INSERT INTO mrp_bans (license, discord, ip, reason, admin_name, expires_at)
        VALUES (?, ?, ?, ?, ?, NULL)
    ]], { license, discord, ip, reason, adminName })
    
    -- Log action
    LogAction('permban', MRP.Players[src].visibleid, adminName, license, targetName, {
        reason = reason
    })
    
    -- Kick player
    DropPlayer(targetId, 'Permanently banned: ' .. reason)
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Permanently banned ' .. targetName })
end, false)

-- Unban
RegisterCommand('unban', function(source, args)
    local src = source
    
    if not HasPermission(src, 'permban') then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission' })
        return
    end
    
    local license = args[1]
    
    if not license then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Usage: /unban [license]' })
        return
    end
    
    -- Remove ban
    local affected = MySQL.update.await('DELETE FROM mrp_bans WHERE license = ?', { license })
    
    if affected > 0 then
        local adminName = MRP.Characters[src] and MRP.Characters[src].name or GetPlayerName(src)
        LogAction('unban', MRP.Players[src].visibleid, adminName, license, nil, {})
        TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Unbanned license: ' .. license })
    else
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No ban found for that license' })
    end
end, false)

-- ============================================================================
-- TELEPORT COMMANDS
-- ============================================================================

-- Teleport to player
RegisterCommand('goto', function(source, args)
    local src = source
    
    if not HasPermission(src, 'teleport') then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission' })
        return
    end
    
    local targetId = tonumber(args[1])
    
    if not targetId then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Usage: /goto [id]' })
        return
    end
    
    local targetPed = GetPlayerPed(targetId)
    if not targetPed or not DoesEntityExist(targetPed) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Player not found' })
        return
    end
    
    local coords = GetEntityCoords(targetPed)
    TriggerClientEvent('mrp:teleport', src, coords.x, coords.y, coords.z)
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Teleported to ' .. GetPlayerName(targetId) })
end, false)

-- Bring player to you
RegisterCommand('bring', function(source, args)
    local src = source
    
    if not HasPermission(src, 'bring') then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission' })
        return
    end
    
    local targetId = tonumber(args[1])
    
    if not targetId then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Usage: /bring [id]' })
        return
    end
    
    local adminPed = GetPlayerPed(src)
    if not adminPed then return end
    
    local coords = GetEntityCoords(adminPed)
    TriggerClientEvent('mrp:teleport', targetId, coords.x, coords.y, coords.z)
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Brought ' .. GetPlayerName(targetId) })
    TriggerClientEvent('ox_lib:notify', targetId, { type = 'info', description = 'You were teleported by an admin' })
end, false)

-- Teleport to coordinates
RegisterCommand('tpc', function(source, args)
    local src = source
    
    if not HasPermission(src, 'teleport') then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission' })
        return
    end
    
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    local z = tonumber(args[3])
    
    if not x or not y or not z then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Usage: /tpc [x] [y] [z]' })
        return
    end
    
    TriggerClientEvent('mrp:teleport', src, x, y, z)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Teleported to coordinates' })
end, false)

-- ============================================================================
-- PLAYER MANAGEMENT
-- ============================================================================

-- Set admin level
RegisterCommand('setadmin', function(source, args)
    local src = source
    
    -- Only super admins can set admin levels (or console)
    if src ~= 0 and (not MRP.Players[src] or MRP.Players[src].adminLevel < 5) then
        if src ~= 0 then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission' })
        end
        return
    end
    
    local targetId = tonumber(args[1])
    local level = tonumber(args[2])
    
    if not targetId or not level then
        print('Usage: /setadmin [id] [level 0-5]')
        return
    end
    
    if level < 0 or level > 5 then
        print('Level must be 0-5')
        return
    end
    
    local targetPlayer = MRP.Players[targetId]
    if not targetPlayer then
        print('Player not found')
        return
    end
    
    -- Update in memory
    targetPlayer.adminLevel = level
    
    -- Update in database
    MySQL.update('UPDATE mrp_players SET admin_level = ? WHERE license = ?', { level, targetPlayer.license })
    
    -- Notify
    local levelName = GetAdminLevelName(level)
    TriggerClientEvent('ox_lib:notify', targetId, { type = 'info', description = 'Your admin level is now: ' .. levelName })
    
    if src ~= 0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Set ' .. GetPlayerName(targetId) .. ' to ' .. levelName })
    end
    
    print('[MRP] Set ' .. GetPlayerName(targetId) .. ' admin level to ' .. level .. ' (' .. levelName .. ')')
end, false)

-- Warn player
RegisterCommand('warn', function(source, args)
    local src = source
    
    if not HasPermission(src, 'warn') then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission' })
        return
    end
    
    local targetId = tonumber(args[1])
    local reason = table.concat(args, ' ', 2)
    
    if not targetId or not reason or reason == '' then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Usage: /warn [id] [reason]' })
        return
    end
    
    local targetName = GetPlayerName(targetId)
    if not targetName then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Player not found' })
        return
    end
    
    local adminName = MRP.Characters[src] and MRP.Characters[src].name or GetPlayerName(src)
    
    -- Log warning
    LogAction('warn', MRP.Players[src].visibleid, adminName, GetPlayerIdentifierByType(targetId, 'license'), targetName, {
        reason = reason
    })
    
    -- Notify player with big warning
    TriggerClientEvent('mrp:adminWarning', targetId, reason, adminName)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Warned ' .. targetName })
end, false)

-- ============================================================================
-- SPECTATE
-- ============================================================================
RegisterCommand('spectate', function(source, args)
    local src = source
    
    if not HasPermission(src, 'spectate') then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission' })
        return
    end
    
    local targetId = tonumber(args[1])
    
    TriggerClientEvent('mrp:spectate', src, targetId)
end, false)

-- ============================================================================
-- ECONOMY ADMIN
-- ============================================================================

-- Set money
RegisterCommand('setmoney', function(source, args)
    local src = source
    
    if not HasPermission(src, 'set_money') then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission' })
        return
    end
    
    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    
    if not targetId or not amount then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Usage: /setmoney [id] [amount]' })
        return
    end
    
    local target = MRP.Characters[targetId]
    if not target then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Target not found' })
        return
    end
    
    target.money = amount
    TriggerClientEvent('mrp:updateStats', targetId, { money = amount })
    
    local adminName = MRP.Characters[src] and MRP.Characters[src].name or GetPlayerName(src)
    LogAction('set_money', MRP.Players[src].visibleid, adminName, MRP.Players[targetId].visibleid, target.name, { amount = amount })
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Set ' .. target.name .. ' money to $' .. amount })
end, false)

-- Set XP
RegisterCommand('setxp', function(source, args)
    local src = source
    
    if not HasPermission(src, 'set_xp') then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission' })
        return
    end
    
    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    
    if not targetId or not amount then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Usage: /setxp [id] [amount]' })
        return
    end
    
    local target = MRP.Characters[targetId]
    if not target then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Target not found' })
        return
    end
    
    target.xp = amount
    CheckRankUp(targetId)
    TriggerClientEvent('mrp:updateStats', targetId, { xp = amount })
    
    local adminName = MRP.Characters[src] and MRP.Characters[src].name or GetPlayerName(src)
    LogAction('set_xp', MRP.Players[src].visibleid, adminName, MRP.Players[targetId].visibleid, target.name, { amount = amount })
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Set ' .. target.name .. ' XP to ' .. amount })
end, false)

-- ============================================================================
-- UTILITY COMMANDS
-- ============================================================================

-- Get player IDs
RegisterCommand('players', function(source, args)
    local src = source
    
    if src ~= 0 and not MRP.Players[src] then return end
    if src ~= 0 and MRP.Players[src].adminLevel < 1 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission' })
        return
    end
    
    local players = GetPlayers()
    local list = {}
    
    for _, playerId in ipairs(players) do
        local name = GetPlayerName(playerId)
        local charName = MRP.Characters[tonumber(playerId)] and MRP.Characters[tonumber(playerId)].name or 'No character'
        table.insert(list, string.format('[%s] %s (%s)', playerId, name, charName))
    end
    
    if src == 0 then
        print('Online Players:')
        for _, line in ipairs(list) do
            print('  ' .. line)
        end
    else
        TriggerClientEvent('mrp:showPlayerList', src, list)
    end
end, false)

-- Announce
RegisterCommand('announce', function(source, args)
    local src = source
    
    if src ~= 0 and not HasPermission(src, 'kick') then -- Basic mod permission
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission' })
        return
    end
    
    local message = table.concat(args, ' ')
    
    if not message or message == '' then
        if src ~= 0 then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Usage: /announce [message]' })
        end
        return
    end
    
    TriggerClientEvent('mrp:serverAnnouncement', -1, message)
    
    if src ~= 0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Announcement sent' })
    end
end, false)

-- Heal
RegisterCommand('heal', function(source, args)
    local src = source
    
    if not HasPermission(src, 'teleport') then -- Mod+ permission
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission' })
        return
    end
    
    local targetId = tonumber(args[1]) or src
    TriggerClientEvent('mrp:heal', targetId)
    
    if targetId ~= src then
        TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Healed player' })
    end
end, false)

-- ============================================================================
-- ADMIN MENU (ox_lib)
-- ============================================================================
RegisterNetEvent('mrp:openAdminMenu', function()
    local src = source
    local player = MRP.Players[src]
    
    if not player or player.adminLevel < 1 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission' })
        return
    end
    
    TriggerClientEvent('mrp:showAdminMenu', src, player.adminLevel)
end)

Config.Print('server/admin.lua loaded')
