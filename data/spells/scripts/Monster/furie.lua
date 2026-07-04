local arr = {
    {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0},
    {0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0},
    {0, 0, 0, 1, 1, 2, 1, 1, 0, 0, 0},
    {0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0},
    {0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
}

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, 9)
combat:setFormula(COMBAT_FORMULA_LEVELMAGIC, -325.0, 0, -335.0, 0)
combat:setArea(createCombatArea(arr))

function onCastSpell(creature, var)
	local creatureId = creature:getId()
	
	addEvent(function()
		local currentCreature = Creature(creatureId)
		if currentCreature then
			combat:execute(currentCreature, var)
		end
	end, 150)
	
	return combat:execute(creature, var)
end