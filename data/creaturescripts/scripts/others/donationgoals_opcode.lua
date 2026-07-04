local DONATION_OPCODE = 8

-- =============================================
-- CONFIGURACAO DAS METAS DE DOACAO
-- Edite aqui para mudar metas, recompensas, etc.
-- =============================================

-- Storage keys
local STORAGE_PLAYER_DONATED = 85001       -- quanto o jogador doou neste ciclo
local STORAGE_GLOBAL_REWARD_CLAIMED = 85002 -- se ja coletou recompensa global (1 = sim)
local STORAGE_PERSONAL_REWARD_1 = 85003     -- se ja coletou recompensa pessoal tier 1
local STORAGE_PERSONAL_REWARD_2 = 85004     -- se ja coletou recompensa pessoal tier 2
local STORAGE_PERSONAL_REWARD_3 = 85005     -- se ja coletou recompensa pessoal tier 3

-- Global variable key para total doado do servidor
local GLOBAL_SERVER_DONATED = 85100

-- Data de fim do ciclo (formato DD-MM-YYYY)
local END_DATE = "28-02-2026"

-- Meta global (configuravel)
local GLOBAL_GOAL = {
    meta = 50000,            -- meta total do servidor
    playerDonate = 500,      -- minimo que o jogador precisa doar pra ganhar recompensa global
    type = "ITEM",           -- "ITEM" ou "POKEMON"
    reward = {
        id = 2160,           -- crystal coin
        count = 100
    },
    -- outfit = {type = 130}, -- usar se type = "POKEMON"
    desc = "Recompensa Global: 100 Crystal Coins para todos que doaram 500+ pontos!"
}

-- Metas pessoais (3 tiers)
local PERSONAL_GOALS = {
    [1] = {
        meta = 100,
        desc = "Tier 1: 50 Platinum Coins",
        rewardItemId = 2152,
        rewardCount = 50
    },
    [2] = {
        meta = 300,
        desc = "Tier 2: 20 Crystal Coins",
        rewardItemId = 2160,
        rewardCount = 20
    },
    [3] = {
        meta = 500,
        desc = "Tier 3: 50 Crystal Coins",
        rewardItemId = 2160,
        rewardCount = 50
    }
}

-- =============================================
-- FUNCOES AUXILIARES
-- =============================================

local function getPlayerDonated(player)
    local val = player:getStorageValue(STORAGE_PLAYER_DONATED)
    return math.max(0, val)
end

local function getServerDonated()
    local val = Game.getStorageValue(GLOBAL_SERVER_DONATED)
    if not val or val < 0 then return 0 end
    return val
end

local function getCurrentDate()
    return os.date("%d-%m-%Y")
end

local function parseDate(dateStr)
    local p1, p2, p3 = dateStr:match("(%d+)-(%d+)-(%d+)")
    if not p1 then return os.time() end
    local day, month, year = tonumber(p1), tonumber(p2), tonumber(p3)
    if year < 100 then year = year + 2000 end
    return os.time({year = year, month = month, day = day, hour = 0, min = 0, sec = 0})
end

local function getRemainingTimeText(endDateStr)
    local now = os.time()
    local endTime = parseDate(endDateStr)
    local remainingDays = math.floor((endTime - now) / (24 * 60 * 60))
    if remainingDays > 1 then
        return "Ends in " .. remainingDays .. " days"
    elseif remainingDays == 1 then
        return "Ends tomorrow"
    else
        return "Ends today"
    end
end

