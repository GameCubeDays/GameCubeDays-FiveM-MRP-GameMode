--[[
    MRP GAMEMODE - CLIENT VEHICLES
    ==============================
    Handles vehicle shop and interactions:
    - Vehicle shop UI
    - Vehicle spawning
    - Lock/unlock controls
    - Vehicle info display
]]

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================
local vehicleShopBlips = {}
local isInVehicleShop = false
local vehicleShopData = nil
local currentVehicle = nil

-- ============================================================================
-- INITIALIZE VEHICLE SHOP LOCATIONS
-- ============================================================================
CreateThread(function()
    -- Wait for character to load
    while not MRP.IsLoaded do
        Wait(1000)
    end
    
    -- Create blips for faction vehicle spawns
    local faction = MRP.PlayerData.faction
    local base = Config.Bases[faction]
    
    if base and base.vehicleSpawn then
        local blip = AddBlipForCoord(base.vehicleSpawn.x, base.vehicleSpawn.y, base.vehicleSpawn.z)
        SetBlipSprite(blip, 225) -- Garage icon
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, Config.Factions[faction].blipColor)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Vehicle Depot')
        EndTextCommandSetBlipName(blip)
        
        table.insert(vehicleShopBlips, blip)
    end
end)

-- ============================================================================
-- VEHICLE SHOP ZONE DETECTION
-- ============================================================================
CreateThread(function()
    while true do
        Wait(500)
        
        if MRP.IsLoaded and MRP.PlayerData then
            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)
            local faction = MRP.PlayerData.faction
            local base = Config.Bases[faction]
            
            if base and base.vehicleSpawn then
                local distance = #(playerCoords - vector3(base.vehicleSpawn.x, base.vehicleSpawn.y, base.vehicleSpawn.z))
                
                if distance < 5.0 then
                    if not isInVehicleShop then
                        isInVehicleShop = true
                    end
                    
                    -- Draw prompt
                    DrawText3D(base.vehicleSpawn.x, base.vehicleSpawn.y, base.vehicleSpawn.z + 1.0, '[E] Vehicle Depot')
                    
                    if IsControlJustPressed(0, 38) then -- E key
                        OpenVehicleShop()
                    end
                    
                    Wait(0)
                else
                    isInVehicleShop = false
                end
            end
        end
    end
end)

-- ============================================================================
-- VEHICLE SHOP MENU
-- ============================================================================
function OpenVehicleShop()
    TriggerServerEvent('mrp:getVehicleShopData')
end

RegisterNetEvent('mrp:receiveVehicleShopData', function(data)
    vehicleShopData = data
    ShowVehicleShopMenu()
end)

function ShowVehicleShopMenu()
    if not vehicleShopData then return end
    
    local options = {
        {
            title = 'XP: ' .. vehicleShopData.xp .. ' | Money: $' .. vehicleShopData.money,
            description = 'Your current resources',
            icon = 'wallet',
            disabled = true
        }
    }
    
    -- Group vehicles by category
    local categories = {
        car = { name = 'Cars', icon = 'car' },
        suv = { name = 'SUVs & Trucks', icon = 'truck' },
        military = { name = 'Military Vehicles', icon = 'shield' },
        helicopter = { name = 'Helicopters', icon = 'helicopter' },
        boat = { name = 'Boats', icon = 'ship' },
        bike = { name = 'Motorcycles', icon = 'motorcycle' }
    }
    
    -- Count available vehicles per category
    local categoryCounts = {}
    for _, vehicle in ipairs(vehicleShopData.vehicles) do
        if vehicle.canUse then
            categoryCounts[vehicle.category] = (categoryCounts[vehicle.category] or 0) + 1
        end
    end
    
    for catId, catInfo in pairs(categories) do
        local count = categoryCounts[catId] or 0
        if count > 0 then
            table.insert(options, {
                title = catInfo.name,
                description = count .. ' vehicles available',
                icon = catInfo.icon,
                onSelect = function()
                    ShowVehiclesInCategory(catId, catInfo.name)
                end
            })
        end
    end
    
    lib.registerContext({
        id = 'mrp_vehicle_shop',
        title = 'Vehicle Depot',
        options = options
    })
    
    lib.showContext('mrp_vehicle_shop')
end

