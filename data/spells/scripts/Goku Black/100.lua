local effect = 47

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

local function showAreaEffects(player, arr, effect, offsetX, offsetY)
    local centerY = math.floor(#arr / 2) + 1
    local centerX = math.floor(#arr[1] / 2) + 1
    local pos = player:getPosition()

    for y = 1, #arr do
        for x = 1, #arr[y] do
            local value = arr[y][x]
            if value == 1 then
                local dx = x - centerX + offsetX
                local dy = y - centerY + offsetY
                local targetPos = Position(pos.x + dx, pos.y + dy, pos.z)
                targetPos:sendMagicEffect(effect)
            end
        end
    end
end

local combat1 = Combat()
combat1:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
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

    showAreaEffects(player, arr1, effect, 1, 1)

    local result = combat1:execute(player, var)

    -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(player, "Shockwave")
    end
    return result
end
