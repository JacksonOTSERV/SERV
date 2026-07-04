-- MyMarket Server Script
-- Player-to-player market system

local OPCODE_MYMARKET = 35

-- Create database table if not exists
do
    db.query([[
        CREATE TABLE IF NOT EXISTS `mymarket_offers` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `player_id` INT NOT NULL,
            `player_name` VARCHAR(255) NOT NULL,
            `item_id` INT NOT NULL,
            `item_count` INT NOT NULL DEFAULT 1,
            `price` BIGINT NOT NULL,
            `created_at` BIGINT NOT NULL,
            PRIMARY KEY (`id`)
        );
    ]])
    
    db.query([[
        CREATE TABLE IF NOT EXISTS `mymarket_history` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `seller_id` INT NOT NULL,
            `seller_name` VARCHAR(255) NOT NULL,
            `buyer_id` INT NOT NULL,
            `buyer_name` VARCHAR(255) NOT NULL,
            `item_id` INT NOT NULL,
            `item_count` INT NOT NULL DEFAULT 1,
            `price` BIGINT NOT NULL,
            `tax` BIGINT NOT NULL DEFAULT 0,
            `state` TINYINT NOT NULL DEFAULT 1 COMMENT '1=Sold, 2=Cancelled',
            `timestamp` BIGINT NOT NULL,
            PRIMARY KEY (`id`)
        );
    ]])
    
    -- Migration: Check if timestamp column exists using SHOW COLUMNS (more reliable)
    local check = db.storeQuery("SHOW COLUMNS FROM `mymarket_history` LIKE 'timestamp'")
    if check then
        result.free(check)
    else
        print(">> MyMarket: Adding missing columns to mymarket_history table...")
        db.query("ALTER TABLE `mymarket_history` ADD COLUMN `timestamp` BIGINT NOT NULL DEFAULT 0;")
        db.query("ALTER TABLE `mymarket_history` ADD COLUMN `tax` BIGINT NOT NULL DEFAULT 0;")
        db.query("ALTER TABLE `mymarket_history` ADD COLUMN `state` TINYINT NOT NULL DEFAULT 1;")
    end
    
    -- Migration: Check for legacy 'created_at' column and remove it (fixing 'default value' error)
    local checkLegacy = db.storeQuery("SHOW COLUMNS FROM `mymarket_history` LIKE 'created_at'")
    if checkLegacy then
        print(">> MyMarket: Dropping legacy 'created_at' column from mymarket_history table...")
        db.query("ALTER TABLE `mymarket_history` DROP COLUMN `created_at`;")
        result.free(checkLegacy)
    end
end

local function sendJSON(player, data)
    local msg = json.encode(data)
    player:sendExtendedOpcode(OPCODE_MYMARKET, msg)
end

local function getPlayerGUIDByName(name)
    if not name or name == "" then return nil end
    
    local query = db.storeQuery("SELECT `id` FROM `players` WHERE `name` = " .. db.escapeString(name))
    if query then
        local guid = result.getNumber(query, "id")
        result.free(query)
        return guid
    end
    return nil
end

local function giveItemToPlayer(player, itemId, count)
    -- Try adding to inventory
    local item = player:addItem(itemId, count)
    if item then
        return true
    end
    
    -- If inventory full, try Depot
    local townId = player:getTown():getId()
    local depot = player:getDepotChest(townId, true)
    if not depot then
        -- Fallback to Depot 1 (default)
        depot = player:getDepotChest(1, true)
    end
    
    if depot then
        local depotItem = depot:addItem(itemId, count)
        if depotItem then
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Backpack full. Item sent to your Depot.")
            return true
        end
    end
    
    return false
end

local function getItemNameById(itemId)
    local itemType = ItemType(itemId)
    if itemType then
        return itemType:getName()
    end
    return "Item #" .. itemId
end

local function getAllOffers()
    local offers = {}
    local query = db.storeQuery("SELECT * FROM `mymarket_offers` ORDER BY `created_at` DESC LIMIT 100")
    if query then
        repeat
            local sid = result.getNumber(query, "item_id")
            local cid = sid
            local itType = ItemType(sid)
            if itType and itType.getClientId and itType:getClientId() > 0 then
                cid = itType:getClientId()
            end
            
            local offer = {
                id = result.getNumber(query, "id"),
                playerId = result.getNumber(query, "player_id"),
                seller = result.getString(query, "player_name"),
                itemId = cid, -- Send Client ID for display
                count = result.getNumber(query, "item_count"),
                price = result.getNumber(query, "price"),
                createdAt = result.getNumber(query, "created_at")
            }
            offer.itemName = getItemNameById(sid) -- Get name from Server ID
            table.insert(offers, offer)
        until not result.next(query)
        result.free(query)
    end
    return offers
