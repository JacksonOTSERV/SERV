function onStepIn(creature, item, position, fromPosition)
    if not creature:isPlayer() then
        return true
    end

    local player = creature
    local portalCost = 15000000

    if player:removeMoney(portalCost) then
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Você pagou 15000000 money para iniciar a Quest Reborn.")
    else
        player:sendTextMessage(MESSAGE_INFO_DESCR, "Você precisa de 15000000 money para iniciar a Quest Reborn")
        player:teleportTo(fromPosition, true)
    end

    return true
end