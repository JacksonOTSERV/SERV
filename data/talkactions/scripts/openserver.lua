function onSay(player, words, param)
	if not player:getGroup():getAccess() then
		return true
	end
	Game.setGameState(GAME_STATE_NORMAL)
	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Server is now open.")
	return false
end
