--[[
    MRP GAMEMODE - SERVER PROGRESSION
    ==================================
    Handles all progression mechanics:
    - XP earning (kills, assists, captures, time)
    - Rank calculation and auto-promotion
    - Skill upgrades
    - 30-minute tick rewards
    - Kill streaks
]]

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================
local PlayerKillStreaks = {}      -- [source] = current streak count
local PlayerLastDamage = {}       -- [victimSource] = { [attackerSource] = timestamp }

-- ============================================================================
-- XP FUNCTIONS
-- ============================================================================

-- Award XP to a player
function AwardXP(src, amount, reason)
    local character = MRP.Characters[src]
    if not character then return false end
    
    -- Apply XP bonus skill
    local xpBonus = GetSkillEffect(src, 'xp_bonus')
    local finalAmount = math.floor(amount * (1 + xpBonus))
    
    -- Update character
    character.xp = character.xp + finalAmount
    
    -- Track in session
    if MRP.Sessions[src] then
        MRP.Sessions[src].xpEarned = MRP.Sessions[src].xpEarned + finalAmount
    end
    
    -- Check for rank up
    CheckRankUp(src)
    
    -- Notify client
    TriggerClientEvent('mrp:xpGained', src, finalAmount, reason, character.xp)
    
    -- Update client stats
    TriggerClientEvent('mrp:updateStats', src, { xp = character.xp, rankId = character.rankId, rankName = character.rankName, rankAbbr = character.rankAbbr })
    
    Config.Print('XP awarded to', character.name, ':', finalAmount, '(', reason, ')')
    
    return true
end

-- Remove XP from a player (penalties)
function RemoveXP(src, amount, reason)
    local character = MRP.Characters[src]
    if not character then return false end
    
    -- Don't go below 0
    character.xp = math.max(0, character.xp - amount)
    
    -- Notify client
    TriggerClientEvent('mrp:xpLost', src, amount, reason, character.xp)
    
    -- Update client stats
    TriggerClientEvent('mrp:updateStats', src, { xp = character.xp })
    
    Config.Print('XP removed from', character.name, ':', amount, '(', reason, ')')
    
    return true
end

-- Export for other scripts
exports('AwardXP', AwardXP)
exports('RemoveXP', RemoveXP)

-- ============================================================================
-- MONEY FUNCTIONS
-- ============================================================================

-- Award money to a player
function AwardMoney(src, amount, reason)
    local character = MRP.Characters[src]
    if not character then return false end
    
    -- Apply money bonus skill for capture-related earnings
    if reason and string.find(reason:lower(), 'capture') then
        local moneyBonus = GetSkillEffect(src, 'money_bonus')
        amount = math.floor(amount * (1 + moneyBonus))
    end
    
    -- Update character
    character.money = character.money + amount
    
    -- Track in session
    if MRP.Sessions[src] then
        MRP.Sessions[src].moneyEarned = MRP.Sessions[src].moneyEarned + amount
    end
    
    -- Notify client
    TriggerClientEvent('mrp:moneyGained', src, amount, reason, character.money)
    
    -- Update client stats
    TriggerClientEvent('mrp:updateStats', src, { money = character.money })
    
    Config.Print('Money awarded to', character.name, ':', amount, '(', reason, ')')
    
    return true
end

-- Remove money from a player
function RemoveMoney(src, amount, reason)
    local character = MRP.Characters[src]
    if not character then return false end
    
    -- Check if player has enough
    if character.money < amount then
        return false
    end
    
    -- Update character
    character.money = character.money - amount
    
    -- Notify client
    TriggerClientEvent('mrp:moneyLost', src, amount, reason, character.money)
    
    -- Update client stats
    TriggerClientEvent('mrp:updateStats', src, { money = character.money })
    
    Config.Print('Money removed from', character.name, ':', amount, '(', reason, ')')
    
    return true
end

-- Check if player can afford something
function CanAfford(src, amount)
    local character = MRP.Characters[src]
    if not character then return false end
    return character.money >= amount
