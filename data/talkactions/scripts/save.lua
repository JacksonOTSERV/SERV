function onSay(player, words, param, channel)
	if not player:getGroup():getAccess() then
		return true
	end
	
    doSaveServer()
    Game.broadcastMessage('O servidor foi salvo.', MESSAGE_STATUS_WARNING)
    return false
end