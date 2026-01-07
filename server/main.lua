--[[
    MRP GAMEMODE - SERVER MAIN
    ==========================
    Core server-side logic:
    - Player connection/disconnection
    - Data loading/saving
    - Session management
    - Core utility functions
]]

-- ============================================================================
-- GLOBAL VARIABLES
-- ============================================================================
MRP = MRP or {}
MRP.Players = {}           -- Online players data: [source] = { player data }
MRP.Characters = {}        -- Active character data: [source] = { character data }
MRP.Sessions = {}          -- Session tracking: [source] = { session data }

-- ============================================================================
-- PLAYER CONNECTION
-- ============================================================================
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    local identifiers = GetPlayerIdentifiers(src)
    local license = nil
    local discord = nil
    local steam = nil
    
    -- Extract identifiers
    for _, id in pairs(identifiers) do
        if string.find(id, 'license:') then
            license = id
        elseif string.find(id, 'discord:') then
            discord = id
        elseif string.find(id, 'steam:') then
            steam = id
        end
    end
    
    -- Require license identifier
    if not license then
        deferrals.done('You must have a valid license identifier to join this server.')
        return
    end
    
    deferrals.defer()
    deferrals.update('Checking player data...')
    
    -- Check for bans
    local ban = MySQL.single.await('SELECT * FROM mrp_bans WHERE license = ? AND active = 1 AND (expires_at IS NULL OR expires_at > NOW())', { license })
    
    if ban then
        local expiry = ban.expires_at and ('Expires: ' .. ban.expires_at) or 'Permanent'
        deferrals.done(string.format('You are banned from this server.\nReason: %s\n%s', ban.reason, expiry))
        return
    end
    
    deferrals.update('Loading player data...')
    
    -- Get or create player record
    local player = MySQL.single.await([[
        INSERT INTO mrp_players (license, discord, steam) 
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE 
            discord = COALESCE(VALUES(discord), discord),
            steam = COALESCE(VALUES(steam), steam),
            last_seen = NOW()
    ]], { license, discord, steam })
    
    -- Fetch player data
    player = MySQL.single.await('SELECT * FROM mrp_players WHERE license = ?', { license })
    
    if not player then
        deferrals.done('Failed to load player data. Please try again.')
        return
    end
    
    deferrals.done()
    
    Config.Print('Player connecting:', name, '| License:', license)
end)

-- ============================================================================
-- PLAYER JOINED (Fully Connected)
-- ============================================================================
RegisterNetEvent('mrp:playerJoined', function()
    local src = source
    local identifiers = GetPlayerIdentifiers(src)
    local license = nil
    
    for _, id in pairs(identifiers) do
        if string.find(id, 'license:') then
            license = id
            break
        end
    end
    
    if not license then
        DropPlayer(src, 'Invalid license identifier')
        return
    end
    
    -- Load player data
    local player = MySQL.single.await('SELECT * FROM mrp_players WHERE license = ?', { license })
    
    if not player then
        DropPlayer(src, 'Failed to load player data')
        return
    end
    
    -- Store player data
    MRP.Players[src] = {
        id = player.id,
        visibleid = license,
        discord = player.discord,
        steam = player.steam,
        adminLevel = player.admin_level,
        firstJoin = player.first_join,
        lastSeen = player.last_seen,
        totalPlaytime = player.total_playtime
    }
    
    -- Update last seen
    MySQL.update('UPDATE mrp_players SET last_seen = NOW() WHERE id = ?', { player.id })
    
    -- Log connection
    LogAction('player_connect', license, GetPlayerName(src), nil, nil, {
        playerName = GetPlayerName(src),
        adminLevel = player.admin_level
    })
    
    Config.Print('Player joined:', GetPlayerName(src), '| Source:', src)
    
    -- Send player to character selection
    TriggerClientEvent('mrp:openCharacterSelect', src)
end)

