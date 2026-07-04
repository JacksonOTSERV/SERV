-- TESTE: adiciona keys/gems do shop ao personagem
-- /addkeys <qtd>       → adiciona keys (storage 50002)
-- /addkeys gems <qtd>  → adiciona gems (storage 50001)

local STORAGE_KEYS = 50002
local STORAGE_GEMS = 50001

function onSay(player, words, param)
    param = param:trim()

    if param == "" then
        player:sendCancelMessage("Use: /addkeys <qtd>  ou  /addkeys gems <qtd>")
        return false
    end

    local isGems = false
    local amount

    local sub, n = param:match("^(%a+)%s+(%d+)$")
    if sub and sub:lower() == "gems" then
        isGems = true
        amount = tonumber(n)
    else
        amount = tonumber(param)
    end

    if not amount then
        player:sendCancelMessage("Quantidade invalida. Use: /addkeys 100")
        return false
    end

    if isGems then
        local cur = player:getStorageValue(STORAGE_GEMS)
        cur = (cur > 0) and cur or 0
        player:setStorageValue(STORAGE_GEMS, cur + amount)
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
            string.format("+%d gems. Total storage: %d", amount, cur + amount))
    else
        local cur = player:getStorageValue(STORAGE_KEYS)
        cur = (cur > 0) and cur or 0
        player:setStorageValue(STORAGE_KEYS, cur + amount)
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
            string.format("+%d keys. Total: %d", amount, cur + amount))
    end

    return false
end
