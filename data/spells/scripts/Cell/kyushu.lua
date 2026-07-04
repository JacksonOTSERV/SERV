local config = {
    duration_spell = 8,    -- tempo do buff em segundos
	effect = 120,           -- efeito do reflect insta
	storage = STORAGE_REVIVE,        -- storage do reflect temporario
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
	doSendMagicEffect(position, config.effect)
	doSendAnimatedText(creature:getPosition(), "Kyushu!", TEXTCOLOR_LIGHTGREEN)
	
	creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Se você morrer dentro de "..config.duration_spell.." segundos, você irá renascer.")
	
	creature:setStorageValue(config.storage, config.duration_spell + os.time())

	creature:setStorageValue(STORAGE_ESPECIAL1, currentTime + config.reuse_delay)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Kyushu")
    end
    return true
end