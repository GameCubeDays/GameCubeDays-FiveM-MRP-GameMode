--[[
    MRP GAMEMODE - CLIENT ROSTER
    ============================
    Handles player rosters:
    - TAB key online roster (scoreboard)
    - /roster command (full details)
    - Faction-grouped display
]]

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================
local isRosterOpen = false
local rosterData = {}

-- ============================================================================
-- TAB ROSTER (SCOREBOARD)
-- ============================================================================
CreateThread(function()
    while true do
        Wait(0)
        
        if MRP.IsLoaded then
            -- Check for TAB key
            if IsControlPressed(0, 37) then -- TAB
                if not isRosterOpen then
                    isRosterOpen = true
                    ShowTabRoster()
                end
            else
                if isRosterOpen then
                    isRosterOpen = false
                    HideTabRoster()
                end
            end
        end
    end
end)

function ShowTabRoster()
    if not MRP.AllPlayers then return end
    
    -- Group players by faction
    local factions = {
        [1] = { name = 'Military', color = {0, 100, 255}, players = {} },
        [2] = { name = 'Resistance', color = {255, 50, 50}, players = {} },
        [3] = { name = 'Civilian', color = {200, 200, 200}, players = {} }
    }
    
    for playerId, playerData in pairs(MRP.AllPlayers) do
        local faction = playerData.faction or 3
        table.insert(factions[faction].players, {
            id = playerId,
            name = playerData.name or 'Unknown',
            rank = playerData.rankAbbr or '???',
            whitelist = GetWhitelistAbbr(playerData.whitelist),
            kills = playerData.kills or 0,
            deaths = playerData.deaths or 0,
            ping = GetPlayerPing(GetPlayerFromServerId(playerId))
        })
    end
    
    -- Sort players by rank within each faction
    for _, factionData in pairs(factions) do
        table.sort(factionData.players, function(a, b)
            return (a.kills or 0) > (b.kills or 0)
        end)
    end
    
    -- Send to NUI
    SendNUIMessage({
        type = 'showRoster',
        factions = factions,
        myFaction = MRP.PlayerData and MRP.PlayerData.faction or 0
    })
end

function HideTabRoster()
    SendNUIMessage({
        type = 'hideRoster'
    })
end

-- ============================================================================
-- MASTER ROSTER COMMAND
-- ============================================================================
RegisterCommand('roster', function(source, args)
    if not MRP.IsLoaded then return end
    
    local factionFilter = nil
    
    if args[1] then
        local filterArg = string.lower(args[1])
        if filterArg == 'mil' or filterArg == 'military' or filterArg == '1' then
            factionFilter = 1
        elseif filterArg == 'res' or filterArg == 'resistance' or filterArg == '2' then
            factionFilter = 2
        elseif filterArg == 'civ' or filterArg == 'civilian' or filterArg == '3' then
            factionFilter = 3
        end
    end
    
    ShowMasterRoster(factionFilter)
end, false)

