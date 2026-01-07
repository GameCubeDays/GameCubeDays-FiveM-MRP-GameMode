--[[
    MRP GAMEMODE - SERVER VEHICLES
    ==============================
    Handles vehicle management:
    - Vehicle spawning
    - Ownership tracking
    - Despawn timer system
    - Vehicle stealing/claiming
]]

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================
local SpawnedVehicles = {}  -- [netId] = { owner, faction, spawnTime, model }

-- ============================================================================
-- VEHICLE SPAWNING
-- ============================================================================

-- Request vehicle spawn from client
RegisterNetEvent('mrp:vehicleSpawned', function(netId, model)
    local src = source
    local character = MRP.Characters[src]
    
    if not character then return end
    
    -- Register vehicle
    SpawnedVehicles[netId] = {
        owner = src,
        ownerName = character.name,
        faction = character.faction,
        model = model,
        spawnTime = os.time(),
        lastNearbyCheck = os.time()
    }
    
    Config.Print('Vehicle spawned:', model, '| Owner:', character.name, '| NetID:', netId)
end)

-- ============================================================================
-- VEHICLE DESPAWN SYSTEM
-- ============================================================================
CreateThread(function()
    while true do
        Wait(30000) -- Check every 30 seconds
        
        local currentTime = os.time()
        local despawnTime = Config.Vehicles.despawnTime
        local despawnRadius = Config.Vehicles.despawnRadius
        
        for netId, vehicleData in pairs(SpawnedVehicles) do
            -- Check if vehicle still exists
            local vehicle = NetworkGetEntityFromNetworkId(netId)
            
            if not DoesEntityExist(vehicle) then
                -- Vehicle no longer exists, clean up
                SpawnedVehicles[netId] = nil
                Config.Print('Vehicle removed (no longer exists):', netId)
            else
                -- Check if any faction member is nearby
                local vehicleCoords = GetEntityCoords(vehicle)
                local hasNearbyMember = false
                
                for playerSrc, playerChar in pairs(MRP.Characters) do
                    if playerChar.faction == vehicleData.faction then
                        local playerPed = GetPlayerPed(playerSrc)
                        if playerPed and DoesEntityExist(playerPed) then
                            local playerCoords = GetEntityCoords(playerPed)
                            local distance = #(vehicleCoords - playerCoords)
                            
                            if distance <= despawnRadius then
                                hasNearbyMember = true
                                break
                            end
                        end
                    end
                end
                
                if hasNearbyMember then
                    -- Reset timer
                    vehicleData.lastNearbyCheck = currentTime
                else
                    -- Check if despawn time exceeded
                    local timeSinceNearby = currentTime - vehicleData.lastNearbyCheck
                    
                    if timeSinceNearby >= despawnTime then
                        -- Despawn vehicle
                        DeleteEntity(vehicle)
                        SpawnedVehicles[netId] = nil
                        
                        -- Notify owner if online
                        if MRP.Characters[vehicleData.owner] then
                            TriggerClientEvent('ox_lib:notify', vehicleData.owner, {
                                type = 'info',
                                description = 'Your vehicle has despawned due to inactivity'
                            })
                        end
                        
                        Config.Print('Vehicle despawned (timeout):', vehicleData.model, '| NetID:', netId)
                    end
                end
            end
        end
    end
end)