-- ============================================================================
-- VEHICLES BY CATEGORY
-- ============================================================================
function ShowVehiclesInCategory(category, categoryName)
    local options = {}
    
    for _, vehicle in ipairs(vehicleShopData.vehicles) do
        if vehicle.category == category and vehicle.canUse then
            local isUnlocked = vehicleShopData.unlocks[vehicle.model] or vehicle.xpUnlock == 0
            local status = ''
            local iconColor = '#ffffff'
            
            if isUnlocked then
                status = 'Unlocked | $' .. vehicle.price .. ' per spawn'
                iconColor = '#44ff44'
            else
                status = 'Locked | ' .. vehicle.xpUnlock .. ' XP to unlock'
                iconColor = '#ff4444'
            end
            
            -- Add restriction info
            local metadata = {
                { label = 'Price', value = '$' .. vehicle.price },
                { label = 'Unlock XP', value = vehicle.xpUnlock }
            }
            
            if vehicle.whitelistRequired then
                table.insert(metadata, { label = 'Whitelist', value = table.concat(vehicle.whitelistRequired, ', ') })
            end
            
            if vehicle.rankRequired then
                table.insert(metadata, { label = 'Min Rank', value = vehicle.rankRequired })
            end
            
            table.insert(options, {
                title = vehicle.name,
                description = status,
                icon = GetVehicleIcon(vehicle.category),
                iconColor = iconColor,
                metadata = metadata,
                onSelect = function()
                    ShowVehicleOptions(vehicle, isUnlocked)
                end
            })
        end
    end
    
    -- Show unavailable vehicles as disabled
    for _, vehicle in ipairs(vehicleShopData.vehicles) do
        if vehicle.category == category and not vehicle.canUse then
            local reason = 'Restricted'
            if vehicle.whitelistRequired then
                reason = 'Requires: ' .. table.concat(vehicle.whitelistRequired, ', ')
            end
            
            table.insert(options, {
                title = vehicle.name .. ' [RESTRICTED]',
                description = reason,
                icon = GetVehicleIcon(vehicle.category),
                iconColor = '#666666',
                disabled = true
            })
        end
    end
    
    table.insert(options, {
        title = '← Back',
        icon = 'arrow-left',
        onSelect = function()
            ShowVehicleShopMenu()
        end
    })
    
    lib.registerContext({
        id = 'mrp_vehicle_category',
        title = categoryName,
        options = options
    })
    
    lib.showContext('mrp_vehicle_category')
end

function GetVehicleIcon(category)
    local icons = {
        car = 'car',
        suv = 'truck',
        military = 'shield',
        helicopter = 'helicopter',
        boat = 'ship',
        bike = 'motorcycle'
    }
    return icons[category] or 'car'
end

-- ============================================================================
-- VEHICLE OPTIONS
-- ============================================================================
function ShowVehicleOptions(vehicle, isUnlocked)
    local options = {}
    
    if not isUnlocked then
        table.insert(options, {
            title = 'Unlock Vehicle',
            description = 'Spend ' .. vehicle.xpUnlock .. ' XP to unlock',
            icon = 'lock-open',
            iconColor = '#ffaa00',
            onSelect = function()
                ConfirmVehicleUnlock(vehicle)
            end
        })
    else
        table.insert(options, {
            title = 'Spawn Vehicle',
            description = 'Spawn for $' .. vehicle.price,
            icon = 'car',
            iconColor = '#44ff44',
            onSelect = function()
                ConfirmVehiclePurchase(vehicle)
            end
        })
    end
    
    table.insert(options, {
        title = '← Back',
        icon = 'arrow-left',
        onSelect = function()
            ShowVehicleShopMenu()
        end
    })
    
    lib.registerContext({
        id = 'mrp_vehicle_options',
        title = vehicle.name,
        options = options
    })
    
    lib.showContext('mrp_vehicle_options')
end

-- ============================================================================
-- CONFIRMATIONS
-- ============================================================================
function ConfirmVehicleUnlock(vehicle)
    local confirm = lib.alertDialog({
        header = 'Unlock ' .. vehicle.name .. '?',
        content = string.format(
            'Spend **%d XP** to permanently unlock **%s**?\n\nYour XP: %d',
            vehicle.xpUnlock,
            vehicle.name,
            vehicleShopData.xp
        ),
        centered = true,
        cancel = true,
        labels = { confirm = 'Unlock', cancel = 'Cancel' }
    })
    
    if confirm == 'confirm' then
        TriggerServerEvent('mrp:unlockVehicle', vehicle.model)
        SetTimeout(500, function()
            TriggerServerEvent('mrp:getVehicleShopData')
        end)
    end
end

function ConfirmVehiclePurchase(vehicle)
    local confirm = lib.alertDialog({
        header = 'Spawn ' .. vehicle.name .. '?',
        content = string.format(
            'Spawn **%s** for **$%d**?\n\nYour Money: $%d',
            vehicle.name,
            vehicle.price,
            vehicleShopData.money
        ),
        centered = true,
        cancel = true,
        labels = { confirm = 'Spawn', cancel = 'Cancel' }
    })
    
    if confirm == 'confirm' then
        TriggerServerEvent('mrp:purchaseVehicle', vehicle.model)
    end
