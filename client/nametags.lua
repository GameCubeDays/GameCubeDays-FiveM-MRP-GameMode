--[[
    MRP GAMEMODE - CLIENT NAMETAGS
    ==============================
    Handles player nameplates:
    - Friendly nameplates (30m range)
    - Enemy nameplates (5m range)
    - Format: [WHITELIST] RANK Name
    - Faction-colored backgrounds
    - Health bars for friendlies
]]

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================
local nametagsEnabled = true
local friendlyDistance = 30.0
local enemyDistance = 5.0

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
RegisterNetEvent('mrp:characterLoaded', function()
    friendlyDistance = Config.HUD.friendlyNameplateDistance
    enemyDistance = Config.HUD.enemyNameplateDistance
end)

-- ============================================================================
-- NAMETAG RENDERING
-- ============================================================================
CreateThread(function()
    while true do
        Wait(0)
        
        if MRP.IsLoaded and nametagsEnabled and MRP.AllPlayers then
            local myPed = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)
            local myFaction = MRP.PlayerData and MRP.PlayerData.faction or 0
            
            for playerId, playerData in pairs(MRP.AllPlayers) do
                -- Skip self
                if playerId ~= GetPlayerServerId(PlayerId()) then
                    local targetPlayer = GetPlayerFromServerId(playerId)
                    
                    if targetPlayer ~= -1 then
                        local targetPed = GetPlayerPed(targetPlayer)
                        
                        if targetPed and DoesEntityExist(targetPed) and not IsEntityDead(targetPed) then
                            local targetCoords = GetEntityCoords(targetPed)
                            local distance = #(myCoords - targetCoords)
                            
                            local isFriendly = (playerData.faction == myFaction)
                            local maxDistance = isFriendly and friendlyDistance or enemyDistance
                            
                            if distance <= maxDistance then
                                -- Check line of sight for enemies
                                local canSee = true
                                if not isFriendly then
                                    canSee = HasEntityClearLosToEntity(myPed, targetPed, 17)
                                end
                                
                                if canSee then
                                    DrawNametag(targetPed, playerData, distance, isFriendly)
                                end
                            end
                        end
                    end
                end
            end
        else
            Wait(500)
        end
    end
end)

-- ============================================================================
-- DRAW NAMETAG
-- ============================================================================
function DrawNametag(ped, playerData, distance, isFriendly)
    local headBone = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0) -- Head bone
    local tagPos = vector3(headBone.x, headBone.y, headBone.z + 0.35)
    
    -- Screen position
    local onScreen, screenX, screenY = World3dToScreen2d(tagPos.x, tagPos.y, tagPos.z)
    
    if onScreen then
        -- Calculate scale based on distance
        local scale = math.max(0.25, 0.5 - (distance * 0.01))
        
        -- Get faction colors
        local r, g, b = GetFactionColor(playerData.faction)
        
        -- Format name
        local displayName = FormatNametag(playerData)
        
        -- Draw background
        local textWidth = string.len(displayName) * 0.004 * scale
        DrawRect(screenX, screenY, textWidth + 0.02, 0.025 * scale, 0, 0, 0, 150)
        
        -- Draw faction color bar on left
        DrawRect(screenX - (textWidth / 2) - 0.008, screenY, 0.004, 0.025 * scale, r, g, b, 255)
        
        -- Draw text
        SetTextFont(4)
        SetTextScale(scale * 0.35, scale * 0.35)
        SetTextColour(255, 255, 255, 255)
        SetTextCentre(true)
        SetTextOutline()
        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName(displayName)
        EndTextCommandDisplayText(screenX, screenY - 0.012 * scale)
        
        -- Draw health bar for friendlies
        if isFriendly then
            local health = GetEntityHealth(ped)
            local maxHealth = GetEntityMaxHealth(ped)
            local healthPercent = (health - 100) / (maxHealth - 100) -- GTA health starts at 100
            healthPercent = math.max(0, math.min(1, healthPercent))
            
            -- Health bar background
            local barWidth = textWidth + 0.01
            local barY = screenY + 0.015 * scale
            DrawRect(screenX, barY, barWidth, 0.006 * scale, 50, 50, 50, 200)
            
            -- Health bar fill
            local healthR, healthG = 255, 255
            if healthPercent < 0.25 then
                healthR, healthG = 255, 0  -- Red
            elseif healthPercent < 0.5 then
                healthR, healthG = 255, 165  -- Orange
            elseif healthPercent < 0.75 then
                healthR, healthG = 255, 255  -- Yellow
            else
                healthR, healthG = 0, 255  -- Green
            end
            
            local fillWidth = barWidth * healthPercent
            local fillX = screenX - (barWidth / 2) + (fillWidth / 2)
            DrawRect(fillX, barY, fillWidth, 0.005 * scale, healthR, healthG, 0, 255)
        end
    end
end

-- ============================================================================
-- FORMAT NAMETAG
-- ============================================================================
function FormatNametag(playerData)
    -- Format: [WHITELIST] RANK Name
    local parts = {}
    
    -- Whitelist abbreviation
    if playerData.whitelist then
        local wlName = GetWhitelistAbbr(playerData.whitelist)
        if wlName then
            table.insert(parts, wlName)
        end
    end
    
    -- Rank abbreviation
    if playerData.rankAbbr then
        table.insert(parts, playerData.rankAbbr)
    end
    
    -- Name
    if playerData.name then
        table.insert(parts, playerData.name)
    end
    
    return table.concat(parts, ' ')
end

function GetWhitelistAbbr(whitelist)
    local abbrs = {
        ['army'] = 'ARMY',
        ['navy'] = 'NAVY',
        ['marine'] = 'MARN',
        ['fighter'] = 'FGTR',
        ['militia'] = 'MLIT',
        ['citizen'] = 'CIV'
    }
    return abbrs[whitelist] or string.upper(string.sub(whitelist, 1, 4))
end

-- ============================================================================
-- FACTION COLORS
-- ============================================================================
function GetFactionColor(faction)
    if faction == 1 then
        return 0, 100, 255  -- Blue (Military)
    elseif faction == 2 then
        return 255, 50, 50  -- Red (Resistance)
    else
        return 200, 200, 200  -- Gray (Civilian)
    end
end

-- ============================================================================
-- COMMANDS
-- ============================================================================
RegisterCommand('nametags', function()
    nametagsEnabled = not nametagsEnabled
    lib.notify({
        type = 'info',
        description = 'Nametags ' .. (nametagsEnabled and 'enabled' or 'disabled')
    })
end, false)

-- ============================================================================
-- EXPORTS
-- ============================================================================
exports('AreNametagsEnabled', function() return nametagsEnabled end)
exports('SetNametagsEnabled', function(enabled) nametagsEnabled = enabled end)

Config.Print('client/nametags.lua loaded')
