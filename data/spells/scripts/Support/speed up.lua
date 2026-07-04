local waittime = 1 -- Tempo de exhaustion
local storage = 6945 -- Storage do exhaustion

local combat = Combat()
combat:setParameter(COMBAT_PARAM_EFFECT, 28)
combat:setParameter(COMBAT_PARAM_AGGRESSIVE, false)

local condition = Condition(CONDITION_HASTE)
condition:setTicks(60000)
condition:setFormula(1.0, -24, 1.0, -24)

combat:setCondition(condition)

function onCastSpell(cid, var)
    if cid:getStorageValue(storage) - os.time() > 0 then
        return false
    end
	
    if cid:hasCondition(CONDITION_PARALYZE) then
        cid:sendCancelMessage("Você não pode usar tecnicas de speed enquanto estiver paralisado.")
        return false
    end

    cid:setStorageValue(storage, waittime + os.time())
    local result = combat:execute(cid, var)
    -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(cid, "Speed up")
    end
    return result
end