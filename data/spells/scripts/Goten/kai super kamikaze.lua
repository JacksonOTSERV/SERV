local exhaustion_time = 45
local exhaustion_storage = STORAGE_ESPECIAL1

local inverter = Condition(CONDITION_DRUNK)
inverter:setParameter(CONDITION_PARAM_TICKS, 5 * 1000)

function onCastSpell(creature, cid, variant)
    if not creature or not creature:isCreature() then
        return false
    end
    
    if not creature:isPlayer() then
		creature:sendCancelMessage("Você só pode usar isso em players.")
        return false
    end
    
    local currentTime = os.time()
    local lastCast = creature:getStorageValue(STORAGE_ESPECIAL1)

    if lastCast > currentTime then
        creature:sendCancelMessage("Você precisa esperar " .. (lastCast - currentTime) .. " segundos para usar este especial novamente.")
        return false
    end

    local target = creature:getTarget()

    if target:hasCondition(CONDITION_MANASHIELD) then
        creature:sendCancelMessage("Você não pode usar isso em uma Kagome sob efeito do Kinzoku no kawa.")
        return false
    end
	
    target:addCondition(inverter)
    
    doSendMagicEffect(target:getPosition(), 92)
    creature:setStorageValue(exhaustion_storage, currentTime + exhaustion_time)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Kai super kamikaze")
    end
    return true
end
