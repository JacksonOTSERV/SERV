local OPCODE_RECEIVE = 38 -- Client sends requests on this opcode
local OPCODE_SEND = 11    -- Client listens for responses on this opcode

-- Configuration
local PASS_CONFIG = {
    passDurationDays = 30, -- Duration of the pass in days
    eliteCost = 1000,      -- Cost to upgrade to Elite Pass (points/coins)
    levelCost = 50,        -- Cost to buy one level
    maxLevel = 50,         -- Maximum pass level
    expPerLevel = 100,     -- EXP needed to level up
    
    -- Missions configuration (expReward = EXP granted on completion)
    missions = {
        -- Easy (Daily)
        {name = "Rotworm", count = 50, expReward = 15, outfit = 26, bonus = false, storageCount = 81001, storageCompleted = 81101, type = "daily"},
        {name = "Cyclops", count = 30, expReward = 20, outfit = 22, bonus = false, storageCount = 81002, storageCompleted = 81102, type = "daily"},
        
        -- Medium (Weekly)
        {name = "Dragon", count = 20, expReward = 30, outfit = 34, bonus = false, storageCount = 81003, storageCompleted = 81103, type = "weekly"},
        {name = "Dragon Lord", count = 15, expReward = 40, outfit = 39, bonus = false, storageCount = 81004, storageCompleted = 81104, type = "weekly"},
        
        -- Permanent
        {name = "Giant Spider", count = 25, expReward = 35, outfit = 38, bonus = true, bonusExp = 20, bonusCount = 5, storageCount = 81005, storageCompleted = 81105},
        {name = "Hydra", count = 15, expReward = 45, outfit = 37, bonus = false, storageCount = 81006, storageCompleted = 81106},
        -- Hard missions
        {name = "Demon", count = 10, expReward = 60, outfit = 35, bonus = true, bonusExp = 30, bonusCount = 5, storageCount = 81007, storageCompleted = 81107},
        {name = "Warlock", count = 15, expReward = 50, outfit = 130, bonus = false, storageCount = 81008, storageCompleted = 81108},
        {name = "Behemoth", count = 10, expReward = 55, outfit = 55, bonus = true, bonusExp = 25, bonusCount = 3, storageCount = 81009, storageCompleted = 81109},
        {name = "Plaguesmith", count = 8, expReward = 70, outfit = 110, bonus = false, storageCount = 81010, storageCompleted = 81110},
    },
    
    -- Rewards configuration (Level -> Rewards)
    -- Format: [Level] = { free = {list of items}, elite = {list of items} }
    rewards = {}
}

-- Populate rewards with some dummy data for testing
for i = 1, PASS_CONFIG.maxLevel do
    -- Level 1-9: Crystal Coins + Magic Plate
    PASS_CONFIG.rewards[i] = {
        free = {
            {id = 2160, count = 1, name = 'Crystal Coin'}
        },
        elite = {
            {id = 2472, count = 1, name = 'Magic Plate Armor'}
        }
    }
end

-- Level 10: Exclusive Mount (Elite only)
PASS_CONFIG.rewards[10] = {
    free = {{id = 2160, count = 5, name = 'Crystal Coins'}},
    elite = {{type = 'mount', id = 1, name = 'Widow Queen'}}
}

-- Level 25: Exclusive Outfit (Elite only)
PASS_CONFIG.rewards[25] = {
    free = {{id = 2160, count = 10, name = 'Crystal Coins'}},
    elite = {{type = 'outfit', id = 136, name = 'Assassin Outfit'}}
}

-- Level 50: Final Reward - Mount + Outfit (Elite only)
PASS_CONFIG.rewards[50] = {
    free = {{id = 2160, count = 25, name = 'Crystal Coins'}},
    elite = {
        {type = 'outfit', id = 541, name = 'Battle Pass Champion'},
        {type = 'mount', id = 25, name = 'Crystal Wolf'}
    }
}

