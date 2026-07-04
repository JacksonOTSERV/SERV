local keywordHandler = KeywordHandler:new()
local npcHandler     = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

function onCreatureAppear(cid)             npcHandler:onCreatureAppear(cid)            end
function onCreatureDisappear(cid)          npcHandler:onCreatureDisappear(cid)         end
function onCreatureSay(cid, type, msg)     npcHandler:onCreatureSay(cid, type, msg)    end
function onThink()                         npcHandler:onThink()                        end

local TELEPORT_POS = Position(99, 188, 7)

local function greetCallback(cid)
    local player = Player(cid)
    if not player then
        return false
    end

    player:teleportTo(TELEPORT_POS)
    player:getPosition():sendMagicEffect(CONST_ME_TELEPORT, player)

    npcHandler:say({PT="Adeus!", EN="Goodbye!"}, cid)

    return false
end

npcHandler:setCallback(CALLBACK_GREET, greetCallback)
npcHandler:addModule(FocusModule:new())
