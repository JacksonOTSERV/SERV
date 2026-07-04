local config = {
    spell_duration = 4,       -- duração do muted em segundos
    effect = 11,                -- efeito visual no alvo
    storage = STORAGE_ESPECIAL1, -- storage de cooldown
    reuse_delay = 40             -- tempo de recarga da spell em segundos
}

function onCastSpell(creature, variant)
    if not creature or not creature:isPlayer() then
        return false
    end

    local currentTime = os.time()
    local lastCast = creature:getStorageValue(config.storage)

    if lastCast > currentTime then
        creature:sendCancelMessage("Você precisa esperar " .. (lastCast - currentTime) .. " segundos para usar este especial novamente.")
        return false
    end

    local target = creature:getTarget()
    if not target or not target:isPlayer() then
        creature:sendCancelMessage("Você só pode usar essa tecnica em outros jogadores.")
        return false
    end
	
    if target:hasCondition(CONDITION_MANASHIELD) then
        creature:sendCancelMessage("Você não pode usar isso em uma Kagome sob efeito do Kinzoku no kawa.")
        return false
    end

	target:setStorageValue(1000100, os.time() + config.spell_duration)
	target:setStorageValue(100075, os.time() + config.spell_duration)
	target:setStorageValue(1000150, os.time() + config.spell_duration)
	target:setStorageValue(1000200, os.time() + config.spell_duration)
	target:setStorageValue(1000250, os.time() + config.spell_duration)
	target:setStorageValue(1000300, os.time() + config.spell_duration)
	target:setStorageValue(1000400, os.time() + config.spell_duration)
	target:setStorageValue(STORAGE_ESPECIAL1, os.time() + config.spell_duration)
	target:setStorageValue(STORAGE_ESPECIAL2, os.time() + config.spell_duration)
    doSendMagicEffect(target:getPosition(), config.effect)
    doSendAnimatedText(target:getPosition(), "Muted!", TEXTCOLOR_WHITE)

    creature:setStorageValue(config.storage, currentTime + config.reuse_delay)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Heros flute")
    end
    return true
end
