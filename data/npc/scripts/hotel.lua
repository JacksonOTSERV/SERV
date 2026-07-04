local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

npcHandler:setMessage(MESSAGE_GREET, {
    PT = "Olá |PLAYERNAME|. Eu vendo chaves especiais.",
    EN = "Hello |PLAYERNAME|. I sell special keys."
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
function onCreatureSay(cid, type, msg) npcHandler:onCreatureSay(cid, type, msg:lower()) end
function onThink() npcHandler:onThink() end

local keys = {
	["bone key"] = {id_key = 2092, price = 100000, action_id = 2092},
	["golden key"] = {id_key = 2091, price = 100000, action_id = 2091},
	["silver key"] = {id_key = 2088, price = 1000000, action_id = 2088},
	["cooper key"] = {id_key = 2089, price = 1000000, action_id = 2089},
}

local function creatureSayCallback(cid, type, msg)
	local player = Player(cid)
	if not npcHandler:isFocused(cid) then
		return false
	end

	local keyInfo = keys[msg:lower()]
	if not keyInfo then
		npcHandler:say({PT="Eu não vendo esta chave.", EN="I do not sell this key."}, cid)
		return true
	end

	if player:removeMoney(keyInfo.price) then
		local item = player:addItem(keyInfo.id_key, 1)
		if item then
			item:setActionId(keyInfo.action_id)
		end
		npcHandler:say({PT="Obrigado, aqui está sua chave.", EN="Thank you, here is your key."}, cid)
	else
		npcHandler:say({PT="Você não tem dinheiro suficiente.", EN="You do not have enough money."}, cid)
	end

	return true
end

npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
