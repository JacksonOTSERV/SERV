local soulOffers = {
    ["magic wall creator"] = {itemId = 13578, count = 1, soul = 3},
    ["stamina potion"]     = {itemId = 12289, count = 1, soul = 125},
    ["ki level god booster"]= {itemId = 13572, count = 1, soul = 75},
    ["skill god booster"]  = {itemId = 13574, count = 1, soul = 75}
}

local offerOrder = {
    "magic wall creator",
    "stamina potion",
    "ki level god booster",
    "skill god booster"
}

local requiredGoldBars = 50
local goldBarId = 2160
local ticketStorage = 3331

local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

npcHandler:setMessage(MESSAGE_GREET, {
    PT = "Olá |PLAYERNAME|. Eu ofereço itens por soul points.",
    EN = "Hello |PLAYERNAME|. I offer items for soul points."
})
npcHandler:setMessage(MESSAGE_FAREWELL, {
    PT = "Adeus.",
    EN = "Goodbye."
})
npcHandler:setMessage(MESSAGE_WALKAWAY, {
    PT = "Adeus.",
    EN = "Goodbye."
})

function onCreatureAppear(cid) npcHandler:onCreatureAppear(cid) end
function onCreatureDisappear(cid) npcHandler:onCreatureDisappear(cid) end
function onCreatureSay(cid, type, msg) npcHandler:onCreatureSay(cid, type, msg) end
function onThink() npcHandler:onThink() end

local function checkPlayer(cid)
    local player = Player(cid)
    return player and player:isPlayer()
end

local function listOffers(cid)
    local list = {}
    for _, name in ipairs(offerOrder) do
        local offer = soulOffers[name]
        table.insert(list, string.format("{%s} (Soul por unidade: %d)", name, offer.soul))
    end
    npcHandler:say({PT="Aqui estão as ofertas disponíveis: " .. table.concat(list, ", "), EN="Here are the available offers: " .. table.concat(list, ", ")}, cid)
end

local function askQuantity(cid, offerName)
    npcHandler.topic[cid] = offerName
    npcHandler:say({PT="Quantos " .. offerName .. " você quer comprar?", EN="How many " .. offerName .. " do you want to buy?"}, cid)
end

local function giveItem(player, itemId, totalCount)
    local itemType = ItemType(itemId)
    if itemType:isStackable() then
        return player:addItem(itemId, totalCount, true)
    else
        for i = 1, totalCount do
            if not player:addItem(itemId, 1, true) then
                return false
            end
        end
        return true
    end
end

local function tradeSoulForItem(cid, offerName, quantity)
    local player = Player(cid)
    local offer = soulOffers[offerName]
    if not player or not offer then return end

    quantity = tonumber(quantity)
    if not quantity or quantity < 1 then
        npcHandler:say({PT="Quantidade inválida.", EN="Invalid quantity."}, cid)
        return
    end

    local totalSoul = offer.soul * quantity
    if player:getSoul() < totalSoul then
        npcHandler:say({PT="Você precisa de pelo menos " .. totalSoul .. " soul points para isso.", EN="You need at least " .. totalSoul .. " soul points for this."}, cid)
        return
    end

    if not giveItem(player, offer.itemId, offer.count * quantity) then
        npcHandler:say({PT="Você não tem espaço suficiente na mochila.", EN="You do not have enough space in your backpack."}, cid)
        return
    end

    player:addSoul(-totalSoul)
    npcHandler:say({PT="Aqui está seu(s) " .. quantity .. " " .. offerName .. ". Você perdeu " .. totalSoul .. " soul points.", EN="Here is your " .. quantity .. " " .. offerName .. ". You lost " .. totalSoul .. " soul points."}, cid)
end

local function buyTicket(cid)
    local player = Player(cid)
    if not player then return end

    if player:getStorageValue(ticketStorage) == 1 then
        npcHandler:say({PT="Você já possui o ticket.", EN="You already have the ticket."}, cid)
        return
    end

    if player:getItemCount(goldBarId) < requiredGoldBars then
        npcHandler:say({PT="Você precisa de 50 gold bars para adquirir o ticket.", EN="You need 50 gold bars to acquire the ticket."}, cid)
        return
    end

    if not player:removeItem(goldBarId, requiredGoldBars) then
        npcHandler:say({PT="Erro ao retirar os gold bars. Verifique seu inventário.", EN="Error removing gold bars. Check your inventory."}, cid)
        return
    end

    player:setStorageValue(ticketStorage, 1)
    npcHandler:say({PT="Parabéns! Você adquiriu o ticket.", EN="Congratulations! You acquired the ticket."}, cid)
end

npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, function(cid, type, msg)
    local message = msg:lower()
    local topic = npcHandler.topic[cid]

    if topic and soulOffers[topic] then
        local quantity = tonumber(message)
        if quantity and quantity > 0 then
            tradeSoulForItem(cid, topic, quantity)
            npcHandler.topic[cid] = nil
        else
            npcHandler:say({PT="Por favor, diga uma quantidade válida.", EN="Please say a valid quantity."}, cid)
        end
        return true
    end

    return false
end)

keywordHandler:addKeyword({"negociar"}, function(cid)
    if not checkPlayer(cid) then return false end
    listOffers(cid)
    return true
end)

keywordHandler:addKeyword({"ticket"}, function(cid)
    if not checkPlayer(cid) then return false end
    buyTicket(cid)
    return true
end)

for _, offerName in ipairs(offerOrder) do
    keywordHandler:addKeyword({offerName}, function(cid)
        if not checkPlayer(cid) then return false end
        askQuantity(cid, offerName)
        return true
    end)
end

npcHandler:addModule(FocusModule:new())
