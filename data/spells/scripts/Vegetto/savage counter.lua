local config = {
    duration_spell = 10,    -- tempo do buff em segundos
    aura = 1264,        -- aura do buff
	reuse_delay = 25      -- tempo para reutilizar a spell em segundos
}

local function buff(creatureId, variant)
    local creature = Creature(creatureId)
    if creature and creature:isPlayer() then
		if getCreatureCondition(creature, CONDITION_ATTRIBUTES, 124) then
			local outfit = creature:getOutfit()
			outfit.lookAura = creature:getStorageValue(STORAGE_BUFF)
			creature:setOutfit(outfit)
		else
			local outfit = creature:getOutfit()
			outfit.lookAura = 0
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
    
	local outfit = creature:getOutfit()
	outfit.lookAura = config.aura
	creature:setOutfit(outfit)

    if isCreature(creature) then
        doSendAnimatedText(creature:getPosition(), "Weapons Distance", TEXTCOLOR_WHITE)
    end

    addEvent(buff, config.duration_spell * 1000, creature:getId(), variant)
	creature:setStorageValue(STORAGE_ESPECIAL1, currentTime + config.reuse_delay)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Savage counter")
    end
    return true
end