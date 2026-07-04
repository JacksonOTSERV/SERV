local firstTimeItems = {
    {id = 12677, count = 1},
}

local STORAGE_CHEST = 60030

function onUse(player, item, fromPosition, target, isHotkey)
    if player:getStorageValue(STORAGE_CHEST) ~= 1 then
        local bag = doCreateItemEx(12764, 1)
        local receivedItems = "Você recebeu os seguintes itens dentro da mochila: "

        for i, reward in ipairs(firstTimeItems) do
            doAddContainerItem(bag, reward.id, reward.count)
            local itemName = getItemNameById(reward.id)
            receivedItems = receivedItems .. reward.count .. "x " .. itemName

            if i < #firstTimeItems then
                receivedItems = receivedItems .. ", "
            else
                receivedItems = receivedItems .. "."
            end
        end

        local result = doPlayerAddItemEx(player, bag, false)
        if result ~= RETURNVALUE_NOERROR then
            return true
        end

        doPlayerSendTextMessage(player, MESSAGE_EVENT_ADVANCE, receivedItems)
        player:setStorageValue(STORAGE_CHEST, 1)
    else
        player:sendTextMessage(MESSAGE_INFO_DESCR, "Você já pegou os itens disponíveis nesse baú.")
    end

    return true
end