-- Storage keys
local STORAGE_PASS_LEVEL = 80001
local STORAGE_PASS_EXP = 80002
local STORAGE_PASS_STATUS = 80003 -- 0 = Free, 1 = Elite
local STORAGE_PASS_START = 80004  -- Start timestamp
-- Removed STORAGE_PASS_POINTS, using premium_points from DB
local STORAGE_REWARDS_BASE = 82000 -- Base storage for rewards (82000 + level*10 + type)

-- Helper function to add EXP and handle level-ups
local function addPassExp(player, amount)
    local currentLevel = player:getStorageValue(STORAGE_PASS_LEVEL)
    if currentLevel < 0 then currentLevel = 0 end
    
    local currentExp = player:getStorageValue(STORAGE_PASS_EXP)
    if currentExp < 0 then currentExp = 0 end
    
    -- Apply XP Boost multiplier if active
    local boostMultiplier = 1
    if getPassBoostMultiplier then
        boostMultiplier = getPassBoostMultiplier(player)
    end
    local boostedAmount = amount * boostMultiplier
    if boostMultiplier > 1 then
        player:sendTextMessage(MESSAGE_STATUS_SMALL, 'XP Boost ativo! +' .. boostedAmount .. ' EXP (x' .. boostMultiplier .. ')')
    end
    currentExp = currentExp + boostedAmount
    
    -- Check for level ups
    local levelsGained = 0
    while currentExp >= PASS_CONFIG.expPerLevel and currentLevel < PASS_CONFIG.maxLevel do
        currentExp = currentExp - PASS_CONFIG.expPerLevel
        currentLevel = currentLevel + 1
        levelsGained = levelsGained + 1
    end
    
    -- Save new values
    player:setStorageValue(STORAGE_PASS_EXP, currentExp)
    player:setStorageValue(STORAGE_PASS_LEVEL, currentLevel)
    
    -- Notify player
    if levelsGained > 0 then
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Battle Pass Level Up! You are now level " .. currentLevel .. "!")
        player:getPosition():sendMagicEffect(CONST_ME_FIREWORK_YELLOW, player)
    else
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Battle Pass: +" .. amount .. " EXP")
    end
    
    return levelsGained
end

-- Helper function to get player points
local function getPlayerPoints(player)
    local accountId = player:getAccountId()
    local resultId = db.storeQuery('SELECT premium_points FROM accounts WHERE id = ' .. accountId)
    if resultId then
        local points = result.getNumber(resultId, 'premium_points')
        result.free(resultId)
        return points
    end
    return 0
end

-- Helper function to remove player points
local function removePlayerPoints(player, amount)
    local accountId = player:getAccountId()
    local points = getPlayerPoints(player)
    if points >= amount then
        db.query('UPDATE accounts SET premium_points = premium_points - ' .. amount .. ' WHERE id = ' .. accountId)
        return true
    end
    return false
end

