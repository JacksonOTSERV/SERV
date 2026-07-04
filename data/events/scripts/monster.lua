local noLootAreas = {
	{fromPos = {x = 293, y = 1149, z = 7}, toPos = {x = 512, y = 1290, z = 7}},
	{fromPos = {x = 293, y = 1149, z = 6}, toPos = {x = 512, y = 1290, z = 6}},
	{fromPos = {x = 401, y = 1044, z = 7}, toPos = {x = 512, y = 1290, z = 7}},
	{fromPos = {x = 1457, y = 401, z = 7}, toPos = {x = 1679, y = 519, z = 7}},
	{fromPos = {x = 721, y = 79, z = 11}, toPos = {x = 738, y = 108, z = 11}},
	{fromPos = {x = 177, y = 342, z = 8}, toPos = {x = 247, y = 390, z = 8}},
	{fromPos = {x = 315, y = 1057, z = 10}, toPos = {x = 494, y = 1126, z = 10}},
	{fromPos = {x = 315, y = 1057, z = 9}, toPos = {x = 494, y = 1126, z = 9}},
	{fromPos = {x = 400, y = 1135, z = 10}, toPos = {x = 572, y = 1295, z = 10}},
	{fromPos = {x = 41, y = 1064, z = 10}, toPos = {x = 310, y = 1231, z = 10}},
	{fromPos = {x = 427, y = 204, z = 8}, toPos = {x = 556, y = 271, z = 8}},
	{fromPos = {x = 523, y = 753, z = 8}, toPos = {x = 602, y = 823, z = 8}},
	{fromPos = {x = 602, y = 794, z = 7}, toPos = {x = 713, y = 866, z = 7}},
	{fromPos = {x = 602, y = 794, z = 6}, toPos = {x = 713, y = 866, z = 6}},
	{fromPos = {x = 602, y = 794, z = 5}, toPos = {x = 713, y = 866, z = 5}},
	{fromPos = {x = 602, y = 794, z = 4}, toPos = {x = 713, y = 866, z = 4}},
	{fromPos = {x = 602, y = 794, z = 3}, toPos = {x = 713, y = 866, z = 3}},
	{fromPos = {x = 1163, y = 546, z = 7}, toPos = {x = 1254, y = 637, z = 7}},
	{fromPos = {x = 1163, y = 546, z = 6}, toPos = {x = 1254, y = 637, z = 6}},
	{fromPos = {x = 1163, y = 546, z = 5}, toPos = {x = 1254, y = 637, z = 5}},
	{fromPos = {x = 322, y = 489, z = 8}, toPos = {x = 428, y = 561, z = 8}},
	{fromPos = {x = 490, y = 761, z = 14}, toPos = {x = 757, y = 952, z = 14}},
	{fromPos = {x = 481, y = 1265, z = 9}, toPos = {x = 511, y = 1292, z = 9}},
}

local function isInNoLootArea(pos)
	for _, area in ipairs(noLootAreas) do
		if pos.z == area.fromPos.z and
		   pos.x >= area.fromPos.x and pos.x <= area.toPos.x and
		   pos.y >= area.fromPos.y and pos.y <= area.toPos.y then
			return true
		end
	end
	return false
end

local function getFreeSlotsFromContainer(item)
    if not item or not item:isContainer() then
        return 0
    end

    local slots = 0
    local containers = {item}

    while #containers > 0 do
        local firstContainer = table.remove(containers, 1)
        local freeInThis = firstContainer:getCapacity() - firstContainer:getSize()
        if freeInThis > 0 then
            slots = slots + freeInThis
        end
        for i = 0, firstContainer:getSize() - 1 do
            local containerItem = firstContainer:getItem(i)
            if containerItem and containerItem:isContainer() then
                table.insert(containers, containerItem)
            end
        end
    end

    return slots
end

local function canCarryItem(player, item)
    if not player or not item then
        return false
    end
    return player:getFreeCapacity() >= item:getWeight()
end

local function moveItemToPlayer(player, item)
    if not player or not item then
        return false
    end

    local backpack = player:getSlotItem(CONST_SLOT_BACKPACK)
    if not backpack or getFreeSlotsFromContainer(backpack) <= 0 then
        return false
    end

    if not canCarryItem(player, item) then
        return false
    end

    return item:moveTo(player)
end

