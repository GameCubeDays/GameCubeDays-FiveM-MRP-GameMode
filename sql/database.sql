-- ============================================================================
-- MRP GAMEMODE - DATABASE SCHEMA
-- ============================================================================
-- Run this SQL file in your MySQL database (via PHPMyAdmin on NodeCraft)
-- Make sure to create the database first if it doesn't exist
-- ============================================================================

-- Create database (if needed - NodeCraft may already have one)
-- CREATE DATABASE IF NOT EXISTS mrp_gamemode;
-- USE mrp_gamemode;

-- ============================================================================
-- PLAYERS TABLE
-- Stores account-level data (one row per FiveM player)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `mrp_players` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `license` VARCHAR(100) NOT NULL,                    -- FiveM license identifier
    `discord` VARCHAR(50) DEFAULT NULL,                 -- Discord ID if available
    `steam` VARCHAR(50) DEFAULT NULL,                   -- Steam ID if available
    `admin_level` INT(1) NOT NULL DEFAULT 0,            -- 0=Player, 1-5=Admin tiers
    `first_join` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_seen` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `total_playtime` INT(11) NOT NULL DEFAULT 0,        -- Total minutes played
    `banned` TINYINT(1) NOT NULL DEFAULT 0,             -- Is player banned
    `ban_reason` VARCHAR(255) DEFAULT NULL,
    `ban_expires` DATETIME DEFAULT NULL,                -- NULL = permanent
    `ban_by` VARCHAR(100) DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `license` (`license`),
    INDEX `idx_discord` (`discord`),
    INDEX `idx_steam` (`steam`),
    INDEX `idx_banned` (`banned`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- CHARACTERS TABLE
-- Stores character data (up to 3 per player, one per faction)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `mrp_characters` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `player_id` INT(11) NOT NULL,                       -- FK to mrp_players
    `license` VARCHAR(100) NOT NULL,                    -- Duplicate for quick lookups
    `faction` INT(1) NOT NULL,                          -- 1=Military, 2=Resistance, 3=Civilian
    `name` VARCHAR(50) NOT NULL,                        -- Character name
    `rank_id` INT(2) NOT NULL DEFAULT 1,                -- Current rank ID
    `whitelist` VARCHAR(50) NOT NULL DEFAULT 'army',    -- Sub-faction whitelist
    `xp` INT(11) NOT NULL DEFAULT 0,                    -- Total XP earned
    `money` INT(11) NOT NULL DEFAULT 1000,              -- Current money balance
    `kills` INT(11) NOT NULL DEFAULT 0,
    `deaths` INT(11) NOT NULL DEFAULT 0,
    `assists` INT(11) NOT NULL DEFAULT 0,
    `captures` INT(11) NOT NULL DEFAULT 0,              -- Total capture points taken
    `playtime` INT(11) NOT NULL DEFAULT 0,              -- Minutes on this character
    `last_played` DATETIME DEFAULT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_faction` (`license`, `faction`), -- One character per faction
    INDEX `idx_player` (`player_id`),
    INDEX `idx_license` (`license`),
    INDEX `idx_faction` (`faction`),
    INDEX `idx_xp` (`xp`),
    FOREIGN KEY (`player_id`) REFERENCES `mrp_players`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- CHARACTER SKILLS TABLE
