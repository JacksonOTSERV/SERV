-- Battle Pass Admin Commands

-- /givepassexp playername, amount
function onSay(player, words, param)
    if not player:getGroup():getAccess() then
        return true
    end

    local split = param:split(",")
    if not split[2] then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Usage: /givepassexp playername, amount")
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

    -- Add EXP logic (duplicated from pass_opcode.lua for standalone use)
    local STORAGE_PASS_LEVEL = 80001
    local STORAGE_PASS_EXP = 80002
    local PASS_CONFIG_EXP_PER_LEVEL = 100
    local PASS_CONFIG_MAX_LEVEL = 50
    
    local currentLevel = target:getStorageValue(STORAGE_PASS_LEVEL)
    if currentLevel < 0 then currentLevel = 0 end
    
    local currentExp = target:getStorageValue(STORAGE_PASS_EXP)
    if currentExp < 0 then currentExp = 0 end
    
    currentExp = currentExp + amount
    
    local levelsGained = 0
    while currentExp >= PASS_CONFIG_EXP_PER_LEVEL and currentLevel < PASS_CONFIG_MAX_LEVEL do
        currentExp = currentExp - PASS_CONFIG_EXP_PER_LEVEL
        currentLevel = currentLevel + 1
        levelsGained = levelsGained + 1
    end
    
    target:setStorageValue(STORAGE_PASS_EXP, currentExp)
    target:setStorageValue(STORAGE_PASS_LEVEL, currentLevel)
    
    target:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Admin gave you " .. amount .. " Battle Pass EXP!")
    if levelsGained > 0 then
        target:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Battle Pass Level Up! You are now level " .. currentLevel .. "!")
    end
    
    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Gave " .. amount .. " EXP to " .. targetName .. ". New Level: " .. currentLevel)
    return false
end

-- Register talkaction in XML or here if supported
-- <talkaction words="/givepassexp" separator=" " script="pass_admin.lua" access="5" />
