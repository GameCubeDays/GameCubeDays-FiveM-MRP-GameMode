--[[
    MRP GAMEMODE - CLIENT HUD
    =========================
    Handles core HUD elements:
    - Compass (Battlefield-style horizontal strip)
    - Player stats display
    - NUI communication
]]

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================
local compassEnabled = true
local lastHeading = 0
local hudVisible = true

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
RegisterNetEvent('mrp:characterLoaded', function()
    -- Initialize HUD
    compassEnabled = Config.HUD.compassEnabled
    
    -- Show HUD
    SetHudVisible(true)
    
    -- Start compass updates
    if compassEnabled then
        StartCompassUpdates()
    end
end)

-- ============================================================================
-- COMPASS SYSTEM
-- ============================================================================
function StartCompassUpdates()
    CreateThread(function()
        while MRP.IsLoaded do
            if compassEnabled and hudVisible then
                local ped = PlayerPedId()
                local heading = GetEntityHeading(ped)
                
                -- Only update if heading changed significantly
                if math.abs(heading - lastHeading) > 1 then
                    lastHeading = heading
                    
                    SendNUIMessage({
                        type = 'updateCompass',
                        heading = heading
                    })
                end
            end
            
            Wait(50) -- 20 updates per second for smooth compass
        end
    end)
end

-- ============================================================================
-- HUD VISIBILITY
-- ============================================================================
function SetHudVisible(visible)
    hudVisible = visible
    
    SendNUIMessage({
        type = visible and 'showHUD' or 'hideHUD'
    })
end

-- Hide HUD during character selection
RegisterNetEvent('mrp:openCharacterSelect', function()
    SetHudVisible(false)
end)

-- Show HUD after character loaded
RegisterNetEvent('mrp:characterLoaded', function()
    SetHudVisible(true)
end)

-- ============================================================================
-- STATS DISPLAY
-- ============================================================================
RegisterNetEvent('mrp:updateStats', function(stats)
    -- Update local player data
    if MRP.PlayerData then
        for key, value in pairs(stats) do
            MRP.PlayerData[key] = value
        end
    end
    
    -- Send to NUI for display
    SendNUIMessage({
        type = 'updateStats',
        stats = {
            xp = MRP.PlayerData and MRP.PlayerData.xp or 0,
            money = MRP.PlayerData and MRP.PlayerData.money or 0,
            rankName = MRP.PlayerData and MRP.PlayerData.rankName or 'Unknown',
            rankAbbr = MRP.PlayerData and MRP.PlayerData.rankAbbr or '???',
            kills = MRP.PlayerData and MRP.PlayerData.kills or 0,
            deaths = MRP.PlayerData and MRP.PlayerData.deaths or 0,
            captures = MRP.PlayerData and MRP.PlayerData.captures or 0
        }
    })
end)

-- ============================================================================
-- MINIMAP CUSTOMIZATION
-- ============================================================================
CreateThread(function()
    while true do
        Wait(0)
        
        if MRP.IsLoaded then
            -- Expanded minimap while in vehicle or on foot
            local ped = PlayerPedId()
            
            if IsPedInAnyVehicle(ped, false) then
                -- Larger minimap in vehicle
                SetRadarBigmapEnabled(false, false)
            end
            
            -- Keep radar visible
            DisplayRadar(true)
        end
    end
end)

-- ============================================================================
-- COMMANDS
-- ============================================================================

-- Toggle compass
RegisterCommand('compass', function()
    compassEnabled = not compassEnabled
    
    if compassEnabled then
        SendNUIMessage({ type = 'showCompass' })
        lib.notify({ type = 'info', description = 'Compass enabled' })
    else
        SendNUIMessage({ type = 'hideCompass' })
        lib.notify({ type = 'info', description = 'Compass disabled' })
    end
end, false)

-- Toggle HUD
RegisterCommand('togglehud', function()
    SetHudVisible(not hudVisible)
    lib.notify({ type = 'info', description = 'HUD ' .. (hudVisible and 'shown' or 'hidden') })
end, false)

-- ============================================================================
-- EXPORTS
-- ============================================================================
exports('IsHudVisible', function() return hudVisible end)
exports('SetHudVisible', SetHudVisible)

Config.Print('client/hud.lua loaded')
