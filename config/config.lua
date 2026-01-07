--[[
    MRP GAMEMODE - CONFIGURATION FILE
    =================================
    All tunable game variables are defined here.
    Adjust these values to balance gameplay without touching code.
    
    ORGANIZATION:
    - General Settings
    - Factions & Whitelists
    - Ranks (Per Faction)
    - Spawn Points & Bases
    - Capture Points
    - XP & Progression
    - Money & Economy
    - Skills
    - Weapons & Loadouts
    - Vehicles
    - Combat & Death
    - HUD & UI
    - Admin
]]

Config = {}

-- ============================================================================
-- GENERAL SETTINGS
-- ============================================================================
Config.Debug = true                          -- Enable debug prints in console
Config.ServerTickRate = 1800000              -- 30 minutes in milliseconds (1800000ms)
Config.ResourceName = 'mrp_gamemode'

-- ============================================================================
-- FACTIONS
-- ============================================================================
Config.Factions = {
    [1] = {
        id = 1,
        name = 'Military',
        shortName = 'MIL',
        color = {r = 0, g = 100, b = 255},   -- Blue
        blipColor = 38,                       -- Blue blip
        canCapture = true
    },
    [2] = {
        id = 2,
        name = 'Resistance',
        shortName = 'RES',
        color = {r = 255, g = 50, b = 50},   -- Red
        blipColor = 1,                        -- Red blip
        canCapture = true
    },
    [3] = {
        id = 3,
        name = 'Civilian',
        shortName = 'CIV',
        color = {r = 200, g = 200, b = 200}, -- Gray
        blipColor = 4,                        -- White blip
        canCapture = false
    }
}

-- ============================================================================
-- WHITELISTS (Sub-factions)
-- ============================================================================
Config.Whitelists = {
    -- Military whitelists
    [1] = {
        { id = 'army',   name = 'Army',   faction = 1 },
        { id = 'navy',   name = 'Navy',   faction = 1 },
        { id = 'marine', name = 'Marine', faction = 1 }
    },
    -- Resistance whitelists
    [2] = {
        { id = 'fighter', name = 'Resistance Fighter', faction = 2 },
        { id = 'militia', name = 'Rogue Militia',      faction = 2 }
    },
    -- Civilian whitelists
    [3] = {
        { id = 'citizen', name = 'Citizen', faction = 3 }
    }
}

-- Default whitelist when player creates character (first in list)
Config.DefaultWhitelist = {
    [1] = 'army',
    [2] = 'fighter',
    [3] = 'citizen'
}

