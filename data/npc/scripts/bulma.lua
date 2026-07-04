local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

npcHandler:setMessage(MESSAGE_GREET, {
    PT = "Olá |PLAYERNAME|. Estou procurando as Esferas do Dragão.",
    EN = "Hello |PLAYERNAME|. I am looking for the Dragon Balls."
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

local talkState = {}

local dragonBalls = {
	12750, 12751, 12752, 12753, 12754, 12755, 12756
}

function creatureSayCallback(cid, type, msg)
	local player = Player(cid)
	if not npcHandler:isFocused(cid) then
		return false
	end

	local talkUser = 1

	if msg:find("entregar") or msg:find("deliver") or msg:find("give") then
		npcHandler:say({PT="Você encontrou as Esferas do Dragão? Deseja me entregar agora? {yes}", EN="Have you found the Dragon Balls? Do you want to give them to me now? {yes}"}, cid)
		talkState[talkUser] = 1

	elseif msg:find("yes") and talkState[talkUser] == 1 then
		local hasAll = true
		for _, itemId in ipairs(dragonBalls) do
			if player:getItemCount(itemId) < 1 then
				hasAll = false
				break
			end
		end

		if hasAll then
			for _, itemId in ipairs(dragonBalls) do
				player:removeItem(itemId, 1)
			end
			player:setStorageValue(43234, 1)
			npcHandler:say({PT="Obrigada, agora você tem 15% de exp extra.", EN="Thank you, now you have 15% extra exp."}, cid)
		else
			npcHandler:say({PT="Desculpe, você precisa de todas as esferas.", EN="Sorry, you need all the spheres."}, cid)
		end
		talkState[talkUser] = 0
	end

	return true
end

npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
