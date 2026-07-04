local keywordHandler = KeywordHandler:new()
local npcHandler     = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

function onCreatureAppear(cid)             npcHandler:onCreatureAppear(cid)            end
function onCreatureDisappear(cid)          npcHandler:onCreatureDisappear(cid)         end
function onCreatureSay(cid, type, msg)     npcHandler:onCreatureSay(cid, type, msg)    end
function onThink()                         npcHandler:onThink()                        end

local TELEPORT_POS = Position(655, 401, 7)

local AREA_FROM = Position(89, 182, 7)
local AREA_TO   = Position(93, 186, 7)

local function isPlayerInArea(player)
    local pos = player:getPosition()
    return pos.x >= AREA_FROM.x and pos.x <= AREA_TO.x
       and pos.y >= AREA_FROM.y and pos.y <= AREA_TO.y
       and pos.z == AREA_FROM.z
end

local function greetCallback(cid)
    local player = Player(cid)
    if not player then return false end

    if player:isPzLocked() then return true end

    if not isPlayerInArea(player) then
        return false
    end

    player:teleportTo(TELEPORT_POS)
    player:getPosition():sendMagicEffect(CONST_ME_TELEPORT, player)

    npcHandler:say({PT="Adeus!", EN="Goodbye!"}, cid)
    return false
end

npcHandler:setCallback(CALLBACK_GREET, greetCallback)
npcHandler:addModule(FocusModule:new())
