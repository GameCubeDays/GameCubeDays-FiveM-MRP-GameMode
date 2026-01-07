--[[
    MRP GAMEMODE - SERVER CHARACTERS
    =================================
    Character management:
    - Create new characters
    - Load existing characters
    - Delete characters
    - Switch between characters
]]

-- ============================================================================
-- GET PLAYER CHARACTERS
-- ============================================================================
RegisterNetEvent('mrp:getCharacters', function()
    local src = source
    local player = MRP.Players[src]
    
    if not player then
        Config.Print('ERROR: Player not found for source:', src)
        return
    end
    
    -- Fetch all characters for this player
    local characters = MySQL.query.await([[
        SELECT 
            c.*,
            (SELECT COUNT(*) FROM mrp_character_skills WHERE character_id = c.id) as skill_count,
            (SELECT COUNT(*) FROM mrp_character_unlocks WHERE character_id = c.id) as unlock_count
        FROM mrp_characters c
        WHERE c.license = ?
        ORDER BY c.faction
    ]], { player.visibleid })
    
    -- Format character data for client
    local formattedCharacters = {}
    for _, char in ipairs(characters or {}) do
        local rank = GetRankById(char.rank_id, char.faction)
        
        formattedCharacters[char.faction] = {
            id = char.id,
            name = char.name,
            faction = char.faction,
            factionName = Config.Factions[char.faction] and Config.Factions[char.faction].name or 'Unknown',
            rankId = char.rank_id,
            rankName = rank.name,
            rankAbbr = rank.abbr,
            whitelist = char.whitelist,
            whitelistName = GetWhitelistName(char.faction, char.whitelist),
            xp = char.xp,
            money = char.money,
            kills = char.kills,
            deaths = char.deaths,
            assists = char.assists,
            captures = char.captures,
            playtime = char.playtime,
            skillCount = char.skill_count,
            unlockCount = char.unlock_count,
            lastPlayed = char.last_played
        }
    end
    
    Config.Print('Sending', #(characters or {}), 'characters to player:', src)
    TriggerClientEvent('mrp:receiveCharacters', src, formattedCharacters)
end)

-- ============================================================================
-- CREATE CHARACTER
-- ============================================================================
RegisterNetEvent('mrp:createCharacter', function(data)
    local src = source
    local player = MRP.Players[src]
    
    if not player then
        TriggerClientEvent('mrp:characterCreateResult', src, false, 'Player data not found')
        return
    end
    
    local faction = tonumber(data.faction)
    local name = data.name
    
    -- Validate faction
    if not faction or faction < 1 or faction > 3 then
        TriggerClientEvent('mrp:characterCreateResult', src, false, 'Invalid faction selected')
        return
    end
    
    -- Validate name
    if not name or #name < 3 or #name > 20 then
        TriggerClientEvent('mrp:characterCreateResult', src, false, 'Name must be 3-20 characters')
        return
    end
    
    -- Check for valid characters (alphanumeric and spaces only)
    if not string.match(name, '^[%w%s]+$') then
        TriggerClientEvent('mrp:characterCreateResult', src, false, 'Name can only contain letters, numbers, and spaces')
        return
    end
    
    -- Check if character already exists for this faction
    local existing = MySQL.single.await(
        'SELECT id FROM mrp_characters WHERE license = ? AND faction = ?',
        { player.visibleid, faction }
    )
    
    if existing then
        TriggerClientEvent('mrp:characterCreateResult', src, false, 'You already have a character in this faction')
        return
    end
    
    -- Check if name is taken (optional - remove if you want duplicate names)
    local nameTaken = MySQL.single.await(
        'SELECT id FROM mrp_characters WHERE name = ?',
        { name }
    )
    
    if nameTaken then
        TriggerClientEvent('mrp:characterCreateResult', src, false, 'This name is already taken')
        return
    end
    
    -- Get default whitelist for faction
    local defaultWhitelist = Config.DefaultWhitelist[faction] or 'recruit'
    
    -- Create character
    local characterId = MySQL.insert.await([[
        INSERT INTO mrp_characters (player_id, license, faction, name, rank_id, whitelist, money)
        VALUES (?, ?, ?, ?, 1, ?, ?)
    ]], {
        player.id,
        player.visibleid,
        faction,
        name,
        defaultWhitelist,
        Config.Money.startingMoney
    })
    
    if not characterId then
        TriggerClientEvent('mrp:characterCreateResult', src, false, 'Failed to create character')
        return
    end
    
    -- Log character creation
    LogAction('character_create', player.visibleid, name, nil, nil, {
        characterId = characterId,
        faction = faction,
        factionName = Config.Factions[faction].name
    })
    
    Config.Print('Character created:', name, '| Faction:', faction, '| ID:', characterId)
    
    TriggerClientEvent('mrp:characterCreateResult', src, true, 'Character created successfully')
    
    -- Refresh character list
    TriggerEvent('mrp:getCharacters')
end)

-- ============================================================================
-- SELECT CHARACTER
-- ============================================================================
RegisterNetEvent('mrp:selectCharacter', function(faction)
    local src = source
    local player = MRP.Players[src]
    
    if not player then
        TriggerClientEvent('mrp:characterSelectResult', src, false, 'Player data not found')
        return
    end
    
    faction = tonumber(faction)
    
    if not faction or faction < 1 or faction > 3 then
        TriggerClientEvent('mrp:characterSelectResult', src, false, 'Invalid faction')
        return
    end
    
    -- End current session if switching characters
    if MRP.Characters[src] then
        SaveCharacter(src)
        EndSession(src)
    end
    
    -- Load character data
    local character = MySQL.single.await([[
        SELECT * FROM mrp_characters WHERE license = ? AND faction = ?
    ]], { player.visibleid, faction })
    
    if not character then
        TriggerClientEvent('mrp:characterSelectResult', src, false, 'Character not found')
        return
    end
    
    -- Load skills
    local skills = MySQL.query.await([[
        SELECT skill_id, level FROM mrp_character_skills WHERE character_id = ?
    ]], { character.id })
    
    local skillsMap = {}
    for _, skill in ipairs(skills or {}) do
        skillsMap[skill.skill_id] = skill.level
    end
    
    -- Load unlocks
    local unlocks = MySQL.query.await([[
        SELECT item_type, item_id FROM mrp_character_unlocks WHERE character_id = ?
    ]], { character.id })
    
    local unlocksMap = { weapons = {}, vehicles = {} }
    for _, unlock in ipairs(unlocks or {}) do
        if unlock.item_type == 'weapon' then
            unlocksMap.weapons[unlock.item_id] = true
        elseif unlock.item_type == 'vehicle' then
            unlocksMap.vehicles[unlock.item_id] = true
        end
    end
    
    -- Get rank data
    local rank = GetRankById(character.rank_id, character.faction)
    
    -- Store active character
    MRP.Characters[src] = {
        id = character.id,
        name = character.name,
        faction = character.faction,
        factionName = Config.Factions[character.faction].name,
        rankId = character.rank_id,
        rankName = rank.name,
        rankAbbr = rank.abbr,
        whitelist = character.whitelist,
        whitelistName = GetWhitelistName(character.faction, character.whitelist),
        xp = character.xp,
        money = character.money,
        kills = character.kills,
        deaths = character.deaths,
        assists = character.assists,
        captures = character.captures,
        playtime = character.playtime,
        skills = skillsMap,
        unlocks = unlocksMap
    }
    
    -- Start new session
    StartSession(src)
    
    -- Update last played
    MySQL.update('UPDATE mrp_characters SET last_played = NOW() WHERE id = ?', { character.id })
    
    Config.Print('Character selected:', character.name, '| Faction:', character.faction, '| Player:', src)
    
    -- Send character data to client
    TriggerClientEvent('mrp:characterSelectResult', src, true, 'Character loaded')
    TriggerClientEvent('mrp:characterLoaded', src, MRP.Characters[src])
    
    -- Sync to all players
    SyncAllPlayersToClient()
end)

-- ============================================================================
-- DELETE CHARACTER
-- ============================================================================
RegisterNetEvent('mrp:deleteCharacter', function(faction)
    local src = source
    local player = MRP.Players[src]
    
    if not player then
        TriggerClientEvent('mrp:characterDeleteResult', src, false, 'Player data not found')
        return
    end
    
    faction = tonumber(faction)
    
    if not faction or faction < 1 or faction > 3 then
        TriggerClientEvent('mrp:characterDeleteResult', src, false, 'Invalid faction')
        return
    end
    
    -- Check if trying to delete active character
    if MRP.Characters[src] and MRP.Characters[src].faction == faction then
        TriggerClientEvent('mrp:characterDeleteResult', src, false, 'Cannot delete active character. Switch characters first.')
        return
    end
    
    -- Get character info for logging
    local character = MySQL.single.await(
        'SELECT id, name FROM mrp_characters WHERE license = ? AND faction = ?',
        { player.visibleid, faction }
    )
    
    if not character then
        TriggerClientEvent('mrp:characterDeleteResult', src, false, 'Character not found')
        return
    end
    
    -- Delete character (cascades to skills, unlocks, sessions)
    MySQL.update('DELETE FROM mrp_characters WHERE id = ?', { character.id })
    
    -- Log deletion
    LogAction('character_delete', player.visibleid, character.name, nil, nil, {
        characterId = character.id,
        faction = faction,
        factionName = Config.Factions[faction].name
    })
    
    Config.Print('Character deleted:', character.name, '| ID:', character.id)
    
    TriggerClientEvent('mrp:characterDeleteResult', src, true, 'Character deleted')
    
    -- Refresh character list
    TriggerEvent('mrp:getCharacters')
end)

-- ============================================================================
-- SWITCH CHARACTER (Return to selection)
-- ============================================================================
RegisterNetEvent('mrp:switchCharacter', function()
    local src = source
    local player = MRP.Players[src]
    
    if not player then return end
    
    -- Save and end current session
    if MRP.Characters[src] then
        SaveCharacter(src)
        EndSession(src)
        
        Config.Print('Player switching characters:', src)
        
        MRP.Characters[src] = nil
        MRP.Sessions[src] = nil
    end
    
    -- Open character selection
    TriggerClientEvent('mrp:openCharacterSelect', src)
    
    -- Sync to all players
    SyncAllPlayersToClient()
end)

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================
function GetWhitelistName(faction, whitelistId)
    local whitelists = Config.Whitelists[faction]
    if not whitelists then return 'Unknown' end
    
    for _, wl in ipairs(whitelists) do
        if wl.id == whitelistId then
            return wl.name
        end
    end
    
    return 'Recruit'
end

-- ============================================================================
-- UPDATE CHARACTER STATS
-- ============================================================================
function UpdateCharacterStats(src, updates)
    local character = MRP.Characters[src]
    if not character then return false end
    
    for key, value in pairs(updates) do
        if character[key] ~= nil then
            character[key] = value
        end
    end
    
    -- Send updated stats to client
    TriggerClientEvent('mrp:updateStats', src, character)
    
    return true
end

-- Export for other scripts
exports('UpdateCharacterStats', UpdateCharacterStats)
exports('GetCharacter', function(src) return MRP.Characters[src] end)
exports('GetPlayer', function(src) return MRP.Players[src] end)
exports('SaveCharacter', SaveCharacter)

-- ============================================================================
-- ADMIN: SET RANK
-- ============================================================================
RegisterNetEvent('mrp:admin:setRank', function(targetId, rankId)
    local src = source
    local player = MRP.Players[src]
    local targetCharacter = MRP.Characters[targetId]
    
    if not player or player.adminLevel < 3 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Insufficient permissions' })
        return
    end
    
    if not targetCharacter then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Target not found' })
        return
    end
    
    local oldRank = targetCharacter.rankId
    local newRank = GetRankById(rankId, targetCharacter.faction)
    
    targetCharacter.rankId = rankId
    targetCharacter.rankName = newRank.name
    targetCharacter.rankAbbr = newRank.abbr
    
    SaveCharacter(targetId)
    TriggerClientEvent('mrp:updateStats', targetId, targetCharacter)
    TriggerClientEvent('mrp:rankChanged', targetId, newRank)
    
    -- Log
    LogAction('promotion', player.visibleid, MRP.Characters[src] and MRP.Characters[src].name or 'Admin', 
        MRP.Players[targetId].visibleid, targetCharacter.name, {
        oldRank = oldRank,
        newRank = rankId,
        newRankName = newRank.name
    })
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Rank updated to ' .. newRank.name })
    TriggerClientEvent('ox_lib:notify', targetId, { type = 'info', description = 'Your rank has been changed to ' .. newRank.name })
    
    SyncAllPlayersToClient()
end)

-- ============================================================================
-- ADMIN: SET WHITELIST
-- ============================================================================
RegisterNetEvent('mrp:admin:setWhitelist', function(targetId, whitelistId)
    local src = source
    local player = MRP.Players[src]
    local targetCharacter = MRP.Characters[targetId]
    
    if not player or player.adminLevel < 3 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Insufficient permissions' })
        return
    end
    
    if not targetCharacter then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Target not found' })
        return
    end
    
    local oldWhitelist = targetCharacter.whitelist
    local newWhitelistName = GetWhitelistName(targetCharacter.faction, whitelistId)
    
    targetCharacter.whitelist = whitelistId
    targetCharacter.whitelistName = newWhitelistName
    
    SaveCharacter(targetId)
    TriggerClientEvent('mrp:updateStats', targetId, targetCharacter)
    TriggerClientEvent('mrp:whitelistChanged', targetId, whitelistId, newWhitelistName)
    
    -- Log
    LogAction('whitelist_change', player.visibleid, MRP.Characters[src] and MRP.Characters[src].name or 'Admin',
        MRP.Players[targetId].visibleid, targetCharacter.name, {
        oldWhitelist = oldWhitelist,
        newWhitelist = whitelistId,
        newWhitelistName = newWhitelistName
    })
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Whitelist updated to ' .. newWhitelistName })
    TriggerClientEvent('ox_lib:notify', targetId, { type = 'info', description = 'Your whitelist has been changed to ' .. newWhitelistName })
    
    SyncAllPlayersToClient()
end)

Config.Print('server/characters.lua loaded')
