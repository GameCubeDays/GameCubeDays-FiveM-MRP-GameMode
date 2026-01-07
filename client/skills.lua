--[[
    MRP GAMEMODE - CLIENT SKILLS
    ============================
    Handles skills menu and skill effects:
    - Skills menu UI (ox_lib)
    - Apply skill effects to player
    - Skill upgrade purchases
]]

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================
local PlayerSkills = {}
local SkillConfig = nil
local isApplyingEffects = false

-- ============================================================================
-- INITIALIZE SKILLS
-- ============================================================================
RegisterNetEvent('mrp:characterLoaded', function(characterData)
    PlayerSkills = characterData.skills or {}
    
    -- Request full skill config
    TriggerServerEvent('mrp:getSkills')
    
    -- Start applying effects
    StartSkillEffects()
end)

RegisterNetEvent('mrp:receiveSkills', function(skills, config)
    PlayerSkills = skills
    SkillConfig = config
    
    Config.Print('Skills loaded:', json.encode(PlayerSkills))
end)

RegisterNetEvent('mrp:skillUpgraded', function(skillId, newLevel)
    PlayerSkills[skillId] = newLevel
    
    -- Play sound
    PlaySoundFrontend(-1, 'RANK_UP', 'HUD_AWARDS', true)
end)

-- ============================================================================
-- SKILLS MENU
-- ============================================================================
function OpenSkillsMenu()
    if not MRP.PlayerData then
        lib.notify({ type = 'error', description = 'Character not loaded' })
        return
    end
    
    -- Request latest skills from server
    TriggerServerEvent('mrp:getSkills')
    
    Wait(200) -- Wait for response
    
    if not SkillConfig then
        lib.notify({ type = 'error', description = 'Skills not loaded yet' })
        return
    end
    
    local options = {}
    
    -- Add header with current XP
    table.insert(options, {
        title = 'Available XP: ' .. (MRP.PlayerData.xp or 0),
        description = 'Spend XP to upgrade skills',
        icon = 'star',
        iconColor = '#ffcc00',
        disabled = true
    })
    
    -- Add each skill
    for _, skill in ipairs(SkillConfig.list) do
        local currentLevel = PlayerSkills[skill.id] or 0
        local maxLevel = SkillConfig.maxLevel
        local isMaxed = currentLevel >= maxLevel
        
        -- Calculate cost for next level
        local cost = 0
        if not isMaxed then
            cost = math.floor(SkillConfig.xpCostBase * (SkillConfig.xpCostMultiplier ^ currentLevel))
        end
        
        -- Calculate current effect
        local currentEffect = skill.effectPerLevel * currentLevel
        local nextEffect = skill.effectPerLevel * (currentLevel + 1)
        
        local description = skill.description
        if isMaxed then
            description = description .. '\n[MAXED]'
        else
            description = description .. string.format('\nCost: %d XP', cost)
        end
        
        local progress = (currentLevel / maxLevel) * 100
        
        table.insert(options, {
            title = skill.name .. ' [' .. currentLevel .. '/' .. maxLevel .. ']',
            description = description,
            icon = GetSkillIcon(skill.id),
            iconColor = isMaxed and '#44ff44' or '#ffffff',
            progress = progress,
            colorScheme = isMaxed and 'green' or 'blue',
            metadata = {
                { label = 'Current Effect', value = string.format('+%.0f%%', currentEffect * 100) },
                { label = 'Next Level', value = isMaxed and 'MAX' or string.format('+%.0f%%', nextEffect * 100) },
                { label = 'Max Effect', value = string.format('+%.0f%%', skill.maxEffect * 100) }
            },
            disabled = isMaxed,
            onSelect = function()
                if not isMaxed then
                    ConfirmSkillUpgrade(skill, currentLevel, cost)
                end
            end
        })
    end
    
    lib.registerContext({
        id = 'mrp_skills_menu',
        title = 'Skills',
        options = options
    })
    
    lib.showContext('mrp_skills_menu')
end

