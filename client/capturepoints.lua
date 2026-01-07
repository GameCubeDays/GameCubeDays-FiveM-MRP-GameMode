--[[
    MRP GAMEMODE - CLIENT CAPTURE POINTS
    ====================================
    Handles client-side capture point mechanics:
    - Map blips for all points
    - Zone detection (entering/leaving)
    - Capture progress UI
    - NUI updates for capture indicator
]]

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================
local CapturePoints = {}
local CapturePointTiers = {}
local PointBlips = {}
local CurrentZone = nil
local isInZone = false

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
RegisterNetEvent('mrp:characterLoaded', function()
    -- Request capture point data
    TriggerServerEvent('mrp:requestCapturePoints')
end)

RegisterNetEvent('mrp:receiveCapturePoints', function(points, tiers)
    CapturePoints = points
    CapturePointTiers = tiers
    
    -- Create blips
    CreateCaptureBlips()
    
    Config.Print('Capture points received:', GetTableLength(points), 'points')
end)

-- ============================================================================
-- BLIP MANAGEMENT
-- ============================================================================
function CreateCaptureBlips()
    -- Remove old blips
    for _, blip in ipairs(PointBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    PointBlips = {}
    
    -- Create new blips
    for pointId, point in pairs(CapturePoints) do
        local blip = AddBlipForCoord(point.pos.x, point.pos.y, point.pos.z)
        
        -- Set blip properties based on tier
        SetBlipSprite(blip, GetBlipSpriteForTier(point.tier))
        SetBlipScale(blip, GetBlipScaleForTier(point.tier))
        SetBlipColour(blip, GetBlipColorForOwner(point.owner))
        SetBlipAsShortRange(blip, true)
        
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(point.name)
        EndTextCommandSetBlipName(blip)
        
        -- Store blip reference
        PointBlips[pointId] = blip
    end
end

function GetBlipSpriteForTier(tier)
    local sprites = {
        ['low'] = 458,      -- Small point
        ['medium'] = 458,
        ['high'] = 458,
        ['critical'] = 439  -- Larger important point
    }
    return sprites[tier] or 458
end

function GetBlipScaleForTier(tier)
    local scales = {
        ['low'] = 0.7,
        ['medium'] = 0.8,
        ['high'] = 0.9,
        ['critical'] = 1.0
    }
    return scales[tier] or 0.8
end

function GetBlipColorForOwner(owner)
    if owner == 1 then
        return 38  -- Blue (Military)
    elseif owner == 2 then
        return 1   -- Red (Resistance)
    else
        return 4   -- White (Neutral)
    end
end

-- Update blip colors when ownership changes
function UpdateBlipColors()
    for pointId, blip in pairs(PointBlips) do
        if DoesBlipExist(blip) and CapturePoints[pointId] then
            SetBlipColour(blip, GetBlipColorForOwner(CapturePoints[pointId].owner))
        end
    end
end

-- ============================================================================
-- SYNC UPDATES FROM SERVER
-- ============================================================================
RegisterNetEvent('mrp:syncCapturePoints', function(syncData)
    for pointId, data in pairs(syncData) do
        if CapturePoints[pointId] then
            local oldOwner = CapturePoints[pointId].owner
            
            CapturePoints[pointId].owner = data.owner
            CapturePoints[pointId].progress = data.progress
            CapturePoints[pointId].capturing = data.capturing
            CapturePoints[pointId].contested = data.contested
            CapturePoints[pointId].playersInZone = data.playersInZone
            
            -- Update blip if owner changed
            if oldOwner ~= data.owner then
                if PointBlips[pointId] and DoesBlipExist(PointBlips[pointId]) then
                    SetBlipColour(PointBlips[pointId], GetBlipColorForOwner(data.owner))
                end
            end
        end
    end
    
    -- Update NUI if in a zone
    if CurrentZone then
        UpdateCaptureUI()
    end
end)

-- ============================================================================
-- ZONE DETECTION
-- ============================================================================
CreateThread(function()
    while true do
        Wait(500)
        
        if MRP.IsLoaded and CapturePoints then
            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)
            local foundZone = nil
            
            for pointId, point in pairs(CapturePoints) do
                local distance = #(playerCoords - point.pos)
                
                if distance <= point.radius then
                    foundZone = pointId
                    break
                end
            end
            
            -- Check for zone change
            if foundZone ~= CurrentZone then
                if CurrentZone and not foundZone then
                    -- Left a zone
                    TriggerServerEvent('mrp:playerLeftZone', CurrentZone)
                    OnLeftZone(CurrentZone)
                elseif foundZone and not CurrentZone then
                    -- Entered a zone
                    TriggerServerEvent('mrp:playerEnteredZone', foundZone)
                    OnEnteredZone(foundZone)
                elseif foundZone and CurrentZone then
                    -- Moved from one zone to another
                    TriggerServerEvent('mrp:playerLeftZone', CurrentZone)
                    OnLeftZone(CurrentZone)
                    TriggerServerEvent('mrp:playerEnteredZone', foundZone)
                    OnEnteredZone(foundZone)
                end
                
                CurrentZone = foundZone
            end
        end
    end
end)

function OnEnteredZone(pointId)
    isInZone = true
    local point = CapturePoints[pointId]
    
    if not point then return end
    
    -- Show zone entry notification
    local ownerName = GetOwnerName(point.owner)
    lib.notify({
        title = point.name,
        description = 'Controlled by: ' .. ownerName,
        type = 'info',
        duration = 3000
    })
    
    -- Show capture UI
    ShowCaptureUI(point)
    
    Config.Print('Entered zone:', point.name)
end

