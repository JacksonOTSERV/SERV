-- Server-side Autoloot Opcode Handler

-- Load JSON library
local json = nil
pcall(function()
    json = dofile('data/lib/json.lua')
end)

if not json then
    print("[Error - AutolootOpcode] Could not load 'data/lib/json.lua'. Please ensure the file exists.")
end

local function getPlayerAutoLootList(player)
    local list = {}
    local startStorage = 10000
    local endStorage = 10010 
    if AUTOLOOT_STORAGE_START then startStorage = AUTOLOOT_STORAGE_START end
    if AUTOLOOT_STORAGE_END then endStorage = AUTOLOOT_STORAGE_END end

    for i = startStorage, endStorage do
        local itemId = player:getStorageValue(i)
        if itemId > 0 then
            local itemType = ItemType(itemId)
            if itemType then
                table.insert(list, itemType:getName():lower())
            end
        end
    end
    return table.concat(list, "\n")
end

function onExtendedOpcode(player, opcode, buffer)
    if not json then return false end

    if opcode == 33 then
        local status, json_data = pcall(function() return json.decode(buffer) end)
        if not status or type(json_data) ~= 'table' then return false end

        if json_data.type == "openAutoloot" then
            local lootList = getPlayerAutoLootList(player)
            local currentStatus = "On"
            local currentCollect = "Bank"
            
            local response = {
                type = "openAutoloot",
                list = lootList,
                status = currentStatus, 
                collect = currentCollect
            }
            player:sendExtendedOpcode(9, json.encode(response))
        elseif json_data.type == "autolootchangeStatus" then
             -- Handler place holder
        elseif json_data.type == "autolootchangeCollect" then
             -- Handler place holder
        end
    end
    return true
end
