transformationOutfits = {
    ["Tapion"]      = {name = "Tapion",       lookType = 1211, vocationId = 14},
    ["Chilled"]     = {name = "Chilled",      lookType = 1155, vocationId = 15},
    ["Kagome"]      = {name = "Kagome",       lookType = 1163, vocationId = 16},
    ["Zaiko"]       = {name = "Zaiko",        lookType = 1229, vocationId = 17},
    ["King Vegeta"] = {name = "King Vegeta",  lookType = 1180, vocationId = 18},
    ["Vegetto"]     = {name = "Vegetto",      lookType = 1217, vocationId = 19},
    ["Kame"]        = {name = "Kame",         lookType = 1175, vocationId = 20},
    ["Shenron"]     = {name = "Shenron",      lookType = 1197, vocationId = 21},
    ["Goku Black"]  = {name = "Goku Black",   lookType = 651, vocationId = 23},
    ["Zamasu"]      = {name = "Zamasu",       lookType = 1110, vocationId = 24},
    ["Jiren"]       = {name = "Jiren",        lookType = 1001, vocationId = 25}
}

function onUse(player, item, fromPosition, target, toPosition)
    local itemName = item:getAttribute(ITEM_ATTRIBUTE_NAME)
    if not itemName then
        return true
    end

    local vocationName = itemName:match("Scroll contendo a vocation:%s*(.+)")
    if not vocationName then
        return true
    end

    local data = transformationOutfits[vocationName]
    if not data then
        return true
    end

    local vocationId = data.vocationId
    local lookType = data.lookType
    local currentVocationName = player:getVocation():getName()

    if vocationOutfits[currentVocationName] then
        for _, outfitData in pairs(vocationOutfits[currentVocationName]) do
            if type(outfitData) == "table" and player:hasOutfit(outfitData.id) then
                player:removeOutfit(outfitData.id)
            end
        end
    end

    doPlayerSetVocation(player, vocationId)
    doCreatureChangeOutfit(player, {lookType = lookType})
    player:setStorageValue(14389, lookType)

    local newVocationName = player:getVocation():getName()
    if vocationOutfits[newVocationName] then
        local playerLevel = player:getLevel()
        for level, outfitData in pairs(vocationOutfits[newVocationName]) do
            if type(outfitData) == "table" and playerLevel >= level and not player:hasOutfit(outfitData.id) then
                player:addOutfit(outfitData.id)
            end
        end
    end
	
	local weaponLeft = player:getSlotItem(CONST_SLOT_LEFT)
	local weaponRight = player:getSlotItem(CONST_SLOT_RIGHT)
	if weaponLeft and weaponLeft:getId() == 13603 then
		weaponLeft:remove()
	end

	if weaponRight and weaponRight:getId() == 13603 then
		weaponRight:remove()
	end

    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Você foi transformado em " .. data.name .. "!")

    item:remove(1)
    return true
end