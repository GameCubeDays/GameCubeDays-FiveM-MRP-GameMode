--[[
    MRP GAMEMODE - SERVER ECONOMY
    =============================
    Handles all economy mechanics:
    - Weapon unlocks and purchases
    - Vehicle unlocks and purchases
    - Loadout management
    - Two-stage unlock system (XP to unlock, money to buy)
]]

-- ============================================================================
-- WEAPON UNLOCKS
-- ============================================================================

-- Check if player has unlocked a weapon (spent XP)
function HasWeaponUnlocked(src, weaponHash)
    local character = MRP.Characters[src]
    if not character then return false end
    
    -- Find weapon in config
    local weapon = GetWeaponData(weaponHash)
    if not weapon then return false end
    
    -- Free weapons (0 XP required) are always unlocked
    if weapon.xpUnlock == 0 then return true end
    
    -- Check unlocks table
    if character.unlocks and character.unlocks.weapons then
        return character.unlocks.weapons[weaponHash] == true
    end
    
    return false
end

-- Unlock a weapon (spend XP)
RegisterNetEvent('mrp:unlockWeapon', function(weaponHash)
    local src = source
    local character = MRP.Characters[src]
    
    if not character then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Character not loaded' })
        return
    end
    
    -- Find weapon
    local weapon = GetWeaponData(weaponHash)
    if not weapon then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid weapon' })
        return
    end
    
    -- Check if already unlocked
    if HasWeaponUnlocked(src, weaponHash) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Already unlocked' })
        return
    end
    
    -- Check XP requirement
    if character.xp < weapon.xpUnlock then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Need ' .. weapon.xpUnlock .. ' XP to unlock' })
        return
    end
    
    -- Deduct XP
    character.xp = character.xp - weapon.xpUnlock
    
    -- Add to unlocks
    if not character.unlocks then character.unlocks = { weapons = {}, vehicles = {} } end
    if not character.unlocks.weapons then character.unlocks.weapons = {} end
    character.unlocks.weapons[weaponHash] = true
    
    -- Save to database
    MySQL.insert([[
        INSERT INTO mrp_character_unlocks (character_id, item_type, item_id)
        VALUES (?, 'weapon', ?)
        ON DUPLICATE KEY UPDATE item_id = item_id
    ]], { character.id, weaponHash })
    
    -- Update client
    TriggerClientEvent('mrp:updateStats', src, { xp = character.xp, unlocks = character.unlocks })
    TriggerClientEvent('ox_lib:notify', src, { 
        type = 'success', 
        description = weapon.name .. ' unlocked!' 
    })
    
    -- Log
    LogAction('weapon_unlock', MRP.Players[src].visibleid, character.name, nil, nil, {
        weapon = weaponHash,
        weaponName = weapon.name,
        xpCost = weapon.xpUnlock
    })
    
    Config.Print('Weapon unlocked:', character.name, '-', weapon.name)
end)

-- Purchase a weapon (spend money)
RegisterNetEvent('mrp:purchaseWeapon', function(weaponHash)
    local src = source
    local character = MRP.Characters[src]
    
    if not character then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Character not loaded' })
        return
    end
    
    -- Find weapon
    local weapon = GetWeaponData(weaponHash)
    if not weapon then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid weapon' })
        return
    end
    
    -- Check if unlocked
    if not HasWeaponUnlocked(src, weaponHash) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Weapon not unlocked. Unlock first!' })
        return
    end
    
    -- Check money
    if character.money < weapon.price then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Need $' .. weapon.price })
        return
    end
    
    -- Deduct money
    character.money = character.money - weapon.price
    
    -- Give weapon to player
    TriggerClientEvent('mrp:giveWeapon', src, weaponHash, weapon.ammo)
    
    -- Update client
    TriggerClientEvent('mrp:updateStats', src, { money = character.money })
    TriggerClientEvent('ox_lib:notify', src, { 
        type = 'success', 
        description = weapon.name .. ' purchased for $' .. weapon.price 
    })
    
    -- Log
    LogAction('weapon_purchase', MRP.Players[src].visibleid, character.name, nil, nil, {
        weapon = weaponHash,
        weaponName = weapon.name,
        price = weapon.price
    })
    
    Config.Print('Weapon purchased:', character.name, '-', weapon.name, '- $' .. weapon.price)
end)