-- ============================================================================
-- RANKS (Per Faction - Currently identical, easy to diverge later)
-- ============================================================================
Config.Ranks = {
    -- Military Ranks
    [1] = {
        { id = 1,  name = 'Private',             abbr = 'PVT',  xpRequired = 0 },
        { id = 2,  name = 'Private First Class', abbr = 'PFC',  xpRequired = 500 },
        { id = 3,  name = 'Corporal',            abbr = 'CPL',  xpRequired = 1500 },
        { id = 4,  name = 'Sergeant',            abbr = 'SGT',  xpRequired = 3500 },
        { id = 5,  name = 'Staff Sergeant',      abbr = 'SSG',  xpRequired = 6500 },
        { id = 6,  name = 'Sergeant First Class',abbr = 'SFC',  xpRequired = 10500 },
        { id = 7,  name = 'Master Sergeant',     abbr = 'MSG',  xpRequired = 16000 },
        { id = 8,  name = 'First Sergeant',      abbr = '1SG',  xpRequired = 23000 },
        { id = 9,  name = 'Sergeant Major',      abbr = 'SGM',  xpRequired = 32000 },
        { id = 10, name = 'Second Lieutenant',   abbr = '2LT',  xpRequired = 45000 },
        { id = 11, name = 'First Lieutenant',    abbr = '1LT',  xpRequired = 60000 },
        { id = 12, name = 'Captain',             abbr = 'CPT',  xpRequired = 80000 },
        { id = 13, name = 'Major',               abbr = 'MAJ',  xpRequired = 105000 },
        { id = 14, name = 'Lieutenant Colonel',  abbr = 'LTC',  xpRequired = 140000 },
        { id = 15, name = 'Colonel',             abbr = 'COL',  xpRequired = 185000 },
        { id = 16, name = 'Brigadier General',   abbr = 'BG',   xpRequired = 250000 },
        { id = 17, name = 'Major General',       abbr = 'MG',   xpRequired = 350000 },
        { id = 18, name = 'Lieutenant General',  abbr = 'LTG',  xpRequired = 500000 },
        { id = 19, name = 'General',             abbr = 'GEN',  xpRequired = 750000 }
    },
    -- Resistance Ranks (same structure, can be customized)
    [2] = {
        { id = 1,  name = 'Private',             abbr = 'PVT',  xpRequired = 0 },
        { id = 2,  name = 'Private First Class', abbr = 'PFC',  xpRequired = 500 },
        { id = 3,  name = 'Corporal',            abbr = 'CPL',  xpRequired = 1500 },
        { id = 4,  name = 'Sergeant',            abbr = 'SGT',  xpRequired = 3500 },
        { id = 5,  name = 'Staff Sergeant',      abbr = 'SSG',  xpRequired = 6500 },
        { id = 6,  name = 'Sergeant First Class',abbr = 'SFC',  xpRequired = 10500 },
        { id = 7,  name = 'Master Sergeant',     abbr = 'MSG',  xpRequired = 16000 },
        { id = 8,  name = 'First Sergeant',      abbr = '1SG',  xpRequired = 23000 },
        { id = 9,  name = 'Sergeant Major',      abbr = 'SGM',  xpRequired = 32000 },
        { id = 10, name = 'Second Lieutenant',   abbr = '2LT',  xpRequired = 45000 },
        { id = 11, name = 'First Lieutenant',    abbr = '1LT',  xpRequired = 60000 },
        { id = 12, name = 'Captain',             abbr = 'CPT',  xpRequired = 80000 },
        { id = 13, name = 'Major',               abbr = 'MAJ',  xpRequired = 105000 },
        { id = 14, name = 'Lieutenant Colonel',  abbr = 'LTC',  xpRequired = 140000 },
        { id = 15, name = 'Colonel',             abbr = 'COL',  xpRequired = 185000 },
        { id = 16, name = 'Brigadier General',   abbr = 'BG',   xpRequired = 250000 },
        { id = 17, name = 'Major General',       abbr = 'MG',   xpRequired = 350000 },
        { id = 18, name = 'Lieutenant General',  abbr = 'LTG',  xpRequired = 500000 },
        { id = 19, name = 'General',             abbr = 'GEN',  xpRequired = 750000 }
    },
    -- Civilian Ranks (simplified)
    [3] = {
        { id = 1, name = 'Citizen', abbr = 'CIV', xpRequired = 0 }
    }
}

-- Minimum rank ID to promote others (Sergeant = 4)
Config.MinRankToPromote = 4

-- Promotion limits by rank
Config.PromotionLimits = {
    -- [promoterRankId] = maxRankTheyCanPromoteTo
    [4] = 3,   -- Sergeant can promote up to Corporal
    [5] = 4,   -- Staff Sergeant can promote up to Sergeant
    [6] = 5,   -- SFC can promote up to Staff Sergeant
    [7] = 6,   -- MSG can promote up to SFC
    [8] = 7,   -- 1SG can promote up to MSG
    [9] = 8,   -- SGM can promote up to 1SG
    [10] = 9,  -- 2LT can promote up to SGM (all enlisted)
    [11] = 9,  -- 1LT can promote up to SGM
    [12] = 19, -- Captain and above can promote anyone
    [13] = 19,
    [14] = 19,
    [15] = 19,
    [16] = 19,
    [17] = 19,
    [18] = 19,
    [19] = 19
}

-- ============================================================================
-- PLAYER MODELS (Per Whitelist)
-- ============================================================================
Config.PlayerModels = {
    -- Military models
    ['army'] = {
        'mp_m_freemode_01',
        's_m_y_marine_01',
        's_m_y_marine_02',
        's_m_y_marine_03',
        's_m_m_marine_01',
        's_m_m_marine_02'
    },
    ['navy'] = {
        's_m_y_marine_01',
        's_m_y_marine_02'
    },
    ['marine'] = {
        's_m_y_marine_01',
        's_m_y_marine_02',
        's_m_y_marine_03'
    },
    -- Resistance models
    ['fighter'] = {
        'g_m_y_famca_01',
        'g_m_y_famdnf_01',
        'g_m_y_famfor_01',
        'g_m_y_lost_01',
        'g_m_y_lost_02'
    },
    ['militia'] = {
        'g_m_y_mexgang_01',
        'g_m_y_mexgoon_01',
        'g_m_y_mexgoon_02',
        'g_m_y_mexgoon_03'
    },
    -- Civilian models
    ['citizen'] = {
        'a_m_m_business_01',
        'a_m_y_business_01',
        'a_f_m_business_02',
        'a_m_y_hipster_01',
        'a_f_y_hipster_01'
    }
}