local function getPassData(player)
    local level = player:getStorageValue(STORAGE_PASS_LEVEL)
    if level < 0 then level = 0 end
    
    local exp = player:getStorageValue(STORAGE_PASS_EXP)
    if exp < 0 then exp = 0 end
    
    local status = player:getStorageValue(STORAGE_PASS_STATUS)
    if status < 0 then status = 0 end
    
    local startTime = player:getStorageValue(STORAGE_PASS_START)
    if startTime <= 0 then
        startTime = os.time()
        player:setStorageValue(STORAGE_PASS_START, startTime)
    end
    
    local endTime = startTime + (PASS_CONFIG.passDurationDays * 24 * 60 * 60)
    
    -- Auto Season Reset
    if os.time() > endTime then
        -- Reset Level & EXP
        player:setStorageValue(STORAGE_PASS_LEVEL, 0)
        player:setStorageValue(STORAGE_PASS_EXP, 0)
        player:setStorageValue(STORAGE_PASS_STATUS, 0)
        
        -- Reset Missions
        for _, mission in ipairs(PASS_CONFIG.missions) do
            player:setStorageValue(mission.storageCount, 0)
            player:setStorageValue(mission.storageCompleted, 0)
        end
        
        -- Reset Rewards (Loop through all potential reward keys)
        for lvl = 1, PASS_CONFIG.maxLevel do
            player:setStorageValue(STORAGE_REWARDS_BASE + (lvl * 10) + 0, 0) -- Free
            player:setStorageValue(STORAGE_REWARDS_BASE + (lvl * 10) + 1, 0) -- Elite
        end
        
        -- Start New Season
        startTime = os.time()
        player:setStorageValue(STORAGE_PASS_START, startTime)
        endTime = startTime + (PASS_CONFIG.passDurationDays * 24 * 60 * 60)
        
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "A new Battle Pass season has started! Your progress has been reset.")
    end
    
    -- Construct rewards data structure matching client expectations
    local passDataStruct = {
        level = level,
        exp = exp,
        expPerLevel = PASS_CONFIG.expPerLevel,
        maxLevel = PASS_CONFIG.maxLevel,
        status = status,
        passEnd = endTime,
        UpgradePass = PASS_CONFIG.eliteCost,
        levelUp = PASS_CONFIG.levelCost,
        points = getPlayerPoints(player),
        data = {}
    }

    -- Build Basic Rewards List
    local basicRewards = { typePass = "Basic", rewards = {} }
    for lvl = 1, PASS_CONFIG.maxLevel do
        local rewardsForLevel = PASS_CONFIG.rewards[lvl]
        if rewardsForLevel and rewardsForLevel.free then
            for _, item in ipairs(rewardsForLevel.free) do
                local storageKey = STORAGE_REWARDS_BASE + (lvl * 10) + 0 -- 0 for Free
                local collect = player:getStorageValue(storageKey) == 1
                
                -- Handle special reward types (outfit, mount)
                local clientId = 0
                if item.type == 'outfit' or item.type == 'mount' or item.type == 'addon' then
                    clientId = item.type == 'outfit' and 2195 or 2196 -- Placeholder icons
                else
                    clientId = ItemType(item.id):getClientId()
                end
                table.insert(basicRewards.rewards, {
                    index = lvl,
                    itemId = clientId,
                    count = item.count,
                    itemName = item.name,
                    collect = collect
                })
            end
        end
    end
    table.insert(passDataStruct.data, basicRewards)

    -- Build Elite Rewards List
    local eliteRewards = { typePass = "Elite", rewards = {} }
    for lvl = 1, PASS_CONFIG.maxLevel do
        local rewardsForLevel = PASS_CONFIG.rewards[lvl]
        if rewardsForLevel and rewardsForLevel.elite then
            for _, item in ipairs(rewardsForLevel.elite) do
                local storageKey = STORAGE_REWARDS_BASE + (lvl * 10) + 1 -- 1 for Elite
                local collect = player:getStorageValue(storageKey) == 1

                -- Handle special reward types (outfit, mount)
                local clientId = 0
                if item.type == 'outfit' or item.type == 'mount' or item.type == 'addon' then
                    clientId = item.type == 'outfit' and 2195 or 2196 -- Placeholder icons
                else
                    clientId = ItemType(item.id):getClientId()
                end
                table.insert(eliteRewards.rewards, {
                    index = lvl,
                    itemId = clientId,
                    count = item.count,
                    itemName = item.name,
                    collect = collect
                })
            end
        end
    end
    table.insert(passDataStruct.data, eliteRewards)
    
    return passDataStruct
end

