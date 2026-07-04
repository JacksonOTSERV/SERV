function onSay(player, words, param)
    if not param or param == "" then
        player:popupFYI("[+] Comandos do AutoLoot [+]\n\n!autoloot add, [nome do item] --- Adiciona um item ao autoloot, jogadores premium podem colocar até 10 itens e jogadores free 7 itens.\n!autoloot remove, [nome do item] --- Remove um item da lista do autoloot\n!autoloot list --- Vê a lista de itens que estão no seu autoloot\n!autoloot clear --- Remove todos os itens do autoloot.")
        return false
    end

    local split = param:split(",")
    local action = split[1]

	if action == "add" then
		if not split[2] or split[2] == "" then
			player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "Você precisa informar o nome do item. Exemplo: !autoloot add, sword")
			return false
		end

		local item = split[2]:gsub("^%s*(.-)%s*$", "%1")
		local itemType = ItemType(item)
		if not itemType or itemType:getId() == 0 then
			itemType = ItemType(tonumber(item))
			if not itemType or itemType:getId() == 0 then
				player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "O item não existe, tente novamente.")
				return false
			end
		end

		local itemName = tonumber(split[2]) and itemType:getName() or item
		local maxItems = player:isPremium() and 10 or 7
		local size = 0
		for i = AUTOLOOT_STORAGE_START, AUTOLOOT_STORAGE_END do
			local storage = player:getStorageValue(i)
			
			if size == maxItems then
				local slots_used = size
				local max_slots = maxItems
				local playerStatus = player:isPremium() and "premium" or "free account"
				local message = "Sua lista já está cheia, você possui [" .. slots_used .. "/" .. max_slots .. "] slots preenchidos por ser um jogador " .. playerStatus .. ". Remova algum item para adicionar um novo!"
				player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, message)
				break
			end

			if storage == itemType:getId() then
				player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "O item [" ..itemName .. "] já está na lista.")
				break
			end

			if storage <= 0 then
				player:setStorageValue(i, itemType:getId())
				player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "O item ["..itemName .. "] foi adicionado com sucesso na sua lista.")
				break
			end

            size = size + 1
        end
    elseif action == "remove" then
        local item = split[2]:gsub("%s+", "", 1)
        local itemType = ItemType(item)
        
        -- Fix: Check if itemType is nil before accessing logic
        if not itemType or itemType:getId() == 0 then
            itemType = ItemType(tonumber(item))
            if not itemType or itemType:getId() == 0 then
                player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "O item não existe, tente novamente.")
                return false
            end
        end

        local itemName = tonumber(split[2]) and itemType:getName() or item
        for i = AUTOLOOT_STORAGE_START, AUTOLOOT_STORAGE_END do
            if player:getStorageValue(i) == itemType:getId() then
                player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "O item ["..itemName .. "] foi removido com sucesso da sua lista.")
                player:setStorageValue(i, 0)
                return false
            end
        end

        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "O item ["..itemName .. "] não está na sua lista.")
    elseif action == "list" then
		local slotsprem = player:isPremium() and 10 or 7
		local playerStats = player:isPremium() and "premium" or "free account"
        local text = "-- Auto Loot List [".. slotsprem .. " slots " .. playerStats .. "] --\n"
        local count = 1
        for i = AUTOLOOT_STORAGE_START, AUTOLOOT_STORAGE_END do
            local storage = player:getStorageValue(i)
            if storage > 0 then
                text = string.format("%s%d. %s\n", text, count, ItemType(storage):getName())
                count = count + 1
            end
        end

        if text == "" then
            text = "Empty"
        end
 
        player:showTextDialog(901, text, false)
    elseif action == "clear" then
        for i = AUTOLOOT_STORAGE_START, AUTOLOOT_STORAGE_END do
            player:setStorageValue(i, 0)
        end

        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "A lista do seu autoloot foi limpa.")
    else
		player:popupFYI("[+] Comandos do AutoLoot [+]\n\n!autoloot add, [nome do item] --- Adiciona um item ao autoloot, jogadores premium podem colocar até 10 itens e jogadores free 7 itens.\n!autoloot remove, [nome do item] --- Remove um item da lista do autoloot\n!autoloot list --- Vê a lista de itens que estão no seu autoloot\n!autoloot clear --- Remove todos os itens do autoloot.")
    end

    return false
end