-- Confirm skill upgrade
function ConfirmSkillUpgrade(skill, currentLevel, cost)
    local confirm = lib.alertDialog({
        header = 'Upgrade ' .. skill.name .. '?',
        content = string.format(
            'Upgrade **%s** to level %d?\n\n**Cost:** %d XP\n**Current XP:** %d\n\nThis will give you +%.0f%% %s',
            skill.name,
            currentLevel + 1,
            cost,
            MRP.PlayerData.xp or 0,
            skill.effectPerLevel * 100,
            skill.description:lower()
        ),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Upgrade',
            cancel = 'Cancel'
        }
    })
    
    if confirm == 'confirm' then
        TriggerServerEvent('mrp:upgradeSkill', skill.id)
        
        -- Reopen menu after brief delay
        SetTimeout(500, function()
            OpenSkillsMenu()
        end)
    else
        OpenSkillsMenu()
    end
end

-- Get icon for skill
function GetSkillIcon(skillId)
    local icons = {
        sprint_speed = 'person-running',
        stamina = 'heart-pulse',
        stamina_regen = 'lungs',
        weapon_accuracy = 'crosshairs',
        reload_speed = 'rotate',
        recoil_control = 'hand',
        revive_speed = 'kit-medical',
        xp_bonus = 'star',
        damage_resist = 'shield',
        health_regen = 'heart',
        bleedout_time = 'hourglass-half',
        money_bonus = 'dollar-sign',
        vehicle_handling = 'car',
        aircraft_handling = 'helicopter',
        vehicle_armor = 'wrench',
        swim_speed = 'person-swimming'
    }
    return icons[skillId] or 'circle'
end

-- ============================================================================
-- SKILL EFFECTS
-- ============================================================================
function StartSkillEffects()
    if isApplyingEffects then return end
    isApplyingEffects = true
    
    -- Main skill effects thread
    CreateThread(function()
        while MRP.IsLoaded do
            Wait(0)
            ApplySkillEffects()
        end
        isApplyingEffects = false
    end)
    
    -- Slower tick for regeneration effects
    CreateThread(function()
        while MRP.IsLoaded do
            Wait(1000)
            ApplyRegenEffects()
        end
    end)
end

function ApplySkillEffects()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end
    
    -- Sprint Speed
    local sprintBonus = GetSkillEffectValue('sprint_speed')
    if sprintBonus > 0 and IsPedSprinting(ped) then
        local baseSpeed = 1.0
        SetPedMoveRateOverride(ped, baseSpeed + sprintBonus)
    else
        SetPedMoveRateOverride(ped, 1.0)
    end
    
    -- Weapon Accuracy (reduce spread)
    local accuracyBonus = GetSkillEffectValue('weapon_accuracy')
    if accuracyBonus > 0 then
        SetPedAccuracy(ped, math.floor(50 + (50 * accuracyBonus)))
    end
    
    -- Swim Speed
    local swimBonus = GetSkillEffectValue('swim_speed')
    if swimBonus > 0 and IsPedSwimming(ped) then
        SetPedMoveRateOverride(ped, 1.0 + swimBonus)
    end
end

function ApplyRegenEffects()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end
    
    -- Health Regeneration
    local healthRegen = GetSkillEffectValue('health_regen')
    if healthRegen > 0 then
        local health = GetEntityHealth(ped)
        local maxHealth = GetEntityMaxHealth(ped)
        
        if health < maxHealth and health > 0 then
            local regenAmount = math.floor(1 + (5 * healthRegen))
            SetEntityHealth(ped, math.min(health + regenAmount, maxHealth))
        end
    end
    
    -- Stamina (handled by native game mechanics, but we can boost max)
    local staminaBonus = GetSkillEffectValue('stamina')
    if staminaBonus > 0 then
        -- Reset stamina depletion rate
        RestorePlayerStamina(PlayerId(), staminaBonus * 10)
    end
    
    -- Stamina Regeneration
    local staminaRegen = GetSkillEffectValue('stamina_regen')
    if staminaRegen > 0 then
        local currentStamina = GetPlayerSprintStaminaRemaining(PlayerId())
        if currentStamina < 100 then
            RestorePlayerStamina(PlayerId(), staminaRegen * 5)
        end
    end
end

-- Get skill effect value
function GetSkillEffectValue(skillId)
    if not SkillConfig or not PlayerSkills then return 0 end
    
    local level = PlayerSkills[skillId] or 0
    if level == 0 then return 0 end
    
    for _, skill in ipairs(SkillConfig.list) do
        if skill.id == skillId then
            local effect = skill.effectPerLevel * level
            return math.min(effect, skill.maxEffect)
        end
    end
    
    return 0
