--[[
    MRP GAMEMODE - CLIENT COMBAT
    ============================
    Handles client-side combat mechanics:
    - Downed state visuals and controls
    - Revive interaction
    - Execution interaction
    - Death screen
    - Respawn handling
]]

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================
local isDowned = false
local isBeingRevived = false
local isReviving = false
local isExecuting = false
local bleedoutRemaining = 0
local canGiveUp = false
local reviveTarget = nil
local executionTarget = nil

-- ============================================================================
-- DEATH DETECTION
-- ============================================================================
CreateThread(function()
    while true do
        Wait(100)
        
        if MRP.IsLoaded and not isDowned then
            local ped = PlayerPedId()
            
            if IsEntityDead(ped) or IsPedFatallyInjured(ped) then
                -- Get killer info
                local killerPed, killerSrc = GetPedKiller(ped)
                local weaponHash = GetPedCauseOfDeath(ped)
                
                -- Determine killer source
                if killerPed and DoesEntityExist(killerPed) and IsPedAPlayer(killerPed) then
                    killerSrc = GetPlayerServerId(NetworkGetPlayerIndexFromPed(killerPed))
                end
                
                -- Trigger downed state
                TriggerServerEvent('mrp:playerDowned', killerSrc, weaponHash)
            end
        end
    end
end)

-- ============================================================================
-- DOWNED STATE
-- ============================================================================
RegisterNetEvent('mrp:enterDownedState', function(bleedoutTime, killerSrc)
    isDowned = true
    canGiveUp = false
    bleedoutRemaining = bleedoutTime
    MRP.IsDead = true
    
    local ped = PlayerPedId()
    
    -- Ragdoll the player
    SetPedToRagdoll(ped, 1000, 1000, 0, true, true, false)
    
    -- Disable most controls
    CreateThread(function()
        while isDowned do
            Wait(0)
            
            ped = PlayerPedId()
            
            -- Keep player in ragdoll/downed animation
            if not IsPedRagdoll(ped) then
                SetPedToRagdoll(ped, 1000, 1000, 0, true, true, false)
            end
            
            -- Disable controls except camera
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)  -- Camera X
            EnableControlAction(0, 2, true)  -- Camera Y
            EnableControlAction(0, 245, true) -- Chat
            
            -- Give up key (E)
            if canGiveUp then
                EnableControlAction(0, 38, true) -- E key
                
                if IsControlJustPressed(0, 38) then
                    StartGiveUpHold()
                end
            end
        end
    end)
    
    -- Show death screen
    local killerName = nil
    if killerSrc then
        local players = MRP.AllPlayers
        if players[killerSrc] then
            killerName = players[killerSrc].name
        end
    end
    
    SendNUIMessage({
        type = 'showDeath',
        killer = killerName,
        timer = bleedoutTime
    })
    
    -- Play downed sound
    PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
    
    Config.Print('Entered downed state | Bleedout:', bleedoutTime, 'sec')
end)

-- Update bleedout timer
RegisterNetEvent('mrp:updateBleedout', function(remaining)
    bleedoutRemaining = remaining
    
    SendNUIMessage({
        type = 'updateDeathTimer',
        timer = remaining,
        canGiveUp = canGiveUp
    })
end)

-- Can give up notification
RegisterNetEvent('mrp:canGiveUp', function()
    canGiveUp = true
    
    lib.notify({
        title = 'Give Up Available',
        description = 'Hold [E] to give up and respawn',
        type = 'info',
        duration = 3000
    })
end)

-- Give up hold mechanic
local giveUpHolding = false
local giveUpProgress = 0

function StartGiveUpHold()
    if giveUpHolding then return end
    giveUpHolding = true
    giveUpProgress = 0
    
    CreateThread(function()
        while giveUpHolding and isDowned and canGiveUp do
            Wait(100)
            
            if IsControlPressed(0, 38) then
                giveUpProgress = giveUpProgress + 10
                
                if giveUpProgress >= 100 then
                    -- Give up
                    TriggerServerEvent('mrp:giveUp')
                    giveUpHolding = false
                    break
                end
            else
                -- Released early
                giveUpHolding = false
                giveUpProgress = 0
            end
        end
        giveUpHolding = false
    end)
end

