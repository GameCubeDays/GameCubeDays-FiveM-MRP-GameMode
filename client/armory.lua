--[[
    MRP GAMEMODE - CLIENT ARMORY
    ============================
    Handles weapon shop UI and purchases:
    - Armory location markers
    - Weapon purchase menu (ox_lib)
    - Unlock and buy system
    - Ammo and armor purchases
]]

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================
local armoryBlips = {}
local isInArmory = false
local armoryData = nil

-- ============================================================================
-- INITIALIZE ARMORY LOCATIONS
-- ============================================================================
CreateThread(function()
    -- Wait for character to load
    while not MRP.IsLoaded do
        Wait(1000)
    end
    
    -- Create blips for faction armories
    local faction = MRP.PlayerData.faction
    local base = Config.Bases[faction]
    
    if base and base.armory then
        local blip = AddBlipForCoord(base.armory.x, base.armory.y, base.armory.z)
        SetBlipSprite(blip, 110) -- Ammu-Nation icon
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, Config.Factions[faction].blipColor)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Armory')
        EndTextCommandSetBlipName(blip)
        
        table.insert(armoryBlips, blip)
    end
end)

-- ============================================================================
-- ARMORY ZONE DETECTION
-- ============================================================================
CreateThread(function()
    while true do
        Wait(500)
        
        if MRP.IsLoaded and MRP.PlayerData then
            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)
            local faction = MRP.PlayerData.faction
            local base = Config.Bases[faction]
            
            if base and base.armory then
                local distance = #(playerCoords - vector3(base.armory.x, base.armory.y, base.armory.z))
                
                if distance < 3.0 then
                    if not isInArmory then
                        isInArmory = true
                    end
                    
                    -- Draw prompt
                    DrawText3D(base.armory.x, base.armory.y, base.armory.z + 1.0, '[E] Armory')
                    
                    if IsControlJustPressed(0, 38) then -- E key
                        OpenArmoryMenu()
                    end
                    
                    Wait(0)
                else
                    isInArmory = false
                end
            end
        end
    end
end)

-- ============================================================================
-- ARMORY MENU
-- ============================================================================
function OpenArmoryMenu()
    -- Request data from server
    TriggerServerEvent('mrp:getArmoryData')
end

RegisterNetEvent('mrp:receiveArmoryData', function(data)
    armoryData = data
    ShowArmoryMenu()
end)

function ShowArmoryMenu()
    if not armoryData then return end
    
    local options = {
        {
            title = 'XP: ' .. armoryData.xp .. ' | Money: $' .. armoryData.money,
            description = 'Your current resources',
            icon = 'wallet',
            disabled = true
        },
        {
            title = 'Weapons',
            description = 'Browse and purchase weapons',
            icon = 'gun',
            onSelect = function()
                ShowWeaponCategories()
            end
        },
        {
            title = 'Ammo',
            description = 'Refill ammunition',
            icon = 'boxes-stacked',
            onSelect = function()
                ShowAmmoMenu()
            end
        },
        {
            title = 'Armor',
            description = 'Body Armor - $' .. Config.Weapons.armor.price,
            icon = 'shield',
            onSelect = function()
                TriggerServerEvent('mrp:purchaseArmor')
            end
        }
    }
    
    lib.registerContext({
        id = 'mrp_armory_main',
        title = 'Armory',
        options = options
    })
    
    lib.showContext('mrp_armory_main')
end

-- ============================================================================
-- WEAPON CATEGORIES
-- ============================================================================
function ShowWeaponCategories()
    local categories = {}
    local categoryNames = {
        pistol = 'Pistols',
        smg = 'SMGs',
        rifle = 'Assault Rifles',
        shotgun = 'Shotguns',
        sniper = 'Sniper Rifles',
        lmg = 'Light Machine Guns',
        thrown = 'Throwables',
        melee = 'Melee'
    }
    
    -- Count weapons per category
    local categoryCounts = {}
    for _, weapon in ipairs(armoryData.weapons) do
        if not categoryCounts[weapon.category] then
            categoryCounts[weapon.category] = 0
        end
        categoryCounts[weapon.category] = categoryCounts[weapon.category] + 1
    end
    
    local options = {}
    
    for catId, catName in pairs(categoryNames) do
        if categoryCounts[catId] and categoryCounts[catId] > 0 then
            table.insert(options, {
                title = catName,
                description = categoryCounts[catId] .. ' weapons',
                icon = GetCategoryIcon(catId),
                onSelect = function()
                    ShowWeaponsInCategory(catId, catName)
                end
            })
        end
    end
    
    table.insert(options, {
        title = '← Back',
        icon = 'arrow-left',
        onSelect = function()
            ShowArmoryMenu()
        end
    })
    
    lib.registerContext({
        id = 'mrp_weapon_categories',
        title = 'Weapon Categories',
        options = options
    })
    
    lib.showContext('mrp_weapon_categories')