function Monster:onDropLoot(corpse)
    if configManager.getNumber(configKeys.RATE_LOOT) == 0 then
        return
    end

    local pos = self:getPosition()
    if isInNoLootArea(pos) then
        return
    end

    local player = Player(corpse:getCorpseOwner())

    -- Anti-multicliente: extras bloqueados nao recebem loot (storage 20100 = 1)
    if player and player:getStorageValue(20100) == 1 then
        return
    end

    local monsterName = self:getName()
    local isLvl2 = monsterName:find("lvl.2") ~= nil

    if not player or player:getStamina() > 840 then
        local monsterLoot = self:getType():getLoot()
        for i = 1, #monsterLoot do
            local item = corpse:createLootItem(monsterLoot[i])
            if not item then
                print('[Warning] DropLoot:', 'Could not add loot item to corpse.')
            end
        end

        -- Monster Level System: Loot Bonus
        local level = self:getLevel() or 0

        if level > 0 then
            local bonusRate = 0
            if configKeys.MLVL_BONUSLOOT then
                bonusRate = configManager.getNumber(configKeys.MLVL_BONUSLOOT)
            end

            -- Cap bonus rate at 1000%
            if bonusRate > 1000 then 
                bonusRate = 1000 
            end

            if bonusRate > 0 then
                -- Iterate backwards to safely add items if needed
                for i = corpse:getSize() - 1, 0, -1 do
                    local item = corpse:getItem(i)
                    if item then
                        local count = item:getCount()
                        if count > 1 then -- Update only stackable items
                            local extra = math.floor(count * level * (bonusRate / 100))
                            
                            if extra > 0 then
                                local total = count + extra
                                if total <= 100 then
                                    item:transform(item:getId(), total)
                                else
                                    -- Fill current stack to 100
                                    item:transform(item:getId(), 100)
                                    local remainder = total - 100
                                    
                                    -- Add remainder as new items (handling chunks of 100 if necessary)
                                    while remainder > 0 do
                                        local chunk = math.min(100, remainder)
                                        corpse:addItem(item:getId(), chunk)
                                        remainder = remainder - chunk
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if isLvl2 then
            corpse:addItem(12779, math.random(1, 6))
            if math.random(100) <= 50 then
                corpse:addItem(12780, math.random(1, 6))
            end
            doPlayerAddSoul(player, 2)
        end

	if player then
		-- Mod Loot Window Integration
		local lootItemsBuffer = {}
		for i = 0, corpse:getSize() - 1 do
			local item = corpse:getItem(i)
			if item then
				table.insert(lootItemsBuffer, item:getType():getClientId())
				table.insert(lootItemsBuffer, item:getCount())
			end
		end

		if #lootItemsBuffer > 0 then
			player:sendExtendedOpcode(60, table.concat(lootItemsBuffer, "-"))
		end
		-- End Mod Loot Window Integration

		local lootDescription = corpse:getContentDescription()

		if not player:isPremium() then
			local slotsUsed = 0
			for i = AUTOLOOT_STORAGE_START, AUTOLOOT_STORAGE_END do
				if player:getStorageValue(i) > 0 then
					slotsUsed = slotsUsed + 1
				end
			end
			if slotsUsed > 7 then
				for i = AUTOLOOT_STORAGE_START, AUTOLOOT_STORAGE_END do
					player:setStorageValue(i, 0)
				end
				player:sendTextMessage(MESSAGE_STATUS_WARNING, "Você não é mais premium e tinha mais de 7 itens na sua lista de autoloot. Sua lista foi limpa automaticamente.")
			end
		end

		local itemsToLoot = {}
		local autolootNames = {}

		for a = 0, corpse:getSize() - 1 do
			local containerItem = corpse:getItem(a)
			if containerItem then
				for b = AUTOLOOT_STORAGE_START, AUTOLOOT_STORAGE_END do
					if player:getStorageValue(b) == containerItem:getType():getId() then
						table.insert(itemsToLoot, containerItem)
						if containerItem:getCount() > 1 then
							table.insert(autolootNames, containerItem:getCount() .. " " .. containerItem:getName())
						else
							table.insert(autolootNames, containerItem:getName())
						end
						break
					end
				end
			end
		end

		for _, item in ipairs(itemsToLoot) do
			-- autoloot vai pro LOOT BOX; se estiver cheio, cai pro player (fallback)
			if addToLootBox and addToLootBox(player, item:getId(), item:getCount()) then
				item:remove()
			else
				moveItemToPlayer(player, item)
			end
		end

		local text = ("Loot de %s: %s"):format(monsterName, lootDescription)
		if #autolootNames > 0 then
			text = text .. string.format(" (seu autoloot coletou: %s)", table.concat(autolootNames, ", "))
		end

		local party = player:getParty()
		if party then
			party:broadcastPartyLoot(text)
		else
			player:sendTextMessage(MESSAGE_INFO_DESCR, text)
		end
	end
    else
        local text = ("Loot de %s: nada (devido à baixa stamina)"):format(monsterName)
        local party = player and player:getParty()
        if party then
            party:broadcastPartyLoot(text)
        elseif player then
            player:sendTextMessage(MESSAGE_INFO_DESCR, text)
        end
    end
end