-- ============================================================================
-- REVIVE SYSTEM (BEING REVIVED)
-- ============================================================================
RegisterNetEvent('mrp:reviveStarted', function(otherSrc, reviveTime, isReviver)
    if isReviver then
        isReviving = true
        reviveTarget = otherSrc
        
        -- Show progress bar
        if lib.progressBar({
            duration = reviveTime * 1000,
            label = 'Reviving...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = true,
                car = true,
                combat = true
            },
            anim = {
                dict = 'mini@cpr@char_a@cpr_def',
                clip = 'cpr_pumpchest'
            }
        }) then
            -- Completed
            TriggerServerEvent('mrp:completeRevive', reviveTarget)
        else
            -- Cancelled
            TriggerServerEvent('mrp:cancelRevive', reviveTarget)
        end
        
        isReviving = false
        reviveTarget = nil
    else
        -- Being revived
        isBeingRevived = true
        
        lib.notify({
            title = 'Being Revived',
            description = 'A teammate is reviving you',
            type = 'info',
            duration = reviveTime * 1000
        })
        
        SendNUIMessage({
            type = 'showRevive',
            progress = 0
        })
    end
end)

RegisterNetEvent('mrp:reviveCancelled', function()
    isBeingRevived = false
    isReviving = false
    reviveTarget = nil
    
    SendNUIMessage({
        type = 'hideRevive'
    })
    
    if isDowned then
        lib.notify({
            title = 'Revive Cancelled',
            description = 'Revive was interrupted',
            type = 'error',
            duration = 3000
        })
    end
end)

RegisterNetEvent('mrp:revived', function(reviverSrc)
    isDowned = false
    isBeingRevived = false
    canGiveUp = false
    MRP.IsDead = false
    
    local ped = PlayerPedId()
    
    -- Clear ragdoll
    ClearPedTasksImmediately(ped)
    
    -- Set health
    SetEntityHealth(ped, 100)
    
    -- Hide death screen
    SendNUIMessage({
        type = 'hideDeath'
    })
    
    SendNUIMessage({
        type = 'hideRevive'
    })
    
    -- Notification
    lib.notify({
        title = 'Revived!',
        description = 'You have been revived by a teammate',
        type = 'success',
        duration = 3000
    })
    
    -- Play sound
    PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
    
    Config.Print('Player revived')
end)

RegisterNetEvent('mrp:reviveComplete', function(targetSrc)
    lib.notify({
        title = 'Revive Complete',
        description = 'Teammate revived successfully',
        type = 'success',
        duration = 3000
    })
end)

-- ============================================================================
-- EXECUTION SYSTEM
-- ============================================================================
RegisterNetEvent('mrp:executionStarted', function(targetSrc, executionTime)
    isExecuting = true
    executionTarget = targetSrc
    
    -- Show progress bar
    if lib.progressBar({
        duration = executionTime * 1000,
        label = 'Executing...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = 'melee@knife@streamed_core',
            clip = 'plyr_takedown_front_low_knife_a'
        }
    }) then
        -- Completed
        TriggerServerEvent('mrp:completeExecution', executionTarget)
    else
        -- Cancelled
        TriggerServerEvent('mrp:cancelExecution')
    end
    
    isExecuting = false
    executionTarget = nil
end)

RegisterNetEvent('mrp:beingExecuted', function(executorSrc)
    if isDowned then
        lib.notify({
            title = 'Being Executed!',
            description = 'An enemy is executing you!',
            type = 'error',
            duration = 3000
        })
    end
end)

RegisterNetEvent('mrp:executionCancelled', function()
    isExecuting = false
    executionTarget = nil
end)

-- ============================================================================
-- DEATH & RESPAWN
-- ============================================================================
RegisterNetEvent('mrp:playerDied', function(deathType, killerSrc)
    isDowned = false
    canGiveUp = false
    
    -- Keep death screen visible briefly
    Wait(2000)
    
    -- Hide death screen
    SendNUIMessage({
        type = 'hideDeath'
    })
    
    -- Show respawn countdown
    local respawnTime = Config.Combat.respawnTime or 5
    
    lib.notify({
        title = 'You Died',
        description = 'Respawning in ' .. respawnTime .. ' seconds...',
        type = 'error',
        duration = respawnTime * 1000
    })
    
    Wait(respawnTime * 1000)
    
    -- Request respawn
    TriggerServerEvent('mrp:requestRespawn')
end)

