function onExtendedOpcode(player, opcode, buffer)
    if opcode == 100 then
        if buffer and buffer ~= "" then
            HWID_SESSIONS[player:getId()] = buffer
        end
    end
end