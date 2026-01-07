# FiveM Military Roleplay Gamemode (MRP)

A comprehensive faction-based military roleplay gamemode for FiveM featuring capture points, progression systems, and territorial warfare.

## Features

### Factions & Characters
- **3 Factions**: Military, Resistance, Civilians
- **Multi-Character System**: Up to 3 characters per player (one per faction)
- **Whitelists**: Sub-factions within each faction (Navy, Marine, Army, etc.)
- **19 Military Ranks**: From Private to General with XP-based progression

### Progression Systems
- **XP System**: Earn from kills, assists, captures, and time played
- **Money System**: Rank-based income, capture bonuses
- **16 Skills**: Sprint speed, weapon handling, revive speed, and more
- **Kill Streaks**: Bonus XP and server announcements

### Territory Control
- **32 Capture Points**: Strategic locations across the map
- **Tiered Value**: Low, Medium, High, and Critical points
- **Dynamic Capture**: Faster with more players (1-5 player scaling)
- **Contested Mechanics**: Progress freezes when equal forces present

### Combat
- **Downed State**: 30-60 second bleedout with revive option
- **Execution System**: Finish downed enemies
- **Friendly Fire**: Enabled with XP/money penalties
- **Team Kill Penalties**: Discourages griefing

### Economy
- **Weapon Unlocks**: Spend XP to unlock, money to purchase
- **Vehicle System**: Cars, trucks, helicopters, boats with restrictions
- **Vehicle Stealing**: Claim enemy vehicles

### HUD & UI
- **Compass**: Horizontal strip (Battlefield-style)
- **Faction Nameplates**: See friendly names at 30m, enemies at 5m
- **Kill Feed**: Real-time combat notifications
- **Rosters**: Online players and master roster

### Administration
- **5 Admin Tiers**: Trial Mod → Super Admin
- **Comprehensive Logging**: Database + Discord webhook
- **txAdmin Integration**: Compatible

## Requirements

- [oxmysql](https://github.com/overextended/oxmysql)
- [ox_lib](https://github.com/overextended/ox_lib)
- MySQL Database (PHPMyAdmin compatible)

## Installation

1. **Clone the repository**
   ```bash
   cd resources
   git clone https://github.com/GameCubeDays/FiveM-MRP-GameMode.git mrp_gamemode
   ```

2. **Import the database**
   - Open PHPMyAdmin
   - Create a new database (or use existing)
   - Import `sql/database.sql`

3. **Configure your server.cfg**
   ```
   ensure oxmysql
   ensure ox_lib
   ensure mrp_gamemode
   ```

4. **Set up database connection** (in your server.cfg or txAdmin)
   ```
   set mysql_connection_string "mysql://user:password@localhost/database_name"
   ```

5. **Configure the gamemode**
   - Edit `config/config.lua` to adjust game balance
   - All tunable variables are in one place

## Configuration

All game variables are centralized in `config/config.lua`:

- **XP Values**: Kill rewards, capture bonuses, tick rates
- **Money Values**: Rank-based income, penalties
- **Capture Points**: Locations, timers, scaling
- **Weapons**: Unlock requirements, prices, ammo
- **Vehicles**: Restrictions, prices, whitelist requirements
- **Skills**: Effects, max levels, costs

## Folder Structure

```
mrp_gamemode/
├── fxmanifest.lua          # Resource manifest
├── config/
│   └── config.lua          # All tunable variables
├── sql/
│   └── database.sql        # Database schema
├── server/
│   ├── main.lua            # Core server logic
│   ├── characters.lua      # Character management
│   ├── progression.lua     # XP, ranks, skills
│   ├── combat.lua          # Death, revive, kills
│   ├── economy.lua         # Money, purchases
│   ├── capturepoints.lua   # Territory control
│   ├── vehicles.lua        # Vehicle system
│   ├── admin.lua           # Admin commands
│   └── logging.lua         # Event logging
├── client/
│   ├── main.lua            # Core client logic
│   ├── characters.lua      # Character selection UI
│   ├── hud.lua             # Compass, HUD elements
│   ├── nametags.lua        # Player nameplates
│   ├── capturepoints.lua   # Capture zone visuals
│   ├── combat.lua          # Downed state, revive
│   ├── armory.lua          # Weapon shop
│   ├── vehicles.lua        # Vehicle shop
│   ├── skills.lua          # Skill menu
│   └── roster.lua          # Player rosters
└── html/
    ├── index.html          # NUI container
    ├── style.css           # Styling
    └── script.js           # NUI logic
```

## Commands

### Player Commands
- `/skills` - Open skills menu
- `/roster` - Open master roster
- `TAB` - Toggle online roster
- `K` - Quick skills menu

### Admin Commands
- `/promote [id] [rank]` - Promote player
- `/whitelist [id] [whitelist]` - Set whitelist
- `/addxp [id] [amount]` - Give XP
- `/addmoney [id] [amount]` - Give money
- `/kick [id] [reason]` - Kick player
- `/ban [id] [duration] [reason]` - Ban player

## Development Status

### Phase 1: Foundation ✅
- [x] Config system
- [x] Database schema
- [x] Resource manifest

### Phase 2: Characters
- [x] Character creation
- [x] Character selection
- [x] Faction models

### Phase 3: Progression
- [x] XP system
- [x] Money system
- [x] Rank system
- [x] Skills system

### Phase 4: Combat
- [x] Downed state
- [x] Revive mechanics
- [x] Kill tracking

### Phase 5: Economy
- [x] Weapon shop
- [x] Vehicle shop
- [x] Unlock system

### Phase 6: Territory
- [x] Capture points
- [x] 30-minute tick

### Phase 7: UI/HUD
- [x] Compass
- [x] Nameplates
- [x] Rosters

### Phase 8: Admin
- [ ] Admin commands
- [ ] Logging system

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## License

This project is open source. Feel free to use and modify for your server.

## Credits

- **Author**: GameCubeDays
- **Framework**: Standalone with ox_lib integration
- **Database**: oxmysql

## Support

For issues or feature requests, please open a GitHub issue.
