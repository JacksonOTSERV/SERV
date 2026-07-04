function onSay(player, words, param)
	if not player:getGroup():getAccess() then
		return true
	end
	
	local position = player:getPosition()
	local isGhost = not player:isInGhostMode()

	player:setGhostMode(isGhost)
	if isGhost then
		player:sendTextMessage(MESSAGE_INFO_DESCR, "Agora você está invisível.")
	else
		player:sendTextMessage(MESSAGE_INFO_DESCR, "Agora você está visível.")
	end
	return false
end