end

-- Export for other scripts
exports('AwardMoney', AwardMoney)
exports('RemoveMoney', RemoveMoney)
exports('CanAfford', CanAfford)

-- ============================================================================
-- RANK FUNCTIONS
-- ============================================================================

-- Check if player should rank up
function CheckRankUp(src)
    local character = MRP.Characters[src]
    if not character then return end
    
    local ranks = Config.Ranks[character.faction]
    if not ranks then return end
    
    local currentRank = character.rankId
    local newRank = currentRank
    
    -- Find highest rank player qualifies for
    for _, rank in ipairs(ranks) do
        if character.xp >= rank.xpRequired then
            newRank = rank.id
        end
    end
    
    -- Check if rank changed
    if newRank > currentRank then
        local rankData = GetRankById(newRank, character.faction)
        
        character.rankId = newRank
        character.rankName = rankData.name
        character.rankAbbr = rankData.abbr
        
        -- Notify player
        TriggerClientEvent('mrp:rankUp', src, rankData)
        
        -- Announce to faction (optional)
        AnnounceToFaction(character.faction, string.format('%s has been promoted to %s!', character.name, rankData.name))
        
        -- Log the promotion
        LogAction('rank_up', MRP.Players[src].visibleid, character.name, nil, nil, {
            oldRank = currentRank,
            newRank = newRank,
            newRankName = rankData.name
        })
        
        Config.Print('Player ranked up:', character.name, 'to', rankData.name)
        
        -- Sync to all players
        SyncAllPlayersToClient()
    end
end

-- Announce message to all players in a faction
function AnnounceToFaction(faction, message)
    for src, character in pairs(MRP.Characters) do
        if character and character.faction == faction then
            TriggerClientEvent('mrp:factionAnnouncement', src, message)
        end
    end
end

-- ============================================================================
-- KILL TRACKING
-- ============================================================================

-- Track damage for assists
RegisterNetEvent('mrp:playerDamaged', function(attackerSrc)
    local victimSrc = source
    
    if not PlayerLastDamage[victimSrc] then
        PlayerLastDamage[victimSrc] = {}
    end
    
    PlayerLastDamage[victimSrc][attackerSrc] = os.time()
end)

