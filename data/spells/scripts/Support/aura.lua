local combat = Combat()
combat:setParameter(COMBAT_PARAM_EFFECT, 92)
combat:setParameter(COMBAT_PARAM_AGGRESSIVE, false)

local condition = Condition(CONDITION_LIGHT)
condition:setParameter(CONDITION_PARAM_LIGHT_LEVEL, 9)
condition:setParameter(CONDITION_PARAM_LIGHT_COLOR, 215)
condition:setParameter(CONDITION_PARAM_TICKS, 33 * 60 * 1000)

function onCastSpell(creature, variant)
	local result = combat:execute(creature, variant)
    -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Aura")
    end
    return result
end