-- Stores skill levels for each character
-- ============================================================================
CREATE TABLE IF NOT EXISTS `mrp_character_skills` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `character_id` INT(11) NOT NULL,                    -- FK to mrp_characters
    `skill_id` VARCHAR(50) NOT NULL,                    -- Skill identifier (e.g., 'sprint_speed')
    `level` INT(2) NOT NULL DEFAULT 0,                  -- Current skill level (0-25)
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_skill` (`character_id`, `skill_id`),
    INDEX `idx_character` (`character_id`),
    FOREIGN KEY (`character_id`) REFERENCES `mrp_characters`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- CHARACTER UNLOCKS TABLE
-- Tracks what weapons/vehicles the character has unlocked (with XP)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `mrp_character_unlocks` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `character_id` INT(11) NOT NULL,                    -- FK to mrp_characters
    `item_type` ENUM('weapon', 'vehicle') NOT NULL,     -- Type of unlock
    `item_id` VARCHAR(50) NOT NULL,                     -- Weapon hash or vehicle model
    `unlocked_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_unlock` (`character_id`, `item_type`, `item_id`),
    INDEX `idx_character` (`character_id`),
    FOREIGN KEY (`character_id`) REFERENCES `mrp_characters`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- SESSION TRACKING TABLE
-- Tracks individual play sessions for statistics
-- ============================================================================
CREATE TABLE IF NOT EXISTS `mrp_sessions` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `character_id` INT(11) NOT NULL,
    `session_start` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `session_end` DATETIME DEFAULT NULL,
    `kills` INT(11) NOT NULL DEFAULT 0,
    `deaths` INT(11) NOT NULL DEFAULT 0,
    `assists` INT(11) NOT NULL DEFAULT 0,
    `captures` INT(11) NOT NULL DEFAULT 0,
    `xp_earned` INT(11) NOT NULL DEFAULT 0,
    `money_earned` INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    INDEX `idx_character` (`character_id`),
    INDEX `idx_session_start` (`session_start`),
    FOREIGN KEY (`character_id`) REFERENCES `mrp_characters`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- CAPTURE POINTS STATE TABLE
-- Persists capture point ownership (optional - resets daily)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `mrp_capture_points` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `point_id` INT(11) NOT NULL,                        -- Config capture point ID
    `owner_faction` INT(1) NOT NULL DEFAULT 0,          -- 0=Neutral, 1=Military, 2=Resistance
    `capture_progress` DECIMAL(5,2) NOT NULL DEFAULT 0, -- 0-100
    `last_updated` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_point` (`point_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- ACTION LOGS TABLE
-- Comprehensive logging for all important events
-- ============================================================================
CREATE TABLE IF NOT EXISTS `mrp_logs` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `timestamp` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `action_type` VARCHAR(50) NOT NULL,                 -- Type of action (kill, purchase, promotion, etc.)
    `actor_license` VARCHAR(100) DEFAULT NULL,          -- Who performed the action
    `actor_name` VARCHAR(50) DEFAULT NULL,              -- Actor's character name
    `target_license` VARCHAR(100) DEFAULT NULL,         -- Who was affected (if applicable)
    `target_name` VARCHAR(50) DEFAULT NULL,             -- Target's character name
    `details` JSON DEFAULT NULL,                        -- Additional context as JSON
    PRIMARY KEY (`id`),
    INDEX `idx_timestamp` (`timestamp`),
    INDEX `idx_action_type` (`action_type`),
    INDEX `idx_actor` (`actor_license`),
    INDEX `idx_target` (`target_license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- BANS TABLE
-- Separate ban tracking for history
-- ============================================================================
CREATE TABLE IF NOT EXISTS `mrp_bans` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `license` VARCHAR(100) NOT NULL,
    `discord` VARCHAR(50) DEFAULT NULL,
    `steam` VARCHAR(50) DEFAULT NULL,
    `ip` VARCHAR(50) DEFAULT NULL,
    `reason` VARCHAR(255) NOT NULL,
    `banned_by` VARCHAR(100) NOT NULL,                  -- Admin who banned
    `banned_by_name` VARCHAR(50) DEFAULT NULL,
    `banned_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at` DATETIME DEFAULT NULL,                 -- NULL = permanent
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `unbanned_by` VARCHAR(100) DEFAULT NULL,
    `unbanned_at` DATETIME DEFAULT NULL,
    `unban_reason` VARCHAR(255) DEFAULT NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_license` (`license`),
    INDEX `idx_active` (`active`),
    INDEX `idx_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- WARNINGS TABLE
-- Track player warnings
-- ============================================================================
CREATE TABLE IF NOT EXISTS `mrp_warnings` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `license` VARCHAR(100) NOT NULL,
    `character_name` VARCHAR(50) DEFAULT NULL,
    `reason` VARCHAR(255) NOT NULL,
    `warned_by` VARCHAR(100) NOT NULL,
    `warned_by_name` VARCHAR(50) DEFAULT NULL,
    `warned_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `acknowledged` TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    INDEX `idx_license` (`license`),
    INDEX `idx_acknowledged` (`acknowledged`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- LEADERBOARD VIEW
-- Easy leaderboard queries
-- ============================================================================
CREATE OR REPLACE VIEW `mrp_leaderboard` AS
SELECT 
    c.id AS character_id,
    c.name,
    c.faction,
    c.rank_id,
    c.whitelist,
    c.xp,
    c.kills,
    c.deaths,
    c.assists,
    c.captures,
    CASE WHEN c.deaths > 0 THEN ROUND(c.kills / c.deaths, 2) ELSE c.kills END AS kd_ratio,
    c.playtime,
    p.license,
    p.admin_level
FROM mrp_characters c
JOIN mrp_players p ON c.player_id = p.id
ORDER BY c.xp DESC;

-- ============================================================================
-- DAILY STATS VIEW
-- Today's statistics
-- ============================================================================
CREATE OR REPLACE VIEW `mrp_daily_stats` AS
SELECT 
    s.character_id,
    c.name,
    c.faction,
    DATE(s.session_start) AS play_date,
    SUM(s.kills) AS daily_kills,
    SUM(s.deaths) AS daily_deaths,
    SUM(s.captures) AS daily_captures,
    SUM(s.xp_earned) AS daily_xp,
    SUM(s.money_earned) AS daily_money,
    SUM(TIMESTAMPDIFF(MINUTE, s.session_start, COALESCE(s.session_end, NOW()))) AS daily_playtime
FROM mrp_sessions s
JOIN mrp_characters c ON s.character_id = c.id
WHERE DATE(s.session_start) = CURDATE()
GROUP BY s.character_id, c.name, c.faction, DATE(s.session_start);

-- ============================================================================
-- INITIAL DATA - Populate capture points
-- ============================================================================
INSERT IGNORE INTO `mrp_capture_points` (`point_id`, `owner_faction`, `capture_progress`) VALUES
(1, 0, 0), (2, 0, 0), (3, 0, 0), (4, 0, 0), (5, 0, 0),
(6, 0, 0), (7, 0, 0), (8, 0, 0), (9, 0, 0), (10, 0, 0),
(11, 0, 0), (12, 0, 0), (13, 0, 0), (14, 0, 0), (15, 0, 0),
(16, 0, 0), (17, 0, 0), (18, 0, 0), (19, 0, 0), (20, 0, 0),
(21, 0, 0), (22, 0, 0), (23, 0, 0), (24, 0, 0), (25, 0, 0),
(26, 0, 0), (27, 0, 0), (28, 0, 0), (29, 0, 0), (30, 0, 0),
(31, 1, 100), -- Fort Zancudo starts as Military
(32, 2, 100); -- Sandy Shores starts as Resistance

-- ============================================================================
-- STORED PROCEDURES
-- ============================================================================

-- Procedure to get or create a player
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `GetOrCreatePlayer`(
    IN p_license VARCHAR(100),
    IN p_discord VARCHAR(50),
    IN p_steam VARCHAR(50)
)
BEGIN
    DECLARE player_exists INT DEFAULT 0;
    
    SELECT COUNT(*) INTO player_exists FROM mrp_players WHERE license = p_license;
    
    IF player_exists = 0 THEN
        INSERT INTO mrp_players (license, discord, steam) VALUES (p_license, p_discord, p_steam);
    ELSE
        UPDATE mrp_players SET 
            discord = COALESCE(p_discord, discord),
            steam = COALESCE(p_steam, steam),
            last_seen = NOW()
        WHERE license = p_license;
    END IF;
    
    SELECT * FROM mrp_players WHERE license = p_license;
END //
DELIMITER ;

-- Procedure to get all characters for a player
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `GetPlayerCharacters`(
    IN p_license VARCHAR(100)
)
BEGIN
    SELECT 
        c.*,
        (SELECT COUNT(*) FROM mrp_character_skills WHERE character_id = c.id) AS skill_count,
        (SELECT COUNT(*) FROM mrp_character_unlocks WHERE character_id = c.id) AS unlock_count
    FROM mrp_characters c
    WHERE c.license = p_license
    ORDER BY c.faction;
END //
DELIMITER ;

-- Procedure to create a character
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `CreateCharacter`(
    IN p_license VARCHAR(100),
    IN p_faction INT,
    IN p_name VARCHAR(50),
    IN p_whitelist VARCHAR(50)
)
BEGIN
    DECLARE v_player_id INT;
    
    SELECT id INTO v_player_id FROM mrp_players WHERE license = p_license;
    
    IF v_player_id IS NOT NULL THEN
        INSERT INTO mrp_characters (player_id, license, faction, name, whitelist, money)
        VALUES (v_player_id, p_license, p_faction, p_name, p_whitelist, 1000);
        
        SELECT * FROM mrp_characters WHERE id = LAST_INSERT_ID();
    END IF;
END //
DELIMITER ;

-- Procedure to update character stats
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `UpdateCharacterStats`(
    IN p_character_id INT,
    IN p_xp INT,
    IN p_money INT,
    IN p_kills INT,
    IN p_deaths INT,
    IN p_assists INT,
    IN p_captures INT,
    IN p_playtime INT
)
BEGIN
    UPDATE mrp_characters SET
        xp = p_xp,
        money = p_money,
        kills = p_kills,
        deaths = p_deaths,
        assists = p_assists,
        captures = p_captures,
        playtime = p_playtime,
        last_played = NOW()
    WHERE id = p_character_id;
END //
DELIMITER ;

-- Procedure to reset all capture points (for daily reset)
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `ResetCapturePoints`()
BEGIN
    UPDATE mrp_capture_points SET 
        owner_faction = 0, 
        capture_progress = 0,
        last_updated = NOW()
    WHERE point_id NOT IN (31, 32);
    
    -- Reset base points to their factions
    UPDATE mrp_capture_points SET owner_faction = 1, capture_progress = 100 WHERE point_id = 31;
    UPDATE mrp_capture_points SET owner_faction = 2, capture_progress = 100 WHERE point_id = 32;
END //
DELIMITER ;

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================
-- Additional indexes for common queries

-- For leaderboard queries
CREATE INDEX IF NOT EXISTS `idx_chars_xp_faction` ON `mrp_characters` (`faction`, `xp` DESC);

-- For session queries
CREATE INDEX IF NOT EXISTS `idx_sessions_date` ON `mrp_sessions` (`session_start`, `character_id`);

-- For log queries
CREATE INDEX IF NOT EXISTS `idx_logs_composite` ON `mrp_logs` (`action_type`, `timestamp`);
