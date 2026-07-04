local BANK_OPCODE = 100
local BANK_REQUEST_OPCODE = 33

-- Helper: count total gold in player inventory (gold coin=2148, platinum=2152, crystal=2160)
local function getInventoryGold(player)
    local total = 0
    total = total + player:getItemCount(2148)           -- gold coins (1 each)
    total = total + player:getItemCount(2152) * 100     -- platinum coins (100 each)
    total = total + player:getItemCount(2160) * 10000   -- crystal coins (10000 each)
    return total
end

-- Helper: remove gold from inventory (smallest denominations first)
local function removeInventoryGold(player, amount)
    if amount <= 0 then return false end
    local remaining = amount

    -- Remove crystal coins first
    local crystals = math.min(player:getItemCount(2160), math.floor(remaining / 10000))
    if crystals > 0 then
        player:removeItem(2160, crystals)
        remaining = remaining - (crystals * 10000)
    end

    -- Remove platinum coins
    local platinums = math.min(player:getItemCount(2152), math.floor(remaining / 100))
    if platinums > 0 then
        player:removeItem(2152, platinums)
        remaining = remaining - (platinums * 100)
    end

    -- Remove gold coins
    local golds = math.min(player:getItemCount(2148), remaining)
    if golds > 0 then
        player:removeItem(2148, golds)
        remaining = remaining - golds
    end

    -- If there's remaining, we need to break larger coins
    if remaining > 0 then
        -- Try breaking platinum coin
        if remaining < 100 and player:getItemCount(2152) > 0 then
            player:removeItem(2152, 1)
            player:addItem(2148, 100 - remaining)
            remaining = 0
        elseif remaining < 10000 and player:getItemCount(2160) > 0 then
            player:removeItem(2160, 1)
            local change = 10000 - remaining
            local changePlatinums = math.floor(change / 100)
            local changeGolds = change % 100
            if changePlatinums > 0 then
                player:addItem(2152, changePlatinums)
            end
            if changeGolds > 0 then
                player:addItem(2148, changeGolds)
            end
            remaining = 0
        end
    end

    return remaining == 0
end

-- Helper: add gold to inventory as coins
local function addInventoryGold(player, amount)
    local crystals = math.floor(amount / 10000)
    amount = amount % 10000
    local platinums = math.floor(amount / 100)
    amount = amount % 100
    local golds = amount

    if crystals > 0 then player:addItem(2160, crystals) end
    if platinums > 0 then player:addItem(2152, platinums) end
    if golds > 0 then player:addItem(2148, golds) end
end

-- Send balance update to client
local function sendBankUpdate(player)
    local inventoryBalance = getInventoryGold(player)
    local playerBalance = player:getBankBalance()

    player:sendExtendedOpcode(BANK_OPCODE, json.encode({
        protocol = "bankUpdate",
        inventoryBalance = inventoryBalance,
        playerBalance = playerBalance
    }))
end

-- Send message to client
local function sendBankMsg(player, msg)
    player:sendExtendedOpcode(BANK_OPCODE, json.encode({
        protocol = "bankMsg",
        msg = msg
    }))
end

function onExtendedOpcode(player, opcode, buffer)
    if opcode ~= BANK_REQUEST_OPCODE then
        return true
    end

    local status, data = pcall(function()
        return json.decode(buffer)
    end)

    if not status or not data or not data.type then
        return true
    end

    local action = data.type

    -- Open bank: send current balances
    if action == "openBank" then
        sendBankUpdate(player)

    -- Deposit specific amount
    elseif action == "bankDeposit" then
        local value = tonumber(data.value) or 0
        if value <= 0 then
            sendBankMsg(player, "Valor inválido.")
            return true
        end

        local inventoryGold = getInventoryGold(player)
        if inventoryGold < value then
            sendBankMsg(player, "Você não possui gold suficiente no inventário.")
            return true
        end

        if removeInventoryGold(player, value) then
            player:setBankBalance(player:getBankBalance() + value)
            sendBankMsg(player, "Depositado com sucesso: {" .. value .. "#7BD786} gold.")
            sendBankUpdate(player)
        else
            sendBankMsg(player, "Erro ao depositar.")
        end

    -- Deposit all gold
    elseif action == "bankDepositAll" then
        local inventoryGold = getInventoryGold(player)
        if inventoryGold <= 0 then
            sendBankMsg(player, "Você não possui gold no inventário.")
            return true
        end

        if removeInventoryGold(player, inventoryGold) then
            player:setBankBalance(player:getBankBalance() + inventoryGold)
            sendBankMsg(player, "Depositado com sucesso: {" .. inventoryGold .. "#7BD786} gold.")
            sendBankUpdate(player)
        else
            sendBankMsg(player, "Erro ao depositar.")
        end

    -- Withdraw specific amount
    elseif action == "bankWithdraw" then
        local value = tonumber(data.value) or 0
        if value <= 0 then
            sendBankMsg(player, "Valor inválido.")
            return true
        end

        local bankBalance = player:getBankBalance()
        if bankBalance < value then
            sendBankMsg(player, "Saldo bancário insuficiente.")
            return true
        end

        player:setBankBalance(bankBalance - value)
        addInventoryGold(player, value)
        sendBankMsg(player, "Sacado com sucesso: {" .. value .. "#7BD786} gold.")
        sendBankUpdate(player)

    -- Withdraw all
    elseif action == "bankWithdrawAll" then
        local bankBalance = player:getBankBalance()
        if bankBalance <= 0 then
            sendBankMsg(player, "Saldo bancário insuficiente.")
            return true
        end

        player:setBankBalance(0)
        addInventoryGold(player, bankBalance)
        sendBankMsg(player, "Sacado com sucesso: {" .. bankBalance .. "#7BD786} gold.")
        sendBankUpdate(player)
    end

    return true
end
