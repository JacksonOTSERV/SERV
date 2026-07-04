local config = {
	duration_spell = 4, -- duração da spell.
	looktype = 157, -- roupa que ativará ao usar a spell.
	storage = STORAGE_ESPECIAL1, -- storage do cooldown.
	tempo = 60 -- tempo de cooldown.
}

local condition = Condition(CONDITION_ATTRIBUTES)
condition:setParameter(CONDITION_PARAM_SUBID, 435)
condition:setParameter(CONDITION_PARAM_STAT_MAGICPOINTS, 15)
condition:setParameter(CONDITION_PARAM_SKILL_CLUB, 15)
condition:setParameter(CONDITION_PARAM_SKILL_SWORD, 15)
condition:setParameter(CONDITION_PARAM_TICKS, 6 * 1000)

function onCastSpell(creature, variant)
	local player = Player(creature)
	if not player then
		return false
	end
	
	if player:isInGhostMode() then
		player:sendCancelMessage("Can't use yet.")
		return false
	end
	
	local remainingCooldown = player:getStorageValue(config.storage) - os.time()
	if remainingCooldown > 0 then
		player:sendCancelMessage("Aguarde " .. remainingCooldown .. " segundos para usar este especial novamente.")
		return false
	end
	
	local playId = player:getId()

	invisiblesystem(player, config.looktype, config.duration_spell, true)
		
	local pos = player:getPosition()
	pos:sendMagicEffect(105)
		
	player:setStorageValue(config.storage, config.tempo + os.time())
	
	addEvent(function()
		local currentPlayer = Player(playId)
		if currentPlayer then
			currentPlayer:addCondition(condition)
			currentPlayer:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Você agora tem 6 segundos de +15 all skills e retornou do invisível.")
		end
	end, config.duration_spell * 1000)
	    -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Enraged defense")
    end
	return true
end