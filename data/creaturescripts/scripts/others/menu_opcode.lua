local OPCODE_CLIENT_LISTEN = 2 -- Opcode que o CLIENTE ouve (para enviar dados)
local OPCODE_CLIENT_SEND = 33 -- Opcode que o CLIENTE envia (para pedir dados) (ver menu.lua: sendExtendedOpcode(33))

function onExtendedOpcode(player, opcode, buffer)
    if opcode == OPCODE_CLIENT_SEND then
        -- O cliente enviou um request de menu
        local status, json_data = pcall(function() return json.decode(buffer) end)
        if not status then 
             return false 
        end

        local action = json_data.type
        if action == "onOpenMenu" then
            sendMenuInfo(player)
        end
    end
    return true
end

function onLogin(player)
    player:registerEvent("MenuOpcode")
    sendMenuInfo(player) -- Envia ao logar
    return true
end

function sendMenuInfo(player)
    -- Calcula o dinheiro total (Mão + Banco)
    local totalMoney = player:getMoney() + player:getBankBalance()
    
    -- Busca premium points (Assumindo TFS 1.x com db.storeQuery)
    -- Ajuste a query conforme a estrutura do seu banco de dados (ex: 'premium_points', 'coins', etc)
    local points = 0
    local resultId = db.storeQuery("SELECT `premium_points` FROM `accounts` WHERE `id` = " .. player:getAccountId())
    if resultId then
        points = result.getDataInt(resultId, "premium_points")
        result.free(resultId)
    end
    
    -- Envia dados gerais (dinheiro e classe)
    local data = {
        type = "update",
        playerMoney = totalMoney,
        playerClasse = 0, -- Placeholder para sistema de classe
    }
    player:sendExtendedOpcode(OPCODE_CLIENT_LISTEN, json.encode(data))

    -- Envia dados de pontos separadamente (conforme menu.lua espera)
    local pointsData = {
        type = "updatePoints",
        points = points
    }
    player:sendExtendedOpcode(OPCODE_CLIENT_LISTEN, json.encode(pointsData))
end
