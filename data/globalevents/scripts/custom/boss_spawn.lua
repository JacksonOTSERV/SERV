local bossesConfig = {
	{ name = "Shenlong", 
	  spawnPos = Position(91, 188, 7), 
	  fromPos = Position(29, 81, 7), 
	  toPos = Position(149, 209, 7) 
	},
}

local currentBossIndex = 1

local function isBossAliveInArea(bossName, fromPos, toPos)
	for x = fromPos.x, toPos.x do
		for y = fromPos.y, toPos.y do
			local tile = Tile(Position(x, y, fromPos.z))
			if tile then
				for _, thing in ipairs(tile:getCreatures() or {}) do
					if thing:isMonster() and thing:getName():lower() == bossName:lower() then
						return true
					end
				end
			end
		end
	end
	return false
end

local function spawnBoss()
	local boss = bossesConfig[currentBossIndex]
	if not boss then
		currentBossIndex = 1
		return
	end

	if not isBossAliveInArea(boss.name, boss.fromPos, boss.toPos) then
		Game.createMonster(boss.name, boss.spawnPos)
		for _, player in ipairs(Game.getPlayers()) do
			player:sendChannelMessage("", "[SHENLONG INVADER] O ".. boss.name .." estù invadindo earth! derrote-o para garantir: 5 leveis (fixo), 1 presence point (fixo) e 1x Shenlong Scale sendo o TOP1 damage.", TALKTYPE_CHANNEL_O, 8)
		end

		currentBossIndex = currentBossIndex + 1
		if currentBossIndex > #bossesConfig then
			currentBossIndex = 1
		end
	else
		for _, player in ipairs(Game.getPlayers()) do
			player:sendChannelMessage("", "[SHENLONG INVADER] O ".. boss.name .." jù estù sob invasùo em earth e nùo ù possùvel surgir outro. Derrote o existente!", TALKTYPE_CHANNEL_O, 8)
		end
	end
end

function onTime(interval)
	spawnBoss()
	return true
end