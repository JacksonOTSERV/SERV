local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

npcHandler:setMessage(MESSAGE_GREET, {
    PT = "Olá |PLAYERNAME|. Você encontrou meu item?",
    EN = "Hello |PLAYERNAME|. Have you found my item?"
})
npcHandler:setMessage(MESSAGE_FAREWELL, {
    PT = "Adeus.",
    EN = "Goodbye."
})
npcHandler:setMessage(MESSAGE_WALKAWAY, {
    PT = "Adeus.",
    EN = "Goodbye."
})

function onCreatureAppear(creature) npcHandler:onCreatureAppear(creature) end
function onCreatureDisappear(creature) npcHandler:onCreatureDisappear(creature) end
function onCreatureSay(creature, type, msg) npcHandler:onCreatureSay(creature, type, msg:lower()) end
function onThink() npcHandler:onThink() end

function creatureSayCallback(cid, type, msg)
	local player = Player(cid)
	if not npcHandler:isFocused(cid) then
		return false
	end

	if msgcontains(msg, "yes") then
		if player:getItemCount(13100) >= 1 then
			player:removeItem(13100, 1)
			player:addItem(13391, 1)
			npcHandler:say({PT="Aaah! Você já encontrou! Muito obrigado. Aceite este meu humilde presente como recompensa.", EN="Ah! You found it! Thank you very much. Accept this humble gift as a reward."}, cid)
		else
			npcHandler:say({PT="Certo, quando encontrar me avise então por favor.", EN="Right, please let me know when you find it."}, cid)
		end
	end

	return true
end

npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