-- ============================================================================
-- BASE LOCATIONS & SPAWN POINTS
-- ============================================================================
Config.Bases = {
    -- Military Base (Fort Zancudo)
    [1] = {
        name = 'Fort Zancudo',
        faction = 1,
        spawnPoints = {
            vector4(-2357.31, 3249.51, 32.81, 50.0),
            vector4(-2365.12, 3261.23, 32.81, 45.0),
            vector4(-2347.89, 3256.78, 32.81, 55.0),
            vector4(-2340.45, 3267.34, 32.81, 40.0)
        },
        armory = vector3(-2358.10, 3249.30, 32.81),
        vehicleSpawn = vector4(-2364.50, 3243.20, 32.81, 140.0),
        capturePoint = vector3(-2358.00, 3250.00, 32.81)
    },
    -- Resistance Base (Sandy Shores Airfield)
    [2] = {
        name = 'Sandy Shores Airfield',
        faction = 2,
        spawnPoints = {
            vector4(1747.25, 3273.61, 41.12, 15.0),
            vector4(1755.34, 3281.45, 41.12, 20.0),
            vector4(1739.67, 3285.23, 41.12, 10.0),
            vector4(1762.12, 3269.89, 41.12, 25.0)
        },
        armory = vector3(1748.00, 3274.00, 41.12),
        vehicleSpawn = vector4(1735.00, 3292.00, 41.12, 100.0),
        capturePoint = vector3(1750.00, 3275.00, 41.12)
    }
}

-- Civilian spawn points (random across map)
Config.CivilianSpawns = {
    vector4(215.76, -810.12, 30.72, 90.0),    -- Legion Square
    vector4(-269.45, -955.34, 31.22, 180.0),  -- Pillbox Hill
    vector4(434.12, -628.45, 28.72, 0.0),     -- Alta
    vector4(-1227.89, -906.23, 12.32, 45.0),  -- Del Perro
    vector4(1198.34, -1653.67, 43.02, 270.0)  -- Mirror Park
}