local function handleOpenPass(player)
    print("Game Pass: Handling OpenPass for " .. player:getName())
    local passData = getPassData(player)
    
    -- Using json.encode to create the JSON string
    local json_str = json.encode({
        type = "openPass",
        passData = passData
    })
    
    -- Debug print (be careful with large strings in production)
    print("Game Pass: Sending data size: " .. #json_str)

    player:sendExtendedOpcode(OPCODE_SEND, json_str)
end

local function handleBuyPass(player)
    local points = getPlayerPoints(player)
    if points >= PASS_CONFIG.eliteCost then
        if removePlayerPoints(player, PASS_CONFIG.eliteCost) then
            player:setStorageValue(STORAGE_PASS_STATUS, 1)
            player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You upgraded to Elite Pass!")
            if PassHistory and PassHistory.addLog then
                PassHistory.addLog(player, "Upgraded to Elite Pass for " .. PASS_CONFIG.eliteCost .. " points")
            end
            handleOpenPass(player) -- Refresh
        end
    else
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, "Not enough points. You need " .. PASS_CONFIG.eliteCost .. " points.")
    end
end

local function handleBuyLevel(player)
    local points = getPlayerPoints(player)
    if points >= PASS_CONFIG.levelCost then
        local currentLevel = player:getStorageValue(STORAGE_PASS_LEVEL)
        if currentLevel < 0 then currentLevel = 0 end
        
        if currentLevel < PASS_CONFIG.maxLevel then
            if removePlayerPoints(player, PASS_CONFIG.levelCost) then
                player:setStorageValue(STORAGE_PASS_LEVEL, currentLevel + 1)
                player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Battle Pass Level Bought! You are now level " .. (currentLevel + 1) .. "!")
                if PassHistory and PassHistory.addLog then
                    PassHistory.addLog(player, "Bought Level " .. (currentLevel + 1) .. " for " .. PASS_CONFIG.levelCost .. " points")
                end
                handleOpenPass(player)
            end
        else
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, "Max level reached.")
        end
    else
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, "Not enough points. You need " .. PASS_CONFIG.levelCost .. " points.")
    end
end

local function handleMissionUpdate(player)
    print("Game Pass: updatePassMission requested")
    -- Send mission status
    local missionData = {}
    for _, mission in ipairs(PASS_CONFIG.missions) do
        local killCount = player:getStorageValue(mission.storageCount)
        if killCount < 0 then killCount = 0 end
        
        table.insert(missionData, {
            name = mission.name,
            exp = 0, -- Calculate actual progress percentage or value
            kill = killCount,
            count = mission.count,
            outfit = mission.outfit,
            completed = (killCount >= mission.count) and 1 or 0,
            bonusMonsters = mission.bonus,
            bonusInfo = {
                expBonus = mission.bonusExp or 0,
                countBonus = mission.bonusCount or 0
            },
            timeUntilNextUpdate = 3600 -- Dummy time
        })
    end
    print("Game Pass: Sending " .. #missionData .. " missions")
    
    player:sendExtendedOpcode(OPCODE_SEND, json.encode({
        type = "missionUpdate",
        missionData = missionData
    }))
end

local function handleCollectReward(player, data)
    print("Game Pass: collectRewardPass requested index=" .. tostring(data.index) .. " pass=" .. tostring(data.pass))
    local index = data.index
    local passType = data.pass -- "Basic" or "Elite"
    
    if not index or not passType then return end

    local currentLevel = player:getStorageValue(STORAGE_PASS_LEVEL)
    if currentLevel < 1 then currentLevel = 1 end
    
    -- Check level requirement
    if index > currentLevel then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, "You confirm level requirement.")
        return
    end

    -- Check Elite status
    if passType == "Elite" then
        local status = player:getStorageValue(STORAGE_PASS_STATUS)
        if status ~= 1 then
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, "You need Elite Pass to collect this.")
            return
        end
    end
    
    -- Check if already collected
    local storageOffset = (passType == "Basic") and 0 or 1
    local storageKey = STORAGE_REWARDS_BASE + (index * 10) + storageOffset
    
    if player:getStorageValue(storageKey) == 1 then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, "Already collected.")
        return
    end
    
    -- Give Reward
    local rewardsForLevel = PASS_CONFIG.rewards[index]
    if rewardsForLevel then
        local items = (passType == "Basic") and rewardsForLevel.free or rewardsForLevel.elite
        if items then
            print("Game Pass: Giving reward for level " .. index)
            -- Verify capacity/slots here if needed
            for _, item in ipairs(items) do
                -- Handle different reward types
                if item.type == 'outfit' then
                    player:addOutfit(item.id)
                    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, 'Voce desbloqueou uma nova outfit!')
                elseif item.type == 'mount' then
                    player:addMount(item.id)
                    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, 'Voce desbloqueou uma nova mount!')
                elseif item.type == 'addon' then
                    player:addOutfitAddon(item.outfitId, item.addon)
                    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, 'Voce desbloqueou um novo addon!')
                else
                    player:addItem(item.id, item.count)
                end
            end
            
            -- Mark as collected
            player:setStorageValue(storageKey, 1)
            player:getPosition():sendMagicEffect(CONST_ME_GIFT_WRAPS, player)
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Reward collected!")
            
            if PassHistory and PassHistory.addLog then
                PassHistory.addLog(player, "Collected reward for Level " .. index .. " (" .. passType .. ")")
            end
            
            -- Refresh UI to show collected icon
            handleOpenPass(player)
        else
            print("Game Pass: No items found definition for level " .. index)
        end
    else
        print("Game Pass: No rewards definition for level " .. index)
    end
