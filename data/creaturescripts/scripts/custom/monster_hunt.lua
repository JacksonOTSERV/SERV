function onKill(creature, target)
    local player = creature:getPlayer()
    if not player or not target:isMonster() then
        return true
    end

    if MonsterHuntActive.active then
        local monsterName = target:getName()
        if monsterName:find("lvl.2") then
            local currentScore = player:getStorageValue(23281)
            if currentScore < 0 then
                currentScore = 0
            end
            player:setStorageValue(23281, currentScore + 1)
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Você recebeu +1 ponto por aniquilar um monstro lvl.2! Você tem agora: ".. player:getStorageValue(23281) .." pontos de aniquilação!")
        end
    end

    return true
end