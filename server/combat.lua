--[[
    MRP GAMEMODE - SERVER COMBAT
    ============================
    Handles all combat mechanics:
    - Death and downed state
    - Revive system
    - Execution mechanics
    - Respawn handling
    - Damage tracking for kills
]]

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================
local DownedPlayers = {}          -- [source] = { timestamp, bleedoutTime, killer, ... }
local ReviveProgress = {}         -- [targetSource] = { reviverSource, startTime }

-- ============================================================================
-- PLAYER DOWNED
-- ============================================================================
RegisterNetEvent('mrp:playerDowned', function(killerSrc, weaponHash)
    local src = source
    local character = MRP.Characters[src]
    
    if not character then return end
    
    -- Calculate bleedout time
    local baseBleedout = Config.Combat.bleedoutTimeMin
    local maxBleedout = Config.Combat.bleedoutTimeMax
    
    -- Apply Iron Will skill (increases bleedout time)
    local bleedoutBonus = GetSkillEffect(src, 'bleedout_time')
    local bleedoutTime = baseBleedout + ((maxBleedout - baseBleedout) * bleedoutBonus)
    bleedoutTime = math.min(bleedoutTime, maxBleedout)
    
    -- Store downed state
    DownedPlayers[src] = {
        timestamp = os.time(),
        bleedoutTime = bleedoutTime,
        killerSrc = killerSrc,
        weaponHash = weaponHash,
        canGiveUp = false
    }
    
    -- Notify client
    TriggerClientEvent('mrp:enterDownedState', src, bleedoutTime, killerSrc)
    
    -- Notify nearby players that someone is downed
    local killerName = nil
    if killerSrc and MRP.Characters[killerSrc] then
        killerName = MRP.Characters[killerSrc].name
    end
    
    TriggerClientEvent('mrp:playerWentDown', -1, src, character.name, character.faction, killerName)
    
    Config.Print('Player downed:', character.name, '| Bleedout:', bleedoutTime, 'sec')
    
    -- Start bleedout timer
    CreateThread(function()
        local startTime = os.time()
        local halfTime = bleedoutTime / 2
        
        while DownedPlayers[src] do
            Wait(1000)
            
            local elapsed = os.time() - startTime
            
            -- Enable give up after half bleedout time
            if elapsed >= halfTime and DownedPlayers[src] and not DownedPlayers[src].canGiveUp then
                DownedPlayers[src].canGiveUp = true
                TriggerClientEvent('mrp:canGiveUp', src)
            end
            
            -- Check if bleedout complete
            if elapsed >= bleedoutTime then
                if DownedPlayers[src] then
                    -- Player bled out
                    PlayerDied(src, DownedPlayers[src].killerSrc, DownedPlayers[src].weaponHash, 'bleedout')
                end
                break
            end
            
            -- Send timer update to client
            local remaining = math.ceil(bleedoutTime - elapsed)
            TriggerClientEvent('mrp:updateBleedout', src, remaining)
        end
    end)
end)

-- ============================================================================
-- PLAYER GIVE UP (Respawn)
-- ============================================================================
RegisterNetEvent('mrp:giveUp', function()
    local src = source
    
    if not DownedPlayers[src] then return end
    
    if not DownedPlayers[src].canGiveUp then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Cannot give up yet' })
        return
    end
    
    -- Process death
    PlayerDied(src, DownedPlayers[src].killerSrc, DownedPlayers[src].weaponHash, 'giveup')
end)

-- ============================================================================
-- PLAYER DIED
-- ============================================================================
function PlayerDied(src, killerSrc, weaponHash, deathType)
    local character = MRP.Characters[src]
    if not character then return end
    
    -- Clear downed state
    DownedPlayers[src] = nil
    ReviveProgress[src] = nil
    
    -- Process kill rewards/penalties if there was a killer
    if killerSrc and killerSrc ~= src then
        ProcessKill(killerSrc, src, false, weaponHash)
    else
        -- Suicide or environmental death
        character.deaths = character.deaths + 1
        TriggerClientEvent('mrp:updateStats', src, { deaths = character.deaths })
        
        if MRP.Sessions[src] then
            MRP.Sessions[src].deaths = MRP.Sessions[src].deaths + 1
        end
    end
    
    -- Notify client to show death screen and respawn
    TriggerClientEvent('mrp:playerDied', src, deathType, killerSrc)
    
    -- Notify all clients
    TriggerClientEvent('mrp:playerFullyDied', -1, src)
    
    -- Log death
    local killerName = nil
    if killerSrc and MRP.Characters[killerSrc] then
        killerName = MRP.Characters[killerSrc].name
    end
    
    LogAction('death', MRP.Players[src].visibleid, character.name, nil, killerName, {
        deathType = deathType,
        weapon = weaponHash
    })
    
    Config.Print('Player died:', character.name, '| Type:', deathType)
