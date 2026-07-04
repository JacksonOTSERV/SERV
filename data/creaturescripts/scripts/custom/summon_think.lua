function onThink(creature, interval)
    local master = creature:getMaster()
    if not master then return true end

    local pos = creature:getPosition()
    local master_pos = master:getPosition()

    local tile = Tile(master_pos)
    if tile and tile:hasFlag(TILESTATE_PROTECTIONZONE) then
        return true
    end

    local distance = getDistanceBetween({x = pos.x, y = pos.y, z = 0}, {x = master_pos.x, y = master_pos.y, z = 0})

    if distance > 7 then
        if creature:teleportTo(master_pos) then
            pos:sendMagicEffect(CONST_ME_POFF)
        end
    end

    return true
end