function ShowMasterRoster(factionFilter)
    if not MRP.AllPlayers then
        lib.notify({ type = 'error', description = 'No player data available' })
        return
    end
    
    local options = {}
    
    -- Header with player counts
    local milCount, resCount, civCount = 0, 0, 0
    for _, playerData in pairs(MRP.AllPlayers) do
        if playerData.faction == 1 then milCount = milCount + 1
        elseif playerData.faction == 2 then resCount = resCount + 1
        else civCount = civCount + 1 end
    end
    
    table.insert(options, {
        title = 'Online Players',
        description = string.format('Military: %d | Resistance: %d | Civilian: %d', milCount, resCount, civCount),
        icon = 'users',
        disabled = true
    })
    
    -- Add players
    for playerId, playerData in pairs(MRP.AllPlayers) do
        if not factionFilter or playerData.faction == factionFilter then
            local factionName = GetFactionName(playerData.faction)
            local factionIcon = GetFactionIcon(playerData.faction)
            local iconColor = GetFactionColorHex(playerData.faction)
            
            local kd = '0.00'
            if playerData.deaths and playerData.deaths > 0 then
                kd = string.format('%.2f', (playerData.kills or 0) / playerData.deaths)
            elseif playerData.kills and playerData.kills > 0 then
                kd = string.format('%.2f', playerData.kills)
            end
            
            table.insert(options, {
                title = string.format('[%s] %s %s', 
                    GetWhitelistAbbr(playerData.whitelist),
                    playerData.rankAbbr or '???',
                    playerData.name or 'Unknown'
                ),
                description = factionName,
                icon = factionIcon,
                iconColor = iconColor,
                metadata = {
                    { label = 'ID', value = playerId },
                    { label = 'Kills', value = playerData.kills or 0 },
                    { label = 'Deaths', value = playerData.deaths or 0 },
                    { label = 'K/D', value = kd },
                    { label = 'Captures', value = playerData.captures or 0 },
                    { label = 'Ping', value = GetPlayerPing(GetPlayerFromServerId(playerId)) .. 'ms' }
                }
            })
        end
    end
    
    if #options == 1 then
        table.insert(options, {
            title = 'No Players',
            description = factionFilter and 'No players in this faction' or 'No players online',
            icon = 'user-slash',
            disabled = true
        })
    end
    
    lib.registerContext({
        id = 'mrp_master_roster',
        title = 'Player Roster',
        options = options
    })
    
    lib.showContext('mrp_master_roster')
end

-- ============================================================================
-- FACTION INFO
-- ============================================================================
RegisterCommand('factions', function()
    if not MRP.AllPlayers then return end
    
    local counts = { [1] = 0, [2] = 0, [3] = 0 }
    
    for _, playerData in pairs(MRP.AllPlayers) do
        local faction = playerData.faction or 3
        counts[faction] = counts[faction] + 1
    end
    
    local options = {
        {
            title = Config.Factions[1].name,
            description = counts[1] .. ' players online',
            icon = 'shield',
            iconColor = '#0064ff',
            onSelect = function()
                ShowMasterRoster(1)
            end
        },
        {
            title = Config.Factions[2].name,
            description = counts[2] .. ' players online',
            icon = 'fist-raised',
            iconColor = '#ff3232',
            onSelect = function()
                ShowMasterRoster(2)
            end
        },
        {
            title = Config.Factions[3].name,
            description = counts[3] .. ' players online',
            icon = 'user',
            iconColor = '#c8c8c8',
            onSelect = function()
                ShowMasterRoster(3)
            end
        }
    }
    
    lib.registerContext({
        id = 'mrp_factions',
        title = 'Factions',
        options = options
    })
    
    lib.showContext('mrp_factions')
end, false)

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================
function GetWhitelistAbbr(whitelist)
    local abbrs = {
        ['army'] = 'ARMY',
        ['navy'] = 'NAVY',
        ['marine'] = 'MARN',
        ['fighter'] = 'FGTR',
        ['militia'] = 'MLIT',
        ['citizen'] = 'CIV'
    }
    return abbrs[whitelist] or string.upper(string.sub(whitelist or 'UNK', 1, 4))
end

function GetFactionName(faction)
    if Config.Factions[faction] then
        return Config.Factions[faction].name
    end
    return 'Unknown'
end

function GetFactionIcon(faction)
    local icons = {
        [1] = 'shield',
        [2] = 'fist-raised',
        [3] = 'user'
    }
    return icons[faction] or 'user'
end

function GetFactionColorHex(faction)
    local colors = {
        [1] = '#0064ff',
        [2] = '#ff3232',
        [3] = '#c8c8c8'
    }
    return colors[faction] or '#ffffff'
end

-- ============================================================================
-- KEYBIND INFO
-- ============================================================================
RegisterCommand('hudhelp', function()
    lib.notify({
        title = 'HUD Controls',
        description = 'TAB = Roster | K = Skills | L = Lock Vehicle',
        type = 'info',
        duration = 8000
    })
end, false)

Config.Print('client/roster.lua loaded')
