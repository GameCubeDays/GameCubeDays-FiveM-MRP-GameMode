--[[
    MRP GAMEMODE - CLIENT CHARACTERS
    =================================
    Character selection and creation UI:
    - Character selection menu
    - Character creation dialog
    - Character deletion confirmation
    - Uses ox_lib for all UI
]]

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================
local isSelectingCharacter = false
local currentCharacters = {}

-- ============================================================================
-- OPEN CHARACTER SELECTION
-- ============================================================================
RegisterNetEvent('mrp:openCharacterSelect', function()
    isSelectingCharacter = true
    
    -- Freeze player and hide
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)
    
    -- Set camera to nice view
    SetupSelectionCamera()
    
    -- Request characters from server
    TriggerServerEvent('mrp:getCharacters')
    
    Config.Print('Opening character selection')
end)

-- ============================================================================
-- RECEIVE CHARACTERS FROM SERVER
-- ============================================================================
RegisterNetEvent('mrp:receiveCharacters', function(characters)
    currentCharacters = characters
    ShowCharacterMenu()
end)

-- ============================================================================
-- CHARACTER SELECTION MENU
-- ============================================================================
function ShowCharacterMenu()
    local options = {}
    
    -- Add options for each faction
    for factionId = 1, 3 do
        local faction = Config.Factions[factionId]
        local character = currentCharacters[factionId]
        
        if character then
            -- Existing character
            local kdRatio = character.deaths > 0 and string.format('%.2f', character.kills / character.deaths) or tostring(character.kills)
            
            table.insert(options, {
                title = character.name,
                description = string.format('%s | %s %s', faction.name, character.rankAbbr, character.whitelistName),
                icon = factionId == 1 and 'shield-halved' or (factionId == 2 and 'crosshairs' or 'user'),
                iconColor = string.format('rgb(%d,%d,%d)', faction.color.r, faction.color.g, faction.color.b),
                metadata = {
                    { label = 'XP', value = character.xp },
                    { label = 'Money', value = '$' .. character.money },
                    { label = 'K/D', value = character.kills .. '/' .. character.deaths .. ' (' .. kdRatio .. ')' },
                    { label = 'Captures', value = character.captures },
                    { label = 'Playtime', value = FormatPlaytime(character.playtime) }
                },
                onSelect = function()
                    SelectCharacter(factionId)
                end,
                args = { faction = factionId }
            })
            
            -- Add delete option
            table.insert(options, {
                title = 'Delete ' .. character.name,
                description = 'Permanently delete this character',
                icon = 'trash',
                iconColor = '#ff4444',
                onSelect = function()
                    ConfirmDeleteCharacter(factionId, character.name)
                end
            })
        else
            -- No character - create option
            table.insert(options, {
                title = 'Create ' .. faction.name .. ' Character',
                description = 'Start a new character in the ' .. faction.name .. ' faction',
                icon = 'plus',
                iconColor = string.format('rgb(%d,%d,%d)', faction.color.r, faction.color.g, faction.color.b),
                onSelect = function()
                    CreateCharacterDialog(factionId)
                end
            })
        end
        
        -- Add separator between factions (except last)
        if factionId < 3 then
            table.insert(options, {
                title = '',
                disabled = true
            })
        end
    end
    
    -- Show menu
    lib.registerContext({
        id = 'mrp_character_select',
        title = 'Select Your Character',
        options = options,
        onExit = function()
            -- Don't allow closing without selecting
            if isSelectingCharacter then
                Wait(100)
                ShowCharacterMenu()
            end
        end
    })
    
    lib.showContext('mrp_character_select')
end

-- ============================================================================
-- SELECT CHARACTER
-- ============================================================================
function SelectCharacter(factionId)
    isSelectingCharacter = false
    
    -- Show loading
    lib.showTextUI('Loading character...', {
        icon = 'spinner',
        iconAnimation = 'spin'
    })
    
    TriggerServerEvent('mrp:selectCharacter', factionId)
end

-- ============================================================================
-- CHARACTER SELECT RESULT
-- ============================================================================
RegisterNetEvent('mrp:characterSelectResult', function(success, message)
    lib.hideTextUI()
    
    if success then
        -- Unfreeze and show player
        local ped = PlayerPedId()
        Wait(500) -- Wait for model change
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        SetEntityInvincible(ped, false)
        
        -- Destroy selection camera
        DestroySelectionCamera()
        
        Config.Print('Character selected successfully')
    else
        lib.notify({
            title = 'Error',
            description = message,
            type = 'error'
        })
        
        -- Reopen selection
        ShowCharacterMenu()
    end
end)