end

function GetCategoryIcon(category)
    local icons = {
        pistol = 'gun',
        smg = 'gun',
        rifle = 'crosshairs',
        shotgun = 'gun',
        sniper = 'bullseye',
        lmg = 'gun',
        thrown = 'bomb',
        melee = 'knife'
    }
    return icons[category] or 'gun'
end

-- ============================================================================
-- WEAPONS IN CATEGORY
-- ============================================================================
function ShowWeaponsInCategory(category, categoryName)
    local options = {}
    
    for _, weapon in ipairs(armoryData.weapons) do
        if weapon.category == category then
            local isUnlocked = armoryData.unlocks[weapon.hash] or weapon.xpUnlock == 0
            local status = ''
            local iconColor = '#ffffff'
            
            if isUnlocked then
                status = 'Unlocked | $' .. weapon.price
                iconColor = '#44ff44'
            else
                status = 'Locked | ' .. weapon.xpUnlock .. ' XP to unlock'
                iconColor = '#ff4444'
            end
            
            table.insert(options, {
                title = weapon.name,
                description = status,
                icon = 'gun',
                iconColor = iconColor,
                metadata = {
                    { label = 'Price', value = '$' .. weapon.price },
                    { label = 'Unlock XP', value = weapon.xpUnlock },
                    { label = 'Ammo', value = weapon.ammo }
                },
                onSelect = function()
                    ShowWeaponOptions(weapon, isUnlocked)
                end
            })
        end
    end
    
    table.insert(options, {
        title = '← Back',
        icon = 'arrow-left',
        onSelect = function()
            ShowWeaponCategories()
        end
    })
    
    lib.registerContext({
        id = 'mrp_weapons_list',
        title = categoryName,
        options = options
    })
    
    lib.showContext('mrp_weapons_list')
end

-- ============================================================================
-- WEAPON OPTIONS
-- ============================================================================
function ShowWeaponOptions(weapon, isUnlocked)
    local options = {}
    
    if not isUnlocked then
        -- Unlock option
        table.insert(options, {
            title = 'Unlock Weapon',
            description = 'Spend ' .. weapon.xpUnlock .. ' XP to unlock permanently',
            icon = 'lock-open',
            iconColor = '#ffaa00',
            onSelect = function()
                ConfirmUnlock(weapon, 'weapon')
            end
        })
    else
        -- Purchase option
        table.insert(options, {
            title = 'Purchase Weapon',
            description = 'Buy for $' .. weapon.price .. ' (includes ' .. weapon.ammo .. ' ammo)',
            icon = 'cart-shopping',
            iconColor = '#44ff44',
            onSelect = function()
                ConfirmPurchase(weapon, 'weapon')
            end
        })
    end
    
    table.insert(options, {
        title = '← Back',
        icon = 'arrow-left',
        onSelect = function()
            ShowWeaponCategories()
        end
    })
    
    lib.registerContext({
        id = 'mrp_weapon_options',
        title = weapon.name,
        options = options
    })
    
    lib.showContext('mrp_weapon_options')
end

