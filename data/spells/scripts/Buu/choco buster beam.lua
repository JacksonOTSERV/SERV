local config = {
    stun_duration = 4,                -- dura��o do stun em segundos
    effect = 289,                      -- efeito visual no alvo
    storage = STORAGE_ESPECIAL1,     -- storage de cooldown
    reuse_delay = 40                 -- tempo de recarga da spell em segundos
}

local stun = Condition(CONDITION_STUN)
stun:setParameter(CONDITION_PARAM_TICKS, config.stun_duration * 1000)

local function repeatEffect(playerId, remainingTime)
    if remainingTime <= 0 then return end

    local player = Player(playerId)
    if player then
		local playerPos = player:getPosition()
		local effectPos = {x = playerPos.x+1, y = playerPos.y, z = playerPos.z}
		doSendMagicEffect(effectPos, config.effect, currentCreature)
    end

    addEvent(repeatEffect, 400, playerId, remainingTime - 500)
end

function onCastSpell(creature, variant)
    if not creature or not creature:isPlayer() then
        return false
    end

    local currentTime = os.time()
    local lastCast = creature:getStorageValue(config.storage)

    if lastCast > currentTime then
        creature:sendCancelMessage("Voc� precisa esperar " .. (lastCast - currentTime) .. " segundos para usar este especial novamente.")
        return false
    end

    local target = creature:getTarget()
    if not target or not target:isPlayer() then
        creature:sendCancelMessage("Voc� s� pode usar essa t�cnica em outros jogadores.")
        return false
    end
	
    if target:hasCondition(CONDITION_MANASHIELD) then
        creature:sendCancelMessage("Voc� n�o pode usar isso em uma Kagome sob efeito do Kinzoku no kawa.")
        return false
    end

    local targetId = target:getId()
    target:addCondition(stun)
    doSendAnimatedText(target:getPosition(), "Stunned!", TEXTCOLOR_BROWN)
	doSendMagicEffect(target:getPosition(), 288)
    addEvent(function()
		local targetActive = Player(targetId)
		if targetActive then
			repeatEffect(targetId, config.stun_duration * 1000 - 300)
		end
    end, 300)

    creature:setStorageValue(config.storage, currentTime + config.reuse_delay)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Choco buster beam")
    end
    return true
end