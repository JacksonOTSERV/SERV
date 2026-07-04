-- Battle Pass Kill Tracking
-- This script tracks monster kills for Battle Pass missions

-- Import PASS_CONFIG from pass_opcode.lua (these must match)
local STORAGE_PASS_EXP = 80002
local STORAGE_PASS_LEVEL = 80001

-- Mission configuration (must match pass_opcode.lua)
local PASS_MISSIONS = {
    -- Easy (Daily)
    ["rotworm"] = {storageCount = 81001, storageCompleted = 81101, count = 50, expReward = 15, type = "daily"},
    ["cyclops"] = {storageCount = 81002, storageCompleted = 81102, count = 30, expReward = 20, type = "daily"},
    ["dragon"] = {storageCount = 81003, storageCompleted = 81103, count = 20, expReward = 30, type = "weekly"},
    
    -- Medium (Weekly)
    ["dragon lord"] = {storageCount = 81004, storageCompleted = 81104, count = 15, expReward = 40, type = "weekly"},
    ["giant spider"] = {storageCount = 81005, storageCompleted = 81105, count = 25, expReward = 35},
    ["hydra"] = {storageCount = 81006, storageCompleted = 81106, count = 15, expReward = 45},
    
    -- Hard
    ["demon"] = {storageCount = 81007, storageCompleted = 81107, count = 10, expReward = 60},
    ["warlock"] = {storageCount = 81008, storageCompleted = 81108, count = 15, expReward = 50},
    ["behemoth"] = {storageCount = 81009, storageCompleted = 81109, count = 10, expReward = 55},
    ["plaguesmith"] = {storageCount = 81010, storageCompleted = 81110, count = 8, expReward = 70},
}

local PASS_CONFIG_EXP_PER_LEVEL = 100
local PASS_CONFIG_MAX_LEVEL = 50

-- Helper function to add EXP (duplicated for standalone functionality)
local function addPassExpLocal(player, amount)
    local currentLevel = player:getStorageValue(STORAGE_PASS_LEVEL)
    if currentLevel < 0 then currentLevel = 0 end
    
    local currentExp = player:getStorageValue(STORAGE_PASS_EXP)
    if currentExp < 0 then currentExp = 0 end
    
    currentExp = currentExp + amount
    
    -- Check for level ups
    local levelsGained = 0
    while currentExp >= PASS_CONFIG_EXP_PER_LEVEL and currentLevel < PASS_CONFIG_MAX_LEVEL do
        currentExp = currentExp - PASS_CONFIG_EXP_PER_LEVEL
        currentLevel = currentLevel + 1
        levelsGained = levelsGained + 1
    end
    
    -- Save new values
    player:setStorageValue(STORAGE_PASS_EXP, currentExp)
    player:setStorageValue(STORAGE_PASS_LEVEL, currentLevel)
    
    -- Notify player
    if levelsGained > 0 then
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Battle Pass Level Up! You are now level " .. currentLevel .. "!")
    end
    
    return levelsGained
end

-- Kill Event
local passKillEvent = CreatureEvent("BattlePassKill")

function passKillEvent.onKill(player, target)
    if not target:isMonster() then
        return true
    end
    
    local monsterName = target:getName():lower()
    local mission = PASS_MISSIONS[monsterName]
    
    if not mission then
        return true
    end
    
    -- Check if mission already completed
    if player:getStorageValue(mission.storageCompleted) == 1 then
        return true
    end
    
    -- Increment kill count
    local currentKills = player:getStorageValue(mission.storageCount)
    if currentKills < 0 then currentKills = 0 end
    
    currentKills = currentKills + 1
    player:setStorageValue(mission.storageCount, currentKills)
    
    -- Check if mission is now complete
    if currentKills >= mission.count then
        player:setStorageValue(mission.storageCompleted, 1)
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Battle Pass Mission Complete! +" .. mission.expReward .. " EXP")
        player:getPosition():sendMagicEffect(CONST_ME_FIREWORK_RED, player)
        addPassExpLocal(player, mission.expReward)
    else
        -- Progress notification (every 25% or on certain milestones)
        local progress = math.floor((currentKills / mission.count) * 100)
        if progress == 25 or progress == 50 or progress == 75 then
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Battle Pass Mission: " .. currentKills .. "/" .. mission.count .. " (" .. progress .. "%)")
        end
    end
    
    return true
end

passKillEvent:register()

-- Register on login
local passKillLogin = CreatureEvent("BattlePassKillLogin")

function passKillLogin.onLogin(player)
    player:registerEvent("BattlePassKill")
    
    -- Daily Reset Logic
    local today = tonumber(os.date("%d"))
    local lastLoginDay = player:getStorageValue(80006)
    
    if lastLoginDay ~= today then
        player:setStorageValue(80006, today)
        -- Reset daily missions
        for _, mission in pairs(PASS_MISSIONS) do
            if mission.type == "daily" then
                player:setStorageValue(mission.storageCount, 0)
                player:setStorageValue(mission.storageCompleted, 0)
            end
        end
        if lastLoginDay ~= -1 then -- Don't msg on first login ever
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Daily Battle Pass missions have been reset!")
        end
    end
    
    -- Weekly Reset Logic
    local currentWeek = tonumber(os.date("%W"))
    local lastLoginWeek = player:getStorageValue(80007)
    
    if lastLoginWeek ~= currentWeek then
         player:setStorageValue(80007, currentWeek)
         -- Reset weekly
         for _, mission in pairs(PASS_MISSIONS) do
            if mission.type == "weekly" then
                player:setStorageValue(mission.storageCount, 0)
                player:setStorageValue(mission.storageCompleted, 0)
            end
        end
        if lastLoginWeek ~= -1 then
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Weekly Battle Pass missions have been reset!")
        end
    end
    
    return true
end

passKillLogin:register()
