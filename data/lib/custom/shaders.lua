shader = {
    opcode = 200,

    sendShaderOtc = function(player, shaderName, time)
        local playerId = player and player:getId()
        if not playerId then
            return
        end

        player:sendExtendedOpcode(shader.opcode, shaderName)

        addEvent(function()
            local player = Player(playerId)
            if player then
                player:sendExtendedOpcode(shader.opcode, 'Default')
            end
        end, 1000 * time)
    end,
}