RegisterNetEvent('mrp:respawn', function(spawnPoint)
    local ped = PlayerPedId()
    
    -- Screen fade
    DoScreenFadeOut(500)
    Wait(500)
    
    -- Respawn
    NetworkResurrectLocalPlayer(spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w, true, false)
    
    -- Clear states
    isDowned = false
    isBeingRevived = false
    MRP.IsDead = false
    
    -- Set health
    Wait(100)
    ped = PlayerPedId()
    SetEntityHealth(ped, 200)
    ClearPedTasksImmediately(ped)
    ClearPlayerWantedLevel(PlayerId())
    
    -- Fade back in
    DoScreenFadeIn(500)
    
    -- Notification
    lib.notify({
        title = 'Respawned',
        description = 'You have respawned at your base',
        type = 'info',
        duration = 3000
    })
    
    Config.Print('Player respawned')
end)

-- Admin revive
RegisterNetEvent('mrp:adminRevive', function()
    local ped = PlayerPedId()
    
    isDowned = false
    isBeingRevived = false
    canGiveUp = false
    MRP.IsDead = false
    
    -- Clear ragdoll
    ClearPedTasksImmediately(ped)
    
    -- Respawn if dead
    if IsEntityDead(ped) then
        NetworkResurrectLocalPlayer(GetEntityCoords(ped), GetEntityHeading(ped), true, false)
        Wait(100)
        ped = PlayerPedId()
    end
    
    -- Set health
    SetEntityHealth(ped, 200)
    
    -- Hide screens
    SendNUIMessage({ type = 'hideDeath' })
    SendNUIMessage({ type = 'hideRevive' })
    
    lib.notify({
        title = 'Revived',
        description = 'You have been revived by an admin',
        type = 'success',
        duration = 3000
    })
end)

-- ============================================================================
-- INTERACTION DETECTION
-- ============================================================================
CreateThread(function()
    while true do
        Wait(500)
        
        if MRP.IsLoaded and not isDowned and not isReviving and not isExecuting then
            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)
            
            -- Look for nearby downed players
            for playerId, playerData in pairs(MRP.AllPlayers) do
                if playerId ~= GetPlayerServerId(PlayerId()) then
                    local targetPed = GetPlayerPed(GetPlayerFromServerId(playerId))
                    
                    if targetPed and DoesEntityExist(targetPed) then
                        local targetCoords = GetEntityCoords(targetPed)
                        local distance = #(playerCoords - targetCoords)
                        
                        if distance < 2.5 then
                            -- Check if player is downed (ragdoll or dead-like state)
                            if IsPedRagdoll(targetPed) or IsEntityDead(targetPed) then
                                local myFaction = MRP.PlayerData and MRP.PlayerData.faction
                                local targetFaction = playerData.faction
                                
                                if myFaction == targetFaction then
                                    -- Same team - show revive prompt
                                    DrawText3D(targetCoords.x, targetCoords.y, targetCoords.z + 0.5, '[E] Revive')
                                    
                                    if IsControlJustPressed(0, 38) then -- E key
                                        TriggerServerEvent('mrp:startRevive', playerId)
                                    end
                                else
                                    -- Enemy - show execution prompt
                                    DrawText3D(targetCoords.x, targetCoords.y, targetCoords.z + 0.5, '[E] Execute')
                                    
                                    if IsControlJustPressed(0, 38) then -- E key
                                        TriggerServerEvent('mrp:startExecution', playerId)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        Wait(0) -- Quick loop for interaction detection
    end
end)

-- ============================================================================
-- DAMAGE TRACKING
-- ============================================================================
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local attacker = args[2]
        local damage = args[4]
        
        if victim == PlayerPedId() and attacker and DoesEntityExist(attacker) and IsPedAPlayer(attacker) then
            local attackerSrc = GetPlayerServerId(NetworkGetPlayerIndexFromPed(attacker))
            TriggerServerEvent('mrp:playerTookDamage', attackerSrc, damage)
        end
    end
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

function IsPlayerDowned()
    return isDowned
end

function IsPlayerBeingRevived()
    return isBeingRevived
end

-- Exports
exports('IsPlayerDowned', IsPlayerDowned)
exports('IsPlayerBeingRevived', IsPlayerBeingRevived)

-- ============================================================================
-- OTHER PLAYER EVENTS
-- ============================================================================
RegisterNetEvent('mrp:playerWentDown', function(playerSrc, playerName, faction, killerName)
    -- Only show for same faction
    if MRP.PlayerData and MRP.PlayerData.faction == faction then
        local message = playerName .. ' is down!'
        if killerName then
            message = playerName .. ' was downed by ' .. killerName
        end
        
        lib.notify({
            title = 'Teammate Down!',
            description = message,
            type = 'warning',
            duration = 5000
        })
    end
end)

RegisterNetEvent('mrp:playerFullyDied', function(playerSrc)
    -- Update any local tracking
end)

Config.Print('client/combat.lua loaded')
