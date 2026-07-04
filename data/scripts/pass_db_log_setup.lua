-- Battle Pass Activity Log Setup
-- Automaticaly creates required tables on startup

local TABLE_SQL = [[
CREATE TABLE IF NOT EXISTS `player_pass_logs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `player_id` INT NOT NULL,
    `description` TEXT NOT NULL,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`player_id`) REFERENCES `players`(`id`) ON DELETE CASCADE,
    INDEX `idx_player_log` (`player_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
]]

local function setupDatabase()
    -- Try to create the table
    local success = db.query(TABLE_SQL)
    if success then
        print("[Battle Pass] Database table `player_pass_logs` checked/created successfully.")
    else
        print("[Battle Pass] ERROR: Failed to create database table `player_pass_logs`. Please execute the SQL manually.")
        print(TABLE_SQL)
    end
end

-- Run setup immediately on load
setupDatabase()
