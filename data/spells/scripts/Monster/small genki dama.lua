local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, 14)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, 56)
combat:setFormula(COMBAT_FORMULA_LEVELMAGIC, -350.0, 0, -365.0, 0)

function onCastSpell(creature, variant)
    local target = creature:getTarget()
    if not target or target:isInGhostMode() then
        return false
    end
    
    if not target:isInGhostMode() then
        return combat:execute(creature, variant)
    end
    return false
end