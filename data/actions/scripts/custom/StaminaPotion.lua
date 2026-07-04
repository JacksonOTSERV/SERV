function onUse(player, item, fromPosition, target, toPosition, isHotkey)
    player:setStamina(2520)
	
	local position = player:getPosition()
    position.x = position.x + 1
	position.y = position.y + 1
    doSendMagicEffect(position, 54)

    player:say("Stamina Refilled!", TALKTYPE_MONSTER_SAY, false, player)
	
    item:remove(1)
    return true
end