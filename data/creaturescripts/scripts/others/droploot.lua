local blessCount = 5

local function playerHasAllBlessings(player)
    for i = 1, blessCount do
        if not player:hasBlessing(i) then
            return false
        end
    end
    return true
end

function onDeath(player, corpse, killer, mostDamage, unjustified, mostDamage_unjustified)
	if player:hasFlag(PlayerFlag_NotGenerateLoot) or player:getVocation():getId() == VOCATION_NONE then
		return true
	end

	local ring = player:getSlotItem(CONST_SLOT_RING)
	local isRedSkull = player:getSkull() == SKULL_RED
	local isBlackSkull = player:getSkull() == SKULL_BLACK
	local forceDropAll = isRedSkull

	if player:getLevel() < 150 and not forceDropAll then
		return true
	end

	if not forceDropAll and ring and (ring.itemid == 12757 or ring.itemid == 12758) then
		ring:remove()
		return true
	end

	if not forceDropAll and playerHasAllBlessings(player) then
		return true
	end

	for slot = CONST_SLOT_HEAD, CONST_SLOT_AMMO do
		local item = player:getSlotItem(slot)
		if item then
			if forceDropAll or math.random(item:isContainer() and 100 or 1000) <= player:getLossPercent() then
				if not item:moveTo(corpse) then
					item:remove()
				end
			end
		end
	end

	if not player:getSlotItem(CONST_SLOT_BACKPACK) then
		player:addItem(ITEM_BAG, 1, false, CONST_SLOT_BACKPACK)
	end

	return true
end