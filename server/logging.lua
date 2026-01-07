--[[
    MRP GAMEMODE - SERVER LOGGING
    =============================
    Comprehensive logging system:
    - Database logging (mrp_logs table)
    - Discord webhook integration
    - Event filtering
    - Formatted embeds
]]

-- ============================================================================
-- LOGGING FUNCTION (Called from other scripts)
-- ============================================================================
function LogAction(eventType, playerId, playerName, targetId, targetName, data)
    -- Check if this event type should be logged
    if not ShouldLog(eventType) then return end
    
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    
    -- Database logging
    if Config.Logging.dbLogging then
        LogToDatabase(eventType, playerId, playerName, targetId, targetName, data, timestamp)
    end
    
    -- Discord logging
    if Config.Logging.discordWebhook and Config.Logging.discordWebhook ~= '' then
        LogToDiscord(eventType, playerId, playerName, targetId, targetName, data, timestamp)
    end
    
    -- Console logging (debug)
    if Config.Debug then
        local logStr = string.format('[LOG] %s | %s | Player: %s (%s)', 
            timestamp, eventType, playerName or 'N/A', playerId or 'N/A')
        if targetName then
            logStr = logStr .. string.format(' | Target: %s (%s)', targetName, targetId or 'N/A')
        end
        print(logStr)
    end
end

-- Check if event should be logged
function ShouldLog(eventType)
    if not Config.Logging.logEvents then return true end
    
    for _, event in ipairs(Config.Logging.logEvents) do
        if event == eventType then
            return true
        end
    end
    
    -- Always log admin actions regardless of config
    if string.find(eventType, 'admin') then
        return true
    end
    
    return false
end

-- Export for other scripts
exports('LogAction', LogAction)

-- ============================================================================
-- DATABASE LOGGING
-- ============================================================================
function LogToDatabase(eventType, playerId, playerName, targetId, targetName, data, timestamp)
    local dataJson = data and json.encode(data) or nil
    
    MySQL.insert([[
        INSERT INTO mrp_logs (event_type, player_id, player_name, target_id, target_name, data, created_at)
        VALUES (?, ?, ?, ?, ?, ?, NOW())
    ]], { eventType, playerId, playerName, targetId, targetName, dataJson })
end

-- ============================================================================
-- DISCORD WEBHOOK LOGGING
-- ============================================================================
function LogToDiscord(eventType, playerId, playerName, targetId, targetName, data, timestamp)
    local webhook = Config.Logging.discordWebhook
    if not webhook or webhook == '' then return end
    
    -- Build embed
    local embed = BuildDiscordEmbed(eventType, playerId, playerName, targetId, targetName, data, timestamp)
    
    -- Send webhook
    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({
        username = 'MRP Logs',
        embeds = { embed }
    }), { ['Content-Type'] = 'application/json' })
end

-- Build Discord embed based on event type
function BuildDiscordEmbed(eventType, playerId, playerName, targetId, targetName, data, timestamp)
    local color = GetEventColor(eventType)
    local title = GetEventTitle(eventType)
    local description = GetEventDescription(eventType, playerId, playerName, targetId, targetName, data)
    
    local fields = {}
    
    -- Add player field
    if playerName then
        table.insert(fields, {
            name = 'Player',
            value = string.format('%s\n`%s`', playerName, playerId or 'N/A'),
            inline = true
        })
    end
    
    -- Add target field
    if targetName then
        table.insert(fields, {
            name = 'Target',
            value = string.format('%s\n`%s`', targetName, targetId or 'N/A'),
            inline = true
        })
    end
    
    -- Add data fields
    if data then
        for key, value in pairs(data) do
            if type(value) ~= 'table' then
                table.insert(fields, {
                    name = FormatFieldName(key),
                    value = tostring(value),
                    inline = true
                })
            end
        end
    end
    
    return {
        title = title,
        description = description,
        color = color,
        fields = fields,
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer = {
            text = 'MRP Gamemode'
        }
    }
end

-- Get embed color based on event type
function GetEventColor(eventType)
    local colors = {
        -- Green - Positive
        player_connect = 0x44ff44,
        character_create = 0x44ff44,
        rank_up = 0x44ff44,
        revive = 0x44ff44,
        point_captured = 0x44ff44,
        
        -- Blue - Info
        player_disconnect = 0x4499ff,
        character_select = 0x4499ff,
        purchase = 0x4499ff,
        
        -- Yellow - Warning
        warn = 0xffaa00,
        teamkill = 0xffaa00,
        
        -- Red - Negative/Admin
        kick = 0xff4444,
        tempban = 0xff4444,
        permban = 0xff0000,
        character_delete = 0xff4444,
        death = 0xff4444,
        
        -- Purple - Admin actions
        admin_add_xp = 0xaa44ff,
        admin_add_money = 0xaa44ff,
        admin_kill = 0xaa44ff,
        admin_revive = 0xaa44ff,
        set_money = 0xaa44ff,
        set_xp = 0xaa44ff,
        
        -- Default
        default = 0x888888
    }
    
    return colors[eventType] or colors.default
end

