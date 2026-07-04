local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setFormula(COMBAT_FORMULA_LEVELMAGIC, -175.0, 0, -200.0, 0)

function onCastSpell(creature, variant)
    local target = creature:getTarget()
    if not target or target:isInGhostMode() then
        return false
    end
	
    local position = target:getPosition()
    position.x = position.x + 1
	position.y = position.y + 1
    position:sendMagicEffect(55)
    
    if not target:isInGhostMode() then
        return combat:execute(creature, variant)
    end
    return false
end