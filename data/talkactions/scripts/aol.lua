function onSay(player, words, param)
    local cooldownStorage = 55555

    if exhaustion.check(player, cooldownStorage) then
        if player:isPlayer() then
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "Você está em cooldown para utilizar esse comando.")
        end
        return false
    end

    exhaustion.set(player, cooldownStorage, 2)

    local receber1 = 12757

    if player:removeMoney(20000) then
        player:getPosition():sendMagicEffect(14)
        player:addItem(receber1, 1)
        player:say("Você comprou uma Band of Loss!", TALKTYPE_MONSTER_SAY, false, player)
    else
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "Você não possui 20000 money para adquirir esse item.")
    end

    return false
end
