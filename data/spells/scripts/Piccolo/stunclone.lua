local stun = Condition(CONDITION_STUN)
stun:setParameter(CONDITION_PARAM_TICKS, 3000)

function onCastSpell(creature, cid, variant)
    if not creature or not creature:isCreature() then
        return false
    end

    local player = Creature(creature)

    local target = creature:getTarget()
	
    if not target or not target:isPlayer() then
        return false
    end
	
    if target:hasCondition(CONDITION_MANASHIELD) then
        return false
    end
	
    local targetId = target:getId()
    local tPos = target:getPosition()

    target:addCondition(stun)
    doSendMagicEffect({x = tPos.x+1, y = tPos.y+1, z = tPos.z}, 49)

    for i = 1, 5 do 
        addEvent(function()
            local targetPlayer = Creature(targetId)
            if not targetPlayer or not targetPlayer:isPlayer() then
                return
            end
            local pos = targetPlayer:getPosition()
            doSendMagicEffect({x = pos.x+1, y = pos.y+1, z = pos.z}, 49, targetPlayer)
        end, i * 500)
    end
	
	if creature and creature:isCreature() then
		creature:remove()
	end
	
    return true
end