-- Purchase ammo
RegisterNetEvent('mrp:purchaseAmmo', function(weaponHash, amount)
    local src = source
    local character = MRP.Characters[src]
    
    if not character then return end
    
    local weapon = GetWeaponData(weaponHash)
    if not weapon then return end
    
    -- Ammo price (10% of weapon price per full ammo)
    local ammoPrice = math.floor(weapon.price * 0.1)
    
    if character.money < ammoPrice then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Need $' .. ammoPrice })
        return
    end
    
    character.money = character.money - ammoPrice
    
    TriggerClientEvent('mrp:giveAmmo', src, weaponHash, weapon.ammo)
    TriggerClientEvent('mrp:updateStats', src, { money = character.money })
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Ammo purchased' })
end)

-- Purchase armor
RegisterNetEvent('mrp:purchaseArmor', function()
    local src = source
    local character = MRP.Characters[src]
    
    if not character then return end
    
    local armorPrice = Config.Weapons.armor.price
    
    if character.money < armorPrice then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Need $' .. armorPrice })
        return
    end
    
    character.money = character.money - armorPrice
    
    TriggerClientEvent('mrp:giveArmor', src, 100)
    TriggerClientEvent('mrp:updateStats', src, { money = character.money })
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Armor purchased' })
end)

-- ============================================================================
-- VEHICLE UNLOCKS
-- ============================================================================

-- Check if player has unlocked a vehicle
function HasVehicleUnlocked(src, vehicleModel)
    local character = MRP.Characters[src]
    if not character then return false end
    
    local vehicle = GetVehicleData(vehicleModel)
    if not vehicle then return false end
    
    -- Free vehicles are always unlocked
    if vehicle.xpUnlock == 0 then return true end
    
    -- Check unlocks table
    if character.unlocks and character.unlocks.vehicles then
        return character.unlocks.vehicles[vehicleModel] == true
    end
    
    return false
end

-- Check vehicle requirements (whitelist, rank)
function CanUseVehicle(src, vehicleModel)
    local character = MRP.Characters[src]
    if not character then return false, 'Character not loaded' end
    
    local vehicle = GetVehicleData(vehicleModel)
    if not vehicle then return false, 'Invalid vehicle' end
    
    -- Check whitelist requirement
    if vehicle.whitelistRequired then
        local hasWhitelist = false
        for _, wl in ipairs(vehicle.whitelistRequired) do
            if character.whitelist == wl then
                hasWhitelist = true
                break
            end
        end
        if not hasWhitelist then
            return false, 'Requires whitelist: ' .. table.concat(vehicle.whitelistRequired, ', ')
        end
    end
    
    -- Check rank requirement
    if vehicle.rankRequired and character.rankId < vehicle.rankRequired then
        local rankName = GetRankById(vehicle.rankRequired, character.faction).name
        return false, 'Requires rank: ' .. rankName
    end
    
    return true, nil
end

-- Unlock a vehicle (spend XP)
RegisterNetEvent('mrp:unlockVehicle', function(vehicleModel)
    local src = source
    local character = MRP.Characters[src]
    
    if not character then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Character not loaded' })
        return
    end
    
    local vehicle = GetVehicleData(vehicleModel)
    if not vehicle then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid vehicle' })
        return
    end
    
    -- Check requirements
    local canUse, reason = CanUseVehicle(src, vehicleModel)
    if not canUse then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = reason })
        return
    end
    
    -- Check if already unlocked
    if HasVehicleUnlocked(src, vehicleModel) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Already unlocked' })
        return
    end
    
    -- Check XP
    if character.xp < vehicle.xpUnlock then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Need ' .. vehicle.xpUnlock .. ' XP' })
        return
    end
    
    -- Deduct XP
    character.xp = character.xp - vehicle.xpUnlock
    
    -- Add to unlocks
    if not character.unlocks then character.unlocks = { weapons = {}, vehicles = {} } end
    if not character.unlocks.vehicles then character.unlocks.vehicles = {} end
    character.unlocks.vehicles[vehicleModel] = true
    
    -- Save to database
    MySQL.insert([[
        INSERT INTO mrp_character_unlocks (character_id, item_type, item_id)
        VALUES (?, 'vehicle', ?)
        ON DUPLICATE KEY UPDATE item_id = item_id
    ]], { character.id, vehicleModel })
    
    -- Update client
    TriggerClientEvent('mrp:updateStats', src, { xp = character.xp, unlocks = character.unlocks })
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = vehicle.name .. ' unlocked!' })
    
    -- Log
    LogAction('vehicle_unlock', MRP.Players[src].visibleid, character.name, nil, nil, {
        vehicle = vehicleModel,
        vehicleName = vehicle.name,
        xpCost = vehicle.xpUnlock
    })
    
    Config.Print('Vehicle unlocked:', character.name, '-', vehicle.name)
