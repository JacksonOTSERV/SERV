local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

function onCreatureAppear(cid)              npcHandler:onCreatureAppear(cid)            end
function onCreatureDisappear(cid)           npcHandler:onCreatureDisappear(cid)         end
function onCreatureSay(cid, type, msg)      npcHandler:onCreatureSay(cid, type, msg)    end
function onThink()                          npcHandler:onThink()                        end

local blessCost = 200000
local blessCount = 5

local function playerHasAllBlessings(player)
    for i = 1, blessCount do
        if not player:hasBlessing(i) then
            return false
        end
    end
    return true
end

local function blessPlayer(player)
    for i = 1, blessCount do
        player:addBlessing(i)
    end
    player:getPosition():sendMagicEffect(14)
    player:say("[BLESS]", TALKTYPE_MONSTER_SAY)
end

local node = keywordHandler:addKeyword({'bless'}, StdModule.say, {npcHandler = npcHandler, onlyFocus = true, text = {PT='Deseja comprar a bless por 200,000 gold? {yes}', EN='Do you want to buy the blessing for 200,000 gold? {yes}'}})
node:addChildKeyword({'yes'}, function(cid)
    local player = Player(cid)
    if not player then
        return false
    end

    if playerHasAllBlessings(player) then
        npcHandler:say({PT="Você já possui a bless.", EN="You already have the blessing."}, cid)
        return true
    end

    if player:removeMoney(blessCost) then
        blessPlayer(player)
        npcHandler:say({PT="Você agora possui a bless.", EN="You now have the blessing."}, cid)
    else
        npcHandler:say({PT="Você não possui 200000 money para comprar a bless.", EN="You do not have 200,000 money to buy the blessing."}, cid)
    end
    return true
end, {})
node:addChildKeyword({'no'}, StdModule.say, {npcHandler = npcHandler, onlyFocus = true, reset = true, text = {PT='Talvez outra hora.', EN='Maybe another time.'}})

npcHandler:addModule(FocusModule:new())
