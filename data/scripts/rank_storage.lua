local creatureEvent = CreatureEvent("npcRankModal")
function creatureEvent.onModalWindow(player, modalId, buttonId, choiceId)
    if modalId ~= RankModalId then
        return true
    end
    return true
end
creatureEvent:register()

local loginEvent = CreatureEvent("npcRankRegister")
function loginEvent.onLogin(player)
    player:registerEvent("npcRankModal")
    return true
end
loginEvent:register()