-- Process a kill
function ProcessKill(killerSrc, victimSrc, isHeadshot, weaponHash)
    local killer = MRP.Characters[killerSrc]
    local victim = MRP.Characters[victimSrc]
    
    if not killer or not victim then return end
    
    local killerFaction = killer.faction
    local victimFaction = victim.faction
    
    -- Check for team kill
    local isTeamKill = (killerFaction == victimFaction and killerFaction ~= 3)
    local isCivilianKill = (victimFaction == 3)
    
    if isTeamKill then
        -- Team kill penalty
        RemoveXP(killerSrc, math.abs(Config.XP.teamKillPenalty), 'Team Kill')
        RemoveMoney(killerSrc, math.abs(Config.Money.teamKillPenalty), 'Team Kill')
        
        lib.notify(killerSrc, {
            title = 'Team Kill!',
            description = 'You killed a teammate!',
            type = 'error'
        })
        
        -- Reset kill streak
        PlayerKillStreaks[killerSrc] = 0
        
    elseif isCivilianKill then
        -- Civilian kill penalty
        RemoveXP(killerSrc, math.abs(Config.XP.civilianKillPenalty), 'Civilian Kill')
        RemoveMoney(killerSrc, math.abs(Config.Money.civilianKillPenalty), 'Civilian Kill')
        
        -- Reset kill streak
        PlayerKillStreaks[killerSrc] = 0
        
    else
        -- Valid enemy kill
        local xpAmount = Config.XP.killBase
        
        -- Kill streak bonus
        PlayerKillStreaks[killerSrc] = (PlayerKillStreaks[killerSrc] or 0) + 1
        local streak = PlayerKillStreaks[killerSrc]
        
        if streak > 0 and streak % Config.XP.streakThreshold == 0 then
            local streakMultiplier = math.floor(streak / Config.XP.streakThreshold)
            local bonusPercent = Config.XP.streakBonusPercent * streakMultiplier
            xpAmount = math.floor(xpAmount * (1 + bonusPercent))
            
            -- Announce kill streak
            AnnounceToServer(string.format('%s is on a %d kill streak!', killer.name, streak))
        end
        
        -- Award XP
        AwardXP(killerSrc, xpAmount, 'Enemy Kill')
        
        -- Update kill count
        killer.kills = killer.kills + 1
        TriggerClientEvent('mrp:updateStats', killerSrc, { kills = killer.kills })
        
        -- Track session
        if MRP.Sessions[killerSrc] then
            MRP.Sessions[killerSrc].kills = MRP.Sessions[killerSrc].kills + 1
        end
    end
    
    -- Process assists
    ProcessAssists(killerSrc, victimSrc)
    
    -- Update victim death count
    victim.deaths = victim.deaths + 1
    TriggerClientEvent('mrp:updateStats', victimSrc, { deaths = victim.deaths })
    
    -- Track victim session
    if MRP.Sessions[victimSrc] then
        MRP.Sessions[victimSrc].deaths = MRP.Sessions[victimSrc].deaths + 1
    end
    
    -- Reset victim kill streak
    PlayerKillStreaks[victimSrc] = 0
    
    -- Send kill feed to all players
    TriggerClientEvent('mrp:killFeed', -1, {
        killer = killer.name,
        killerFaction = killerFaction,
        victim = victim.name,
        victimFaction = victimFaction,
        isTeamKill = isTeamKill,
        isHeadshot = isHeadshot,
        weapon = weaponHash
    })
    
    -- Log the kill
    LogAction('kill', MRP.Players[killerSrc].visibleid, killer.name, MRP.Players[victimSrc].visibleid, victim.name, {
        isTeamKill = isTeamKill,
        isCivilianKill = isCivilianKill,
        weapon = weaponHash
    })
end

-- Process assists for a kill
function ProcessAssists(killerSrc, victimSrc)
    local damagers = PlayerLastDamage[victimSrc]
    if not damagers then return end
    
    local currentTime = os.time()
    local assistWindow = Config.XP.killAssistWindow
    
    for attackerSrc, timestamp in pairs(damagers) do
        -- Skip the killer
        if attackerSrc ~= killerSrc then
            -- Check if within assist window
            if (currentTime - timestamp) <= assistWindow then
                local attacker = MRP.Characters[attackerSrc]
                if attacker then
                    -- Same faction as killer (valid assist)
                    local killer = MRP.Characters[killerSrc]
                    if killer and attacker.faction == killer.faction then
                        local assistXP = math.floor(Config.XP.killBase * Config.XP.killAssistPercent)
                        AwardXP(attackerSrc, assistXP, 'Kill Assist')
                        
                        -- Update assist count
                        attacker.assists = attacker.assists + 1
                        TriggerClientEvent('mrp:updateStats', attackerSrc, { assists = attacker.assists })
                        
                        -- Track session
                        if MRP.Sessions[attackerSrc] then
                            MRP.Sessions[attackerSrc].assists = MRP.Sessions[attackerSrc].assists + 1
                        end
                    end
                end
            end
        end
    end
    
    -- Clear damage tracking for victim
    PlayerLastDamage[victimSrc] = nil
end

-- Announce to entire server
function AnnounceToServer(message)
    TriggerClientEvent('mrp:serverAnnouncement', -1, message)
end

-- Export kill processing
exports('ProcessKill', ProcessKill)

-- ============================================================================
-- SKILLS
-- ============================================================================

-- Get skill effect for a player
function GetSkillEffect(src, skillId)
    local character = MRP.Characters[src]
    if not character or not character.skills then return 0 end
    
    local level = character.skills[skillId] or 0
    if level == 0 then return 0 end
    
    -- Find skill definition
    for _, skill in ipairs(Config.Skills.list) do
        if skill.id == skillId then
            local effect = skill.effectPerLevel * level
            return math.min(effect, skill.maxEffect)
        end
    end
    
    return 0