end

-- Export for other client scripts
exports('GetSkillEffectValue', GetSkillEffectValue)

-- ============================================================================
-- COMMANDS & KEYBINDS
-- ============================================================================

-- Command to open skills menu
RegisterCommand('skills', function()
    if not MRP.IsLoaded then return end
    OpenSkillsMenu()
end, false)

-- Keybind (K key)
RegisterKeyMapping('skills', 'Open Skills Menu', 'keyboard', 'k')

-- ============================================================================
-- XP/MONEY NOTIFICATIONS
-- ============================================================================
RegisterNetEvent('mrp:xpGained', function(amount, reason, totalXP)
    lib.notify({
        title = '+' .. amount .. ' XP',
        description = reason,
        type = 'success',
        duration = 3000,
        icon = 'star'
    })
    
    -- Update local data
    if MRP.PlayerData then
        MRP.PlayerData.xp = totalXP
    end
end)

RegisterNetEvent('mrp:xpLost', function(amount, reason, totalXP)
    lib.notify({
        title = '-' .. amount .. ' XP',
        description = reason,
        type = 'error',
        duration = 3000,
        icon = 'star'
    })
    
    if MRP.PlayerData then
        MRP.PlayerData.xp = totalXP
    end
end)

RegisterNetEvent('mrp:moneyGained', function(amount, reason, totalMoney)
    lib.notify({
        title = '+$' .. amount,
        description = reason,
        type = 'success',
        duration = 3000,
        icon = 'dollar-sign'
    })
    
    if MRP.PlayerData then
        MRP.PlayerData.money = totalMoney
    end
end)

RegisterNetEvent('mrp:moneyLost', function(amount, reason, totalMoney)
    lib.notify({
        title = '-$' .. amount,
        description = reason,
        type = 'error',
        duration = 3000,
        icon = 'dollar-sign'
    })
    
    if MRP.PlayerData then
        MRP.PlayerData.money = totalMoney
    end
end)

-- ============================================================================
-- RANK UP NOTIFICATION
-- ============================================================================
RegisterNetEvent('mrp:rankUp', function(rankData)
    -- Big notification
    lib.notify({
        title = 'RANK UP!',
        description = 'You are now ' .. rankData.name,
        type = 'success',
        duration = 8000,
        icon = 'chevron-up'
    })
    
    -- Play sounds
    PlaySoundFrontend(-1, 'RANK_UP', 'HUD_AWARDS', true)
    
    -- Screen effect
    StartScreenEffect('SuccessFranklin', 2000, false)
    
    -- Update local data
    if MRP.PlayerData then
        MRP.PlayerData.rankId = rankData.id
        MRP.PlayerData.rankName = rankData.name
        MRP.PlayerData.rankAbbr = rankData.abbr
    end
end)

-- ============================================================================
-- 30-MINUTE TICK NOTIFICATION
-- ============================================================================
RegisterNetEvent('mrp:tickReward', function(xp, money, pointsHeld)
    lib.notify({
        title = '30-Minute Reward',
        description = string.format('+%d XP | +$%d | %d Points Held', xp, money, pointsHeld),
        type = 'info',
        duration = 5000,
        icon = 'clock'
    })
end)

-- ============================================================================
-- FACTION ANNOUNCEMENTS
-- ============================================================================
RegisterNetEvent('mrp:factionAnnouncement', function(message)
    lib.notify({
        title = 'Faction',
        description = message,
        type = 'info',
        duration = 5000
    })
end)

RegisterNetEvent('mrp:serverAnnouncement', function(message)
    lib.notify({
        title = 'Server',
        description = message,
        type = 'warning',
        duration = 5000
    })
end)

-- ============================================================================
-- KILL FEED
-- ============================================================================
RegisterNetEvent('mrp:killFeed', function(data)
    -- Send to NUI
    SendNUIMessage({
        type = 'addKillFeed',
        killer = data.killer,
        victim = data.victim,
        killerFaction = data.killerFaction,
        victimFaction = data.victimFaction,
        isTeamkill = data.isTeamKill
    })
end)

Config.Print('client/skills.lua loaded')
