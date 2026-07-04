function onSay(player, words, param)
	if not player:getGroup():getAccess() then
		return true
	end

	local position = player:getPosition()
	local npc = Game.createNpc(param, position)
	if npc then
		npc:setMasterPos(position)
	else
		player:sendCancelMessage("There is not enough room.")
	end
	return false
end