-- Send donation goals data to client
local function sendDonationGoals(player)
    local playerGoal = getPlayerDonated(player)
    local serverGoal = getServerDonated()

    local globalGoalData = {
        {
            meta = GLOBAL_GOAL.meta,
            playerDonate = GLOBAL_GOAL.playerDonate,
            type = GLOBAL_GOAL.type,
            reward = GLOBAL_GOAL.reward,
            outfit = GLOBAL_GOAL.outfit,
            desc = GLOBAL_GOAL.desc
        }
    }

    local personalGoalData = {}
    for i = 1, 3 do
        local storageKey = STORAGE_PERSONAL_REWARD_1 + (i - 1)
        local claimed = player:getStorageValue(storageKey)
        table.insert(personalGoalData, {
            meta = PERSONAL_GOALS[i].meta,
            desc = PERSONAL_GOALS[i].desc,
            claimed = (claimed and claimed >= 1)
        })
    end

    local payload = json.encode({
        action = "DonationGoalsInformation",
        data = {
            globalGoal = globalGoalData,
            personalGoal = personalGoalData,
            ServerGoal = serverGoal,
            PlayerGoal = playerGoal,
            globalClaimed = (player:getStorageValue(STORAGE_GLOBAL_REWARD_CLAIMED) >= 1),
            date = {
                AtualDate = getCurrentDate(),
                EndDate = END_DATE,
                remainingText = getRemainingTimeText(END_DATE)
            }
        }
    })

    player:sendExtendedOpcode(DONATION_OPCODE, payload)
end

-- Collect global reward
local function collectGlobalReward(player)
    local serverGoal = getServerDonated()
    local playerGoal = getPlayerDonated(player)

    if serverGoal < GLOBAL_GOAL.meta then
        player:sendTextMessage(MESSAGE_STATUS_SMALL, "A meta global ainda nao foi alcancada!")
        return
    end

    if playerGoal < GLOBAL_GOAL.playerDonate then
        player:sendTextMessage(MESSAGE_STATUS_SMALL, "Voce precisa ter doado pelo menos " .. GLOBAL_GOAL.playerDonate .. " pontos!")
        return
    end

    local claimed = player:getStorageValue(STORAGE_GLOBAL_REWARD_CLAIMED)
    if claimed and claimed >= 1 then
        player:sendTextMessage(MESSAGE_STATUS_SMALL, "Voce ja coletou a recompensa global!")
        return
    end

    -- Give reward
    if GLOBAL_GOAL.type == "ITEM" then
        player:addItem(GLOBAL_GOAL.reward.id, GLOBAL_GOAL.reward.count)
    end

    player:setStorageValue(STORAGE_GLOBAL_REWARD_CLAIMED, 1)
    player:sendTextMessage(MESSAGE_INFO_DESCR, "Voce coletou a recompensa global com sucesso!")
    sendDonationGoals(player)
end

-- Collect personal reward (tier 1, 2, or 3)
local function collectPersonalReward(player, tier)
    if tier < 1 or tier > 3 then return end

    local playerGoal = getPlayerDonated(player)
    local goalData = PERSONAL_GOALS[tier]

    if playerGoal < goalData.meta then
        player:sendTextMessage(MESSAGE_STATUS_SMALL, "Voce precisa ter doado pelo menos " .. goalData.meta .. " pontos para esta recompensa!")
        return
    end

    local storageKey = STORAGE_PERSONAL_REWARD_1 + (tier - 1)
    local claimed = player:getStorageValue(storageKey)
    if claimed and claimed >= 1 then
        player:sendTextMessage(MESSAGE_STATUS_SMALL, "Voce ja coletou esta recompensa!")
        return
    end

    -- Give reward
    player:addItem(goalData.rewardItemId, goalData.rewardCount)

    player:setStorageValue(storageKey, 1)
    player:sendTextMessage(MESSAGE_INFO_DESCR, "Voce coletou a recompensa pessoal (Tier " .. tier .. ") com sucesso!")
    sendDonationGoals(player)
end

-- =============================================
-- EVENT HANDLER
-- =============================================

function onExtendedOpcode(player, opcode, buffer)
    if opcode ~= DONATION_OPCODE then
        return true
    end

    -- Try JSON first
    local status, data = pcall(function()
        return json.decode(buffer)
    end)

    if status and data and data.action then
        -- JSON format (future use)
        return true
    end

    -- Plain text commands
    if buffer == "openDonationGoals" or buffer == "requestDonationGoals" or buffer == "" then
        sendDonationGoals(player)
    elseif buffer == "doCollectGlobalReward" then
        collectGlobalReward(player)
    elseif buffer:sub(1, 23) == "doCollectPersonalReward" then
        local tier = tonumber(buffer:sub(24))
        if tier then
            collectPersonalReward(player, tier)
        end
    end

    return true
end
