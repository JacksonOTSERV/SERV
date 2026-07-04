local waittime = 1 -- Tempo de exhaustion
local storage = 1000100 -- Storage do exhaustion

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
combat:setArea(createCombatArea(arr))

function onGetFormulaValues(player, level, magicLevel)
    -- faixa estreita (media 1.00, +-10%) p/ dano consistente: o bonus das stars
    -- fica visivel em vez de sumir na aleatoriedade. Antes era 0.75/1.25 (+-25%).
    local base = - (DAMAGE_FACTOR_LEVEL100 * level + DAMAGE_FACTOR_SKILL100 * magicLevel)
    min = base * 0.98
    max = base * 1.02
    return min, max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

function onCastSpell(player, var)

	if not player then
		return false
	end
	
	if exhaustion.check(player, storage) then
        player:sendCancelMessage("Aguarde " .. tostring(exhaustion.get(player, storage)) .. " segundos para usar essa tecnica novamente.")
        return false
    end
	
	local position = player:getPosition()
    position.x = position.x + 2
	position.y = position.y + 2

    doSendMagicEffect(position, 64)

	exhaustion.set(player, storage, waittime)
	exhaustion.set(player, 1000250, 3)
	exhaustion.set(player, 1000300, 3)

    local result = combat:execute(player, var)
    -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(player, "Big explosion")
    end
    return result
end
