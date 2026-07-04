function canJoin(player)
	return player:isLiveCaster()
end

function onSpeak(player, type, message)
	return false
end