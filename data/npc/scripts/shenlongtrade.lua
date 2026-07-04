local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

npcHandler:setMessage(MESSAGE_GREET, {
    PT = "Olá |PLAYERNAME|. Eu troco itens especiais.",
    EN = "Hello |PLAYERNAME|. I trade special items."
})
npcHandler:setMessage(MESSAGE_FAREWELL, {
    PT = "Adeus.",
    EN = "Goodbye."
})
npcHandler:setMessage(MESSAGE_WALKAWAY, {
    PT = "Adeus.",
    EN = "Goodbye."
})

local function buildTradeModal(player)
    local lang = math.max(0, player:getStorageValue(45001))
    local title = (lang == 1 and "Trade List" or "Lista de Trocas")
    local subtitle = (lang == 1 and "Choose an item to trade!" or "Escolha um item para trocar!")
    local btnTrade = (lang == 1 and "Trade" or "Trocar")
    local btnClose = (lang == 1 and "Close" or "Fechar")

    local modal = ModalWindow(TradeModalId, title, subtitle)
    modal:addButton(1, btnTrade)
    modal:addButton(2, btnClose)
    modal:setDefaultEscapeButton(2)
    modal:setDefaultEnterButton(2)

    TradeChoices = {}
    local index = 1
    for i, trade in ipairs(TradeItems) do
        local reqText = {}
		for _, req in ipairs(trade.give) do
			if req.id then
				table.insert(reqText, req.count .. "x " .. ItemType(req.id):getName())
			elseif req.money then
				table.insert(reqText, req.money .. " money")
			end
		end

        local rewardName = ItemType(trade.reward.id):getName()
        modal:addChoice(index, string.format("%s -> %s", table.concat(reqText, " + "), rewardName))

        TradeChoices[index] = i
        index = index + 1
    end

    return modal
end

local function creatureSayCallback(cid, type, msg)
    if not npcHandler:isFocused(cid) then return false end
    local player = Player(cid)

    if msg:lower() == "trade" or msg:lower() == "troca" then
        buildTradeModal(player):sendToPlayer(player)
    end
    return true
end

function onCreatureAppear(cid) npcHandler:onCreatureAppear(cid) end
function onCreatureDisappear(cid) npcHandler:onCreatureDisappear(cid) end
function onCreatureSay(cid, type, msg) npcHandler:onCreatureSay(cid, type, msg) end
function onThink() npcHandler:onThink() end

npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
