local waittime = 1 -- Tempo de exhaustion
local storage = 1000400 -- Storage do exhaustion

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, 23)

function onGetFormulaValues(player, level, magicLevel)
    local min = - (DAMAGE_FACTOR_LEVEL400 * level + DAMAGE_FACTOR_SKILL400 * magicLevel) * 1.23
    local max = - (DAMAGE_FACTOR_LEVEL400 * level + DAMAGE_FACTOR_SKILL400 * magicLevel) * 1.28
    return min, max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

function onCastSpell(creature, cid, variant)
    if not creature or not creature:isCreature() then
        return false
    end

    local player = Player(creature)

    if exhaustion.check(player, storage) then
        if player:isPlayer() then
            player:sendCancelMessage("Aguarde " .. tostring(exhaustion.get(player, storage)) .. " segundos para usar essa tecnica novamente.")
        end
        return false
    end

    local target = creature:getTarget()
    if not target or not target:isCreature() then
        return false
    end

    local targetPos = target:getPosition()

    local positions = {
        {x = targetPos.x - 4, y = targetPos.y - 5, z = targetPos.z},
        {x = targetPos.x, y = targetPos.y - 5, z = targetPos.z},
        {x = targetPos.x + 4, y = targetPos.y - 5, z = targetPos.z},
    }

    for _, fromPos in ipairs(positions) do
        doSendDistanceShoot(fromPos, target:getPosition(), 33)
    end

    combat:execute(creature, cid, variant)

    exhaustion.set(player, 1000300, 8)
    exhaustion.set(player, 1000150, 4)
    exhaustion.set(player, storage, waittime)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Rage pink beam")
    end
    return true
end
