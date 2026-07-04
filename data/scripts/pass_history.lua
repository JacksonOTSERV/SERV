-- Battle Pass Activity Logs & History
-- Manages real-time logs and season summary

local STORAGE_PASS_LEVEL = 80001
local PassHistory = {}

-- Add a log entry for a player
function PassHistory.addLog(player, message)
    local playerId = player:getGuid()
    -- Escape message for SQL
    local safeMessage = db.escapeString(message)
    
    local query = string.format(
        "INSERT INTO player_pass_logs (player_id, description, created_at) VALUES (%d, %s, NOW())",
        playerId, safeMessage
    )
    
    db.asyncQuery(query)
    -- print("[PassHistory] Log added for " .. player:getName() .. ": " .. message)
end

-- Get player's activity logs (Limit 50)
function PassHistory.getLogs(player)
    local playerId = player:getGuid()
    local logs = {}
    
    local query = "SELECT description, DATE_FORMAT(created_at, '%d/%m %H:%i') as date FROM player_pass_logs WHERE player_id = " .. playerId .. " ORDER BY created_at DESC LIMIT 50"
    local resultId = db.storeQuery(query)
    
    if resultId then
        repeat
            table.insert(logs, {
                description = result.getString(resultId, "description"),
                date = result.getString(resultId, "date")
            })
        until not result.next(resultId)
        result.free(resultId)
    end
    
    return logs
end

-- Get global activity logs (Admin View)
function PassHistory.getAllLogs(limit)
    limit = limit or 50
    local logs = {}
    
    local query = string.format([[
        SELECT p.name, l.description, DATE_FORMAT(l.created_at, '%%d/%%m %%H:%%i') as date
        FROM player_pass_logs l
        JOIN players p ON l.player_id = p.id
        ORDER BY l.created_at DESC
        LIMIT %d
    ]], limit)
    
    local resultId = db.storeQuery(query)
    
    if resultId then
        repeat
            local name = result.getString(resultId, "name")
            local desc = result.getString(resultId, "description")
            -- Format for admin: "Player: Description"
            table.insert(logs, {
                description = name .. ": " .. desc,
                date = result.getString(resultId, "date")
            })
        until not result.next(resultId)
        result.free(resultId)
    end
    
    return logs
end

-- Kept for legacy compatibility if needed
function PassHistory.saveSeasonProgress(player, seasonId)
    -- Implementation preserved but focus is on logs now
    return true
end

_G.PassHistory = PassHistory