-- ============================================================================
-- CREATE CHARACTER DIALOG
-- ============================================================================
function CreateCharacterDialog(factionId)
    local faction = Config.Factions[factionId]
    
    local input = lib.inputDialog('Create ' .. faction.name .. ' Character', {
        {
            type = 'input',
            label = 'Character Name',
            description = '3-20 characters, letters, numbers, and spaces only',
            required = true,
            min = 3,
            max = 20
        }
    })
    
    if not input then
        -- Cancelled, return to menu
        ShowCharacterMenu()
        return
    end
    
    local name = input[1]
    
    -- Basic validation
    if #name < 3 or #name > 20 then
        lib.notify({
            title = 'Invalid Name',
            description = 'Name must be 3-20 characters',
            type = 'error'
        })
        CreateCharacterDialog(factionId)
        return
    end
    
    -- Check valid characters
    if not string.match(name, '^[%w%s]+$') then
        lib.notify({
            title = 'Invalid Name',
            description = 'Name can only contain letters, numbers, and spaces',
            type = 'error'
        })
        CreateCharacterDialog(factionId)
        return
    end
    
    -- Show loading
    lib.showTextUI('Creating character...', {
        icon = 'spinner',
        iconAnimation = 'spin'
    })
    
    TriggerServerEvent('mrp:createCharacter', {
        faction = factionId,
        name = name
    })
end

-- ============================================================================
-- CHARACTER CREATE RESULT
-- ============================================================================
RegisterNetEvent('mrp:characterCreateResult', function(success, message)
    lib.hideTextUI()
    
    if success then
        lib.notify({
            title = 'Success',
            description = message,
            type = 'success'
        })
        
        -- Refresh characters and reopen menu
        TriggerServerEvent('mrp:getCharacters')
    else
        lib.notify({
            title = 'Error',
            description = message,
            type = 'error'
        })
        
        -- Return to menu
        ShowCharacterMenu()
    end
end)

-- ============================================================================
-- DELETE CHARACTER
-- ============================================================================
function ConfirmDeleteCharacter(factionId, characterName)
    local confirm = lib.alertDialog({
        header = 'Delete Character',
        content = string.format('Are you sure you want to **permanently delete** %s?\n\nThis action cannot be undone. All progress, money, XP, and unlocks will be lost.', characterName),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Delete Forever',
            cancel = 'Cancel'
        }
    })
    
    if confirm == 'confirm' then
        -- Double confirm with name input
        local input = lib.inputDialog('Confirm Deletion', {
            {
                type = 'input',
                label = 'Type the character name to confirm',
                description = 'Enter: ' .. characterName,
                required = true
            }
        })
        
        if input and input[1] == characterName then
            lib.showTextUI('Deleting character...', {
                icon = 'spinner',
                iconAnimation = 'spin'
            })
            
            TriggerServerEvent('mrp:deleteCharacter', factionId)
        else
            lib.notify({
                title = 'Cancelled',
                description = 'Character name did not match',
                type = 'info'
            })
            ShowCharacterMenu()
        end
    else
        ShowCharacterMenu()
    end
end

-- ============================================================================
-- CHARACTER DELETE RESULT
-- ============================================================================
RegisterNetEvent('mrp:characterDeleteResult', function(success, message)
    lib.hideTextUI()
    
    if success then
        lib.notify({
            title = 'Deleted',
            description = message,
            type = 'success'
        })
    else
        lib.notify({
            title = 'Error',
            description = message,
            type = 'error'
        })
    end
    
    -- Refresh and show menu
    TriggerServerEvent('mrp:getCharacters')
end)

-- ============================================================================
-- CAMERA SETUP
-- ============================================================================
local selectionCam = nil

function SetupSelectionCamera()
    -- Create camera with nice view of the map
    local camCoords = vector3(-75.0, -818.0, 326.0) -- Above city
    local camRot = vector3(-45.0, 0.0, 0.0)
    
    selectionCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(selectionCam, camCoords.x, camCoords.y, camCoords.z)
    SetCamRot(selectionCam, camRot.x, camRot.y, camRot.z, 2)
    SetCamFov(selectionCam, 50.0)
    
    RenderScriptCams(true, true, 1000, true, true)
    
    -- Fade in
    DoScreenFadeIn(500)
end

function DestroySelectionCamera()
    if selectionCam then
        RenderScriptCams(false, true, 1000, true, true)
        DestroyCam(selectionCam, true)
        selectionCam = nil
    end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================
function FormatPlaytime(minutes)
    if minutes < 60 then
        return minutes .. ' min'
    elseif minutes < 1440 then
        local hours = math.floor(minutes / 60)
        local mins = minutes % 60
        return string.format('%dh %dm', hours, mins)
    else
        local days = math.floor(minutes / 1440)
        local hours = math.floor((minutes % 1440) / 60)
        return string.format('%dd %dh', days, hours)
    end
end

-- ============================================================================
-- CLEANUP ON RESOURCE STOP
-- ============================================================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    DestroySelectionCamera()
    lib.hideContext()
    lib.hideTextUI()
end)

Config.Print('client/characters.lua loaded')
