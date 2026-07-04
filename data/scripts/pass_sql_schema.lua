-- Battle Pass SQL Schema
-- Execute this in your database to create the required tables

--[[
CREATE TABLE IF NOT EXISTS player_pass_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    player_id INT NOT NULL,
    season_id INT NOT NULL,
    final_level INT DEFAULT 0,
    elite_status TINYINT DEFAULT 0,
    rewards_collected INT DEFAULT 0,
    end_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE,
    INDEX idx_player_season (player_id, season_id)
);

-- Optional: Add XP Boost storage key comment
-- STORAGE_PASS_BOOST = 80006 (stores boost expiration timestamp)
-- STORAGE_PASS_BOOST_MULTIPLIER = 80007 (stores multiplier value)
]]

print("[Battle Pass] SQL Schema loaded - execute the CREATE TABLE statement in your database!")
