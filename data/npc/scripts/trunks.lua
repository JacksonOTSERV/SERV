local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

npcHandler:setMessage(MESSAGE_GREET, {
    PT = "Olá |PLAYERNAME|. Eu posso trocar {radar}.",
    EN = "Hello |PLAYERNAME|. I can trade {radar}."
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

local talkState = {}

local items = {
    item1 = {12779, 12749},
}
local counts = {
    count1 = {100, 1},
}

function creatureSayCallback(cid, type, msg)
    local player = Player(cid)
    if not npcHandler:isFocused(cid) then
        return false
    end

    local talkUser = NPCHANDLER_CONVBEHAVIOR == CONVERSATION_DEFAULT and 0 or cid
    if msgcontains(msg, 'radar') then
        npcHandler:say({PT='Você deseja trocar ' .. counts.count1[1] .. ' ' .. ItemType(items.item1[1]):getName() .. ' por ' .. counts.count1[2] .. ' ' .. ItemType(items.item1[2]):getName() .. '?', EN='Do you want to trade ' .. counts.count1[1] .. ' ' .. ItemType(items.item1[1]):getName() .. ' for ' .. counts.count1[2] .. ' ' .. ItemType(items.item1[2]):getName() .. '?'}, cid)
        talkState[talkUser] = 1
    elseif talkState[talkUser] == 1 then
        if msgcontains(msg, 'yes') then
            if player:getItemCount(items.item1[1]) >= counts.count1[1] then
                player:removeItem(items.item1[1], counts.count1[1])
                player:addItem(items.item1[2], counts.count1[2])
                npcHandler:say({PT='Obrigado! Você acaba de trocar ' .. counts.count1[1] .. ' ' .. ItemType(items.item1[1]):getName() .. ' por ' .. counts.count1[2] .. ' ' .. ItemType(items.item1[2]):getName() .. '.', EN='Thank you! You just traded ' .. counts.count1[1] .. ' ' .. ItemType(items.item1[1]):getName() .. ' for ' .. counts.count1[2] .. ' ' .. ItemType(items.item1[2]):getName() .. '.'}, cid)
                talkState[talkUser] = 0
            else
                npcHandler:say({PT='Você precisa de ' .. counts.count1[1] .. ' ' .. ItemType(items.item1[1]):getName() .. '.', EN='You need ' .. counts.count1[1] .. ' ' .. ItemType(items.item1[1]):getName() .. '.'}, cid)
            end
        else
            npcHandler:say({PT='Tudo bem, se mudar de ideia me avise.', EN='Alright, if you change your mind let me know.'}, cid)
            talkState[talkUser] = 0
        end
    end
    return true
end

npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