-- ============================================================================
-- VEHICLE STEALING
-- ============================================================================
RegisterNetEvent('mrp:claimVehicle', function(netId)
    local src = source
    local character = MRP.Characters[src]
    
    if not character then return end
    
    if not Config.Vehicles.allowStealing then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Vehicle stealing disabled' })
        return
    end
    
    local vehicleData = SpawnedVehicles[netId]
    
    if not vehicleData then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Vehicle not registered' })
        return
    end
    
    -- Can't steal from own faction
    if vehicleData.faction == character.faction then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Cannot steal faction vehicle' })
        return
    end
    
    if Config.Vehicles.claimStolenVehicle then
        -- Transfer ownership
        local oldOwner = vehicleData.ownerName
        
        vehicleData.owner = src
        vehicleData.ownerName = character.name
        vehicleData.faction = character.faction
        vehicleData.lastNearbyCheck = os.time()
        
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'success',
            description = 'Vehicle claimed from ' .. oldOwner
        })
        
        -- Log
        LogAction('vehicle_stolen', MRP.Players[src].visibleid, character.name, nil, oldOwner, {
            vehicle = vehicleData.model,
            netId = netId
        })
        
        Config.Print('Vehicle stolen:', vehicleData.model, '| New owner:', character.name)
    end
end)

-- ============================================================================
-- VEHICLE LOCK SYSTEM
-- ============================================================================
local LockedVehicles = {} -- [netId] = true/false

RegisterNetEvent('mrp:toggleVehicleLock', function(netId)
    local src = source
    local vehicleData = SpawnedVehicles[netId]
    
    if not vehicleData then return end
    
    -- Only owner can lock/unlock
    if vehicleData.owner ~= src then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Not your vehicle' })
        return
    end
    
    LockedVehicles[netId] = not LockedVehicles[netId]
    
    -- Sync to all clients
    TriggerClientEvent('mrp:vehicleLockState', -1, netId, LockedVehicles[netId])
    
    local state = LockedVehicles[netId] and 'locked' or 'unlocked'
    TriggerClientEvent('ox_lib:notify', src, { type = 'info', description = 'Vehicle ' .. state })
end)

function IsVehicleLocked(netId)
    return LockedVehicles[netId] == true
end

exports('IsVehicleLocked', IsVehicleLocked)

-- ============================================================================
-- VEHICLE INFO
-- ============================================================================
RegisterNetEvent('mrp:getVehicleInfo', function(netId)
    local src = source
    local vehicleData = SpawnedVehicles[netId]
    
    if vehicleData then
        TriggerClientEvent('mrp:receiveVehicleInfo', src, {
            owner = vehicleData.ownerName,
            faction = vehicleData.faction,
            model = vehicleData.model,
            isOwner = vehicleData.owner == src,
            isLocked = LockedVehicles[netId] == true
        })
    end
end)

-- ============================================================================
-- CLEANUP ON PLAYER DISCONNECT
-- ============================================================================
AddEventHandler('playerDropped', function()
    local src = source
    
    -- Don't despawn vehicles immediately when owner disconnects
    -- They'll despawn via the normal timeout system
    for netId, vehicleData in pairs(SpawnedVehicles) do
        if vehicleData.owner == src then
            vehicleData.lastNearbyCheck = os.time() -- Start despawn timer
            Config.Print('Vehicle owner disconnected:', vehicleData.model)
        end
    end
end)

-- ============================================================================
-- ADMIN COMMANDS
-- ============================================================================
RegisterNetEvent('mrp:admin:deleteVehicle', function(netId)
    local src = source
    local player = MRP.Players[src]
    
    if not player or player.adminLevel < 2 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Insufficient permissions' })
        return
    end
    
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    
    if DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
        SpawnedVehicles[netId] = nil
        LockedVehicles[netId] = nil
        
        TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Vehicle deleted' })
    end
end)

RegisterNetEvent('mrp:admin:deleteAllVehicles', function()
    local src = source
    local player = MRP.Players[src]
    
    if not player or player.adminLevel < 4 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Insufficient permissions' })
        return
    end
    
    local count = 0
    for netId, _ in pairs(SpawnedVehicles) do
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
            count = count + 1
        end
    end
    
    SpawnedVehicles = {}
    LockedVehicles = {}
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Deleted ' .. count .. ' vehicles' })
    
    LogAction('admin_delete_all_vehicles', player.visibleid, MRP.Characters[src] and MRP.Characters[src].name or 'Admin', nil, nil, { count = count })
end)

Config.Print('server/vehicles.lua loaded')
