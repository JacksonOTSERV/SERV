local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

npcHandler:setMessage(MESSAGE_GREET, {
    PT = "Olá |PLAYERNAME|. Você está pronto para o {rebornar}?",
    EN = "Hello |PLAYERNAME|. Are you ready to {reborn}?"
})
npcHandler:setMessage(MESSAGE_FAREWELL, {
    PT = "Adeus.",
    EN = "Goodbye."
})
npcHandler:setMessage(MESSAGE_WALKAWAY, {
    PT = "Adeus.",
    EN = "Goodbye."
})

function onCreatureAppear(cid)              npcHandler:onCreatureAppear(cid)            end
function onCreatureDisappear(cid)           npcHandler:onCreatureDisappear(cid)         end
function onCreatureSay(cid, type, msg)      npcHandler:onCreatureSay(cid, type, msg)    end
function onThink()                          npcHandler:onThink()                        end

local function doReborn(player)
    local levelAtual = player:getLevel()
    player:setStorageValue(4241, levelAtual)
    player:removeExperience(player:getExperience() - getExperienceForLevel(1))
    player:remove()
end

local talkState = {}
function creatureSayCallback(cid, type, msg)
    if not npcHandler:isFocused(cid) then
        return false
    end

    local player = Player(cid)
    local pid = player:getId()

    if msg:lower() == "rebornar" or msg:lower() == "reborn" then
        local levelAtual = player:getLevel()

        if player:getStorageValue(4241) > 0 then
            npcHandler:say({PT="Você já fez o REBORN e não pode fazer novamente.", EN="You have already done REBORN and cannot do it again."}, cid)
            return true
        end

        if levelAtual < 400 then
            npcHandler:say({PT="Você precisa ter pelo menos level 400 para fazer o REBORN.", EN="You need at least level 400 to do REBORN."}, cid)
            return true
        end

        local bonusPercent = (levelAtual / 600) * 25
        if bonusPercent > 25 then
            bonusPercent = 25
        end

        npcHandler:say({
            PT = string.format("Tem certeza que deseja fazer o REBORN? Isso vai resetar seu level para 1 e você receberá %.2f%% de EXP extra permanentemente. Diga {yes} para confirmar.", bonusPercent),
            EN = string.format("Are you sure you want to REBORN? This will reset your level to 1 and you will receive %.2f%% extra EXP permanently. Say {yes} to confirm.", bonusPercent)
        }, cid)

        talkState[pid] = 1

    elseif msg:lower() == "yes" and talkState[pid] == 1 then
        doReborn(player)
        talkState[pid] = 0
    end

    return true
end

npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
