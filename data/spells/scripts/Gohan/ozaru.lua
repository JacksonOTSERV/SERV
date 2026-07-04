local config = {
    duration_spell = 8,    -- tempo do buff em segundos
    looktype = 56,        -- looktype do buff
	reuse_delay = 45      -- tempo para reutilizar a spell em segundos
}

local function buff(creatureTwo, variant)
    local creature = Creature(creatureTwo)
    if creature then
		if getCreatureCondition(creature, CONDITION_ATTRIBUTES, 124) then
			local outfit = creature:getOutfit()
			outfit.lookType = creature:getStorageValue(14312)
			outfit.lookAura = creature:getStorageValue(STORAGE_BUFF)
			creature:setOutfit(outfit)
		end
    end
end

function onCastSpell(creature, cid, variant)
    if not creature or not creature:isPlayer() then
        return false
    end
	
    local currentTime = os.time()
    local lastCast = creature:getStorageValue(STORAGE_ESPECIAL1)

    if lastCast > currentTime then
        creature:sendCancelMessage("Você precisa esperar " .. (lastCast - currentTime) .. " segundos para usar este especial novamente.")
        return false
    end

    local condition = Condition(CONDITION_ATTRIBUTES)
    condition:setParameter(CONDITION_PARAM_SUBID, 135)
	condition:setParameter(CONDITION_PARAM_STAT_MAGICPOINTS, 100)
    condition:setParameter(CONDITION_PARAM_SKILL_SHIELD, 100)
    condition:setParameter(CONDITION_PARAM_SKILL_FIST, 100)
	condition:setParameter(CONDITION_PARAM_SKILL_FISHING, 100)
    condition:setParameter(CONDITION_PARAM_TICKS, config.duration_spell * 1000)

    local outfitCondition = Condition(CONDITION_OUTFIT)
    outfitCondition:setTicks(config.duration_spell * 1000)
    outfitCondition:setOutfit({lookType = config.looktype})

    creature:addCondition(outfitCondition)
    creature:addCondition(condition)

    if isCreature(creature) then
        doSendAnimatedText(creature:getPosition(), "+100 Ki Level", TEXTCOLOR_WHITE)
        doSendAnimatedText(creature:getPosition(), "+100 Attack S.", TEXTCOLOR_WHITE)
        doSendAnimatedText(creature:getPosition(), "+100 Defense", TEXTCOLOR_WHITE)
		doSendAnimatedText(creature:getPosition(), "+100 Critico", TEXTCOLOR_WHITE)
    end
	
	creature:setStorageValue(89201, config.duration_spell + os.time())
	addEvent(buff, config.duration_spell * 1000, creature:getId(), variant)
	creature:setStorageValue(STORAGE_ESPECIAL1, currentTime + config.reuse_delay)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Rage ozaru")
    end
    return true
end