-- ============================================================================
-- PLAYER DROPPED (Disconnected)
-- ============================================================================
AddEventHandler('playerDropped', function(reason)
    local src = source
    local player = MRP.Players[src]
    local character = MRP.Characters[src]
    
    if player then
        -- Save character data if active
        if character then
            SaveCharacter(src)
            
            -- End session
            if MRP.Sessions[src] then
                EndSession(src)
            end
        end
        
        -- Update total playtime
        MySQL.update('UPDATE mrp_players SET last_seen = NOW() WHERE id = ?', { player.id })
        
        -- Log disconnection
        LogAction('player_disconnect', player.visibleid, character and character.name or GetPlayerName(src), nil, nil, {
            reason = reason,
            characterId = character and character.id or nil
        })
        
        Config.Print('Player dropped:', GetPlayerName(src), '| Reason:', reason)
    end
    
    -- Cleanup
    MRP.Players[src] = nil
    MRP.Characters[src] = nil
    MRP.Sessions[src] = nil
    
    -- Notify other clients to remove this player from their lists
    TriggerClientEvent('mrp:playerLeft', -1, src)
end)

-- ============================================================================
-- SESSION MANAGEMENT
-- ============================================================================
function StartSession(src)
    local character = MRP.Characters[src]
    if not character then return end
    
    -- Create session record
    local sessionId = MySQL.insert.await([[
        INSERT INTO mrp_sessions (character_id, session_start)
        VALUES (?, NOW())
    ]], { character.id })
    
    MRP.Sessions[src] = {
        id = sessionId,
        startTime = os.time(),
        kills = 0,
        deaths = 0,
        assists = 0,
        captures = 0,
        xpEarned = 0,
        moneyEarned = 0
    }
    
    Config.Print('Session started for character:', character.name, '| Session ID:', sessionId)
end

function EndSession(src)
    local session = MRP.Sessions[src]
    if not session then return end
    
    -- Update session record
    MySQL.update([[
        UPDATE mrp_sessions SET
            session_end = NOW(),
            kills = ?,
            deaths = ?,
            assists = ?,
            captures = ?,
            xp_earned = ?,
            money_earned = ?
        WHERE id = ?
    ]], {
        session.kills,
        session.deaths,
        session.assists,
        session.captures,
        session.xpEarned,
        session.moneyEarned,
        session.id
    })
    
    Config.Print('Session ended | ID:', session.id, '| Duration:', os.time() - session.startTime, 'seconds')
end

-- ============================================================================
-- CHARACTER SAVING
-- ============================================================================
function SaveCharacter(src)
    local character = MRP.Characters[src]
    if not character then return end
    
    MySQL.update([[
        UPDATE mrp_characters SET
            rank_id = ?,
            whitelist = ?,
            xp = ?,
            money = ?,
            kills = ?,
            deaths = ?,
            assists = ?,
            captures = ?,
            playtime = ?,
            last_played = NOW()
        WHERE id = ?
    ]], {
        character.rankId,
        character.whitelist,
        character.xp,
        character.money,
        character.kills,
        character.deaths,
        character.assists,
        character.captures,
        character.playtime,
        character.id
    })
    
    Config.Print('Character saved:', character.name)
end

