local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

npcHandler:setMessage(MESSAGE_GREET, {
    PT = "Olá |PLAYERNAME|. Posso transferir seus pontos premium.",
    EN = "Hello |PLAYERNAME|. I can transfer your premium points."
})
npcHandler:setMessage(MESSAGE_FAREWELL, {
    PT = "Adeus.",
    EN = "Goodbye."
})
npcHandler:setMessage(MESSAGE_WALKAWAY, {
    PT = "Adeus.",
    EN = "Goodbye."
})

local talkState = {}

function onCreatureAppear(cid) npcHandler:onCreatureAppear(cid) end
function onCreatureDisappear(cid) npcHandler:onCreatureDisappear(cid) end
function onCreatureSay(cid, type, msg) npcHandler:onCreatureSay(cid, type, msg) end
function onThink() npcHandler:onThink() end

local ItemID = 1969
local min, max = 5, 110

function creatureSayCallback(cid, type, msg)
	if not npcHandler:isFocused(cid) then
		return false
	end

	local player = Player(cid)
	local talkUser = NPCHANDLER_CONVBEHAVIOR == CONVERSATION_DEFAULT and 0 or cid

	if talkState[cid] == nil or talkState[cid] == 0 then
		points = tonumber(msg)
		if points and points >= min and points <= max then
			npcHandler:say({PT="Você tem certeza que deseja gerar um papel de transferência para ".. points .." premium points? {yes}", EN="Are you sure you want to generate a transfer paper for ".. points .." premium points? {yes}"}, cid)
			talkState[cid] = points
		else
			npcHandler:say({PT="Você só pode adquirir um papel de transferência com o mínimo de ".. min .." e no máximo ".. max .." premium points.", EN="You can only acquire a transfer paper with a minimum of ".. min .." and a maximum of ".. max .." premium points."}, cid)
			talkState[cid] = 0
		end

	elseif talkState[cid] > 0 then
		if msg:lower() == "yes" then
			local points = talkState[cid]
			local paper = Game.createItem(ItemID, 1)
			if paper then
				paper:setAttribute(ITEM_ATTRIBUTE_NAME, "transferência de ".. points .." premium points")
				player:addItemEx(paper, true)
				npcHandler:say({PT="Aqui está seu papel para a transferência de ".. points .." premium points. Para utilizá-lo basta dar trade em seu comprador/vendedor.", EN="Here is your paper for the transfer of ".. points .." premium points. To use it just trade with your buyer/seller."}, cid)
			else
				npcHandler:say({PT="Erro ao criar o papel de transferência.", EN="Error creating transfer paper."}, cid)
			end
			talkState[cid] = 0
		else
			npcHandler:say({PT="Tudo bem então!", EN="Alright then!"}, cid)
			talkState[cid] = 0
		end
	end

	return true
end

npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
