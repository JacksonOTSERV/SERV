local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, 35)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, 40)
combat:setFormula(COMBAT_FORMULA_LEVELMAGIC, -116.7, 0, -121.7, 0)

local combat2 = Combat()
combat2:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat2:setParameter(COMBAT_PARAM_DISTANCEEFFECT, 45)
combat2:setFormula(COMBAT_FORMULA_LEVELMAGIC, -116.7, 0, -121.7, 0)

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
	
    for i = 1, 1 do
        addEvent(function()
            local currentCreature = Creature(creatureId)
            local targetCreature = Creature(targetId)
            if currentCreature and targetCreature and not targetCreature:isInGhostMode() then
                local tile = Tile(targetCreature:getPosition())
                if tile and tile:hasFlag(TILESTATE_PROTECTIONZONE) then
                    return
                end
                combat2:execute(currentCreature, Variant(targetCreature:getPosition()))
            end
        end, 1 + ((i-1) * 400))
    end
	
    for l = 1, 1 do
        addEvent(function()
            local currentCreature = Creature(creatureId)
            local targetCreature = Creature(targetId)
            if currentCreature and targetCreature and not targetCreature:isInGhostMode() then
                local tile = Tile(targetCreature:getPosition())
                if tile and tile:hasFlag(TILESTATE_PROTECTIONZONE) then
                    return
                end
				local position = targetCreature:getPosition()
				position.x = position.x + 1
				position.y = position.y + 1
				position:sendMagicEffect(49)
            end
        end, 1 + ((l-1) * 500))
    end

    return true
end