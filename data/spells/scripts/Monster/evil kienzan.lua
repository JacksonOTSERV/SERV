local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, 21)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, 28)
combat:setFormula(COMBAT_FORMULA_LEVELMAGIC, -162.0, 0, -167.5, 0)

function onCastSpell(creature, variant)
    local target = creature:getTarget()
    if not target or target:isInGhostMode() then
        return false
    end

    local creatureId = creature:getId()
    local targetId = target:getId()

    for k = 1, 2 do
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

    return true
end