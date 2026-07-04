-- Battle Pass Admin Command: Give Points

-- /givepasspoints playername, amount
function onSay(player, words, param)
    if not player:getGroup():getAccess() then
        return true
    end

    local split = param:split(",")
    if not split[2] then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Usage: /givepasspoints playername, amount")
        return false
    end

    local targetName = split[1]:trim()
    local amount = tonumber(split[2]:trim())
    
    if not amount then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Invalid amount.")
        return false
    end

    local target = Player(targetName)
    if not target then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Player not found.")
        return false
    end

    local STORAGE_PASS_POINTS = 80005
    local currentPoints = target:getStorageValue(STORAGE_PASS_POINTS)
    if currentPoints < 0 then currentPoints = 0 end
    
    target:setStorageValue(STORAGE_PASS_POINTS, currentPoints + amount)
    
    target:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Admin gave you " .. amount .. " Battle Pass Points!")
    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Gave " .. amount .. " points to " .. targetName .. ".")
    return false
end