function OnLeftZone(pointId)
    isInZone = false
    
    -- Hide capture UI
    HideCaptureUI()
    
    Config.Print('Left zone:', pointId)
end

function GetOwnerName(owner)
    if owner == 1 then
        return Config.Factions[1].name
    elseif owner == 2 then
        return Config.Factions[2].name
    else
        return 'Neutral'
    end
end

-- ============================================================================
-- CAPTURE UI (NUI)
-- ============================================================================
function ShowCaptureUI(point)
    SendNUIMessage({
        type = 'showCapture',
        name = point.name,
        owner = point.owner,
        progress = point.progress,
        contested = point.contested,
        tier = point.tier
    })
end

function HideCaptureUI()
    SendNUIMessage({
        type = 'hideCapture'
    })
end

function UpdateCaptureUI()
    if not CurrentZone then return end
    
    local point = CapturePoints[CurrentZone]
    if not point then return end
    
    SendNUIMessage({
        type = 'updateCapture',
        owner = point.owner,
        progress = point.progress,
        contested = point.contested,
        capturing = point.capturing
    })
end

-- ============================================================================
-- CAPTURE EVENTS
-- ============================================================================
RegisterNetEvent('mrp:pointCaptured', function(pointId, pointName, newOwner, oldOwner)
    local factionName = Config.Factions[newOwner] and Config.Factions[newOwner].name or 'Unknown'
    
    -- Update local data
    if CapturePoints[pointId] then
        CapturePoints[pointId].owner = newOwner
        CapturePoints[pointId].progress = 100
        CapturePoints[pointId].capturing = 0
    end
    
    -- Update blip
    if PointBlips[pointId] and DoesBlipExist(PointBlips[pointId]) then
        SetBlipColour(PointBlips[pointId], GetBlipColorForOwner(newOwner))
    end
    
    -- Notification
    local myFaction = MRP.PlayerData and MRP.PlayerData.faction
    local notifType = 'info'
    
    if myFaction == newOwner then
        notifType = 'success'
    elseif myFaction == oldOwner then
        notifType = 'error'
    end
    
    lib.notify({
        title = pointName .. ' Captured!',
        description = 'Now controlled by ' .. factionName,
        type = notifType,
        duration = 5000
    })
    
    -- Play sound
    PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
end)

RegisterNetEvent('mrp:pointNeutralized', function(pointId, pointName, oldOwner)
    -- Update local data
    if CapturePoints[pointId] then
        CapturePoints[pointId].owner = 0
        CapturePoints[pointId].progress = 0
    end
    
    -- Update blip
    if PointBlips[pointId] and DoesBlipExist(PointBlips[pointId]) then
        SetBlipColour(PointBlips[pointId], GetBlipColorForOwner(0))
    end
    
    -- Notification
    lib.notify({
        title = pointName .. ' Neutralized!',
        description = 'Point is now neutral',
        type = 'warning',
        duration = 3000
    })
end)

RegisterNetEvent('mrp:enteredCaptureZone', function(zoneData)
    -- Additional zone info from server
    Config.Print('Zone info received:', zoneData.name)
end)

RegisterNetEvent('mrp:leftCaptureZone', function(pointId)
    -- Server confirmed zone exit
end)

-- ============================================================================
-- DRAW ZONE MARKERS (Optional 3D markers)
-- ============================================================================
local showZoneMarkers = false

CreateThread(function()
    while true do
        if showZoneMarkers and MRP.IsLoaded and CapturePoints then
            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)
            
            for pointId, point in pairs(CapturePoints) do
                local distance = #(playerCoords - point.pos)
                
                if distance < 200.0 then
                    -- Draw cylinder marker
                    local r, g, b = GetOwnerColor(point.owner)
                    local alpha = 50
                    
                    if point.contested then
                        alpha = 100
                    end
                    
                    DrawMarker(1, point.pos.x, point.pos.y, point.pos.z - 1.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        point.radius * 2, point.radius * 2, 2.0,
                        r, g, b, alpha,
                        false, false, 2, false, nil, nil, false)
                end
            end
            
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

function GetOwnerColor(owner)
    if owner == 1 then
        return 0, 100, 255  -- Blue (Military)
    elseif owner == 2 then
        return 255, 50, 50  -- Red (Resistance)
    else
        return 200, 200, 200  -- Gray (Neutral)
    end
end

-- Command to toggle zone markers
RegisterCommand('zonemarkers', function()
    showZoneMarkers = not showZoneMarkers
    lib.notify({
        type = 'info',
        description = 'Zone markers: ' .. (showZoneMarkers and 'ON' or 'OFF')
    })
end, false)

-- ============================================================================
-- TERRITORY OVERVIEW COMMAND
-- ============================================================================
RegisterCommand('territory', function()
    if not CapturePoints then return end
    
    local milCount = 0
    local resCount = 0
    local neutralCount = 0
    local total = 0
    
    for _, point in pairs(CapturePoints) do
        total = total + 1
        if point.owner == 1 then
            milCount = milCount + 1
        elseif point.owner == 2 then
            resCount = resCount + 1
        else
            neutralCount = neutralCount + 1
        end
    end
    
    lib.notify({
        title = 'Territory Control',
        description = string.format(
            'Military: %d (%d%%)\nResistance: %d (%d%%)\nNeutral: %d',
            milCount, math.floor((milCount/total)*100),
            resCount, math.floor((resCount/total)*100),
            neutralCount
        ),
        type = 'info',
        duration = 8000
    })
end, false)

-- ============================================================================
-- UTILITY
-- ============================================================================
function GetTableLength(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- ============================================================================
-- CLEANUP
-- ============================================================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    for _, blip in pairs(PointBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
end)

Config.Print('client/capturepoints.lua loaded')
