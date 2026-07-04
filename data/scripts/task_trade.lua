TaskCoinID = 13577

TaskTradeItems = {
    { name = "Item 1", give = { {id = TaskCoinID, count = 6} }, reward = {id = 13575, count = 1} },
    { name = "Item 2", give = { {id = TaskCoinID, count = 4} }, reward = {id = 8300, count = 1} },
}

TaskTradeChoices = {}
TaskTradeModalId = 10002

local function processTaskTrade(player, trade)
    for _, req in ipairs(trade.give) do
        if player:getItemCount(req.id) < req.count then
            player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Você não tem " .. req.count .. "x " .. ItemType(req.id):getName() .. " necessários.")
            return
        end
    end

    for _, req in ipairs(trade.give) do
        player:removeItem(req.id, req.count)
    end

    player:addItem(trade.reward.id, trade.reward.count)
    player:getPosition():sendMagicEffect(11)
    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Você recebeu " .. trade.reward.count .. "x " .. ItemType(trade.reward.id):getName() .. "!")
end

function buildTaskTradeModal()
    local modal = ModalWindow(TaskTradeModalId, "Troca de Task Coins", "Escolha um item para trocar:")

    modal:addButton(1, "Trocar")
    modal:addButton(2, "Fechar")
    modal:setDefaultEscapeButton(2)
    modal:setDefaultEnterButton(2)

    TaskTradeChoices = {}
    for i, trade in ipairs(TaskTradeItems) do
        local reqText = {}
        for _, req in ipairs(trade.give) do
            table.insert(reqText, req.count .. "x " .. ItemType(req.id):getName())
        end
        modal:addChoice(i, string.format("%s -> %s", table.concat(reqText, " + "), ItemType(trade.reward.id):getName()))
        TaskTradeChoices[i] = i
    end

    return modal
end

local creatureEvent = CreatureEvent("taskTradeModal")
function creatureEvent.onModalWindow(player, modalId, buttonId, choiceId)
    if modalId ~= TaskTradeModalId then return true end
    if buttonId == 1 then
        local tradeIndex = TaskTradeChoices[choiceId]
        if tradeIndex and TaskTradeItems[tradeIndex] then
            processTaskTrade(player, TaskTradeItems[tradeIndex])
        end
    end
    return true
end
creatureEvent:register()

local loginEvent = CreatureEvent("taskTradeRegister")
function loginEvent.onLogin(player)
    player:registerEvent("taskTradeModal")
    return true
end
loginEvent:register()