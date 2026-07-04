local config = {
    duration_spell = 8,    -- tempo do buff em segundos
    looktype = 729,        -- looktype do buff
    healthRegen = 15000,   -- health gain por segundo no buff
	reuse_delay = 45      -- tempo para reutilizar a spell em segundos
}

local regen = Condition(CONDITION_REGENERATION)
regen:setParameter(CONDITION_PARAM_SUBID, 134)
regen:setParameter(CONDITION_PARAM_TICKS, config.duration_spell * 1000)
regen:setParameter(CONDITION_PARAM_HEALTHGAIN, config.healthRegen)
regen:setParameter(CONDITION_PARAM_HEALTHTICKS, 1000)

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
    condition:setParameter(CONDITION_PARAM_SKILL_SHIELD, 80)
    condition:setParameter(CONDITION_PARAM_SKILL_FIST, 80)
	condition:setParameter(CONDITION_PARAM_SKILL_FISHING, 80)
    condition:setParameter(CONDITION_PARAM_TICKS, config.duration_spell * 1000)

    local outfitCondition = Condition(CONDITION_OUTFIT)
    outfitCondition:setTicks(config.duration_spell * 1000)
    outfitCondition:setOutfit({lookType = config.looktype})

    creature:addCondition(outfitCondition)
    creature:addCondition(regen)
    creature:addCondition(condition)
	
    local speed = Condition(CONDITION_PARALYZE)
    speed:setParameter(CONDITION_PARAM_TICKS, config.duration_spell * 1000)
    speed:setParameter(CONDITION_PARAM_SPEED, 5000)

    creature:addCondition(speed)

    if isCreature(creature) then
        doSendAnimatedText(creature:getPosition(), "+5000 Speed", TEXTCOLOR_WHITE)
        doSendAnimatedText(creature:getPosition(), "+80 Attack S.", TEXTCOLOR_WHITE)
        doSendAnimatedText(creature:getPosition(), "+80 Defense", TEXTCOLOR_WHITE)
		doSendAnimatedText(creature:getPosition(), "+80 Critico", TEXTCOLOR_WHITE)
    end
	
	creature:setStorageValue(89201, config.duration_spell + os.time())
    addEvent(buff, config.duration_spell * 1000, creature:getId(), variant)
	creature:setStorageValue(STORAGE_ESPECIAL1, currentTime + config.reuse_delay)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Migatte no gokui")
    end
    return true
end