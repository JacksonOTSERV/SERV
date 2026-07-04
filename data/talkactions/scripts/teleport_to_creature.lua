function onSay(player, words, param)
	if not player:getGroup():getAccess() then
		return true
	end

	if param == "" then
		player:sendCancelMessage("Use: /goto playerName | /goto x, y, z | /goto {x = 3191, y = 487, z = 5}")
		return false
	end

	-- formato de tabela {x = .., y = .., z = ..}: tenta PRIMEIRO (antes de Creature,
	-- senao "{x..." poderia ser interpretado como nome de creature)
	local tx = param:match("x%s*=%s*(%-?%d+)")
	local ty = param:match("y%s*=%s*(%-?%d+)")
	local tz = param:match("z%s*=%s*(%-?%d+)")
	if tx and ty and tz then
		local pos = Position(tonumber(tx), tonumber(ty), tonumber(tz))
		if Tile(pos) then
			player:getPosition():sendMagicEffect(CONST_ME_TELEPORT, player)
			player:teleportTo(pos)
			pos:sendMagicEffect(CONST_ME_TELEPORT)
		else
			player:sendCancelMessage("Posição inválida ou inacessível.")
		end
		return false
	end

	local target = Creature(param)
	if target then
		player:teleportTo(target:getPosition())
		player:getPosition():sendMagicEffect(CONST_ME_TELEPORT, player)
		return false
	end

	-- tenta ler coordenadas x, y, z
	local x, y, z = param:match("(%d+)[,%s]+(%d+)[,%s]+(%d+)")
	if x and y and z then
		local pos = Position(tonumber(x), tonumber(y), tonumber(z))
		if Tile(pos) then
			player:getPosition():sendMagicEffect(CONST_ME_TELEPORT, player)
			player:teleportTo(pos)
			pos:sendMagicEffect(CONST_ME_TELEPORT)
		else
			player:sendCancelMessage("Posição inválida ou inacessível.")
		end
	else
		player:sendCancelMessage("Creature ou coordenadas inválidas.")
	end
	return false
end
