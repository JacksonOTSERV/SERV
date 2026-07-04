local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

npcHandler:setMessage(MESSAGE_GREET, {
    PT = "Olá |PLAYERNAME|. Posso lhe levar ao {Tropico}.",
    EN = "Hello |PLAYERNAME|. I can take you to {Tropico}."
})
npcHandler:setMessage(MESSAGE_FAREWELL, {
    PT = "Adeus.",
    EN = "Goodbye."
})
npcHandler:setMessage(MESSAGE_WALKAWAY, {
    PT = "Adeus.",
    EN = "Goodbye."
})

function onCreatureAppear(creature)     npcHandler:onCreatureAppear(creature) end
function onCreatureDisappear(creature)  npcHandler:onCreatureDisappear(creature) end
function onCreatureSay(creature, type, msg) npcHandler:onCreatureSay(creature, type, msg) end
function onThink()                      npcHandler:onThink() end

local function addTravelKeyword(keyword, label, position)
    local travel = keywordHandler:addKeyword({keyword}, StdModule.say, {
        npcHandler = npcHandler,
        onlyFocus = true,
        text = {PT='Você quer realmente se teletransportar para {' .. label .. '}?', EN='Do you really want to teleport to {' .. label .. '}?'}
    })
    travel:addChildKeyword({'yes'}, StdModule.travel, {
        npcHandler = npcHandler,
        onlyFocus = true,
        premium = false,
        level = 1,
		cost = 0,
        destination = position
    })
    travel:addChildKeyword({'no'}, StdModule.say, {
        npcHandler = npcHandler,
        onlyFocus = true,
        reset = true,
        text = {PT='Tudo bem, até mais!', EN='Alright, see you later!'}
    })
end

addTravelKeyword('tropico', 'Tropico', {x=675, y=247, z=7})
addTravelKeyword('dragon island', 'Dragon Island', {x=129, y=831, z=7})

keywordHandler:addKeyword({'travel'}, StdModule.say, {
    npcHandler = npcHandler,
    onlyFocus = true,
    text = {PT="Posso te teletransportar para: {Tropico} e {Dragon Island}.", EN="I can teleport you to: {Tropico} and {Dragon Island}."}
})

npcHandler:addModule(FocusModule:new())