-- ============================================================================
-- CAPTURE POINTS
-- ============================================================================
Config.CapturePoints = {
    -- Northern Region
    { id = 1,  name = 'Paleto Bay',           pos = vector3(-379.53, 6118.32, 31.85),  radius = 25.0, tier = 'low',      isBase = false },
    { id = 2,  name = 'Paleto Forest',        pos = vector3(-552.12, 5326.45, 74.23),  radius = 25.0, tier = 'low',      isBase = false },
    { id = 3,  name = 'Mount Chiliad',        pos = vector3(501.23, 5604.56, 797.91),  radius = 30.0, tier = 'medium',   isBase = false },
    { id = 4,  name = 'Grapeseed',            pos = vector3(1678.34, 4815.67, 42.01),  radius = 25.0, tier = 'low',      isBase = false },
    { id = 5,  name = 'Sandy Shores Town',    pos = vector3(1959.45, 3740.78, 32.34),  radius = 25.0, tier = 'medium',   isBase = false },
    { id = 6,  name = 'Alamo Sea',            pos = vector3(1328.56, 4318.89, 38.23),  radius = 25.0, tier = 'low',      isBase = false },
    { id = 7,  name = 'Ron Wind Farm',        pos = vector3(2354.67, 2567.90, 47.67),  radius = 30.0, tier = 'medium',   isBase = false },
    { id = 8,  name = 'Chumash',              pos = vector3(-3144.78, 1127.01, 20.86), radius = 25.0, tier = 'low',      isBase = false },
    
    -- Central Region
    { id = 9,  name = 'Harmony',              pos = vector3(544.89, 2662.12, 42.16),   radius = 25.0, tier = 'medium',   isBase = false },
    { id = 10, name = 'Grand Senora Desert',  pos = vector3(2411.90, 4047.23, 37.47),  radius = 30.0, tier = 'medium',   isBase = false },
    { id = 11, name = 'Thomson Scrapyard',    pos = vector3(-437.01, 1598.34, 357.90), radius = 25.0, tier = 'low',      isBase = false },
    { id = 12, name = 'Vinewood Sign',        pos = vector3(726.12, 1198.45, 326.26),  radius = 20.0, tier = 'low',      isBase = false },
    { id = 13, name = 'Galileo Observatory',  pos = vector3(-425.23, 1123.56, 325.90), radius = 30.0, tier = 'high',     isBase = false },
    { id = 14, name = 'Land Act Dam',         pos = vector3(1660.34, -13.67, 170.62),  radius = 30.0, tier = 'high',     isBase = false },
    { id = 15, name = 'Palmer-Taylor Power',  pos = vector3(2720.45, 1518.78, 83.19),  radius = 35.0, tier = 'high',     isBase = false },
    { id = 16, name = 'NOOSE Headquarters',   pos = vector3(2513.56, -384.89, 93.14),  radius = 35.0, tier = 'high',     isBase = false },
    
    -- Los Santos Urban
    { id = 17, name = 'LS Airport',           pos = vector3(-1037.67, -2745.90, 20.17),radius = 40.0, tier = 'high',     isBase = false },
    { id = 18, name = 'Port of LS',           pos = vector3(183.78, -2364.01, 6.00),   radius = 35.0, tier = 'high',     isBase = false },
    { id = 19, name = 'Davis',                pos = vector3(112.89, -1960.12, 20.84),  radius = 25.0, tier = 'medium',   isBase = false },
    { id = 20, name = 'Pillbox Hospital',     pos = vector3(298.90, -584.23, 43.26),   radius = 25.0, tier = 'medium',   isBase = false },
    { id = 21, name = 'Legion Square',        pos = vector3(195.01, -934.34, 30.69),   radius = 25.0, tier = 'medium',   isBase = false },
    { id = 22, name = 'Maze Bank Arena',      pos = vector3(-324.12, -1968.45, 24.52), radius = 35.0, tier = 'medium',   isBase = false },
    { id = 23, name = 'Del Perro Pier',       pos = vector3(-1850.23, -1232.56, 13.02),radius = 30.0, tier = 'low',      isBase = false },
    { id = 24, name = 'Vespucci Canals',      pos = vector3(-1112.34, -1690.67, 4.38), radius = 25.0, tier = 'low',      isBase = false },
    
    -- Southern/Industrial
    { id = 25, name = 'Elysian Island',       pos = vector3(-83.45, -2520.78, 6.01),   radius = 30.0, tier = 'high',     isBase = false },
    { id = 26, name = 'Humane Labs',          pos = vector3(3619.56, 3752.89, 28.69),  radius = 35.0, tier = 'high',     isBase = false },
    { id = 27, name = 'Mirror Park',          pos = vector3(1070.67, -711.90, 58.11),  radius = 25.0, tier = 'low',      isBase = false },
    { id = 28, name = 'Murrieta Oil Field',   pos = vector3(1660.78, -1785.01, 112.58),radius = 30.0, tier = 'medium',   isBase = false },
    { id = 29, name = 'Comm Tower',           pos = vector3(752.89, -2608.12, 73.51),  radius = 25.0, tier = 'high',     isBase = false },
    { id = 30, name = 'Zancudo River Bridge', pos = vector3(-1889.90, 2043.23, 140.98),radius = 25.0, tier = 'medium',   isBase = false },
    
    -- Base Capture Points (Critical)
    { id = 31, name = 'Fort Zancudo Command', pos = vector3(-2358.00, 3250.00, 32.81), radius = 40.0, tier = 'critical', isBase = true, baseFaction = 1 },
    { id = 32, name = 'Sandy Shores HQ',      pos = vector3(1750.00, 3275.00, 41.12),  radius = 40.0, tier = 'critical', isBase = true, baseFaction = 2 }
}

-- Capture point value tiers
Config.CapturePointTiers = {
    ['low'] = {
        xpReward = 100,
        moneyReward = 200,
        tickXP = 10,
        tickMoney = 20
    },
    ['medium'] = {
        xpReward = 200,
        moneyReward = 400,
        tickXP = 20,
        tickMoney = 40
    },
    ['high'] = {
        xpReward = 350,
        moneyReward = 700,
        tickXP = 35,
        tickMoney = 70
    },
    ['critical'] = {
        xpReward = 500,
        moneyReward = 1000,
        tickXP = 50,
        tickMoney = 100
    }
}

-- Capture mechanics
Config.Capture = {
    -- Time to capture based on player count (seconds)
    timeByPlayers = {
        [1] = 60,
        [2] = 50,
        [3] = 40,
        [4] = 30,
        [5] = 20  -- 5+ players use this
    },
    maxSpeedPlayers = 5,          -- Max players that affect speed
    decayRate = 1.0,              -- Progress decay multiplier when abandoned (1.0 = same as capture)
    contestedFreeze = true,       -- Freeze progress when contested (equal players)
    neutralFirst = true           -- Must neutralize before capturing
}

