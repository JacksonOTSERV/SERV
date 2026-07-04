local config = {
    duration_spell = 5,    -- tempo do buff em segundos
	effect = 67,           -- efeito do reflect insta
	storage = 9000,        -- storage do reflect temporario
	reuse_delay = 60       -- tempo para reutilizar a spell em segundos
}

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
    
	local position = creature:getPosition()
	position.x = position.x + 2
	position.y = position.y + 2
	doSendMagicEffect(position, config.effect)
	doSendAnimatedText(creature:getPosition(), "Reflect!", TEXTCOLOR_RED)
	
	creature:setStorageValue(config.storage, config.duration_spell + os.time())

	creature:setStorageValue(STORAGE_ESPECIAL1, currentTime + config.reuse_delay)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Android barrier")
    end
    return true
end