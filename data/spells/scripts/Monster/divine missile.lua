local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, 3)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, 99)
combat:setFormula(COMBAT_FORMULA_LEVELMAGIC, -38.0, 0, -38.5, 0)

function onCastSpell(creature, variant)
    local target = creature:getTarget()
    if not target or target:isInGhostMode() then
        return false
    end

    local creatureId = creature:getId()
    local targetId = target:getId()

	-- nesse código precisa de lyze!

    return true
end