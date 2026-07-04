local pvp_days = {
    ["Saturday"] = true,
    ["Sunday"] = true,
    ["Monday"] = true,
    ["Tuesday"] = true,
    ["Wednesday"] = true,
    ["Thursday"] = true,
    ["Friday"] = true, 
}

local function isPositionOccupied(position)
    local tile = Tile(position)
    if tile then
        for _, creature in ipairs(tile:getCreatures() or {}) do
            if creature:isPlayer() then
                return true
            end
        end
    end
    return false
end

local function getPlayersInArea(topLeft, bottomRight)
    local players = {}
    for x = topLeft.x, bottomRight.x do
        for y = topLeft.y, bottomRight.y do
            for z = 5, 7 do
                local tile = Tile(Position(x, y, z))
                if tile then
                    for _, creature in ipairs(tile:getCreatures() or {}) do
                        if creature:isPlayer() then
                            table.insert(players, creature)
                        end
                    end
                end
            end
        end
    end
    return players
end

local function pvpEvent()
    local currentDay = os.date("%A")
    if not pvp_days[currentDay] then
        return
    end

    local position = {x = 95, y = 186, z = 7}
    local npc = Game.createNpc("Torneio", position)
    local areaTopLeft = {x = 1163, y = 546, z = 7}
    local areaBottomRight = {x = 1254, y = 637, z = 7}
    local teleportPosition = Position(95, 187, 7)
    local MIN_PLAYERS = 2

    if isPositionOccupied(Position(95, 186, 7)) then
        for _, player in ipairs(getPlayersInArea({x = 94, y = 186, z = 7}, {x = 95, y = 186, z = 7})) do
            player:teleportTo(Position(95, 187, 7))
        end
    end
	
	local function isInArea(player)
		local pos = player:getPosition()
		return pos.x >= areaTopLeft.x and pos.x <= areaBottomRight.x and
			   pos.y >= areaTopLeft.y and pos.y <= areaBottomRight.y and
			   (pos.z == areaTopLeft.z or pos.z == 6 or pos.z == 5)
	end

    Game.broadcastMessage("[TORNEIO PvP] O npc de inscriùùo para o torneio PvP apareceu no templo de [EARTH] e irù permanecer por 5 minutos. Participe e seja o melhor para garantir seus presence points e ser um deus da destruiùùo!", MESSAGE_EVENT_ADVANCE)

        addEvent(function()
			local spectators = Game.getSpectators(position, false, false, 3, 3, 3, 3)
				for _, spec in ipairs(spectators) do
					if spec:isNpc() and spec:getName() == "Torneio [PvP]" then
					spec:remove()
				end
			end
            local playersInArea = getPlayersInArea({x = 1342, y = 594, z = 7}, {x = 1358, y = 609, z = 7})
            if #playersInArea < MIN_PLAYERS then
                for _, player in ipairs(playersInArea) do
                    setPresencePoints(player, 3)
                    Game.broadcastMessage("[TORNEIO PvP] Nùo havia jogadores suficientes. ".. player:getName() .." recebeu 3 presence points por esperar na sala.", MESSAGE_EVENT_ADVANCE)
                    player:teleportTo(Position(95, 187, 7))
                end
                return
            end
            Game.broadcastMessage("[TORNEIO PvP] As inscriùùes para o torneio PvP finalizaram. Boa sorte aos participantes!", MESSAGE_EVENT_ADVANCE)

            local areas = {
                {fromPos = {x = 1342, y = 594, z = 7}, toPos = {x = 1358, y = 609, z = 7}},
            }

            local teleportPositions = {
                {x = 1211, y = 568, z = 7}, {x = 1223, y = 598, z = 7},
                {x = 1186, y = 586, z = 7}, {x = 1211, y = 593, z = 7},
                {x = 1208, y = 587, z = 6}, {x = 1214, y = 581, z = 6},
                {x = 1194, y = 590, z = 6}, {x = 1229, y = 605, z = 6},
                {x = 1209, y = 582, z = 5}, {x = 1197, y = 570, z = 6},
                {x = 1225, y = 570, z = 6}
            }

            for _, area in ipairs(areas) do
                for x = area.fromPos.x, area.toPos.x do
                    for y = area.fromPos.y, area.toPos.y do
                        local tile = Tile(Position(x, y, area.fromPos.z))
                        if tile then
                            local creatures = tile:getCreatures() or {}
                            for _, creature in ipairs(creatures) do
                                if creature:isPlayer() then
                                    local randomPos = teleportPositions[math.random(#teleportPositions)]
                                    creature:teleportTo(Position(randomPos))
                                    creature:sendTextMessage(MESSAGE_STATUS_WARNING, "[TORNEIO PVP] O torneio PvP comeùou! Para vencer, vocù deve ser o ùltimo vivo na arena. O evento durarù 5 minutos.")
                                end
                            end
                        end
                    end
                end
            end

		addEvent(function()
			local playersInArena = getPlayersInArea(areaTopLeft, areaBottomRight)
			if #playersInArena > 1 then
				Game.broadcastMessage("[TORNEIO PvP] O evento terminou em empate pois apùs os 5 minutos ainda havia mais de um jogador vivo na arena.", MESSAGE_EVENT_ADVANCE)
				for _, player in ipairs(playersInArena) do
					player:teleportTo(teleportPosition)
				end
			end
		end, 5 * 60 * 1000)
	end, 5 * 60 * 1000)
end

function onTime(interval)
	pvpEvent()
	return true
end