end

local function handleCollectAll(player)
    local currentLevel = player:getStorageValue(STORAGE_PASS_LEVEL)
    if currentLevel < 1 then currentLevel = 1 end
    local isElite = player:getStorageValue(STORAGE_PASS_STATUS) == 1
    local collectedCount = 0

    for lvl = 1, currentLevel do
        local rewardsForLevel = PASS_CONFIG.rewards[lvl]
        if rewardsForLevel then
            -- Collect Free
            local storageKeyFree = STORAGE_REWARDS_BASE + (lvl * 10) + 0
            if player:getStorageValue(storageKeyFree) ~= 1 and rewardsForLevel.free then
                for _, item in ipairs(rewardsForLevel.free) do
                     player:addItem(item.id, item.count)
                end
                player:setStorageValue(storageKeyFree, 1)
                collectedCount = collectedCount + 1
            end

            -- Collect Elite
            if isElite then
                local storageKeyElite = STORAGE_REWARDS_BASE + (lvl * 10) + 1
                if player:getStorageValue(storageKeyElite) ~= 1 and rewardsForLevel.elite then
                    for _, item in ipairs(rewardsForLevel.elite) do
                         player:addItem(item.id, item.count)
                    end
                    player:setStorageValue(storageKeyElite, 1)
                    collectedCount = collectedCount + 1
                end
            end
        end
    end

    if collectedCount > 0 then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Collected " .. collectedCount .. " rewards!")
        if PassHistory and PassHistory.addLog then
            PassHistory.addLog(player, "Collected " .. collectedCount .. " rewards via Collect All")
        end
        handleOpenPass(player)
    else
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, "No rewards to collect.")
    end
end


-- Event Handler
local passEvent = CreatureEvent("GamePassOpcode")

