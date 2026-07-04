local invalidIds = {
	1, 2, 3, 4, 5, 6, 7, 10, 11, 13, 14, 15, 19, 21, 26, 27, 28, 35, 43
}

function onSay(player, words, param)
	if not player:getGroup():getAccess() then
		return true
	end

	if param == "" then
		player:sendCancelMessage("Command param required.")
		return false
	end

	local split = param:splitTrimmed(",")
	local itemName = split[1]
	local count = 1

	-- Determine count logic
	if #split > 1 then
		-- Explicit comma separation: /i name, count
		count = tonumber(split[2]) or 1
	else
		-- No comma: /i name [count]
		-- First, try the full string as item name
		local testItemType = ItemType(itemName)
		if testItemType:getId() == 0 then
			-- Full string invalid, try to check if last part is a count number
			local lastSpace = itemName:match("^.*()%s%d+$")
			if lastSpace then
				local possibleCount = tonumber(itemName:sub(lastSpace + 1))
				local possibleName = itemName:sub(1, lastSpace - 1)
				local possibleType = ItemType(possibleName)
				
				if possibleType:getId() ~= 0 then
					-- Found valid item by stripping number!
					count = possibleCount
					itemName = possibleName
				end
			end
		end
	end

	local itemType = ItemType(itemName)
	if itemType:getId() == 0 then
		itemType = ItemType(tonumber(itemName))
		if not tonumber(itemName) or itemType:getId() == 0 then
			player:sendCancelMessage("There is no item with that id or name.")
			return false
		end
	end

	if table.contains(invalidIds, itemType:getId()) then
		return false
	end

	if count then
		if itemType:isStackable() then
			count = math.min(10000, math.max(1, count))
		elseif not itemType:isFluidContainer() then
			count = math.min(100, math.max(1, count))
		else
			count = math.max(0, count)
		end
	else
		count = 1
	end

	local result = player:addItem(itemType:getId(), count)
	if result then
		if not itemType:isStackable() then
			if type(result) == "table" then
				for _, item in ipairs(result) do
					item:decay()
				end
			else
				result:decay()
			end
		end
		player:getPosition():sendMagicEffect(CONST_ME_MAGIC_RED, player)
	else
		player:sendCancelMessage("Could not create item.")
	end
	return false
end
