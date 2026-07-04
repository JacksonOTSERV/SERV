function onUse(player, item, fromPosition, target, toPosition)
    local piece1pos = Position(160, 91, 8)
    local tempo = 1 * 60 * 1000 -- 1 minuto

    local tile = Tile(piece1pos)
    local getpiece1 = tile and tile:getItemById(13017)

    if item.uid == 60001 and item.itemid == 9825 and getpiece1 then
        getpiece1:remove()
        item:transform(9826)
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Uma nova passagem foi aberta!")
        addEvent(Game.createItem, tempo, 13017, 1, piece1pos)
    elseif item.uid == 60001 and item.itemid == 9826 then
        item:transform(9825)
    else
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Não é possível realizar esta ação.")
    end

    return true
end