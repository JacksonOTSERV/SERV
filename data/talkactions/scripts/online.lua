function onSay(player, words, param)
	local players = Game.getPlayers()
	local onlineList = {}

	for _, targetPlayer in ipairs(players) do
		table.insert(onlineList, ("%s [%d]"):format(targetPlayer:getName(), targetPlayer:getLevel()))
	end

	local playersOnline = #onlineList + 30
	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE,
		("Atualmente existem %d jogadores online."):format(playersOnline)
	)
	return false
end