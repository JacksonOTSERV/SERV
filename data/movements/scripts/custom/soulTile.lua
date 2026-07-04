local config = {
	delay = 60,
}

SOUL_EVENTS = {}

local function rechargeSoul(playerGUID)
	local player = Creature(playerGUID)
	if not player then return end
	doSendAnimatedText(getCreaturePosition(player), "+1 soul", TEXTCOLOR_PURPLE)
	doPlayerAddSoul(player, 1)
	local playerPos = player:getPosition()
	local effectPos = {x = playerPos.x + 1, y = playerPos.y + 1, z = playerPos.z}
	doSendMagicEffect(effectPos, 55)
	SOUL_EVENTS[playerGUID] = addEvent(rechargeSoul, config.delay * 1000, playerGUID)
end

function onStepOut(creature, item, position, fromPosition)
	local item = getTileItemById(getPlayerPosition(creature), 448).actionid
	if item == 12310 then 
	else
		stopEvent(SOUL_EVENTS[creature:getId()])
		SOUL_EVENTS[creature:getId()] = nil
		creature:setStorageValue(3331, 0)
	end
	return true
end

function onStepIn(creature, item, position, fromPosition)
    if not creature:isPlayer() then
        return false
    end
	
	if creature:getStorageValue(3331) < 1 then
		creature:teleportTo(fromPosition)
		creature:sendCancelMessage("Você precisa adquirir um ticket com o Soul Trader para adentrar no treinamento de souls.")
		return false
	end
    
    if not SOUL_EVENTS[creature:getId()] then
        SOUL_EVENTS[creature:getId()] = addEvent(rechargeSoul, config.delay * 1000, creature:getId())
    end
    
    return true
end