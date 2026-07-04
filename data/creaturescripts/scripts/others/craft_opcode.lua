local CRAFT_OPCODE = 5
local CRAFT_REQUEST_OPCODE = 33

-- =============================================
-- CRAFT RECIPES (configuravel)
-- =============================================

local CRAFT_RECIPES = {
    -- HELMET
    {
        index = 1,
        name = "Dragon Helmet",
        clientId = 2471,
        category = "Helmet",
        requeriments = {
            {itemId = 2160, name = "Crystal Coin", count = 5},
            {itemId = 5880, name = "Iron Ore", count = 10},
        },
        resultId = 2471,
        resultCount = 1
    },
    {
        index = 2,
        name = "Magic Plate Helmet",
        clientId = 2474,
        category = "Helmet",
        requeriments = {
            {itemId = 2160, name = "Crystal Coin", count = 10},
            {itemId = 5880, name = "Iron Ore", count = 20},
        },
        resultId = 2474,
        resultCount = 1
    },
    -- ARMOR
    {
        index = 3,
        name = "Golden Armor",
        clientId = 2466,
        category = "Armor",
        requeriments = {
            {itemId = 2160, name = "Crystal Coin", count = 8},
            {itemId = 5880, name = "Iron Ore", count = 15},
        },
        resultId = 2466,
        resultCount = 1
    },
    {
        index = 4,
        name = "Magic Plate Armor",
        clientId = 2472,
        category = "Armor",
        requeriments = {
            {itemId = 2160, name = "Crystal Coin", count = 15},
            {itemId = 5880, name = "Iron Ore", count = 30},
        },
        resultId = 2472,
        resultCount = 1
    },
    -- LEGS
    {
        index = 5,
        name = "Golden Legs",
        clientId = 2470,
        category = "Legs",
        requeriments = {
            {itemId = 2160, name = "Crystal Coin", count = 7},
            {itemId = 5880, name = "Iron Ore", count = 12},
        },
        resultId = 2470,
        resultCount = 1
    },
    {
        index = 6,
        name = "Dragon Scale Legs",
        clientId = 2469,
        category = "Legs",
        requeriments = {
            {itemId = 2160, name = "Crystal Coin", count = 12},
            {itemId = 5880, name = "Iron Ore", count = 25},
        },
        resultId = 2469,
        resultCount = 1
    },
    -- BOOTS
    {
        index = 7,
        name = "Golden Boots",
        clientId = 2646,
        category = "Boots",
        requeriments = {
            {itemId = 2160, name = "Crystal Coin", count = 6},
            {itemId = 5880, name = "Iron Ore", count = 10},
        },
        resultId = 2646,
        resultCount = 1
    },
    {
        index = 8,
        name = "Boots of Haste",
        clientId = 2195,
        category = "Boots",
        requeriments = {
            {itemId = 2160, name = "Crystal Coin", count = 20},
            {itemId = 5880, name = "Iron Ore", count = 40},
        },
        resultId = 2195,
        resultCount = 1
    },
    -- ELEMENTS
    {
        index = 9,
        name = "Fire Sword",
        clientId = 2392,
        category = "Elements",
        requeriments = {
            {itemId = 2160, name = "Crystal Coin", count = 3},
            {itemId = 5880, name = "Iron Ore", count = 8},
        },
        resultId = 2392,
        resultCount = 1
    },
    {
        index = 10,
        name = "Ice Rapier",
        clientId = 2396,
        category = "Elements",
        requeriments = {
            {itemId = 2160, name = "Crystal Coin", count = 4},
            {itemId = 5880, name = "Iron Ore", count = 10},
        },
        resultId = 2396,
        resultCount = 1
    },
    -- SHIELD
    {
        index = 11,
        name = "Mastermind Shield",
        clientId = 2514,
        category = "Shield",
        requeriments = {
            {itemId = 2160, name = "Crystal Coin", count = 10},
            {itemId = 5880, name = "Iron Ore", count = 20},
        },
        resultId = 2514,
        resultCount = 1
    },
    -- AMULET
    {
        index = 12,
        name = "Amulet of Loss",
        clientId = 2173,
        category = "Amulet",
        requeriments = {
            {itemId = 2160, name = "Crystal Coin", count = 5},
        },
        resultId = 2173,
        resultCount = 1
    },
    -- RING
    {
        index = 13,
        name = "Dwarven Ring",
        clientId = 2213,
        category = "Ring",
        requeriments = {
            {itemId = 2160, name = "Crystal Coin", count = 2},
            {itemId = 5880, name = "Iron Ore", count = 5},
        },
        resultId = 2213,
        resultCount = 1
    },
}