-- ============================================================================
-- AMMO MENU
-- ============================================================================
function ShowAmmoMenu()
    local ped = PlayerPedId()
    local options = {}
    
    -- Show ammo options for weapons player has unlocked
    for _, weapon in ipairs(armoryData.weapons) do
        local isUnlocked = armoryData.unlocks[weapon.hash] or weapon.xpUnlock == 0
        
        if isUnlocked and HasPedGotWeapon(ped, GetHashKey(weapon.hash), false) then
            local ammoPrice = math.floor(weapon.price * 0.1)
            
            table.insert(options, {
                title = weapon.name .. ' Ammo',
                description = '$' .. ammoPrice .. ' for ' .. weapon.ammo .. ' rounds',
                icon = 'boxes-stacked',
                onSelect = function()
                    TriggerServerEvent('mrp:purchaseAmmo', weapon.hash, weapon.ammo)
                end
            })
        end
    end
    
    if #options == 0 then
        table.insert(options, {
            title = 'No Weapons',
            description = 'You have no weapons to refill',
            icon = 'circle-xmark',
            disabled = true
        })
    end
    
    table.insert(options, {
        title = '← Back',
        icon = 'arrow-left',
        onSelect = function()
            ShowArmoryMenu()
        end
    })
    
    lib.registerContext({
        id = 'mrp_ammo_menu',
        title = 'Ammunition',
        options = options
    })
    
    lib.showContext('mrp_ammo_menu')
end

-- ============================================================================
-- CONFIRMATION DIALOGS
-- ============================================================================
function ConfirmUnlock(item, itemType)
    local confirm = lib.alertDialog({
        header = 'Unlock ' .. item.name .. '?',
        content = string.format(
            'Spend **%d XP** to permanently unlock **%s**?\n\nYour XP: %d',
            item.xpUnlock,
            item.name,
            armoryData.xp
        ),
        centered = true,
        cancel = true,
        labels = { confirm = 'Unlock', cancel = 'Cancel' }
    })
    
    if confirm == 'confirm' then
        if itemType == 'weapon' then
            TriggerServerEvent('mrp:unlockWeapon', item.hash)
        else
            TriggerServerEvent('mrp:unlockVehicle', item.model)
        end
        
        -- Refresh menu after short delay
        SetTimeout(500, function()
            TriggerServerEvent('mrp:getArmoryData')
        end)
    end
end

function ConfirmPurchase(item, itemType)
    local confirm = lib.alertDialog({
        header = 'Purchase ' .. item.name .. '?',
        content = string.format(
            'Buy **%s** for **$%d**?\n\nYour Money: $%d',
            item.name,
            item.price,
            armoryData.money
        ),
        centered = true,
        cancel = true,
        labels = { confirm = 'Purchase', cancel = 'Cancel' }
    })
    
    if confirm == 'confirm' then
        if itemType == 'weapon' then
            TriggerServerEvent('mrp:purchaseWeapon', item.hash)
        else
            TriggerServerEvent('mrp:purchaseVehicle', item.model)
        end
    end
end

-- ============================================================================
-- RECEIVE WEAPONS/ITEMS
-- ============================================================================
RegisterNetEvent('mrp:giveWeapon', function(weaponHash, ammo)
    local ped = PlayerPedId()
    local hash = GetHashKey(weaponHash)
    
    GiveWeaponToPed(ped, hash, ammo, false, true)
    
    -- Play sound
    PlaySoundFrontend(-1, 'PICK_UP_WEAPON', 'HUD_FRONTEND_CUSTOM_SOUNDSET', true)
end)

RegisterNetEvent('mrp:giveAmmo', function(weaponHash, ammo)
    local ped = PlayerPedId()
    local hash = GetHashKey(weaponHash)
    
    AddAmmoToPed(ped, hash, ammo)
    
    PlaySoundFrontend(-1, 'PICK_UP_WEAPON', 'HUD_FRONTEND_CUSTOM_SOUNDSET', true)
end)

RegisterNetEvent('mrp:giveArmor', function(amount)
    local ped = PlayerPedId()
    SetPedArmour(ped, amount)
    
    PlaySoundFrontend(-1, 'PICK_UP_WEAPON', 'HUD_FRONTEND_CUSTOM_SOUNDSET', true)
end)

-- ============================================================================
-- UTILITY FUNCTIONS
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
    
    for _, blip in ipairs(armoryBlips) do
        RemoveBlip(blip)
    end
end)

-- Command to open armory (for testing or if near armory)
RegisterCommand('armory', function()
    if isInArmory then
        OpenArmoryMenu()
    else
        lib.notify({ type = 'error', description = 'Not at armory' })
    end
end, false)

Config.Print('client/armory.lua loaded')
