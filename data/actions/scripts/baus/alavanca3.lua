function onUse(player, item, fromPosition, target, toPosition)
	local piece1pos = Position(418, 80, 14)
	local piece2pos = Position(418, 81, 14)
	local piece3pos = Position(418, 82, 14)

	local piece1 = Tile(piece1pos):getTopDownItem()
	local piece2 = Tile(piece2pos):getTopDownItem()
	local piece3 = Tile(piece3pos):getTopDownItem()

	if item.uid == 60095 and item.itemid == 1945 and piece1 and piece1.itemid == 13017 then
		if piece1 then piece1:remove(1) end
		if piece2 then piece2:remove(1) end
		if piece3 then piece3:remove(1) end
		item:transform(1946)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Uma nova passagem foi aberta!")
	elseif item.uid == 60095 and item.itemid == 1946 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Não é possível realizar esta ação.")
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Não é possível realizar esta ação.")
	end
	return true
end