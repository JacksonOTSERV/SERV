local PROTECTION_OPCODE = 222

function onExtendedOpcode(player, opcode, buffer)
    if opcode ~= PROTECTION_OPCODE then
        return false
    end

    -- Debug
    print("[PROTECTION BOOST] Recebido do player " .. player:getName() .. ": " .. buffer)

    -- Quando o cliente abre a janela
    if buffer == "openWindow" then
        -- Exemplo: mandar item configurado de volta
        local itemId, itemCount = 2160, 10 -- 10 crystal coins
        local msg = "returnStoneStatus@" .. itemId .. "@" .. itemCount
        player:sendExtendedOpcode(PROTECTION_OPCODE, msg)
        return true
    end

    -- Quando o cliente manda um item
    if buffer:find("PacketProtection@") then
        local parts = buffer:split("@")
        -- parts[1] = "PacketProtection"
        local itemId = tonumber(parts[2]) or 0
        local posX = tonumber(parts[3]) or 0
        local posY = tonumber(parts[4]) or 0
        local posZ = tonumber(parts[5]) or 0
        local stackPos = tonumber(parts[6]) or 0

        print(string.format("[BOOST OPCODE] Item recebido: %d (pos: %d,%d,%d stack:%d)", 
            itemId, posX, posY, posZ, stackPos))

        -- Aqui você decide o que fazer com o item (validar, boostar, etc.)
        -- Exemplo: mandar de volta só pra teste
        local msg = "returnStoneStatus@" .. itemId .. "@1"
        player:sendExtendedOpcode(PROTECTION_OPCODE, msg)
        return true
    end

    return true
end