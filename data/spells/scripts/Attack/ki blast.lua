local waittime = 1 -- Tempo de exaustão
local storage = 1000150 -- Storage da exaustão

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, 8)

function onGetFormulaValues(creature, level, maglevel)
    local min = -(DAMAGE_FACTOR_LEVEL50 * level + DAMAGE_FACTOR_SKILL50 * maglevel) * 0.78
    local max = -(DAMAGE_FACTOR_LEVEL50 * level + DAMAGE_FACTOR_SKILL50 * maglevel) * 0.82
    return min, max 
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

function onCastSpell(creature, variant)
	if not creature then
		return false
	end
	
	if exhaustion.check(creature, storage) and exhaustion.check(creature, 1000200) and exhaustion.check(creature, 1000600) then
        creature:sendCancelMessage("Aguarde " .. tostring(exhaustion.get(creature, storage)) .. " segundos para usar essa tecnica novamente.")
        return false
    end

    local target = creature:getTarget()
    if not target or target:isInGhostMode() then
        return false
    end

    local creatureId = creature:getId()
    local targetId = target:getId()

    for k = 1, 3 do
        addEvent(function()
            local currentCreature = Creature(creatureId)
            local targetCreature = Creature(targetId)
            if currentCreature and targetCreature and not targetCreature:isInGhostMode() then
                local tile = Tile(targetCreature:getPosition())
                if tile and tile:hasFlag(TILESTATE_PROTECTIONZONE) then
                    return
                end
                combat:execute(currentCreature, Variant(targetCreature:getPosition()))
            end
        end, 1 + ((k-1) * 200))
    end
	
	exhaustion.set(creature, 1000250, 4)
	exhaustion.set(creature, 1000300, 4)
	exhaustion.set(creature, storage, waittime)

        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Ki blast")
    end

    return true
end
