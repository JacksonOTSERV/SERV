-- Battle Pass Ranking System
-- Displays top players by Battle Pass level

local STORAGE_PASS_LEVEL = 80001
local STORAGE_PASS_STATUS = 80003

local PassRanking = {}

-- Get top Battle Pass players
function PassRanking.getTopPlayers(limit)
    limit = limit or 10
    local ranking = {}
    
    -- Query players with highest pass levels
    local query = string.format([[
        SELECT p.name, ps.value as level, 
               IFNULL((SELECT value FROM player_storage WHERE player_id = p.id AND `key` = %d), 0) as elite
        FROM players p
        JOIN player_storage ps ON p.id = ps.player_id
        WHERE ps.`key` = %d AND ps.value > 0
        ORDER BY ps.value DESC
        LIMIT %d
    ]], STORAGE_PASS_STATUS, STORAGE_PASS_LEVEL, limit)
    
    local resultId = db.storeQuery(query)
    
    if resultId then
        local position = 1
        repeat
            table.insert(ranking, {
                position = position,
                name = result.getString(resultId, "name"),
                level = result.getNumber(resultId, "level"),
                elite = result.getNumber(resultId, "elite") == 1
            })
            position = position + 1
        until not result.next(resultId)
        result.free(resultId)
    end
    
    return ranking
end

-- Get player's rank position
function PassRanking.getPlayerRank(player)
    local playerId = player:getGuid()
    local playerLevel = player:getStorageValue(STORAGE_PASS_LEVEL)
    
    if playerLevel < 0 then return 0 end
    
    local query = string.format([[
        SELECT COUNT(*) as rank FROM player_storage 
        WHERE `key` = %d AND value > %d
    ]], STORAGE_PASS_LEVEL, playerLevel)
    
    local resultId = db.storeQuery(query)
    
    if resultId then
        local rank = result.getNumber(resultId, "rank") + 1
        result.free(resultId)
        return rank
    end
    
    return 0
end

_G.PassRanking = PassRanking

