
local TASKS_OPCODE = 56

local STORAGE_TASKS_POINTS = 50500 -- Points count

-- Config matches client expectations
local CONFIG = {
    kills = {
        Min = 10,
        Max = 100
    },
    range = 999, -- Level range visibility
    bonus = 50, -- Kills step for bonus calculation
    points = 1, -- Multiplier
    exp = 5,    -- Multiplier %
    gold = 5    -- Multiplier %
}

local RewardType = {
  Points = 1,
  Ranking = 2,
  Experience = 3,
  Gold = 4,
  Item = 5,
  Storage = 6,
  Teleport = 7,
}

local TASKS = {
    [1] = {
        name = "Rotworms",
        lvl = 8,
        mobs = {"Rotworm", "Carrion Worm"},
        rewards = {
            {type = RewardType.Experience, value = 1000},
            {type = RewardType.Gold, value = 500},
            {type = RewardType.Points, value = 1}
        }
    },
    [2] = {
        name = "Dragons",
        lvl = 20,
        mobs = {"Dragon", "Dragon Hatchling"},
        rewards = {
            {type = RewardType.Experience, value = 5000},
            {type = RewardType.Item, amount = 1, name = "Dragon Shield", itemId = 2516},
            {type = RewardType.Points, value = 2}
        }
    },
    [3] = {
        name = "Demons",
        lvl = 50,
        mobs = {"Demon"},
        rewards = {
            {type = RewardType.Experience, value = 20000},
            {type = RewardType.Gold, value = 10000},
            {type = RewardType.Points, value = 5}
        }
    }
}

local STORAGE_BASE_STATUS = 50100
local STORAGE_BASE_KILLS = 50200
local STORAGE_BASE_REQ = 50300

-- Helpers

local function getActiveTasks(player)
    local active = {}
    for id, task in pairs(TASKS) do
        local status = math.max(0, player:getStorageValue(STORAGE_BASE_STATUS + id))
        if status > 0 then
            local kills = math.max(0, player:getStorageValue(STORAGE_BASE_KILLS + id))
            local req = math.max(0, player:getStorageValue(STORAGE_BASE_REQ + id))
            if req == 0 then req = CONFIG.kills.Max end -- Fallback/Default
            
            active[tostring(id)] = {
                taskId = id,
                kills = kills,
                required = req,
                status = status
            }
        end
    end
    return active
end

-- saveActiveTasks is no longer needed as we set storage directly

local function sendJSON(player, action, data)
    player:sendExtendedOpcode(TASKS_OPCODE, json.encode({action = action, data = data}))
end

-- Handlers

local function sendConfig(player)
    sendJSON(player, "config", CONFIG)
end

local function sendTasksList(player)
    sendJSON(player, "tasks", TASKS)
end

local function sendActiveTasks(player)
    local active = getActiveTasks(player)
    local arr = {}
    for id, info in pairs(active) do
        table.insert(arr, {
            taskId = tonumber(id),
            kills = info.kills,
            required = info.required,
            status = info.status
        })
    end
    sendJSON(player, "active", arr)
end

local function sendPoints(player)
    local pts = math.max(0, player:getStorageValue(STORAGE_TASKS_POINTS))
    sendJSON(player, "points", pts)
    -- sendJSON(player, "ranking", {rank = pts}) 
end

local function startTask(player, taskId, killsCount)
    if not TASKS[taskId] then return end
    
    -- Validate kills count
    killsCount = killsCount or CONFIG.kills.Min
    killsCount = math.max(CONFIG.kills.Min, math.min(CONFIG.kills.Max, killsCount))
    
    local status = player:getStorageValue(STORAGE_BASE_STATUS + taskId)
    if status > 0 then
        player:sendTextMessage(MESSAGE_STATUS_SMALL, "Task already active.")
        return
    end
    
    player:setStorageValue(STORAGE_BASE_STATUS + taskId, 1)
    player:setStorageValue(STORAGE_BASE_KILLS + taskId, 0)
    player:setStorageValue(STORAGE_BASE_REQ + taskId, killsCount)
    
    sendActiveTasks(player)
    player:sendTextMessage(MESSAGE_STATUS_SMALL, "Task started: " .. TASKS[taskId].name)
end

