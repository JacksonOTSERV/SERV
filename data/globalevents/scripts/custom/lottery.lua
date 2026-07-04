local rewards = {
	{8300, 1},
	{13575, 1},
	{12289, 1},
	{13599, 5},
	{5920, 1},
}

function onThink(interval)
	local players = Game.getPlayers()
	
	if #players > 0 and #rewards > 0 then
		local uid, n = math.random(1, #players), math.random(1, #rewards)
		local ganhador = players[uid]
		local reward, count = rewards[n][1], rewards[n][2]
		
		if ganhador and reward and count then
			ganhador:addItem(reward, count)
			local itemName = ItemType(reward):getName() or "item desconhecido"
			Game.broadcastMessage('[LOTTERY SYSTEM] Ganhador: '.. ganhador:getName() ..', Recompensa: '.. count ..'x '.. itemName ..'. Parab�ns! (Pr�xima loteria em 1 hora)', MESSAGE_STATUS_WARNING)
		end
	end
	
	return true
end