function passEvent.onExtendedOpcode(player, opcode, buffer)
    if opcode ~= OPCODE_RECEIVE then return false end
    
    local status, data = pcall(json.decode, buffer)
    if not status or not data then return false end
    
    -- print("Game Pass: Code " .. (data.type or "nil")) -- Debug print

    if data.type == "openPass" then
        handleOpenPass(player)
    elseif data.type == "BuyPass" then
        handleBuyPass(player)
    elseif data.type == "buyLevel" then
        handleBuyLevel(player)
    elseif data.type == "updatePassMission" then
        handleMissionUpdate(player)
    elseif data.type == "collectRewardPass" then
        handleCollectReward(player, data)
    elseif data.type == "collectAllReward" then
        handleCollectAll(player)
    elseif data.type == "getRanking" then
        -- Get Battle Pass ranking
        local ranking = {}
        if PassRanking and PassRanking.getTopPlayers then
            ranking = PassRanking.getTopPlayers(10)
        end
        local playerRank = 0
        if PassRanking and PassRanking.getPlayerRank then
            playerRank = PassRanking.getPlayerRank(player)
        end
        player:sendExtendedOpcode(OPCODE_SEND, json.encode({
            opcode = "ranking",
            ranking = ranking,
            yourRank = playerRank
        }))
    elseif data.type == "getHistory" then
        -- Get activity logs
        local logs = {}
        if PassHistory and PassHistory.getLogs then
            if player:getGroup():getAccess() and data.admin then -- Check if admin request
                logs = PassHistory.getAllLogs(50)
            else
                 -- For now always return own logs unless we implement specific admin switch
                 -- The client sends {type='getHistory'}
                 -- If admin wants to see Global, we might need a flag. 
                 -- User said "Admins: Veem o log global".
                 -- I'll check player access here.
                 if player:getGroup():getAccess() then
                    logs = PassHistory.getAllLogs(100) -- Admin sees global
                 else
                    logs = PassHistory.getLogs(player)
                 end
            end
        end
        player:sendExtendedOpcode(OPCODE_SEND, json.encode({
            opcode = "history",
            history = logs,
            isAdmin = player:getGroup():getAccess() -- Send admin status to client
        }))
    end
    
    return true
end

passEvent:register()

local passLoginEvent = CreatureEvent("GamePassLogin")
function passLoginEvent.onLogin(player)
    player:registerEvent("GamePassOpcode")
    return true
end
passLoginEvent:register()








-- Admin Commands

local givePassExp = TalkAction("/givepassexp")

function givePassExp.onSay(player, words, param)
    if not player:getGroup():getAccess() then
        return true
    end

    local split = param:split(",")
    if not split[2] then
        player:sendCancelMessage("Insufficient parameters. Usage: /givepassexp player_name, amount")
        return false
    end

    local targetName = split[1]:trim()
    local amount = tonumber(split[2]:trim())

    if not amount then
        player:sendCancelMessage("Invalid amount. Usage: /givepassexp player_name, amount")
        return false
    end

    local target = Player(targetName)
    if not target then
        player:sendCancelMessage("Player " .. targetName .. " not found.") 
        return false
    end

    addPassExp(target, amount)
    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Added " .. amount .. " Battle Pass EXP to " .. targetName .. ".")
    target:sendTextMessage(MESSAGE_INFO_DESCR, "You received " .. amount .. " Battle Pass EXP from an administrator.")
    return false
end

givePassExp:separator(" ")
givePassExp:register()

local givePassPoints = TalkAction("/givepasspoints")

function givePassPoints.onSay(player, words, param)
    if not player:getGroup():getAccess() then
        return true
    end

    local split = param:split(",")
    if not split[2] then
        player:sendCancelMessage("Insufficient parameters. Usage: /givepasspoints player_name, amount")
        return false
    end

    local targetName = split[1]:trim()
    local amount = tonumber(split[2]:trim())

    if not amount then
        player:sendCancelMessage("Invalid amount. Usage: /givepasspoints player_name, amount")
        return false
    end

    local target = Player(targetName)
    if not target then
        player:sendCancelMessage("Player " .. targetName .. " not found.")
        return false
    end

    local currentPoints = getPlayerPoints(target)
    local accountId = target:getAccountId(); db.query('UPDATE accounts SET premium_points = premium_points + ' .. amount .. ' WHERE id = ' .. accountId)
    
    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, 'Added ' .. amount .. ' Premium Points to ' .. targetName .. '.')
    target:sendTextMessage(MESSAGE_INFO_DESCR, "You received " .. amount .. " Battle Pass Points from an administrator.")
    
    -- Update client just in case needed
    target:sendExtendedOpcode(OPCODE_SEND, json.encode({
        type = "pointsUpdate",
        points = currentPoints + amount
    }))
    
    return false
end

givePassPoints:separator(" ")
givePassPoints:register()