-- Categories list (ORDER matters for client display)
-- Categories list (ORDER matters for client display)
local CATEGORIES = {"Helmet", "Armor", "Legs", "Boots", "Elements", "Shield", "Amulet", "Ring"}

-- =============================================
-- HELPER FUNCTIONS
-- =============================================

local function getRecipeByIndex(index)
    local target = tostring(index)
    -- print("[Debug] getRecipeByIndex searching for: " .. target)
    for k, recipe in pairs(CRAFT_RECIPES) do
        local rIdx = tostring(recipe.index)
        if rIdx == target then
            return recipe
        end
    end
    print("[Craft] Error: Recipe not found for index " .. index)
    return nil
end

local function getClientId(id)
    local it = ItemType(id)
    return it and it:getClientId() or id
end

-- Build items data for client (list of all items with basic info)
local function buildItemsData()
    local items = {}
    for _, recipe in ipairs(CRAFT_RECIPES) do
        table.insert(items, {
            index = recipe.index,
            name = recipe.name,
            clientId = getClientId(recipe.clientId),
            category = recipe.category
        })
    end
    return items
end

-- Build item info for client (detailed info for a single item)
local function buildItemInfo(recipe)
    return {
        index = recipe.index,
        item = getClientId(recipe.clientId),
        name = recipe.name,
        requeriments = (function()
            local reqs = {}
            for _, r in ipairs(recipe.requeriments) do
                table.insert(reqs, {
                    itemId = getClientId(r.itemId),
                    name = r.name,
                    count = r.count
                })
            end
            return reqs
        end)()
    }
end

-- Check if player has all required items
local function hasRequirements(player, recipe)
    for _, req in ipairs(recipe.requeriments) do
        -- Debug: remove this later
        -- print("[Debug] Checking Req: " .. req.name .. " ID: " .. req.itemId .. " Count: " .. req.count .. " PlayerHas: " .. player:getItemCount(req.itemId))
        if player:getItemCount(req.itemId) < req.count then
            return false
        end
    end
    return true
end

-- Remove required items from player
local function removeRequirements(player, recipe)
    for _, req in ipairs(recipe.requeriments) do
        player:removeItem(req.itemId, req.count)
    end
end

-- =============================================
-- OPCODE HANDLER
-- =============================================

function onExtendedOpcode(player, opcode, buffer)
    if opcode ~= CRAFT_REQUEST_OPCODE then
        return true
    end

    local status, data = pcall(function()
        return json.decode(buffer)
    end)

    if not status or not data or not data.type then
        return true
    end

    local action = data.type
    -- print("[Debug] Opcode Action: " .. action)

    -- Send craft window data (categories + items list)
    if action == "craftInfo" then
        player:sendExtendedOpcode(CRAFT_OPCODE, json.encode({
            type = "craftWindow",
            category = CATEGORIES,
            itemsData = buildItemsData()
        }))

    -- Send detailed info for a specific item
    elseif action == "infoCraftItem" then
        local index = data.index -- kept as is, getRecipe will tostring it
        if not index then return true end

        local recipe = getRecipeByIndex(index)
        if not recipe then return true end

        player:sendExtendedOpcode(CRAFT_OPCODE, json.encode({
            type = "itemInfo",
            info = buildItemInfo(recipe)
        }))

    -- Craft an item
    elseif action == "craftItem" then
        local index = data.index
        if not index then return true end

        local recipe = getRecipeByIndex(index)
        if not recipe then
            player:sendTextMessage(MESSAGE_STATUS_SMALL, "Recipe not found.")
            return true
        end

        -- Check requirements
        if not hasRequirements(player, recipe) then
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "You don't have the required materials!")
            return true
        end



        -- Remove materials
        removeRequirements(player, recipe)

        -- Give crafted item
        player:addItem(recipe.resultId, recipe.resultCount)

        -- Effects
        player:getPosition():sendMagicEffect(CONST_ME_MAGIC_GREEN, player)
        player:sendTextMessage(MESSAGE_INFO_DESCR, "You crafted: " .. recipe.name .. "!")

        -- Refresh item info (to update UI)
        player:sendExtendedOpcode(CRAFT_OPCODE, json.encode({
            type = "itemInfo",
            info = buildItemInfo(recipe)
        }))
    end

    return true
end