-- ============================================================================
-- XP & PROGRESSION
-- ============================================================================
Config.XP = {
    -- Kill rewards
    killBase = 50,                -- Base XP per enemy kill
    killAssistPercent = 0.25,     -- 25% of kill XP for assists
    killAssistWindow = 10,        -- Seconds to count as assist
    
    -- Kill streak bonuses
    streakThreshold = 10,         -- Announce every 10 kills
    streakBonusPercent = 0.10,    -- 10% bonus per streak milestone
    
    -- Penalties
    teamKillPenalty = -100,       -- XP lost for killing teammate
    civilianKillPenalty = -50,    -- XP lost for killing civilian
    
    -- 30-minute tick rewards
    tickBase = 100,               -- Base XP per tick
    tickPerPoint = 25,            -- Bonus XP per capture point held
    
    -- Offline earnings
    offlineEarnings = false       -- No XP while offline
}

-- ============================================================================
-- MONEY & ECONOMY
-- ============================================================================
Config.Money = {
    -- Starting money
    startingMoney = 1000,
    
    -- 30-minute tick rewards by rank ID
    tickByRank = {
        [1] = 100,   -- Private
        [2] = 120,   -- PFC
        [3] = 150,   -- Corporal
        [4] = 200,   -- Sergeant
        [5] = 250,   -- Staff Sergeant
        [6] = 300,   -- SFC
        [7] = 375,   -- MSG
        [8] = 450,   -- 1SG
        [9] = 550,   -- SGM
        [10] = 700,  -- 2LT
        [11] = 850,  -- 1LT
        [12] = 1000, -- Captain
        [13] = 1200, -- Major
        [14] = 1500, -- LTC
        [15] = 1800, -- Colonel
        [16] = 2200, -- BG
        [17] = 2700, -- MG
        [18] = 3300, -- LTG
        [19] = 4000  -- General
    },
    
    -- Per capture point held bonus
    tickPerPoint = 50,
    
    -- Penalties
    teamKillPenalty = -200,
    civilianKillPenalty = -100,
    
    -- Offline earnings
    offlineEarnings = false
}

-- ============================================================================
-- SKILLS
-- ============================================================================
Config.Skills = {
    maxLevel = 25,
    
    -- Skill definitions
    list = {
        {
            id = 'sprint_speed',
            name = 'Sprint Speed',
            description = 'Increases movement speed while sprinting',
            effectPerLevel = 0.01,      -- +1% per level
            maxEffect = 0.25            -- Max 25% bonus
        },
        {
            id = 'stamina',
            name = 'Marathon',
            description = 'Increases total stamina pool',
            effectPerLevel = 0.02,      -- +2% per level
            maxEffect = 0.50            -- Max 50% bonus
        },
        {
            id = 'stamina_regen',
            name = 'Endurance',
            description = 'Increases stamina regeneration rate',
            effectPerLevel = 0.02,
            maxEffect = 0.50
        },
        {
            id = 'weapon_accuracy',
            name = 'Weapon Handling',
            description = 'Reduces bullet spread',
            effectPerLevel = 0.02,
            maxEffect = 0.50
        },
        {
            id = 'reload_speed',
            name = 'Quick Reload',
            description = 'Decreases weapon reload time',
            effectPerLevel = 0.02,
            maxEffect = 0.50
        },
        {
            id = 'recoil_control',
            name = 'Steady Aim',
            description = 'Reduces weapon recoil',
            effectPerLevel = 0.02,
            maxEffect = 0.50
        },
        {
            id = 'revive_speed',
            name = 'Combat Medic',
            description = 'Decreases time to revive teammates',
            effectPerLevel = 0.03,      -- +3% per level
            maxEffect = 0.75            -- Max 75% faster revives
        },
        {
            id = 'xp_bonus',
            name = 'XP Hunter',
            description = 'Increases XP earned from kills',
            effectPerLevel = 0.02,
            maxEffect = 0.50
        },
        {
            id = 'damage_resist',
            name = 'Thick Skin',
            description = 'Reduces damage taken',
            effectPerLevel = 0.01,
            maxEffect = 0.25
        },
        {
            id = 'health_regen',
            name = 'Recovery',
            description = 'Increases health regeneration rate',
            effectPerLevel = 0.02,
            maxEffect = 0.50
        },
        {
            id = 'bleedout_time',
            name = 'Iron Will',
            description = 'Increases bleedout time when downed',
            effectPerLevel = 0.02,
            maxEffect = 0.50
        },
        {
            id = 'money_bonus',
            name = 'Scavenger',
            description = 'Increases money earned from captures',
            effectPerLevel = 0.02,
            maxEffect = 0.50
        },
        {
            id = 'vehicle_handling',
            name = 'Driver',
            description = 'Improves vehicle handling',
            effectPerLevel = 0.02,
            maxEffect = 0.50
        },
        {
            id = 'aircraft_handling',
            name = 'Pilot',
            description = 'Improves aircraft handling',
            effectPerLevel = 0.02,
            maxEffect = 0.50
        },
        {
            id = 'vehicle_armor',
            name = 'Mechanic',
            description = 'Reduces vehicle damage taken',
            effectPerLevel = 0.02,
            maxEffect = 0.50
        },
        {
            id = 'swim_speed',
            name = 'Swimmer',
            description = 'Increases swimming speed',
            effectPerLevel = 0.03,
            maxEffect = 0.75
        }
    },
    
    -- XP cost per skill level (increases as you level up)
    xpCostBase = 100,            -- Cost for level 1
    xpCostMultiplier = 1.15      -- Each level costs 15% more
}

