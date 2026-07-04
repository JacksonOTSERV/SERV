TradeItems = {
    {
        name = "helmet",
        give = {
            {id = 2471, count = 1},
            {id = 5920, count = 10},
            {money = 35000000}
        },
        reward = {id = 13586, count = 1}
    },
    {
        name = "coat",
        give = {
            {id = 13394, count = 1},
            {id = 5920, count = 10},
            {money = 35000000}
        },
        reward = {id = 13587, count = 1}
    },
    {
        name = "legs",
        give = {
            {id = 13395, count = 1},
            {id = 5920, count = 10},
            {money = 35000000}
        },
        reward = {id = 13588, count = 1}
    },
    {
        name = "boots",
        give = {
            {id = 13396, count = 1},
            {id = 5920, count = 10},
            {money = 35000000}
        },
        reward = {id = 13589, count = 1}
    },
    {
        name = "Potara",
        give = {
            {id = 5920, count = 20},
            {money = 35000000}
        },
        reward = {id = 13555, count = 1}
    },
    {
        name = "helmet esfera",
        give = {
            {id = 13595, count = 1},
            {id = 13596, count = 1},
            {id = 13597, count = 1},
            {id = 13598, count = 1},
            {id = 13599, count = 1},
            {id = 13600, count = 1},
            {id = 13601, count = 1},
            {money = 35000000}
        },
        reward = {id = 13586, count = 1}
    },
    {
        name = "coat esfera",
        give = {
            {id = 13595, count = 1},
            {id = 13596, count = 1},
            {id = 13597, count = 1},
            {id = 13598, count = 1},
            {id = 13599, count = 1},
            {id = 13600, count = 1},
            {id = 13601, count = 1},
            {money = 35000000}
        },
        reward = {id = 13587, count = 1}
    },
    {
        name = "legs esfera",
        give = {
            {id = 13595, count = 1},
            {id = 13596, count = 1},
            {id = 13597, count = 1},
            {id = 13598, count = 1},
            {id = 13599, count = 1},
            {id = 13600, count = 1},
            {id = 13601, count = 1},
            {money = 35000000}
        },
        reward = {id = 13588, count = 1}
    },
    {
        name = "boots esfera",
        give = {
            {id = 13595, count = 1},
            {id = 13596, count = 1},
            {id = 13597, count = 1},
            {id = 13598, count = 1},
            {id = 13599, count = 1},
            {id = 13600, count = 1},
            {id = 13601, count = 1},
            {money = 35000000}
        },
        reward = {id = 13589, count = 1}
    },
    {
        name = "Potara esfera",
        give = {
            {id = 13595, count = 1},
            {id = 13596, count = 1},
            {id = 13597, count = 1},
            {id = 13598, count = 1},
            {id = 13599, count = 1},
            {id = 13600, count = 1},
            {id = 13601, count = 1},
            {money = 35000000}
        },
        reward = {id = 13555, count = 1}
    },
}

TradeChoices = {}
TradeModalId = 10001

local function processTrade(player, trade)
    for _, req in ipairs(trade.give) do
        if req.id then
            if player:getItemCount(req.id) < req.count then
                player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Você não tem todos os itens necessários.")
                return
            end
        elseif req.money then
            if player:getMoney() < req.money then
                player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Você não tem money suficiente (precisa de 35000000).")
                return
            end
        end
    end

    for _, req in ipairs(trade.give) do
        if req.id then
            player:removeItem(req.id, req.count)
        elseif req.money then
            player:removeMoney(req.money)
        end
    end

    player:addItem(trade.reward.id, trade.reward.count)
    player:getPosition():sendMagicEffect(11)
    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Você recebeu " .. trade.reward.count .. "x " .. ItemType(trade.reward.id):getName() .. "!")
end

local creatureEvent = CreatureEvent("npcTradeModal")
function creatureEvent.onModalWindow(player, modalId, buttonId, choiceId)
    if modalId ~= TradeModalId then
        return true
    end

    if buttonId == 1 then
        local tradeIndex = TradeChoices[choiceId]
        if tradeIndex and TradeItems[tradeIndex] then
            processTrade(player, TradeItems[tradeIndex])
        end
    end
    return true
end
creatureEvent:register()

local loginEvent = CreatureEvent("npcTradeRegister")
function loginEvent.onLogin(player)
    player:registerEvent("npcTradeModal")
    return true
end
loginEvent:register()