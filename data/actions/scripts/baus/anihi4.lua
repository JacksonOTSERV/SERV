local questLevel = 150
local storage = 6026

function onUse(player, item, fromPosition, target, toPosition)
	if item.uid ~= 60099 or item.itemid ~= 1945 then
		return false
	end

	local playerPositions = {
		Position(162, 309, 8),
		Position(162, 308, 8),
		Position(162, 307, 8),
		Position(162, 306, 8)
	}

	local players = {}

	for _, pos in ipairs(playerPositions) do
		local tile = Tile(pos)
		if tile then
			local topCreature = tile:getTopCreature()
			if topCreature and topCreature:isPlayer() then
				table.insert(players, topCreature)
			end
		end
	end

	if #players == 0 then
		player:sendCancelMessage("At least one player must be on the correct positions.")
		return true
	elseif #players > 4 then
		player:sendCancelMessage("Maximum of 4 players allowed.")
		return true
	end

	for _, p in ipairs(players) do
		if p:getLevel() < questLevel or p:getStorageValue(storage) ~= -1 then
			player:sendCancelMessage("All players must be level " .. questLevel .. " and not have completed the quest.")
			return true
		end
	end

	local teleportPositions = {
		Position(192, 354, 8),
		Position(191, 354, 8),
		Position(190, 354, 8),
		Position(189, 354, 8)
	}

	for i, p in ipairs(players) do
		playerPositions[i]:sendMagicEffect(CONST_ME_POFF)
		p:teleportTo(teleportPositions[i])
		teleportPositions[i]:sendMagicEffect(CONST_ME_TELEPORT)
	end

	item:transform(item.itemid)

	return true
end
