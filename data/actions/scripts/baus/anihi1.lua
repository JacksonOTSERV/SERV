local questLevel = 150
local storage = 6026

function onUse(player, item, fromPosition, target, toPosition)
	if item.uid ~= 60096 then
		return false
	end

	if item.itemid ~= 1945 then
		return false
	end

	local playerPositions = {
		Position(155, 302, 8),
		Position(156, 302, 8),
		Position(157, 302, 8),
		Position(158, 302, 8)
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

	local newPositions = {
		Position(227, 354, 8),
		Position(226, 354, 8),
		Position(225, 354, 8),
		Position(224, 354, 8)
	}

	for i, p in ipairs(players) do
		p:getPosition():sendMagicEffect(CONST_ME_POFF)
		p:teleportTo(newPositions[i])
		newPositions[i]:sendMagicEffect(CONST_ME_TELEPORT)
	end

	item:transform(item.itemid)
	return true
end