end

-- ============================================================================
-- VEHICLE SPAWNING
-- ============================================================================
RegisterNetEvent('mrp:spawnVehicle', function(model)
    local ped = PlayerPedId()
    local faction = MRP.PlayerData.faction
    local base = Config.Bases[faction]
    
    if not base or not base.vehicleSpawn then
        lib.notify({ type = 'error', description = 'No spawn point available' })
        return
    end
    
    local spawnCoords = vector3(base.vehicleSpawn.x, base.vehicleSpawn.y, base.vehicleSpawn.z)
    local spawnHeading = base.vehicleSpawn.w or 0.0
    
    -- Load model
    local modelHash = GetHashKey(model)
    RequestModel(modelHash)
    
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Wait(100)
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(modelHash) then
        lib.notify({ type = 'error', description = 'Failed to load vehicle' })
        return
    end
    
    -- Create vehicle
    local vehicle = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnHeading, true, false)
    
    -- Wait for network registration
    local netTimeout = 0
    while not NetworkGetEntityIsNetworked(vehicle) and netTimeout < 100 do
        Wait(10)
        netTimeout = netTimeout + 1
    end
    
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
    -- Set vehicle properties
    SetVehicleOnGroundProperly(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleDoorsLocked(vehicle, 1) -- Unlocked
    
    -- Put player in vehicle
    TaskWarpPedIntoVehicle(ped, vehicle, -1)
    
    -- Clean up model
    SetModelAsNoLongerNeeded(modelHash)
    
    -- Register with server
    TriggerServerEvent('mrp:vehicleSpawned', netId, model)
    
    -- Store current vehicle
    currentVehicle = { netId = netId, entity = vehicle }
    
    -- Play sound
    PlaySoundFrontend(-1, 'VEHICLE_PURCHASE', 'HUD_FRONTEND_CUSTOM_SOUNDSET', true)
    
    Config.Print('Vehicle spawned:', model, '| NetID:', netId)
end)

-- ============================================================================
-- VEHICLE LOCK CONTROLS
-- ============================================================================
CreateThread(function()
    while true do
        Wait(0)
        
        if MRP.IsLoaded then
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            
            if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
                -- L key to toggle lock
                if IsControlJustPressed(0, 182) then -- L key
                    local netId = NetworkGetNetworkIdFromEntity(vehicle)
                    TriggerServerEvent('mrp:toggleVehicleLock', netId)
                end
            end
        end
    end
end)

-- Receive lock state updates
RegisterNetEvent('mrp:vehicleLockState', function(netId, isLocked)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    
    if DoesEntityExist(vehicle) then
        if isLocked then
            SetVehicleDoorsLocked(vehicle, 2) -- Locked
        else
            SetVehicleDoorsLocked(vehicle, 1) -- Unlocked
        end
        
        -- Play lock/unlock sound
        PlaySoundFrontend(-1, isLocked and 'DOOR_LOCK' or 'DOOR_UNLOCK', 'GTAO_EXEC_ARCADE_OFFICE_SOUNDS', true)
    end
end)

-- ============================================================================
-- VEHICLE STEALING
-- ============================================================================
CreateThread(function()
    while true do
        Wait(500)
        
        if MRP.IsLoaded then
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            
            if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
                -- Check if this is an enemy vehicle we can claim
                local netId = NetworkGetNetworkIdFromEntity(vehicle)
                
                -- H key to claim vehicle
                if IsControlJustPressed(0, 74) then -- H key
                    TriggerServerEvent('mrp:claimVehicle', netId)
                end
            end
        end
    end
end)

-- ============================================================================
-- VEHICLE INFO
-- ============================================================================
RegisterNetEvent('mrp:receiveVehicleInfo', function(info)
    local message = string.format(
        'Owner: %s\nFaction: %s\nLocked: %s',
        info.owner,
        Config.Factions[info.faction] and Config.Factions[info.faction].name or 'Unknown',
        info.isLocked and 'Yes' or 'No'
    )
    
    lib.notify({
        title = 'Vehicle Info',
        description = message,
        type = 'info',
        duration = 5000
    })
end)

-- ============================================================================
-- UTILITY
-- ============================================================================
function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    
    local factor = string.len(text) / 150
    DrawRect(0.0, 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 100)
    ClearDrawOrigin()
end

-- ============================================================================
-- CLEANUP
-- ============================================================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    for _, blip in ipairs(vehicleShopBlips) do
        RemoveBlip(blip)
    end
end)

-- Command for testing
RegisterCommand('vshop', function()
    if isInVehicleShop then
        OpenVehicleShop()
    else
        lib.notify({ type = 'error', description = 'Not at vehicle depot' })
    end
end, false)

Config.Print('client/vehicles.lua loaded')
