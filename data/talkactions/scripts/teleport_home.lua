function onSay(player, words, param)
	if not player:getGroup():getAccess() then
		return true
	end

	-- Se não tiver parâmetro, mostra a lista de towns
	if param == "" then
		local townList = {}
		for _, town in ipairs(Game.getTowns()) do
			table.insert(townList, string.format("%s (ID: %d)", town:getName(), town:getId()))
		end
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Towns disponíveis:\n" .. table.concat(townList, "\n"))
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Use: " .. words .. " [town] - para se teleportar")
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Use: " .. words .. " [jogador], [town] - para teleportar outro jogador")
		return false
	end

	local split = param:split(",")
	local target = player
	local townParam = param
	
	-- Se tiver vírgula, está teleportando outro jogador
	if #split >= 2 then
		local targetName = split[1]:trim()
		townParam = split[2]:trim()
		
		target = Player(targetName)
		if not target then
			player:sendCancelMessage("Jogador '" .. targetName .. "' não encontrado.")
			return false
		end
	end

	-- Busca a town por nome ou ID
	local town = nil
	local townId = tonumber(townParam)
	
	if townId then
		town = Town(townId)
	else
		for _, t in ipairs(Game.getTowns()) do
			if t:getName():lower() == townParam:lower() then
				town = t
				break
			end
		end
	end

	if not town then
		player:sendCancelMessage("Town '" .. townParam .. "' não encontrada.")
		return false
	end

	-- Teleporta
	target:getPosition():sendMagicEffect(CONST_ME_POFF)
	target:teleportTo(town:getTemplePosition())
	target:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
	
	if target == player then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Você foi teletransportado para " .. town:getName() .. ".")
	else
		target:sendCancelMessage("Você foi teletransportado para " .. town:getName() .. ".")
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, target:getName() .. " foi teletransportado para " .. town:getName() .. ".")
	end

	return false
end