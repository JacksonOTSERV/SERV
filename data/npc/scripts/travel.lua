local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

npcHandler:setMessage(MESSAGE_GREET, {
    PT = "Olá |PLAYERNAME|. Posso te levar para vários lugares. Diga {travel}.",
    EN = "Hello |PLAYERNAME|. I can take you to many places. Say {travel}."
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

local function travelWithBattleCheck(cid, message, keywords, parameters, node)
    local player = Player(cid)
    if not player then
        return false
    end

    if player:isPzLocked() then
        return true
    end

    player:teleportTo(parameters.destination)
    player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
    return true
end

local function addTravelKeyword(keyword, label, position)
    local travel = keywordHandler:addKeyword({keyword}, StdModule.say, {
        npcHandler = npcHandler,
        onlyFocus = true,
        text = {PT='Você quer realmente se teletransportar para {' .. label .. '}?', EN='Do you really want to teleport to {' .. label .. '}?'}
    })
    travel:addChildKeyword({'yes'}, travelWithBattleCheck, {
        npcHandler = npcHandler,
        onlyFocus = true,
        destination = position
    })
    travel:addChildKeyword({'no'}, StdModule.say, {
        npcHandler = npcHandler,
        onlyFocus = true,
        reset = true,
        text = {PT='Tudo bem, até mais!', EN='Alright, see you later!'}
    })
end

addTravelKeyword('earth', 'Earth', {x = 106, y = 149, z = 10})
addTravelKeyword('sand city', 'Sand City', {x = 288, y = 935, z = 8})
addTravelKeyword('m2', 'M2', {x = 78, y = 514, z = 8})
addTravelKeyword('tsufur', 'Tsufur', {x = 105, y = 489, z = 8})
addTravelKeyword('zelta', 'Zelta', {x = 105, y = 515, z = 8})
addTravelKeyword('vegeta', 'Vegeta', {x = 141, y = 489, z = 8})
addTravelKeyword('namek', 'Namek', {x = 141, y = 515, z = 8})
addTravelKeyword('lude', 'Lude', {x = 191, y = 498, z = 8})
addTravelKeyword('premia', 'Premia', {x = 191, y = 524, z = 8})
addTravelKeyword("boar's island", "Boar's Island", {x = 75, y = 488, z = 8})
addTravelKeyword("ruudo", "Ruudo", {x = 103, y = 547, z = 8})
addTravelKeyword("city 17", "City 17", {x = 800, y = 1133, z = 8})
addTravelKeyword("gardia", "Gardia", {x = 48, y = 1274, z = 8})

keywordHandler:addKeyword({'travel'}, StdModule.say, {
    npcHandler = npcHandler,
    onlyFocus = true,
    text = {PT="Posso te teletransportar para: {Earth}, {Sand City}, {M2}, {Tsufur}, {Zelta}, {Vegeta}, {Namek}, {Lude}, {Premia}, {Boar's Island}, {Ruudo}, {City 17} e {Gardia}.", EN="I can teleport you to: {Earth}, {Sand City}, {M2}, {Tsufur}, {Zelta}, {Vegeta}, {Namek}, {Lude}, {Premia}, {Boar's Island}, {Ruudo}, {City 17} and {Gardia}."}
})

npcHandler:addModule(FocusModule:new())
