-- Stream spectator channel (id 23)
-- Acesso: hosts e spectators ativos

function canJoin(player)
    if Hosts and Hosts[player:getId()] then
        return true
    end
    if player:isSpectator() then
        return true
    end
    return false
end

function onSpeak(player, type, message)
    -- Host e spectators podem falar no canal
    if Hosts and Hosts[player:getId()] then
        return true
    end
    if player:isSpectator() then
        return true
    end
    return false
end
