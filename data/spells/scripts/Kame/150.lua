local waittime = 1 -- Tempo de exhaustion
local storage = 1000150 -- Storage do exhaustion

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, 7)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, 18)

function onGetFormulaValues(player, level, magicLevel)
    local min = - (DAMAGE_FACTOR_LEVEL150 * level + DAMAGE_FACTOR_SKILL150 * magicLevel) / 1 * 0.98
    local max = - (DAMAGE_FACTOR_LEVEL150 * level + DAMAGE_FACTOR_SKILL150 * magicLevel) / 1 * 1.02
    return min, max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

function onCastSpell(creature, variant)
	if not creature then
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
    if not target or target:isInGhostMode() then
        return false
    end

    local creatureId = creature:getId()
    local targetId = target:getId()

    for k = 1, 4 do
        addEvent(function()
            local currentCreature = Creature(creatureId)
            local targetCreature = Creature(targetId)
            if currentCreature and targetCreature and not targetCreature:isInGhostMode() then
                local tile = Tile(targetCreature:getPosition())
                if tile and tile:hasFlag(TILESTATE_PROTECTIONZONE) then
                    return
                end
				local distance = getDistanceBetween(currentCreature:getPosition(), targetCreature:getPosition())
				if distance > 6 then return end
				local playerPos = targetCreature:getPosition()
                combat:execute(currentCreature, Variant(targetCreature:getPosition()))
            end
        end, 1 + ((k-1) * 200))
    end
	exhaustion.set(player, 1000300, 4)
	exhaustion.set(player, 1000400, 4)
	exhaustion.set(player, storage, waittime)

        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Rush attack")
    end

    return true
end
