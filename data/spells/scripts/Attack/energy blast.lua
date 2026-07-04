local waittime = 1 -- Tempo de exhaustion
local storage = 100075 -- Storage do exhaustion

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, 27)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, 1)

function onGetFormulaValues(player, level, maglevel)
    local min = -(DAMAGE_FACTOR_LEVEL50 * level + DAMAGE_FACTOR_SKILL50 * maglevel) * 0.78
    local max = -(DAMAGE_FACTOR_LEVEL50 * level + DAMAGE_FACTOR_SKILL50 * maglevel) * 0.82
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
                combat:execute(currentCreature, Variant(targetCreature:getPosition()))
            end
        end, 1 + ((k-1) * 200))
    end
	
	exhaustion.set(player, 1000250, 4)
	exhaustion.set(player, 1000300, 4)
	exhaustion.set(player, storage, waittime)

        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Energy blast")
    end

    return true
end