end

-- ============================================================================
-- REVIVE SYSTEM
-- ============================================================================

-- Start reviving a downed player
RegisterNetEvent('mrp:startRevive', function(targetSrc)
    local src = source
    local reviver = MRP.Characters[src]
    local target = MRP.Characters[targetSrc]
    
    if not reviver or not target then return end
    
    -- Check if target is actually downed
    if not DownedPlayers[targetSrc] then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Player is not downed' })
        return
    end
    
    -- Check if same faction (can only revive teammates)
    if reviver.faction ~= target.faction then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Cannot revive enemies' })
        return
    end
    
    -- Check if already being revived
    if ReviveProgress[targetSrc] then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Already being revived' })
        return
    end
    
    -- Calculate revive time
    local baseReviveTime = Config.Combat.reviveTime
    local reviveBonus = GetSkillEffect(src, 'revive_speed')
    local reviveTime = baseReviveTime * (1 - reviveBonus)
    reviveTime = math.max(reviveTime, 2) -- Minimum 2 seconds
    
    -- Start revive
    ReviveProgress[targetSrc] = {
        reviverSrc = src,
        startTime = os.time(),
        reviveTime = reviveTime
    }
    
    -- Notify both players
    TriggerClientEvent('mrp:reviveStarted', src, targetSrc, reviveTime, true) -- true = reviver
    TriggerClientEvent('mrp:reviveStarted', targetSrc, src, reviveTime, false) -- false = being revived
    
    Config.Print('Revive started:', reviver.name, 'reviving', target.name, '| Time:', reviveTime, 'sec')
end)

-- Cancel revive
RegisterNetEvent('mrp:cancelRevive', function(targetSrc)
    local src = source
    
    if ReviveProgress[targetSrc] and ReviveProgress[targetSrc].reviverSrc == src then
        ReviveProgress[targetSrc] = nil
        
        TriggerClientEvent('mrp:reviveCancelled', src)
        TriggerClientEvent('mrp:reviveCancelled', targetSrc)
        
        Config.Print('Revive cancelled')
    end
end)

-- Complete revive
RegisterNetEvent('mrp:completeRevive', function(targetSrc)
    local src = source
    local reviver = MRP.Characters[src]
    local target = MRP.Characters[targetSrc]
    
    if not reviver or not target then return end
    
    -- Verify revive was in progress
    if not ReviveProgress[targetSrc] or ReviveProgress[targetSrc].reviverSrc ~= src then
        return
    end
    
    -- Clear states
    DownedPlayers[targetSrc] = nil
    ReviveProgress[targetSrc] = nil
    
    -- Notify clients
    TriggerClientEvent('mrp:revived', targetSrc, src)
    TriggerClientEvent('mrp:reviveComplete', src, targetSrc)
    
    -- Award XP for revive
    AwardXP(src, Config.Combat.reviveXP or 25, 'Revive')
    
    -- Log
    LogAction('revive', MRP.Players[src].visibleid, reviver.name, MRP.Players[targetSrc].visibleid, target.name, {})
    
    Config.Print('Revive complete:', reviver.name, 'revived', target.name)
end)

-- ============================================================================
-- EXECUTION SYSTEM
-- ============================================================================

-- Start executing a downed enemy
RegisterNetEvent('mrp:startExecution', function(targetSrc)
    local src = source
    local executor = MRP.Characters[src]
    local target = MRP.Characters[targetSrc]
    
    if not executor or not target then return end
    
    -- Check if target is downed
    if not DownedPlayers[targetSrc] then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Player is not downed' })
        return
    end
    
    -- Check if enemy faction
    if executor.faction == target.faction then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Cannot execute teammates' })
        return
    end
    
    -- Notify client to start execution progress
    TriggerClientEvent('mrp:executionStarted', src, targetSrc, Config.Combat.executionTime)
    TriggerClientEvent('mrp:beingExecuted', targetSrc, src)
    
    Config.Print('Execution started:', executor.name, 'executing', target.name)
end)

-- Complete execution
RegisterNetEvent('mrp:completeExecution', function(targetSrc)
    local src = source
    local executor = MRP.Characters[src]
    local target = MRP.Characters[targetSrc]
    
    if not executor or not target then return end
    
    -- Verify target is still downed
    if not DownedPlayers[targetSrc] then return end
    
    -- Process the kill (executor gets credit)
    PlayerDied(targetSrc, src, nil, 'executed')
    
    -- Bonus XP for execution
    AwardXP(src, Config.Combat.executionXP or 75, 'Execution')
    
    Config.Print('Execution complete:', executor.name, 'executed', target.name)
end)