-- ============================================================================
-- WEAPONS
-- ============================================================================
Config.Weapons = {
    -- Weapon categories and unlock requirements
    list = {
        -- Pistols
        { hash = 'WEAPON_PISTOL',           name = 'Pistol',           category = 'pistol',  xpUnlock = 0,     price = 500,   ammo = 120 },
        { hash = 'WEAPON_COMBATPISTOL',     name = 'Combat Pistol',    category = 'pistol',  xpUnlock = 500,   price = 750,   ammo = 120 },
        { hash = 'WEAPON_PISTOL50',         name = 'Pistol .50',       category = 'pistol',  xpUnlock = 2000,  price = 1500,  ammo = 84 },
        { hash = 'WEAPON_HEAVYPISTOL',      name = 'Heavy Pistol',     category = 'pistol',  xpUnlock = 3500,  price = 2000,  ammo = 108 },
        
        -- SMGs
        { hash = 'WEAPON_MICROSMG',         name = 'Micro SMG',        category = 'smg',     xpUnlock = 1000,  price = 2000,  ammo = 240 },
        { hash = 'WEAPON_SMG',              name = 'SMG',              category = 'smg',     xpUnlock = 2500,  price = 3500,  ammo = 300 },
        { hash = 'WEAPON_COMBATPDW',        name = 'Combat PDW',       category = 'smg',     xpUnlock = 5000,  price = 5000,  ammo = 300 },
        
        -- Assault Rifles
        { hash = 'WEAPON_ASSAULTRIFLE',     name = 'Assault Rifle',    category = 'rifle',   xpUnlock = 3000,  price = 4500,  ammo = 300 },
        { hash = 'WEAPON_CARBINERIFLE',     name = 'Carbine Rifle',    category = 'rifle',   xpUnlock = 6000,  price = 6000,  ammo = 300 },
        { hash = 'WEAPON_ADVANCEDRIFLE',    name = 'Advanced Rifle',   category = 'rifle',   xpUnlock = 10000, price = 8000,  ammo = 300 },
        { hash = 'WEAPON_SPECIALCARBINE',   name = 'Special Carbine',  category = 'rifle',   xpUnlock = 15000, price = 10000, ammo = 300 },
        
        -- Shotguns
        { hash = 'WEAPON_PUMPSHOTGUN',      name = 'Pump Shotgun',     category = 'shotgun', xpUnlock = 2000,  price = 3000,  ammo = 48 },
        { hash = 'WEAPON_SAWNOFFSHOTGUN',   name = 'Sawed-Off',        category = 'shotgun', xpUnlock = 1500,  price = 2500,  ammo = 48 },
        { hash = 'WEAPON_ASSAULTSHOTGUN',   name = 'Assault Shotgun',  category = 'shotgun', xpUnlock = 8000,  price = 7500,  ammo = 64 },
        
        -- Sniper Rifles
        { hash = 'WEAPON_SNIPERRIFLE',      name = 'Sniper Rifle',     category = 'sniper',  xpUnlock = 8000,  price = 10000, ammo = 40 },
        { hash = 'WEAPON_HEAVYSNIPER',      name = 'Heavy Sniper',     category = 'sniper',  xpUnlock = 20000, price = 15000, ammo = 32 },
        { hash = 'WEAPON_MARKSMANRIFLE',    name = 'Marksman Rifle',   category = 'sniper',  xpUnlock = 12000, price = 12000, ammo = 64 },
        
        -- LMGs
        { hash = 'WEAPON_MG',               name = 'MG',               category = 'lmg',     xpUnlock = 15000, price = 12000, ammo = 400 },
        { hash = 'WEAPON_COMBATMG',         name = 'Combat MG',        category = 'lmg',     xpUnlock = 25000, price = 18000, ammo = 400 },
        
        -- Throwables
        { hash = 'WEAPON_GRENADE',          name = 'Grenade',          category = 'thrown',  xpUnlock = 5000,  price = 500,   ammo = 5 },
        { hash = 'WEAPON_SMOKEGRENADE',     name = 'Smoke Grenade',    category = 'thrown',  xpUnlock = 3000,  price = 300,   ammo = 5 },
        
        -- Melee
        { hash = 'WEAPON_KNIFE',            name = 'Knife',            category = 'melee',   xpUnlock = 0,     price = 100,   ammo = 0 }
    },
    
    -- Armor
    armor = { name = 'Body Armor', price = 1500 }
}