-- Get embed title based on event type
function GetEventTitle(eventType)
    local titles = {
        player_connect = '🟢 Player Connected',
        player_disconnect = '🔴 Player Disconnected',
        character_create = '📝 Character Created',
        character_delete = '🗑️ Character Deleted',
        character_select = '👤 Character Selected',
        kill = '☠️ Player Kill',
        teamkill = '⚠️ Team Kill',
        death = '💀 Player Death',
        rank_up = '⬆️ Rank Up',
        point_captured = '🏴 Point Captured',
        purchase = '💰 Purchase',
        weapon_unlock = '🔓 Weapon Unlocked',
        weapon_purchase = '🔫 Weapon Purchased',
        vehicle_unlock = '🔓 Vehicle Unlocked',
        vehicle_purchase = '🚗 Vehicle Purchased',
        kick = '👢 Player Kicked',
        warn = '⚠️ Player Warned',
        tempban = '🔨 Temporary Ban',
        permban = '🔨 Permanent Ban',
        unban = '✅ Player Unbanned',
        admin_add_xp = '⭐ Admin Added XP',
        admin_add_money = '💵 Admin Added Money',
        admin_kill = '💀 Admin Kill',
        admin_revive = '❤️ Admin Revive',
        set_money = '💵 Money Set',
        set_xp = '⭐ XP Set',
        skill_upgrade = '📈 Skill Upgraded',
        revive = '❤️ Player Revived',
        whitelist_change = '📋 Whitelist Changed',
        rank_change = '🎖️ Rank Changed'
    }
    
    return titles[eventType] or ('📋 ' .. eventType)
end

-- Get description based on event type
function GetEventDescription(eventType, playerId, playerName, targetId, targetName, data)
    local descriptions = {
        player_connect = playerName .. ' connected to the server',
        player_disconnect = playerName .. ' disconnected from the server',
        character_create = playerName .. ' created a new character',
        character_delete = playerName .. ' deleted a character',
        kill = playerName .. ' killed ' .. (targetName or 'someone'),
        teamkill = playerName .. ' killed teammate ' .. (targetName or 'someone'),
        kick = playerName .. ' kicked ' .. (targetName or 'someone'),
        tempban = playerName .. ' temporarily banned ' .. (targetName or 'someone'),
        permban = playerName .. ' permanently banned ' .. (targetName or 'someone'),
        warn = playerName .. ' warned ' .. (targetName or 'someone')
    }
    
    return descriptions[eventType] or ''
end

-- Format field name for display
function FormatFieldName(name)
    -- Convert snake_case to Title Case
    local formatted = name:gsub('_', ' ')
    formatted = formatted:gsub('(%a)([%w]*)', function(first, rest)
        return first:upper() .. rest:lower()
    end)
    return formatted
end

-- ============================================================================
-- AUTOMATIC EVENT LOGGING
-- ============================================================================

-- Log player connections (called from main.lua)
-- Already handled in main.lua via LogAction calls

-- ============================================================================
-- LOG QUERY COMMANDS
-- ============================================================================

-- Get logs for a player
RegisterCommand('getlogs', function(source, args)
    local src = source
    
    if src ~= 0 and (not MRP.Players[src] or MRP.Players[src].adminLevel < 3) then
        if src ~= 0 then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission' })
        end
        return
    end
    
    local searchTerm = args[1]
    local limit = tonumber(args[2]) or 20
    
    if not searchTerm then
        if src == 0 then
            print('Usage: /getlogs [player_name/event_type] [limit]')
        else
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Usage: /getlogs [search] [limit]' })
        end
        return
    end
    
    local logs = MySQL.query.await([[
        SELECT * FROM mrp_logs 
        WHERE player_name LIKE ? OR target_name LIKE ? OR event_type LIKE ?
        ORDER BY created_at DESC 
        LIMIT ?
    ]], { '%'..searchTerm..'%', '%'..searchTerm..'%', '%'..searchTerm..'%', limit })
    
    if src == 0 then
        print('=== Logs for: ' .. searchTerm .. ' ===')
        for _, log in ipairs(logs or {}) do
            print(string.format('[%s] %s | %s -> %s | %s', 
                log.created_at, log.event_type, log.player_name or 'N/A', log.target_name or 'N/A', log.data or ''))
        end
        print('=== End of logs ===')
    else
        TriggerClientEvent('mrp:showLogs', src, logs)
    end
end, false)

-- Get ban list
RegisterCommand('bans', function(source, args)
    local src = source
    
    if src ~= 0 and (not MRP.Players[src] or MRP.Players[src].adminLevel < 2) then
        if src ~= 0 then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission' })
        end
        return
    end
    
    local bans = MySQL.query.await([[
        SELECT * FROM mrp_bans 
        WHERE expires_at IS NULL OR expires_at > NOW()
        ORDER BY created_at DESC 
        LIMIT 50
    ]])
    
    if src == 0 then
        print('=== Active Bans ===')
        for _, ban in ipairs(bans or {}) do
            local expiry = ban.expires_at or 'PERMANENT'
            print(string.format('[%s] %s | Reason: %s | By: %s | Expires: %s', 
                ban.created_at, ban.license, ban.reason, ban.admin_name, expiry))
        end
        print('=== End of bans ===')
    else
        TriggerClientEvent('mrp:showBans', src, bans)
    end
end, false)

-- ============================================================================
-- CLEANUP OLD LOGS (Optional scheduled task)
-- ============================================================================
CreateThread(function()
    while true do
        Wait(86400000) -- Run once per day (24 hours)
        
        -- Delete logs older than 30 days
        local deleted = MySQL.update.await([[
            DELETE FROM mrp_logs WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)
        ]])
        
        if deleted > 0 then
            Config.Print('Cleaned up', deleted, 'old log entries')
        end
        
        -- Delete expired bans
        local expiredBans = MySQL.update.await([[
            DELETE FROM mrp_bans WHERE expires_at IS NOT NULL AND expires_at < NOW()
        ]])
        
        if expiredBans > 0 then
            Config.Print('Cleaned up', expiredBans, 'expired bans')
        end
    end
end)

Config.Print('server/logging.lua loaded')
