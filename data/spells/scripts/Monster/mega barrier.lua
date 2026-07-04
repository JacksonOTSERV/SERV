local arr = {
	{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	{0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0},
	{0, 0, 0, 0, 1, 2, 1, 0, 0, 0, 0},
	{0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0},
	{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
}

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setFormula(COMBAT_FORMULA_LEVELMAGIC, -325.0, 0, -335.0, 0)
combat:setArea(createCombatArea(arr))

function onCastSpell(creature, var)
    local position = creature:getPosition()
    position.x = position.x + 1
	position.y = position.y + 1
    position:sendMagicEffect(49)
	position:sendMagicEffect(54)
    return combat:execute(creature, var)
end