-- Cancel execution
RegisterNetEvent('mrp:cancelExecution', function()
    local src = source
    TriggerClientEvent('mrp:executionCancelled', src)
end)

-- ============================================================================
-- RESPAWN
-- ============================================================================
RegisterNetEvent('mrp:requestRespawn', function()
    local src = source
    local character = MRP.Characters[src]
    
    if not character then return end
    
    -- Clear any downed state
    DownedPlayers[src] = nil
    ReviveProgress[src] = nil
    
    -- Get spawn location
    local faction = character.faction
    local base = Config.Bases[faction]
    local spawnPoint = nil
    
    if faction == 3 then
        -- Civilian random spawn
        local spawns = Config.CivilianSpawns
        spawnPoint = spawns[math.random(#spawns)]
    elseif base then
        local spawns = base.spawnPoints
        spawnPoint = spawns[math.random(#spawns)]
    end
    
    if not spawnPoint then
        -- Fallback spawn
        spawnPoint = { x = 0, y = 0, z = 72, w = 0 }
    end
    
    -- Send respawn command to client
    TriggerClientEvent('mrp:respawn', src, spawnPoint)
    
    Config.Print('Player respawning:', character.name)
end)

-- ============================================================================
-- DAMAGE TRACKING
-- ============================================================================

-- Track when player takes damage (for assist system)
RegisterNetEvent('mrp:playerTookDamage', function(attackerSrc, damage)
    local src = source
    
    if attackerSrc and attackerSrc ~= src then
        TriggerEvent('mrp:playerDamaged', attackerSrc)
    end
end)

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Check if player is downed
function IsPlayerDowned(src)
    return DownedPlayers[src] ~= nil
end

-- Get downed player info
function GetDownedInfo(src)
    return DownedPlayers[src]
end

-- Force kill a player (admin)
function ForceKill(src)
    local character = MRP.Characters[src]
    if not character then return false end
    
    DownedPlayers[src] = nil
    ReviveProgress[src] = nil
    
    PlayerDied(src, nil, nil, 'admin')
    return true
end

-- Exports
exports('IsPlayerDowned', IsPlayerDowned)
exports('GetDownedInfo', GetDownedInfo)
exports('ForceKill', ForceKill)

-- ============================================================================
-- CLEANUP
-- ============================================================================
AddEventHandler('playerDropped', function()
    local src = source
    
    -- Clear downed state
    DownedPlayers[src] = nil
    
    -- Cancel any revives this player was doing
    for targetSrc, progress in pairs(ReviveProgress) do
        if progress.reviverSrc == src then
            ReviveProgress[targetSrc] = nil
            TriggerClientEvent('mrp:reviveCancelled', targetSrc)
        end
    end
    
    -- Clear if being revived
    ReviveProgress[src] = nil
end)

-- ============================================================================
-- ADMIN COMMANDS
-- ============================================================================

-- Kill player command
RegisterNetEvent('mrp:admin:kill', function(targetId)
    local src = source
    local player = MRP.Players[src]
    
    if not player or player.adminLevel < 2 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Insufficient permissions' })
        return
    end
    
    targetId = tonumber(targetId)
    if not targetId then return end
    
    local target = MRP.Characters[targetId]
    if not target then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Target not found' })
        return
    end
    
    ForceKill(targetId)
    
    LogAction('admin_kill', player.visibleid, MRP.Characters[src] and MRP.Characters[src].name or 'Admin',
        MRP.Players[targetId].visibleid, target.name, {})
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Killed ' .. target.name })
end)

-- Revive player command
RegisterNetEvent('mrp:admin:revive', function(targetId)
    local src = source
    local player = MRP.Players[src]
    
    if not player or player.adminLevel < 2 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Insufficient permissions' })
        return
    end
    
    targetId = tonumber(targetId)
    if not targetId then 
        targetId = src -- Revive self
    end
    
    local target = MRP.Characters[targetId]
    if not target then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Target not found' })
        return
    end
    
    -- Clear downed state
    DownedPlayers[targetId] = nil
    ReviveProgress[targetId] = nil
    
    -- Notify client
    TriggerClientEvent('mrp:adminRevive', targetId)
    
    LogAction('admin_revive', player.visibleid, MRP.Characters[src] and MRP.Characters[src].name or 'Admin',
        MRP.Players[targetId].visibleid, target.name, {})
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Revived ' .. target.name })
end)

Config.Print('server/combat.lua loaded')
