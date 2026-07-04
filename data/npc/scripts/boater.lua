local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

npcHandler:setMessage(MESSAGE_GREET, {
    PT = "Olá |PLAYERNAME|. Eu vendo o {ticket} de viagem.",
    EN = "Hello |PLAYERNAME|. I sell the travel {ticket}."
})
npcHandler:setMessage(MESSAGE_FAREWELL, {
    PT = "Adeus.",
    EN = "Goodbye."
})
npcHandler:setMessage(MESSAGE_WALKAWAY, {
    PT = "Adeus.",
    EN = "Goodbye."
})

function onCreatureAppear(cid)             npcHandler:onCreatureAppear(cid) end
function onCreatureDisappear(cid)          npcHandler:onCreatureDisappear(cid) end
function onCreatureSay(cid, type, msg)     npcHandler:onCreatureSay(cid, type, msg) end
function onThink()                         npcHandler:onThink() end

local itemId = 13215 -- ID do item necessário (Ticket)
local itemCount = 1  -- Quantidade necessária
local storageKey = 4150

local talkState = {}

local function creatureSayCallback(cid, type, msg)
	local player = Player(cid)
	if not npcHandler:isFocused(cid) then
		return false
	end

	local talkUser = 1

	if msg:lower():find("ticket") then
		npcHandler:say({PT="Ao me dar um Ticket você obterá a passagem. Tem certeza disso?", EN="Give me a Ticket and you will get the pass. Are you sure?"}, cid)
		talkState[talkUser] = 1

	elseif talkState[talkUser] == 1 then
		if msg:lower():find("yes") then
			if player:getItemCount(itemId) >= itemCount then
				player:removeItem(itemId, itemCount)
				player:setStorageValue(storageKey, 1)
				npcHandler:say({PT="Você acaba de obter a passagem gratuita com o meu amigo Dederin.", EN="You have just obtained the free pass with my friend Dederin."}, cid)
			else
				npcHandler:say({PT="Você precisa de um Ticket.", EN="You need a Ticket."}, cid)
			end
			talkState[talkUser] = 0
		else
			npcHandler:say({PT="Tudo bem.", EN="Alright."}, cid)
			talkState[talkUser] = 0
		end
	end
	return true
end

npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
