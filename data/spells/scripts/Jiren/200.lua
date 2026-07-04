local waittime = 1 -- Tempo de exhaustion
local storage = 1000200 -- Storage do exhaustion

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)

function onGetFormulaValues(player, level, magicLevel)
    local min = - (DAMAGE_FACTOR_LEVEL200 * level + DAMAGE_FACTOR_LEVEL200 * magicLevel) / 1 * 0.98
    local max = - (DAMAGE_FACTOR_LEVEL200 * level + DAMAGE_FACTOR_LEVEL200 * magicLevel) / 1 * 1.02
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
    
    local position = target:getPosition()
    local positions = {
        {x=position.x+1, y=position.y+2,z=position.z},
        {x=position.x+1, y=position.y,z=position.z},
        {x=position.x, y=position.y+1,z=position.z},
        {x=position.x+2, y=position.y+1,z=position.z}
    }
    for i, pos in pairs(positions) do
        doSendMagicEffect(pos, 312)
    end
    local playerPos = creature:getPosition()
    playerPos.x = playerPos.x + 1
    doSendMagicEffect(playerPos, 310)
	
	exhaustion.set(player, storage, waittime)

    local result = combat:execute(creature, cid, variant)

    -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Colossal flash")
    end
    return result
end
