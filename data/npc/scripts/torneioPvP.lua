local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

function onCreatureAppear(creature) npcHandler:onCreatureAppear(creature) end
function onCreatureDisappear(creature) npcHandler:onCreatureDisappear(creature) end
function onCreatureSay(creature, type, msg) npcHandler:onCreatureSay(creature, type, msg:lower()) end
function onThink() npcHandler:onThink() end

keywordHandler:addKeyword({'torneio'}, function(cid)
    local player = Player(cid)
    if not player then return false end
    buildTournamentModal():sendToPlayer(player)
    return true
end)

npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())