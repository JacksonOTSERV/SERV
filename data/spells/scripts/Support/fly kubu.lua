local config = {
	duration_spell = 2, -- duração da spell.
	looktype = 157, -- roupa que ativará ao usar a spell.
	storage = STORAGE_ESPECIAL2, -- storage do cooldown.
	tempo = 60 -- tempo padrão de cooldown.
}

function onCastSpell(creature, variant)
	local player = Player(creature)
	if not player then
		return false
	end
	
	if player:isInGhostMode() then
		player:sendCancelMessage("Can't use yet.")
		return false
	end
	
	local isReborn = player:getStorageValue(4241) > 0
	local cooldownTime = isReborn and 45 or config.tempo
	
	local remainingCooldown = player:getStorageValue(config.storage) - os.time()
	if remainingCooldown > 0 then
		player:sendCancelMessage("Aguarde " .. remainingCooldown .. " segundos para usar este especial novamente.")
		return false
	end
	
	invisiblesystem(player, config.looktype, config.duration_spell, true)
	
	local pos = player:getPosition()
	pos.x = pos.x + 1
	pos:sendMagicEffect(80)
	
	player:setStorageValue(config.storage, cooldownTime + os.time())
	    -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Fly kubu")
    end
	return true
end