end

-- Calculate skill upgrade cost
function GetSkillUpgradeCost(currentLevel)
    local baseCost = Config.Skills.xpCostBase
    local multiplier = Config.Skills.xpCostMultiplier
    
    -- Cost = base * multiplier^level
    return math.floor(baseCost * (multiplier ^ currentLevel))
end

-- Upgrade a skill
RegisterNetEvent('mrp:upgradeSkill', function(skillId)
    local src = source
    local character = MRP.Characters[src]
    
    if not character then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Character not loaded' })
        return
    end
    
    -- Find skill
    local skillDef = nil
    for _, skill in ipairs(Config.Skills.list) do
        if skill.id == skillId then
            skillDef = skill
            break
        end
    end
    
    if not skillDef then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid skill' })
        return
    end
    
    -- Initialize skills if needed
    if not character.skills then
        character.skills = {}
    end
    
    local currentLevel = character.skills[skillId] or 0
    
    -- Check max level
    if currentLevel >= Config.Skills.maxLevel then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Skill already at max level' })
        return
    end
    
    -- Calculate cost
    local cost = GetSkillUpgradeCost(currentLevel)
    
    -- Check if player has enough XP
    if character.xp < cost then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Not enough XP. Need ' .. cost .. ' XP' })
        return
    end
    
    -- Deduct XP and upgrade
    character.xp = character.xp - cost
    character.skills[skillId] = currentLevel + 1
    
    -- Save to database
    MySQL.insert([[
        INSERT INTO mrp_character_skills (character_id, skill_id, level)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE level = ?
    ]], { character.id, skillId, character.skills[skillId], character.skills[skillId] })
    
    -- Notify client
    TriggerClientEvent('ox_lib:notify', src, { 
        type = 'success', 
        description = string.format('%s upgraded to level %d', skillDef.name, character.skills[skillId])
    })
    
    -- Update client stats
    TriggerClientEvent('mrp:updateStats', src, { xp = character.xp, skills = character.skills })
    TriggerClientEvent('mrp:skillUpgraded', src, skillId, character.skills[skillId])
    
    -- Log
    LogAction('skill_upgrade', MRP.Players[src].visibleid, character.name, nil, nil, {
        skill = skillId,
        newLevel = character.skills[skillId],
        xpCost = cost
    })
    
    Config.Print('Skill upgraded:', character.name, '-', skillId, 'to level', character.skills[skillId])
end)

-- Get player skills
RegisterNetEvent('mrp:getSkills', function()
    local src = source
    local character = MRP.Characters[src]
    
    if not character then return end
    
    TriggerClientEvent('mrp:receiveSkills', src, character.skills or {}, Config.Skills)
end)

-- Export for other scripts
exports('GetSkillEffect', GetSkillEffect)

-- ============================================================================
-- 30-MINUTE TICK REWARDS
-- ============================================================================
CreateThread(function()
    while true do
        Wait(Config.ServerTickRate) -- 30 minutes
        
        Config.Print('========================================')
        Config.Print('30-Minute Tick - Processing Rewards')
        Config.Print('========================================')
        
        -- Get capture point status
        local pointsHeld = {}
        for factionId = 1, 3 do
            pointsHeld[factionId] = 0
        end
        
        -- Count points per faction (this will be replaced with actual capture point data in Phase 6)
        -- For now, we'll use a placeholder
        local capturePoints = exports[Config.ResourceName]:GetCapturePoints()
        if capturePoints then
            for _, point in pairs(capturePoints) do
                if point.owner and point.owner > 0 then
                    pointsHeld[point.owner] = (pointsHeld[point.owner] or 0) + 1
                end
            end
        end
        
        -- Process each online player
        for src, character in pairs(MRP.Characters) do
            if character and character.faction ~= 3 then -- Civilians don't get tick rewards
                -- Calculate XP reward
                local xpReward = Config.XP.tickBase
                local factionPoints = pointsHeld[character.faction] or 0
                xpReward = xpReward + (Config.XP.tickPerPoint * factionPoints)
                
                -- Calculate money reward
                local moneyReward = Config.Money.tickByRank[character.rankId] or Config.Money.tickByRank[1]
                moneyReward = moneyReward + (Config.Money.tickPerPoint * factionPoints)
                
                -- Award rewards
                AwardXP(src, xpReward, '30-Min Tick')
                AwardMoney(src, moneyReward, '30-Min Tick')
                
                -- Notify player
                TriggerClientEvent('mrp:tickReward', src, xpReward, moneyReward, factionPoints)
                
                Config.Print('Tick reward for', character.name, '- XP:', xpReward, 'Money:', moneyReward)
            end
        end
        
        Config.Print('30-Minute Tick Complete')
        Config.Print('========================================')
    end
end)