end

local function getPlayerOffers(playerId)
    local offers = {}
    local query = db.storeQuery("SELECT * FROM `mymarket_offers` WHERE `player_id` = " .. playerId .. " ORDER BY `created_at` DESC")
    if query then
        repeat
            local sid = result.getNumber(query, "item_id")
            local cid = sid
            local itType = ItemType(sid)
            if itType and itType.getClientId and itType:getClientId() > 0 then
                cid = itType:getClientId()
            end
            
            local offer = {
                id = result.getNumber(query, "id"),
                playerId = result.getNumber(query, "player_id"),
                seller = result.getString(query, "player_name"),
                itemId = cid, -- Send Client ID for display
                count = result.getNumber(query, "item_count"),
                price = result.getNumber(query, "price"),
                createdAt = result.getNumber(query, "created_at")
            }
            offer.itemName = getItemNameById(sid) -- Get name from Server ID
            table.insert(offers, offer)
        until not result.next(query)
        result.free(query)
    end
    return offers
end

local function createOffer(player, itemId, itemCount, price, data)
    -- Find item in player's inventory
    local item = nil
    local container = nil
    local slot = nil
    
    -- Search in backpack
    for i = 0, 15 do
        local c = player:getContainerById(i)
        if c then
            for s = 0, c:getSize() - 1 do
                local it = c:getItem(s)
                if it then
                    local match = false
                    local itemType = ItemType(it:getId())
                    
                    -- Check exact ID
                    if it:getId() == itemId then
                        match = true
                        print("Matched item by ID: " .. it:getId())
                    -- Check Client ID (workaround for custom items)
                    elseif itemType and itemType.getClientId and itemType:getClientId() == itemId then
                         match = true
                         itemId = it:getId()
                         print("Matched item by ClientID: " .. itemId)
                    -- Check Name (fallback)
                    elseif data and data.itemName and data.itemName ~= "" and it:getName():lower() == data.itemName:lower() then
                         match = true
                         itemId = it:getId()
                         print("Matched item by name: " .. it:getName())
                    end
                    
                    if match and it:getCount() >= itemCount then
                        item = it
                        container = c
                        slot = s
                        break
                    end
                end
            end
        end
        if item then break end
    end
    
    if not item then
        sendJSON(player, {action = "error", data = "Item not found in your inventory."})
        return false
    end
    
    -- Remove item from inventory
    if item:getCount() > itemCount then
        item:remove(itemCount)
    else
        item:remove()
    end
    
    -- Create offer in database
    local playerId = player:getGuid()
    local playerName = player:getName()
    local createdAt = os.time()
    
    db.query(string.format(
        "INSERT INTO `mymarket_offers` (`player_id`, `player_name`, `item_id`, `item_count`, `price`, `created_at`) VALUES (%d, %s, %d, %d, %d, %d)",
        playerId, db.escapeString(playerName), itemId, itemCount, price, createdAt
    ))
    
    sendJSON(player, {action = "success", data = "Item listed for sale!"})
    return true
end

