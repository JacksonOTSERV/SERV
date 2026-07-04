local STORAGE = 4150
local travelDestinations = {
	["small city"] = {pos = {x=107, y=200, z=7}, state = 1},
	["namek island"] = {pos = {x=461, y=447, z=5}, state = 2},
	["big city"] = {pos = {x=117, y=102, z=7}, state = 3},
	["ice city"] = {pos = {x=315, y=179, z=7}, state = 4},
	["frozen city"] = {pos = {x=477, y=643, z=7}, state = 5},
	["west island"] = {pos = {x=83, y=39, z=7}, state = 6},
	["east island"] = {pos = {x=111, y=39, z=7}, state = 7},
	["broken city"] = {pos = {x=99, y=343, z=7}, state = 8},
	["assassin tower"] = {pos = {x=254, y=393, z=7}, state = 9},
}

local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

npcHandler:setMessage(MESSAGE_GREET, {
    PT = "Olá |PLAYERNAME|. Eu controlo as viagens especiais. Diga {travel}.",
    EN = "Hello |PLAYERNAME|. I control the special travels. Say {travel}."
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

function creatureSayCallback(cid, type, msg)
	local player = Player(cid)
	if not npcHandler:isFocused(cid) then
		return false
	end

	local talkUser = 1
	msg = msg:lower()

	if msg:find("travel") then
		npcHandler:say({PT="Eu posso te levar para {Small City}, {Namek Island}, {Big City}, {Ice City}, {Frozen City}, {West Island}, {East Island}, {Broken City}, {Assassin Tower}.", EN="I can take you to {Small City}, {Namek Island}, {Big City}, {Ice City}, {Frozen City}, {West Island}, {East Island}, {Broken City}, {Assassin Tower}."}, cid)
		return true
	end

	for cityName, data in pairs(travelDestinations) do
		if msg:find(cityName) then
			npcHandler:say({PT="Você realmente quer viajar para {" .. cityName:gsub("^%l", string.upper) .. "}?", EN="Do you really want to travel to {" .. cityName:gsub("^%l", string.upper) .. "}?"}, cid)
			talkState[talkUser] = data.state
			return true
		end
	end

	if msg == "yes" then
		for cityName, data in pairs(travelDestinations) do
			if talkState[talkUser] == data.state then
				if player:getStorageValue(STORAGE) == 1 then
					if not player:isPzLocked() then
						local fromPos = player:getPosition()
						player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
						player:teleportTo(Position(data.pos))
						Position(data.pos):sendMagicEffect(CONST_ME_TELEPORT)
						npcHandler:releaseFocus(cid)
					else
						npcHandler:say({PT="Você deve estar sem PZ locked!", EN="You must not be PZ locked!"}, cid)
					end
				else
					npcHandler:say({PT="Desculpe, você não possui passagem!", EN="Sorry, you do not have a pass!"}, cid)
				end
				talkState[talkUser] = 0
				return true
			end
		end
	end

	return true
end

npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
