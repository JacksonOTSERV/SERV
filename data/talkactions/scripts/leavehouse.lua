function onSay(player, words, param)
    local position = player:getPosition()
    local tile = Tile(position)
    local house = tile and tile:getHouse()
    if not house then
        player:sendCancelMessage("You are not inside a house.")
        position:sendMagicEffect(CONST_ME_POFF)
        return false
    end

    if house:getOwnerGuid() ~= player:getGuid() then
		player:sendTextMessage(MESSAGE_INFO_DESCR, "Você não é o dono da house.")
        position:sendMagicEffect(CONST_ME_POFF)
        return false
    end

    local houseTiles = house:getTiles()
    for _, hTile in ipairs(houseTiles) do
        local thingCount = hTile:getThingCount()
        for i = 1, thingCount do
            local thing = hTile:getThing(i)
            if thing and thing:isItem() then
                local itemType = thing:getType()
                if itemType and itemType:isMovable() then
					player:sendTextMessage(MESSAGE_INFO_DESCR, "Você precisa remover todos os itens da house antes de deixa-la.")
                    return false
                end
            end
        end
    end
	
    local exitPos = house:getExitPosition()
    for _, hTile in ipairs(houseTiles) do
        local thingCount = hTile:getThingCount()
        for i = 1, thingCount do
            local thing = hTile:getThing(i)
            if thing and thing:isCreature() then
                local target = thing:getPlayer()
                if target then
                    target:teleportTo(exitPos, true)
                    exitPos:sendMagicEffect(CONST_ME_POFF)
                end
            end
        end
    end

    house:setOwnerGuid(0)
	player:sendTextMessage(MESSAGE_INFO_DESCR, "Você agora não é mais dono da house.")
    return false
end