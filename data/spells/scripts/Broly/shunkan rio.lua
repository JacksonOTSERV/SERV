local config = {
    duration_spell = 5,   -- tempo do buff em segundos
    looktype = 944,       -- looktype do buff
	reuse_delay = 50,      -- tempo para reutilizar a spell em segundos
	storage = 6612     	  -- storage do blocked
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

    local outfitCondition = Condition(CONDITION_OUTFIT)
    outfitCondition:setTicks(config.duration_spell * 1000)
    outfitCondition:setOutfit({lookType = config.looktype})

    creature:addCondition(outfitCondition)
	
	creature:setStorageValue(config.storage, config.duration_spell + os.time())

    addEvent(buff, config.duration_spell * 1000, creature:getId(), variant)
	creature:setStorageValue(STORAGE_ESPECIAL1, currentTime + config.reuse_delay)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Shunkan rio")
    end
    return true
end