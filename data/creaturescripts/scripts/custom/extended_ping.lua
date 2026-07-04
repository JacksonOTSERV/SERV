local EXTENDED_OPCODE_PING = 190

function onExtendedOpcode(player, opcode, buffer)
    if opcode == EXTENDED_OPCODE_PING then
        player:sendExtendedOpcode(EXTENDED_OPCODE_PING, buffer)
    end
    return true
end
