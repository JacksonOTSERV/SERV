-- Talkaction: !adddonate [valor]
-- Exemplo: !adddonate 500
-- Adiciona pontos de doacao ao jogador (para testes)

local STORAGE_PLAYER_DONATED = 85001
local GLOBAL_SERVER_DONATED = 85100

function onSay(player, words, param)
    local value = tonumber(param)
    if not value or value <= 0 then
        player:sendTextMessage(MESSAGE_STATUS_SMALL, "Use: !adddonate [valor]. Ex: !adddonate 500")
        return false
    end

    -- Add to player donated
    local currentPlayer = player:getStorageValue(STORAGE_PLAYER_DONATED)
    if currentPlayer < 0 then currentPlayer = 0 end
    player:setStorageValue(STORAGE_PLAYER_DONATED, currentPlayer + value)

    -- Add to server total
    local currentServer = Game.getStorageValue(GLOBAL_SERVER_DONATED)
    if not currentServer or currentServer < 0 then currentServer = 0 end
    Game.setStorageValue(GLOBAL_SERVER_DONATED, currentServer + value)

    player:sendTextMessage(MESSAGE_INFO_DESCR, "Adicionado " .. value .. " pontos de doacao! Total pessoal: " .. (currentPlayer + value) .. ". Total servidor: " .. (currentServer + value))
    return false
end
