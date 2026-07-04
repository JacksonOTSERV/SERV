function onExtendedOpcode(player, opcode, buffer)
    if opcode == 189 then

        local playerPos = player:getPosition()

        for areaId, _ in pairs(DungeonTimers) do
            local fromX, fromY, fromZ, toX, toY, toZ =
                string.match(areaId, "(%d+),(%d+),(%d+)_(%d+),(%d+),(%d+)")
            if fromX then
                local fromPos = Position(tonumber(fromX), tonumber(fromY), tonumber(fromZ))
                local toPos   = Position(tonumber(toX), tonumber(toY), tonumber(toZ))

                if isInRange(playerPos, fromPos, toPos) then
                    local remaining = getDungeonRemaining(areaId)

                    player:sendExtendedOpcode(DUNGEON_OPCODE_TEXT, "Dungeon iniciada!")

                    if remaining > 0 then
                        local minutes = math.floor(remaining / 60)
                        local seconds = remaining % 60
                        local timeStr = string.format("%02d:%02d", minutes, seconds)
                        player:sendExtendedOpcode(DUNGEON_OPCODE_ReceiveStart, timeStr)
                    else
                        player:sendExtendedOpcode(DUNGEON_OPCODE_ReceiveStart, "00:00")
                    end
                    break
                end
            end
        end
    end
end