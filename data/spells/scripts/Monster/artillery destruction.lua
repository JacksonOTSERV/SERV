arr1 = {
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0},
{0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0},
{0, 0, 1, 1, 1, 2, 1, 1, 1, 0, 0},
{0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0},
{0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
}

arr2 = {
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
}

arr3 = {
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0},
{0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0},
{0, 0, 0, 0, 1, 0, 3, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
}

arr4 = {
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0},
{0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0},
{0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0},
{0, 0, 0, 1, 0, 0, 2, 1, 0, 0, 0},
{0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
}

local combat1 = Combat()
combat1:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat1:setParameter(COMBAT_PARAM_EFFECT, 46)
combat1:setFormula(COMBAT_FORMULA_LEVELMAGIC, -325.0, 0, -335.0, 0)
combat1:setArea(createCombatArea(arr1))

local combat2 = Combat()
combat2:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat2:setParameter(COMBAT_PARAM_EFFECT, 46)
combat2:setFormula(COMBAT_FORMULA_LEVELMAGIC, -325.0, 0, -335.0, 0)
combat2:setArea(createCombatArea(arr2))

local combat3 = Combat()
combat3:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat3:setParameter(COMBAT_PARAM_EFFECT, 46)
combat3:setFormula(COMBAT_FORMULA_LEVELMAGIC, -325.0, 0, -335.0, 0)
combat3:setArea(createCombatArea(arr3))

local combat4 = Combat()
combat4:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat4:setParameter(COMBAT_PARAM_EFFECT, 46)
combat4:setFormula(COMBAT_FORMULA_LEVELMAGIC, -325.0, 0, -335.0, 0)
combat4:setArea(createCombatArea(arr4))

local combat5 = Combat()
combat5:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat5:setParameter(COMBAT_PARAM_EFFECT, 46)
combat5:setFormula(COMBAT_FORMULA_LEVELMAGIC, -325.0, 0, -335.0, 0)
combat5:setArea(createCombatArea(arr5))

function onCastSpell(creature, var)
    local cid = creature:getId()

    addEvent(function()
        local c = Creature(cid)
        if c then combat1:execute(c, var) end
    end, 0)

    addEvent(function()
        local c = Creature(cid)
        if c then combat2:execute(c, var) end
    end, 100)

    addEvent(function()
        local c = Creature(cid)
        if c then combat3:execute(c, var) end
    end, 200)

    addEvent(function()
        local c = Creature(cid)
        if c then combat4:execute(c, var) end
    end, 300)

    return true
end