-- Default loadout for new players (by rank)
Config.DefaultLoadout = {
    [1] = { -- Private
        weapons = { 'WEAPON_PISTOL' },
        ammo = { ['WEAPON_PISTOL'] = 60 },
        armor = 0
    },
    [4] = { -- Sergeant
        weapons = { 'WEAPON_PISTOL', 'WEAPON_SMG' },
        ammo = { ['WEAPON_PISTOL'] = 60, ['WEAPON_SMG'] = 120 },
        armor = 50
    },
    [10] = { -- 2LT
        weapons = { 'WEAPON_COMBATPISTOL', 'WEAPON_CARBINERIFLE' },
        ammo = { ['WEAPON_COMBATPISTOL'] = 84, ['WEAPON_CARBINERIFLE'] = 180 },
        armor = 100
    }
}

-- ============================================================================
-- VEHICLES
-- ============================================================================
Config.Vehicles = {
    list = {
        -- Cars
        { model = 'sultan',       name = 'Sultan',         category = 'car',        xpUnlock = 0,      price = 1000 },
        { model = 'kuruma',       name = 'Kuruma',         category = 'car',        xpUnlock = 2000,   price = 3000 },
        { model = 'buffalo',      name = 'Buffalo',        category = 'car',        xpUnlock = 1000,   price = 2000 },
        
        -- Trucks/SUVs
        { model = 'dubsta',       name = 'Dubsta',         category = 'suv',        xpUnlock = 1500,   price = 2500 },
        { model = 'mesa',         name = 'Mesa',           category = 'suv',        xpUnlock = 500,    price = 1500 },
        { model = 'insurgent',    name = 'Insurgent',      category = 'military',   xpUnlock = 15000,  price = 15000, whitelistRequired = {'army', 'marine'} },
        
        -- Military
        { model = 'barracks',     name = 'Barracks',       category = 'military',   xpUnlock = 5000,   price = 5000,  whitelistRequired = {'army', 'marine'} },
        { model = 'crusader',     name = 'Crusader',       category = 'military',   xpUnlock = 8000,   price = 8000,  whitelistRequired = {'army', 'marine'} },
        { model = 'rhino',        name = 'Rhino Tank',     category = 'military',   xpUnlock = 50000,  price = 50000, whitelistRequired = {'army'}, rankRequired = 12 },
        
        -- Helicopters
        { model = 'maverick',     name = 'Maverick',       category = 'helicopter', xpUnlock = 10000,  price = 12000, whitelistRequired = {'army', 'navy'} },
        { model = 'buzzard',      name = 'Buzzard',        category = 'helicopter', xpUnlock = 25000,  price = 25000, whitelistRequired = {'army'}, rankRequired = 10 },
        { model = 'valkyrie',     name = 'Valkyrie',       category = 'helicopter', xpUnlock = 40000,  price = 40000, whitelistRequired = {'army'}, rankRequired = 12 },
        
        -- Boats
        { model = 'dinghy',       name = 'Dinghy',         category = 'boat',       xpUnlock = 2000,   price = 3000,  whitelistRequired = {'navy'} },
        { model = 'jetmax',       name = 'Jetmax',         category = 'boat',       xpUnlock = 5000,   price = 6000,  whitelistRequired = {'navy'} },
        
        -- Bikes
        { model = 'sanchez',      name = 'Sanchez',        category = 'bike',       xpUnlock = 500,    price = 800 },
        { model = 'bf400',        name = 'BF400',          category = 'bike',       xpUnlock = 1500,   price = 1500 }
    },
    
    -- Despawn settings
    despawnTime = 600,           -- 10 minutes (600 seconds)
    despawnRadius = 100.0,       -- Faction member within 100m keeps it alive
    
    -- Stealing
    allowStealing = true,
    claimStolenVehicle = true    -- Ownership transfers when stolen
}