end)

-- Purchase/spawn a vehicle
RegisterNetEvent('mrp:purchaseVehicle', function(vehicleModel)
    local src = source
    local character = MRP.Characters[src]
    
    if not character then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Character not loaded' })
        return
    end
    
    local vehicle = GetVehicleData(vehicleModel)
    if not vehicle then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid vehicle' })
        return
    end
    
    -- Check requirements
    local canUse, reason = CanUseVehicle(src, vehicleModel)
    if not canUse then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = reason })
        return
    end
    
    -- Check if unlocked
    if not HasVehicleUnlocked(src, vehicleModel) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Vehicle not unlocked' })
        return
    end
    
    -- Check money
    if character.money < vehicle.price then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Need $' .. vehicle.price })
        return
    end
    
    -- Deduct money
    character.money = character.money - vehicle.price
    
    -- Spawn vehicle for player
    TriggerClientEvent('mrp:spawnVehicle', src, vehicleModel)
    
    -- Update client
    TriggerClientEvent('mrp:updateStats', src, { money = character.money })
    TriggerClientEvent('ox_lib:notify', src, { 
        type = 'success', 
        description = vehicle.name .. ' spawned for $' .. vehicle.price 
    })
    
    -- Log
    LogAction('vehicle_purchase', MRP.Players[src].visibleid, character.name, nil, nil, {
        vehicle = vehicleModel,
        vehicleName = vehicle.name,
        price = vehicle.price
    })
    
    Config.Print('Vehicle purchased:', character.name, '-', vehicle.name)
end)

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function GetWeaponData(weaponHash)
    for _, weapon in ipairs(Config.Weapons.list) do
        if weapon.hash == weaponHash then
            return weapon
        end
    end
    return nil
end

function GetVehicleData(vehicleModel)
    for _, vehicle in ipairs(Config.Vehicles.list) do
        if vehicle.model == vehicleModel then
            return vehicle
        end
    end
    return nil
end

-- Exports
exports('HasWeaponUnlocked', HasWeaponUnlocked)
exports('HasVehicleUnlocked', HasVehicleUnlocked)
exports('CanUseVehicle', CanUseVehicle)
exports('GetWeaponData', GetWeaponData)
exports('GetVehicleData', GetVehicleData)

-- ============================================================================
-- CLIENT REQUESTS
-- ============================================================================

-- Get armory data
RegisterNetEvent('mrp:getArmoryData', function()
    local src = source
    local character = MRP.Characters[src]
    
    if not character then return end
    
    TriggerClientEvent('mrp:receiveArmoryData', src, {
        weapons = Config.Weapons.list,
        armor = Config.Weapons.armor,
        unlocks = character.unlocks and character.unlocks.weapons or {},
        xp = character.xp,
        money = character.money
    })
end)

-- Get vehicle shop data
RegisterNetEvent('mrp:getVehicleShopData', function()
    local src = source
    local character = MRP.Characters[src]
    
    if not character then return end
    
    -- Filter vehicles by faction/whitelist availability
    local availableVehicles = {}
    for _, vehicle in ipairs(Config.Vehicles.list) do
        local canUse, _ = CanUseVehicle(src, vehicle.model)
        table.insert(availableVehicles, {
            model = vehicle.model,
            name = vehicle.name,
            category = vehicle.category,
            xpUnlock = vehicle.xpUnlock,
            price = vehicle.price,
            canUse = canUse,
            whitelistRequired = vehicle.whitelistRequired,
            rankRequired = vehicle.rankRequired
        })
    end
    
    TriggerClientEvent('mrp:receiveVehicleShopData', src, {
        vehicles = availableVehicles,
        unlocks = character.unlocks and character.unlocks.vehicles or {},
        xp = character.xp,
        money = character.money
    })
end)

Config.Print('server/economy.lua loaded')