-- ============================================================================
-- CLIENT REQUESTS
-- ============================================================================

-- Get leaderboard data
RegisterNetEvent('mrp:getLeaderboard', function(type)
    local src = source
    local leaderboard = {}
    
    if type == 'xp' then
        leaderboard = MySQL.query.await([[
            SELECT name, faction, xp, kills, deaths, captures 
            FROM mrp_characters 
            ORDER BY xp DESC 
            LIMIT 20
        ]])
    elseif type == 'kills' then
        leaderboard = MySQL.query.await([[
            SELECT name, faction, kills, deaths, xp, captures 
            FROM mrp_characters 
            ORDER BY kills DESC 
            LIMIT 20
        ]])
    elseif type == 'captures' then
        leaderboard = MySQL.query.await([[
            SELECT name, faction, captures, xp, kills, deaths 
            FROM mrp_characters 
            ORDER BY captures DESC 
            LIMIT 20
        ]])
    end
    
    TriggerClientEvent('mrp:receiveLeaderboard', src, type, leaderboard or {})
end)

-- ============================================================================
-- ADMIN COMMANDS
-- ============================================================================

-- Add XP command
RegisterNetEvent('mrp:admin:addXP', function(targetId, amount)
    local src = source
    local player = MRP.Players[src]
    
    if not player or player.adminLevel < 2 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Insufficient permissions' })
        return
    end
    
    targetId = tonumber(targetId)
    amount = tonumber(amount)
    
    if not targetId or not amount then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid parameters' })
        return
    end
    
    local target = MRP.Characters[targetId]
    if not target then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Target not found' })
        return
    end
    
    AwardXP(targetId, amount, 'Admin Grant')
    
    LogAction('admin_add_xp', player.visibleid, MRP.Characters[src] and MRP.Characters[src].name or 'Admin',
        MRP.Players[targetId].visibleid, target.name, { amount = amount })
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Added ' .. amount .. ' XP to ' .. target.name })
end)

-- Add Money command
RegisterNetEvent('mrp:admin:addMoney', function(targetId, amount)
    local src = source
    local player = MRP.Players[src]
    
    if not player or player.adminLevel < 2 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Insufficient permissions' })
        return
    end
    
    targetId = tonumber(targetId)
    amount = tonumber(amount)
    
    if not targetId or not amount then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid parameters' })
        return
    end
    
    local target = MRP.Characters[targetId]
    if not target then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Target not found' })
        return
    end
    
    AwardMoney(targetId, amount, 'Admin Grant')
    
    LogAction('admin_add_money', player.visibleid, MRP.Characters[src] and MRP.Characters[src].name or 'Admin',
        MRP.Players[targetId].visibleid, target.name, { amount = amount })
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Added $' .. amount .. ' to ' .. target.name })
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================
AddEventHandler('playerDropped', function()
    local src = source
    PlayerKillStreaks[src] = nil
    PlayerLastDamage[src] = nil
end)

Config.Print('server/progression.lua loaded')