-- ============================================================================
-- COMBAT & DEATH
-- ============================================================================
Config.Combat = {
    -- Friendly fire
    friendlyFire = true,
    friendlyFirePenalty = true,  -- Apply XP/money penalty
    
    -- Downed state
    downedState = true,
    bleedoutTimeMin = 30,        -- Minimum 30 seconds before can give up
    bleedoutTimeMax = 60,        -- Maximum 60 seconds before forced death
    
    -- Revive
    reviveTime = 8,              -- Base revive time in seconds
    reviveDistance = 2.0,        -- Must be within 2m to revive
    
    -- Execution
    executionEnabled = true,
    executionTime = 3,           -- Hold E for 3 seconds to execute
    executionDistance = 1.5,     -- Must be within 1.5m to execute
    
    -- Respawn
    respawnAtBase = true,        -- Always respawn at faction base
    loseLoadoutOnDeath = true    -- Purchased weapons lost on death
}

-- ============================================================================
-- HUD & UI
-- ============================================================================
Config.HUD = {
    -- Compass
    compassEnabled = true,
    compassStyle = 'strip',      -- 'strip' (horizontal) or 'circular'
    
    -- Nameplates
    friendlyNameplateDistance = 30.0,  -- See friendly names within 30m
    enemyNameplateDistance = 5.0,      -- See enemy names within 5m
    nameplateFormat = '{whitelist} {rank} {name}',  -- e.g., "NAVY CPT John"
    
    -- Kill feed
    killFeedEnabled = true,
    killFeedDuration = 5000,     -- 5 seconds
    killFeedMaxItems = 5,
    
    -- Death notification
    deathNotification = true     -- "You were killed by X"
}

-- ============================================================================
-- ROSTERS
-- ============================================================================
Config.Roster = {
    -- Online roster (keybind: TAB)
    onlineRosterKey = 'TAB',
    
    -- Master roster (command: /roster)
    masterRosterCommand = 'roster',
    
    -- Fields to display
    displayFields = {
        'name',
        'faction',
        'rank',
        'whitelist',
        'kd',
        'online',
        'zone',
        'killsToday',
        'capturesToday',
        'playtimeToday'
    }
}

-- ============================================================================
-- ADMIN
-- ============================================================================
Config.Admin = {
    -- Permission levels
    levels = {
        [0] = 'Player',
        [1] = 'Trial Mod',
        [2] = 'Moderator',
        [3] = 'Admin',
        [4] = 'Head Admin',
        [5] = 'Super Admin'
    },
    
    -- Permissions per level
    permissions = {
        [1] = { 'kick', 'mute', 'spectate', 'warn' },
        [2] = { 'kick', 'mute', 'spectate', 'warn', 'tempban', 'teleport', 'bring' },
        [3] = { 'kick', 'mute', 'spectate', 'warn', 'tempban', 'teleport', 'bring', 'promote', 'whitelist', 'spawn_items', 'spawn_vehicles' },
        [4] = { 'kick', 'mute', 'spectate', 'warn', 'tempban', 'permban', 'teleport', 'bring', 'promote', 'whitelist', 'spawn_items', 'spawn_vehicles', 'set_money', 'set_xp', 'config_edit' },
        [5] = { '*' }  -- All permissions
    }
}

-- ============================================================================
-- LOGGING
-- ============================================================================
Config.Logging = {
    -- Database logging
    dbLogging = true,
    
    -- Discord webhook (set to '' to disable)
    discordWebhook = '',
    
    -- What to log
    logEvents = {
        'player_connect',
        'player_disconnect',
        'character_create',
        'character_delete',
        'faction_change',
        'promotion',
        'whitelist_change',
        'kill',
        'teamkill',
        'capture',
        'purchase',
        'admin_action',
        'ban',
        'kick'
    }
}

-- ============================================================================
-- DEBUG HELPERS
-- ============================================================================
function Config.Print(...)
    if Config.Debug then
        print('[MRP DEBUG]', ...)
    end
end
