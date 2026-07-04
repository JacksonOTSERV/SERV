function onThink(cid, interval)
    local player = Player(cid)
    if not player or not player:isCreature() then
        return true
    end
	
	local skull, skullEnd = getCreatureSkull(player), getPlayerSkullEnd(player)
    if skullEnd > 0 and skull > SKULL_WHITE and os.time() > skullEnd and not player:hasCondition(CONDITION_INFIGHT) then
        player:setSkull(SKULL_NONE)
    end

    return true
end