local function buyOffer(player, offerId)
    -- Get offer details
    local query = db.storeQuery("SELECT * FROM `mymarket_offers` WHERE `id` = " .. offerId)
    if not query then
        sendJSON(player, {action = "error", data = "Offer not found."})
        return false
    end
    
    local sellerId = result.getNumber(query, "player_id")
    local sellerName = result.getString(query, "player_name")
    local itemId = result.getNumber(query, "item_id")
    local itemCount = result.getNumber(query, "item_count")
    local price = result.getNumber(query, "price")
    result.free(query)
    
    -- Check if player is trying to buy their own item
    if player:getGuid() == sellerId then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, "You cannot buy your own items.")
        sendJSON(player, {action = "error", data = "You cannot buy your own items."})
        return false
    end
    
    -- Check if player has enough money
    if player:getMoney() < price then
        sendJSON(player, {action = "error", data = "You don't have enough gold."})
        return false
    end
    
    -- Check if player can carry the item
    local itemType = ItemType(itemId)
    if not itemType then
        sendJSON(player, {action = "error", data = "Invalid item."})
        return false
    end
    
    -- Remove money from buyer
    if not player:removeMoney(price) then
        sendJSON(player, {action = "error", data = "You don't have enough gold."})
        return false
    end
    
    -- Give item to buyer
    if not giveItemToPlayer(player, itemId, itemCount) then
        -- Refund money if failed
        player:addMoney(price)
        sendJSON(player, {action = "error", data = "Not enough space in Inventory or Depot."})
        return false
    end
    
    -- Calculate Tax (1%)
    local tax = math.ceil(price * 0.01)
    local sellerReceive = price - tax
    
    -- Give money to seller (if online) or store for later
    local seller = Player(sellerName)
    if seller then
        seller:addMoney(sellerReceive)
        seller:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Your item was sold for " .. price .. " gold! Tax: " .. tax .. " gold.")
    else
        -- Add to player's bank balance in database
        db.query("UPDATE `players` SET `balance` = `balance` + " .. sellerReceive .. " WHERE `id` = " .. sellerId)
    end
    
    -- Log to History
    local timestamp = os.time()
    db.query(string.format(
        "INSERT INTO `mymarket_history` (`seller_id`, `seller_name`, `buyer_id`, `buyer_name`, `item_id`, `item_count`, `price`, `tax`, `state`, `timestamp`) VALUES (%d, %s, %d, %s, %d, %d, %d, %d, 1, %d)",
        sellerId, db.escapeString(sellerName), player:getGuid(), db.escapeString(player:getName()), itemId, itemCount, price, tax, timestamp
    ))
    
    -- Remove offer from database
    db.query("DELETE FROM `mymarket_offers` WHERE `id` = " .. offerId)
    
    sendJSON(player, {action = "success", data = "Item purchased successfully! Tax paid by seller."})
    return true
end

local function cancelOffer(player, offerId)
    -- Get offer details
    local query = db.storeQuery("SELECT * FROM `mymarket_offers` WHERE `id` = " .. offerId .. " AND `player_id` = " .. player:getGuid())
    if not query then
        sendJSON(player, {action = "error", data = "Offer not found or not yours."})
        return false
    end
    
    local itemId = result.getNumber(query, "item_id")
    local itemCount = result.getNumber(query, "item_count")
    local price = result.getNumber(query, "price")
    result.free(query)
    
    -- Return item to player
    if not giveItemToPlayer(player, itemId, itemCount) then
        sendJSON(player, {action = "error", data = "Cannot return item: Inventory and Depot full."})
        return false
    end
    
    -- Log to History (Cancelled)
    local timestamp = os.time()
    local sellerId = player:getGuid()
    local sellerName = player:getName()
    
    db.query(string.format(
        "INSERT INTO `mymarket_history` (`seller_id`, `seller_name`, `buyer_id`, `buyer_name`, `item_id`, `item_count`, `price`, `tax`, `state`, `timestamp`) VALUES (%d, %s, %d, %s, %d, %d, %d, 0, 2, %d)",
        sellerId, db.escapeString(sellerName), sellerId, db.escapeString(sellerName), itemId, itemCount, price, timestamp
    ))

    -- Remove offer from database
    db.query("DELETE FROM `mymarket_offers` WHERE `id` = " .. offerId)
    
    sendJSON(player, {action = "success", data = "Offer cancelled. Item returned."})
    return true
end

local function getHistory(playerId)
    local history = {}
    local query = db.storeQuery("SELECT * FROM `mymarket_history` WHERE `seller_id` = " .. playerId .. " OR `buyer_id` = " .. playerId .. " ORDER BY `timestamp` DESC LIMIT 50")
    if query then
        repeat
            local sid = result.getNumber(query, "item_id")
            local cid = sid
            local itType = ItemType(sid)
            if itType and itType.getClientId and itType:getClientId() > 0 then
                cid = itType:getClientId()
            end

            local entry = {
                id = result.getNumber(query, "id"),
                seller = result.getString(query, "seller_name"),
                buyer = result.getString(query, "buyer_name"),
                itemId = cid,
                count = result.getNumber(query, "item_count"),
                price = result.getNumber(query, "price"),
                state = result.getNumber(query, "state"),
                timestamp = result.getNumber(query, "timestamp")
            }
            entry.itemName = getItemNameById(sid)
            table.insert(history, entry)
        until not result.next(query)
        result.free(query)
    end
    return history
