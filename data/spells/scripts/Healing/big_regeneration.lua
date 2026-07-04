local waittime = 1 -- Tempo de exhaustion
local storage = 5945 -- Storage do exhaustion

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_HEALING)
combat:setParameter(COMBAT_PARAM_AGGRESSIVE, false)
combat:setParameter(COMBAT_PARAM_EFFECT, 88)

function onGetFormulaValues(player, level, maglevel)
	min = (level * 53 + maglevel * 120)
	max = (level * 78 + maglevel * 160)
    return min, max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

function onCastSpell(player, var)
    if player:isInGhostMode() then
        player:sendCancelMessage("Can't use yet.")
        return false
    end
    if player:getStorageValue(storage) - os.time() > 0 then
        return false
    end
    player:setStorageValue(storage, waittime + os.time())
    local result = combat:execute(player, var)
    -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(player, "Big regeneration")
    end
    return result
end