local function cancelTask(player, taskId)
    local status = player:getStorageValue(STORAGE_BASE_STATUS + taskId)
    if status > 0 then
        player:setStorageValue(STORAGE_BASE_STATUS + taskId, -1)
        player:setStorageValue(STORAGE_BASE_KILLS + taskId, 0)
        player:setStorageValue(STORAGE_BASE_REQ + taskId, 0)
        
        sendActiveTasks(player)
        player:sendTextMessage(MESSAGE_STATUS_SMALL, "Task canceled.")
    else
        player:sendTextMessage(MESSAGE_STATUS_SMALL, "You do not have this task active.")
    end
end

local function checkReward(player, taskId, bonusKills)
    local task = TASKS[taskId]
    if not task then return end
    
    local msg = "Task Complete! Rewards: "
    
    for _, reward in ipairs(task.rewards) do
        if reward.type == RewardType.Experience then
            player:addExperience(reward.value)
            msg = msg .. reward.value .. " EXP, "
            
        elseif reward.type == RewardType.Gold then
            player:addMoney(reward.value)
            msg = msg .. reward.value .. " Gold, "
            
        elseif reward.type == RewardType.Item and reward.itemId then
            player:addItem(reward.itemId, reward.amount or 1)
            msg = msg .. (reward.amount or 1) .. "x " .. (reward.name or "Item") .. ", "
            
        elseif reward.type == RewardType.Points then
            local current = math.max(0, player:getStorageValue(STORAGE_TASKS_POINTS))
            player:setStorageValue(STORAGE_TASKS_POINTS, current + reward.value)
             msg = msg .. reward.value .. " Points. "
        end
    end
    
    player:sendTextMessage(MESSAGE_INFO_DESCR, msg)
    sendPoints(player)
end

function onExtendedOpcode(player, opcode, buffer)
    if opcode ~= TASKS_OPCODE then return false end
    
    local status, json_data = pcall(json.decode, buffer)
    if not status then 
        return false 
    end
    
    local action = json_data.action
    local data = json_data.data
    

    if action == "start" then
        if data and data.taskId then
            startTask(player, tonumber(data.taskId), tonumber(data.kills))
        end
    elseif action == "cancel" then
        if data then
            cancelTask(player, tonumber(data))
        end
    elseif action == "refresh" then
        sendConfig(player)
        sendTasksList(player)
        sendActiveTasks(player)
        sendPoints(player)
    end
    return true
end

function onKill(player, target)
    if not target:isMonster() then return true end
    
    local name = target:getName():lower()
    local changed = false
    
    for id, task in pairs(TASKS) do
        local status = math.max(0, player:getStorageValue(STORAGE_BASE_STATUS + id))
        
        if status == 1 then
             for _, mob in ipairs(task.mobs) do
                if mob:lower() == name then
                    local kills = math.max(0, player:getStorageValue(STORAGE_BASE_KILLS + id))
                    local req = math.max(0, player:getStorageValue(STORAGE_BASE_REQ + id))
                    if req == 0 then req = CONFIG.kills.Max end
                    
                    kills = kills + 1
                    player:setStorageValue(STORAGE_BASE_KILLS + id, kills)
                    
                    if kills >= req then
                        player:setStorageValue(STORAGE_BASE_STATUS + id, 2) -- Completed
                        checkReward(player, id, 0)
                        
                        -- Keep as completed in storage? 
                        -- User might want to repeat? Or clear? 
                        -- For now, leave as 2 (Completed). 
                        -- To clear, user must cancel or loop? 
                        -- Original logic: active[taskIdStr] = nil. So it was removed.
                        -- If we remove it:
                        player:setStorageValue(STORAGE_BASE_STATUS + id, -1)
                        player:setStorageValue(STORAGE_BASE_KILLS + id, 0)
                        player:setStorageValue(STORAGE_BASE_REQ + id, 0)
                        
                        -- Send update to remove from client list
                        -- We should just sendFullActiveTasks to be safe?
                        sendActiveTasks(player)
                    else
                         sendJSON(player, "update", {
                            taskId = id,
                            kills = kills,
                            required = req,
                            status = 1
                         })
                    end
                    break
                end
             end
        end
    end
    
    return true
end

function onLogin(player)
    player:registerEvent("GameTasksOpcode")
    player:registerEvent("GameTasksKill")
    
    sendConfig(player)
    sendTasksList(player)
    sendActiveTasks(player)
    sendPoints(player)
    return true
end
