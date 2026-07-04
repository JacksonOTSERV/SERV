--[[
Talkaction: Summon NPC
Descrição: Permite summonar NPCs em qualquer posição
Comando: /summonnpc nome_do_npc
Exemplo: /summonnpc Oracle
Compatível com: TFS 1.3 (Baiak Thunder)
]]--

function onSay(player, words, param)
    -- Verifica se o jogador tem permissão (GM/GOD)
    if not player:getGroup():getAccess() then
        player:sendCancelMessage("Você não tem permissão para usar este comando.")
        return false
    end

    -- Verifica se foi informado o nome do NPC
    if param == "" then
        player:sendCancelMessage("Uso: /summonnpc <nome do npc>")
        player:sendCancelMessage("Exemplo: /summonnpc Oracle")
        return false
    end

    -- Pega a posição do jogador
    local playerPos = player:getPosition()
    
    -- Posição onde o NPC será summonado (na frente do jogador)
    local summonPos = Position(playerPos.x + 1, playerPos.y, playerPos.z)
    
    -- Verifica se a posição está livre
    local tile = Tile(summonPos)
    if tile then
        local creatures = tile:getCreatures()
        if creatures and #creatures > 0 then
            -- Se a posição estiver ocupada, tenta ao lado
            summonPos = Position(playerPos.x, playerPos.y + 1, playerPos.z)
            tile = Tile(summonPos)
            if tile then
                creatures = tile:getCreatures()
                if creatures and #creatures > 0 then
                    player:sendCancelMessage("Não há espaço disponível para summonar o NPC.")
                    return false
                end
            end
        end
    end

    -- Tenta criar o NPC
    local npc = Game.createNpc(param, summonPos, false, true)
    
    if npc then
        -- Efeito visual ao summonar
        summonPos:sendMagicEffect(CONST_ME_TELEPORT)
        
        -- Mensagem de sucesso
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "NPC '" .. param .. "' summonado com sucesso!")
        
        -- Log da ação
        print(string.format("[SUMMONNPC] %s summonou o NPC '%s' na posição %s", 
            player:getName(), param, summonPos:toString()))
    else
        -- Mensagem de erro se o NPC não existir
        player:sendCancelMessage("NPC '" .. param .. "' não encontrado. Verifique o nome e tente novamente.")
        return false
    end

    return false
end