-- Auto-save every 5 minutes
CreateThread(function()
    while true do
        Wait(300000) -- 5 minutes
        
        for src, character in pairs(MRP.Characters) do
            if character then
                -- Update playtime
                if MRP.Sessions[src] then
                    local sessionMinutes = math.floor((os.time() - MRP.Sessions[src].startTime) / 60)
                    character.playtime = character.playtime + sessionMinutes
                    MRP.Sessions[src].startTime = os.time() -- Reset for next interval
                end
                
                SaveCharacter(src)
            end
        end
        
        Config.Print('Auto-save completed for', GetTableLength(MRP.Characters), 'characters')
    end
end)

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================
function GetTableLength(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

function GetPlayerByLicense(license)
    for src, player in pairs(MRP.Players) do
        if player.visibleid == license then
            return src, player
        end
    end
    return nil, nil
end

function GetPlayerByCharacterId(characterId)
    for src, character in pairs(MRP.Characters) do
        if character.id == characterId then
            return src, character
        end
    end
    return nil, nil
end

function GetRankFromXP(xp, faction)
    local ranks = Config.Ranks[faction] or Config.Ranks[1]
    local currentRank = ranks[1]
    
    for _, rank in ipairs(ranks) do
        if xp >= rank.xpRequired then
            currentRank = rank
        else
            break
        end
    end
    
    return currentRank
end

function GetRankById(rankId, faction)
    local ranks = Config.Ranks[faction] or Config.Ranks[1]
    for _, rank in ipairs(ranks) do
        if rank.id == rankId then
            return rank
        end
    end
    return ranks[1]
end

-- ============================================================================
-- LOGGING
-- ============================================================================
function LogAction(actionType, actorLicense, actorName, targetLicense, targetName, details)
    -- Database logging
    if Config.Logging.dbLogging then
        MySQL.insert([[
            INSERT INTO mrp_logs (action_type, actor_license, actor_name, target_license, target_name, details)
            VALUES (?, ?, ?, ?, ?, ?)
        ]], {
            actionType,
            actorLicense,
            actorName,
            targetLicense,
            targetName,
            details and json.encode(details) or nil
        })
    end
    
    -- Discord webhook
    if Config.Logging.discordWebhook and Config.Logging.discordWebhook ~= '' then
        -- Check if this event type should be logged
        local shouldLog = false
        for _, event in ipairs(Config.Logging.logEvents) do
            if event == actionType then
                shouldLog = true
                break
            end
        end
        
        if shouldLog then
            PerformHttpRequest(Config.Logging.discordWebhook, function(err, text, headers) end, 'POST', json.encode({
                embeds = {{
                    title = 'MRP Log: ' .. actionType,
                    description = string.format('**Actor:** %s\n**Target:** %s\n**Details:** %s',
                        actorName or 'N/A',
                        targetName or 'N/A',
                        details and json.encode(details) or 'N/A'
                    ),
                    color = 3447003,
                    timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
                }}
            }), { ['Content-Type'] = 'application/json' })
        end
    end
end

-- Export logging function for other scripts
exports('LogAction', LogAction)

-- ============================================================================
-- SYNC PLAYER DATA TO CLIENTS
-- ============================================================================
function SyncAllPlayersToClient(targetSrc)
    local playersData = {}
    
    for src, character in pairs(MRP.Characters) do
        if character and character.faction > 0 then
            playersData[src] = {
                name = character.name,
                faction = character.faction,
                rankId = character.rankId,
                whitelist = character.whitelist,
                xp = character.xp,
                kills = character.kills,
                deaths = character.deaths
            }
        end
    end
    
    if targetSrc then
        TriggerClientEvent('mrp:syncAllPlayers', targetSrc, playersData)
    else
        TriggerClientEvent('mrp:syncAllPlayers', -1, playersData)
    end
end

-- Sync players periodically
CreateThread(function()
    while true do
        Wait(10000) -- Every 10 seconds
        SyncAllPlayersToClient()
    end
end)

-- ============================================================================
-- CLIENT REQUESTS
-- ============================================================================
RegisterNetEvent('mrp:requestPlayerData', function()
    local src = source
    local character = MRP.Characters[src]
    
    if character then
        TriggerClientEvent('mrp:receivePlayerData', src, character)
    end
end)

-- ============================================================================
-- RESOURCE START
-- ============================================================================
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    Config.Print('========================================')
    Config.Print('MRP Gamemode - Server Starting')
    Config.Print('========================================')
    
    -- Reset any stale sessions from server crash
    MySQL.update('UPDATE mrp_sessions SET session_end = NOW() WHERE session_end IS NULL')
    
    Config.Print('Server initialized successfully')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Save all characters
    for src, character in pairs(MRP.Characters) do
        if character then
            SaveCharacter(src)
            EndSession(src)
        end
    end
    
    Config.Print('Server stopped - All data saved')
end)

Config.Print('server/main.lua loaded')
