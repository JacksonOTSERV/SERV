-- Battle Pass SQL Setup
-- Automaticaly creates required tables on startup

local TABLE_SQL = [[
CREATE TABLE IF NOT EXISTS `player_pass_history` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `player_id` INT NOT NULL,
    `season_id` INT NOT NULL,
    `final_level` INT DEFAULT 0,
    `elite_status` TINYINT DEFAULT 0,
    `rewards_collected` INT DEFAULT 0,
    `end_date` DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`player_id`) REFERENCES `players`(`id`) ON DELETE CASCADE,
    INDEX `idx_player_season` (`player_id`, `season_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
]]

local function setupDatabase()
    -- Try to create the table
    local success = db.query(TABLE_SQL)
    if success then
        print("[Battle Pass] Database table `player_pass_history` checked/created successfully.")
    else
        print("[Battle Pass] ERROR: Failed to create database table. Please execute the SQL manually.")
        print(TABLE_SQL)
    end
end

-- Run setup immediately on load
setupDatabase()
