local effect = 16 -- Effect da area

local arr1 = {
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

local combat1 = Combat()
combat1:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat1:setParameter(COMBAT_PARAM_EFFECT, effect)
combat1:setArea(createCombatArea(arr1))

function onGetFormulaValues(player, level, magicLevel)
    local min = - (DAMAGE_FACTOR_LEVEL100 * level + DAMAGE_FACTOR_SKILL100 * magicLevel) * 0.98
    local max = - (DAMAGE_FACTOR_LEVEL100 * level + DAMAGE_FACTOR_SKILL100 * magicLevel) * 1.02
    return min, max
end

combat1:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

function onCastSpell(player, var)
    if not player then
        return false
    end

    if exhaustion.check(player, storage) then
        player:sendCancelMessage("Aguarde " .. tostring(exhaustion.get(player, storage)) .. " segundos para usar a tecnica novamente.")
        return false
    end

	exhaustion.set(player, 1000250, 3)
	exhaustion.set(player, 1000300, 3)
	exhaustion.set(player, 1000400, 3)
    local result = combat1:execute(player, var)

    -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(player, "Demon furie")
    end
    return result
end
