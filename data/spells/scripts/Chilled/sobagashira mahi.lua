local config = {
    paralyze_duration = 4,       -- duração da paralyze em segundos
    paralyze_speed = -1000,       -- redução da velocidade (valores negativos = mais lento)
    effect = 72,                -- efeito visual no alvo
    storage = STORAGE_ESPECIAL1, -- storage de cooldown
    reuse_delay = 25             -- tempo de recarga da spell em segundos
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

    local condition = Condition(CONDITION_PARALYZE)
    condition:setParameter(CONDITION_PARAM_TICKS, config.paralyze_duration * 1000)
    condition:setParameter(CONDITION_PARAM_SPEED, config.paralyze_speed)
	
	local poison = Condition(CONDITION_POISON)
	poison:setParameter(CONDITION_PARAM_DELAYED, true)
	poison:setParameter(CONDITION_PARAM_TICKINTERVAL, 1000)
	poison:setParameter(CONDITION_PARAM_MINVALUE, -30000)
	poison:setParameter(CONDITION_PARAM_MAXVALUE, -30000)
	poison:setParameter(CONDITION_PARAM_STARTVALUE, -30000)

    target:addCondition(condition)
	target:addCondition(poison)

	local targetId = target:getId()
	addEvent(function()
		local targetPlayer = Creature(targetId)
		if targetPlayer and targetPlayer:isCreature() and targetPlayer:hasCondition(CONDITION_POISON) then
			targetPlayer:removeCondition(CONDITION_POISON)
		end
	end, config.paralyze_duration * 1000)
	
    doSendMagicEffect(target:getPosition(), config.effect)
    doSendAnimatedText(target:getPosition(), "Paralyzed!", TEXTCOLOR_PURPLE)
	doSendAnimatedText(target:getPosition(), "Poisoned!", TEXTCOLOR_PURPLE)
    creature:setStorageValue(config.storage, currentTime + config.reuse_delay)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Sobagashira mahi")
    end
    return true
end
