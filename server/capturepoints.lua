--[[
    MRP GAMEMODE - SERVER CAPTURE POINTS
    ====================================
    Handles all capture point mechanics:
    - Point state tracking (owner, progress)
    - Capture progress calculation
    - Contested detection
    - Capture rewards
    - Territory control tracking
]]

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================
local CapturePoints = {}          -- [pointId] = { owner, progress, capturing, contested, playersInZone }
local PointUpdateRate = 1000      -- Update every 1 second
local LastTickTime = 0

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
CreateThread(function()
    -- Initialize all capture points
    for _, point in ipairs(Config.CapturePoints) do
        CapturePoints[point.id] = {
            id = point.id,
            name = point.name,
            pos = point.pos,
            radius = point.radius,
            tier = point.tier,
            isBase = point.isBase,
            baseFaction = point.baseFaction,
            
            -- State
            owner = point.baseFaction or 0,     -- 0 = neutral, 1 = military, 2 = resistance
            progress = point.baseFaction and 100 or 0,  -- Base points start fully captured
            capturing = 0,                       -- Faction currently capturing (0 = none)
            contested = false,                   -- True if multiple factions present
            playersInZone = {                    -- [faction] = count
                [1] = 0,
                [2] = 0,
                [3] = 0
            }
        }
    end
    
    Config.Print('Capture points initialized:', #Config.CapturePoints, 'points')
    
    -- Start capture update loop
    CaptureUpdateLoop()
end)

-- ============================================================================
-- CAPTURE UPDATE LOOP
-- ============================================================================
function CaptureUpdateLoop()
    CreateThread(function()
        while true do
            Wait(PointUpdateRate)
            
            -- Update player counts in each zone
            UpdatePlayerCounts()
            
            -- Process capture progress for each point
            for pointId, point in pairs(CapturePoints) do
                ProcessCapture(pointId)
            end
            
            -- Sync state to all clients
            SyncCapturePoints()
        end
    end)
end

-- ============================================================================
-- PLAYER COUNT TRACKING
-- ============================================================================
function UpdatePlayerCounts()
    -- Reset all counts
    for pointId, point in pairs(CapturePoints) do
        point.playersInZone = { [1] = 0, [2] = 0, [3] = 0 }
    end
    
    -- Count players in each zone
    for src, character in pairs(MRP.Characters) do
        if character and character.faction then
            local ped = GetPlayerPed(src)
            if ped and DoesEntityExist(ped) then
                local playerCoords = GetEntityCoords(ped)
                
                for pointId, point in pairs(CapturePoints) do
                    local distance = #(playerCoords - point.pos)
                    
                    if distance <= point.radius then
                        point.playersInZone[character.faction] = point.playersInZone[character.faction] + 1
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- CAPTURE PROCESSING
-- ============================================================================
function ProcessCapture(pointId)
    local point = CapturePoints[pointId]
    if not point then return end
    
    -- Count capturing factions (only Military and Resistance can capture)
    local milCount = point.playersInZone[1] or 0
    local resCount = point.playersInZone[2] or 0
    
    -- Determine capture state
    local attackingFaction = 0
    local attackerCount = 0
    local defenderCount = 0
    
    if milCount > 0 and resCount > 0 then
        -- Contested - both factions present
        point.contested = true
        
        if Config.Capture.contestedFreeze then
            point.capturing = 0
            return -- No progress when contested
        else
            -- Larger force captures
            if milCount > resCount then
                attackingFaction = 1
                attackerCount = milCount - resCount
            elseif resCount > milCount then
                attackingFaction = 2
                attackerCount = resCount - milCount
            else
                -- Equal forces, frozen
                point.capturing = 0
                return
            end
        end
    elseif milCount > 0 then
        attackingFaction = 1
        attackerCount = milCount
        point.contested = false
    elseif resCount > 0 then
        attackingFaction = 2
        attackerCount = resCount
        point.contested = false
    else
        -- No one in zone - decay progress if capturing
        point.contested = false
        
        if point.capturing > 0 and point.progress > 0 and point.progress < 100 then
            -- Decay capture progress
            local decayAmount = GetCaptureSpeed(1) * Config.Capture.decayRate
            point.progress = math.max(0, point.progress - decayAmount)
            
            if point.progress == 0 then
                point.capturing = 0
            end
        end
        return
    end
    
    -- Calculate capture speed based on player count
    attackerCount = math.min(attackerCount, Config.Capture.maxSpeedPlayers)
    local captureSpeed = GetCaptureSpeed(attackerCount)
    
    -- Process capture based on current owner
    if point.owner == 0 then
        -- Neutral point - capture directly
        point.capturing = attackingFaction
        point.progress = math.min(100, point.progress + captureSpeed)
        
        if point.progress >= 100 then
            CapturePoint(pointId, attackingFaction)
        end
        
    elseif point.owner == attackingFaction then
        -- Own point - reinforce if not full
        if point.progress < 100 then
            point.capturing = attackingFaction
            point.progress = math.min(100, point.progress + captureSpeed)
        else
            point.capturing = 0
        end
        
    else
        -- Enemy point - must neutralize first (if enabled)
        if Config.Capture.neutralFirst then
            point.capturing = attackingFaction
            point.progress = math.max(0, point.progress - captureSpeed)
            
            if point.progress <= 0 then
                -- Neutralized
                local oldOwner = point.owner
                point.owner = 0
                point.progress = 0
                
                -- Notify of neutralization
                TriggerClientEvent('mrp:pointNeutralized', -1, pointId, point.name, oldOwner)
            end
        else
            -- Direct capture (flip ownership)
            point.capturing = attackingFaction
            point.progress = math.max(0, point.progress - captureSpeed)
            
            if point.progress <= 0 then
                point.owner = attackingFaction
                point.progress = 0
                CapturePoint(pointId, attackingFaction)
            end
        end
    end
end

-- Get capture speed (progress per second)
function GetCaptureSpeed(playerCount)
    local baseTime = Config.Capture.timeByPlayers[playerCount] or Config.Capture.timeByPlayers[Config.Capture.maxSpeedPlayers]
    return 100 / baseTime -- Progress per second to reach 100% in baseTime seconds
end

-- ============================================================================
-- POINT CAPTURED
-- ============================================================================
function CapturePoint(pointId, faction)
    local point = CapturePoints[pointId]
    if not point then return end
    
    local oldOwner = point.owner
    point.owner = faction
    point.progress = 100
    point.capturing = 0
    
    local tierData = Config.CapturePointTiers[point.tier]
    
    -- Award rewards to all players of capturing faction in zone
    for src, character in pairs(MRP.Characters) do
        if character and character.faction == faction then
            local ped = GetPlayerPed(src)
            if ped and DoesEntityExist(ped) then
                local playerCoords = GetEntityCoords(ped)
                local distance = #(playerCoords - point.pos)
                
                if distance <= point.radius then
                    -- Award capture rewards
                    AwardXP(src, tierData.xpReward, 'Captured ' .. point.name)
                    AwardMoney(src, tierData.moneyReward, 'Captured ' .. point.name)
                    
                    -- Update capture count
                    character.captures = character.captures + 1
                    TriggerClientEvent('mrp:updateStats', src, { captures = character.captures })
                    
                    if MRP.Sessions[src] then
                        MRP.Sessions[src].captures = MRP.Sessions[src].captures + 1
                    end
                end
            end
        end
    end
    
    -- Notify all players
    TriggerClientEvent('mrp:pointCaptured', -1, pointId, point.name, faction, oldOwner)
    
    -- Log
    LogAction('point_captured', nil, Config.Factions[faction].name, nil, point.name, {
        pointId = pointId,
        tier = point.tier,
        oldOwner = oldOwner
    })
    
    Config.Print('Point captured:', point.name, '| New owner:', Config.Factions[faction].name)
end

-- ============================================================================
-- SYNC TO CLIENTS
-- ============================================================================
function SyncCapturePoints()
    local syncData = {}
    
    for pointId, point in pairs(CapturePoints) do
        syncData[pointId] = {
            owner = point.owner,
            progress = point.progress,
            capturing = point.capturing,
            contested = point.contested,
            playersInZone = point.playersInZone
        }
    end
    
    TriggerClientEvent('mrp:syncCapturePoints', -1, syncData)
end

-- Send full capture point data to a single player
function SendFullCaptureData(src)
    local fullData = {}
    
    for pointId, point in pairs(CapturePoints) do
        fullData[pointId] = {
            id = point.id,
            name = point.name,
            pos = point.pos,
            radius = point.radius,
            tier = point.tier,
            isBase = point.isBase,
            baseFaction = point.baseFaction,
            owner = point.owner,
            progress = point.progress,
            capturing = point.capturing,
            contested = point.contested
        }
    end
    
    TriggerClientEvent('mrp:receiveCapturePoints', src, fullData, Config.CapturePointTiers)
end

RegisterNetEvent('mrp:requestCapturePoints', function()
    local src = source
    SendFullCaptureData(src)
end)

-- ============================================================================
-- TERRITORY CONTROL STATS
-- ============================================================================
function GetTerritoryStats()
    local stats = {
        [1] = { points = 0, total = 0 },
        [2] = { points = 0, total = 0 },
        [0] = { points = 0, total = 0 } -- Neutral
    }
    
    for _, point in pairs(CapturePoints) do
        stats[point.owner].points = stats[point.owner].points + 1
        stats[point.owner].total = stats[point.owner].total + 1
        
        if point.owner ~= 0 then
            -- Count for total controlled
        end
    end
    
    local totalPoints = #Config.CapturePoints
    
    return {
        military = {
            count = stats[1].points,
            percent = math.floor((stats[1].points / totalPoints) * 100)
        },
        resistance = {
            count = stats[2].points,
            percent = math.floor((stats[2].points / totalPoints) * 100)
        },
        neutral = {
            count = stats[0].points,
            percent = math.floor((stats[0].points / totalPoints) * 100)
        },
        total = totalPoints
    }
end

exports('GetTerritoryStats', GetTerritoryStats)
exports('GetCapturePoints', function() return CapturePoints end)

-- ============================================================================
-- PLAYER ENTERING/LEAVING ZONES
-- ============================================================================
RegisterNetEvent('mrp:playerEnteredZone', function(pointId)
    local src = source
    local character = MRP.Characters[src]
    
    if not character then return end
    
    local point = CapturePoints[pointId]
    if not point then return end
    
    -- Notify player of zone entry
    TriggerClientEvent('mrp:enteredCaptureZone', src, {
        id = pointId,
        name = point.name,
        owner = point.owner,
        tier = point.tier,
        progress = point.progress
    })
end)

RegisterNetEvent('mrp:playerLeftZone', function(pointId)
    local src = source
    TriggerClientEvent('mrp:leftCaptureZone', src, pointId)
end)

-- ============================================================================
-- ADMIN COMMANDS
-- ============================================================================

-- Force capture a point
RegisterNetEvent('mrp:admin:capturePoint', function(pointId, faction)
    local src = source
    local player = MRP.Players[src]
    
    if not player or player.adminLevel < 3 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Insufficient permissions' })
        return
    end
    
    pointId = tonumber(pointId)
    faction = tonumber(faction)
    
    local point = CapturePoints[pointId]
    if not point then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid point ID' })
        return
    end
    
    if faction < 0 or faction > 2 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid faction (0=neutral, 1=military, 2=resistance)' })
        return
    end
    
    point.owner = faction
    point.progress = faction == 0 and 0 or 100
    point.capturing = 0
    point.contested = false
    
    TriggerClientEvent('mrp:pointCaptured', -1, pointId, point.name, faction, point.owner)
    
    LogAction('admin_capture_point', player.visibleid, MRP.Characters[src] and MRP.Characters[src].name or 'Admin', nil, point.name, { faction = faction })
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Point ' .. point.name .. ' set to faction ' .. faction })
end)

-- Reset all points
RegisterNetEvent('mrp:admin:resetPoints', function()
    local src = source
    local player = MRP.Players[src]
    
    if not player or player.adminLevel < 4 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Insufficient permissions' })
        return
    end
    
    for pointId, point in pairs(CapturePoints) do
        if point.isBase then
            point.owner = point.baseFaction
            point.progress = 100
        else
            point.owner = 0
            point.progress = 0
        end
        point.capturing = 0
        point.contested = false
    end
    
    TriggerClientEvent('ox_lib:notify', -1, { type = 'info', description = 'All capture points have been reset' })
    
    LogAction('admin_reset_points', player.visibleid, MRP.Characters[src] and MRP.Characters[src].name or 'Admin', nil, nil, {})
end)

Config.Print('server/capturepoints.lua loaded')
