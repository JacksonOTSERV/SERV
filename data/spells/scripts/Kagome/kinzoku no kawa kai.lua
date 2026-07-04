function onCastSpell(player, var)
    if not player:hasCondition(CONDITION_MANASHIELD) then
        player:sendCancelMessage("Você precisa estar com o Ki Shield ativo para usar esta tecnica.")
        return false
    end

    player:removeCondition(CONDITION_MANASHIELD)
	
    if isCreature(player) then
        doSendAnimatedText(player:getPosition(), "Ki shield kai", TEXTCOLOR_WHITE)
    end
	
    if player and player:isPlayer() then
		if getCreatureCondition(player, CONDITION_ATTRIBUTES, 124) then
			local outfit = player:getOutfit()
			outfit.lookAura = player:getStorageValue(STORAGE_BUFF)
			player:setOutfit(outfit)
		else
			local outfit = player:getOutfit()
			outfit.lookAura = 0
			player:setOutfit(outfit)
		end
    end
    return true
end