end

local function getAdminHistory(targetName)
    local history = {}
    local targetId = getPlayerGUIDByName(targetName)
    if not targetId then return {} end
    
    local query = db.storeQuery("SELECT * FROM `mymarket_history` WHERE `seller_id` = " .. targetId .. " OR `buyer_id` = " .. targetId .. " ORDER BY `timestamp` DESC LIMIT 100")
    if query then
        repeat
             local sid = result.getNumber(query, "item_id")
            local cid = sid
            local itType = ItemType(sid)
            if itType and itType.getClientId and itType:getClientId() > 0 then
                cid = itType:getClientId()
            end

            local entry = {
                id = result.getNumber(query, "id"),
                seller = result.getString(query, "seller_name"),
                buyer = result.getString(query, "buyer_name"),
                itemId = cid,
                count = result.getNumber(query, "item_count"),
                price = result.getNumber(query, "price"),
                state = result.getNumber(query, "state"),
                timestamp = result.getNumber(query, "timestamp")
            }
            entry.itemName = getItemNameById(sid)
            table.insert(history, entry)
        until not result.next(query)
        result.free(query)
    end
    return history
end

local function handleMyMarketAction(player, action, data)
    if action == "fetch" then
        local offers = getAllOffers()
        local balance = 0
        if player.getBankBalance then
             balance = player:getBankBalance() + player:getMoney()
        else
             balance = player:getMoney()
        end
        local isAdmin = player:getGroup():getId() >= 3
        sendJSON(player, {action = "offers", data = offers, balance = balance, isAdmin = isAdmin})
        
    elseif action == "myoffers" then
        local offers = getPlayerOffers(player:getGuid())
        sendJSON(player, {action = "myoffers", data = offers})
        
    elseif action == "history" then
        local history = getHistory(player:getGuid())
        sendJSON(player, {action = "history", data = history})
        
    elseif action == "admin_history" then
        if player:getGroup():getId() >= 3 then -- Check for Admin Access (Group 3+)
            local targetName = data.name
            local history = getAdminHistory(targetName)
            sendJSON(player, {action = "history", data = history})
        else
             sendJSON(player, {action = "error", data = "Access denied."})
        end


    elseif action == "sell" then
        local itemId = tonumber(data.itemId)
        local count = tonumber(data.count) or 1
        local price = tonumber(data.price)
        
        if not itemId or not price or price <= 0 then
            sendJSON(player, {action = "error", data = "Invalid item or price."})
            return
        end
        
        -- Block selling currency
        if itemId == 2148 or itemId == 2152 or itemId == 2160 or 
           itemId == 3031 or itemId == 3035 or itemId == 3043 then
            sendJSON(player, {action = "error", data = "You cannot sell money."})
            return
        end
        
        createOffer(player, itemId, count, price, data)
        
    elseif action == "buy" then
        local offerId = tonumber(data.offerId)
        if not offerId then
            sendJSON(player, {action = "error", data = "Invalid offer."})
            return
        end
        
        buyOffer(player, offerId)
        
    elseif action == "cancel" then
        -- ... existing cancel logic
        local offerId = tonumber(data.offerId)
        if not offerId then
            sendJSON(player, {action = "error", data = "Invalid offer."})
            return
        end
        
        cancelOffer(player, offerId)
    end
end

-- Extended opcode event
local mymarketEvent = CreatureEvent("MyMarketOpcode")

function mymarketEvent.onExtendedOpcode(player, opcode, buffer)
    if opcode ~= OPCODE_MYMARKET then
        return false
    end
    
    local status, jsonData = pcall(function() return json.decode(buffer) end)
    if not status or not jsonData then
        return false
    end
    
    local action = jsonData.action
    local data = jsonData.data
    
    handleMyMarketAction(player, action, data)
    return true
end

mymarketEvent:register()

-- Login event to register opcode handler
local mymarketLogin = CreatureEvent("MyMarketLogin")
mymarketLogin:type("login")

function mymarketLogin.onLogin(player)
    player:registerEvent("MyMarketOpcode")
    return true
end

mymarketLogin:register()
