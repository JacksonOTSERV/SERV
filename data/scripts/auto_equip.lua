-- Auto Equip System
-- Double right-click on items in bag to auto-equip them

local OPCODE_AUTOEQUIP = 34

-- Inventory slot IDs
local SLOT_HEAD = 1
local SLOT_NECKLACE = 2
local SLOT_BACKPACK = 3
local SLOT_ARMOR = 4
local SLOT_RIGHT = 5   -- Right hand (weapons)
local SLOT_LEFT = 6    -- Left hand (shields/two-handed)
local SLOT_LEGS = 7
local SLOT_FEET = 8
local SLOT_RING = 9
local SLOT_AMMO = 10

-- Weapon types
local WEAPON_NONE = 0
local WEAPON_SWORD = 1
local WEAPON_CLUB = 2
local WEAPON_AXE = 3
local WEAPON_SHIELD = 4
local WEAPON_DISTANCE = 5
local WEAPON_WAND = 6
local WEAPON_AMMO = 7

-- Map item to correct slot based on TFS source code getSlotType function
-- Only allows: Head, Necklace, Armor, Legs, Feet, Ring, Shield, Weapons
local function getSlotFromItem(itemType)
    local weaponType = itemType:getWeaponType()
    local slotPosition = itemType:getSlotPosition()
    
    -- Shields go to RIGHT hand (slot 5)
    if weaponType == WEAPON_SHIELD then
        return SLOT_RIGHT
    end
    
    -- Equipment slots only
    if bit.band(slotPosition, 1) ~= 0 then return SLOT_HEAD end       -- Helmet
    if bit.band(slotPosition, 2) ~= 0 then return SLOT_NECKLACE end   -- Amulet
    if bit.band(slotPosition, 8) ~= 0 then return SLOT_ARMOR end      -- Armor
    if bit.band(slotPosition, 64) ~= 0 then return SLOT_LEGS end      -- Legs
    if bit.band(slotPosition, 128) ~= 0 then return SLOT_FEET end     -- Boots
    if bit.band(slotPosition, 256) ~= 0 then return SLOT_RING end     -- Ring
    
    -- Two-handed or left hand slot goes to LEFT (slot 6)
    if bit.band(slotPosition, 4096) ~= 0 or bit.band(slotPosition, 32) ~= 0 then
        return SLOT_LEFT
    end
    
    -- Weapons go to LEFT (slot 6)
    if weaponType == WEAPON_SWORD or weaponType == WEAPON_CLUB or 
       weaponType == WEAPON_AXE or weaponType == WEAPON_DISTANCE or
       weaponType == WEAPON_WAND then
        return SLOT_LEFT
    end
    
    -- Everything else (ammo, backpack, stackables, etc) - NOT EQUIPABLE via auto-equip
    return nil
end

local function autoEquipItem(player, data)
    if not player or not data then
        return false
    end
    
    local containerId = tonumber(data.containerId)
    local slotId = tonumber(data.slotId)
    
    if containerId == nil or slotId == nil then
        player:sendTextMessage(MESSAGE_STATUS_SMALL, "Invalid item position.")
        return false
    end
    
    local container = player:getContainerById(containerId)
    if not container then
        player:sendTextMessage(MESSAGE_STATUS_SMALL, "Container not found.")
        return false
    end
    
    local item = container:getItem(slotId)
    if not item then
        player:sendTextMessage(MESSAGE_STATUS_SMALL, "Item not found.")
        return false
    end
    
    local itemType = ItemType(item:getId())
    if not itemType then
        player:sendTextMessage(MESSAGE_STATUS_SMALL, "Invalid item type.")
        return false
    end
    
    local targetSlot = getSlotFromItem(itemType)
    if not targetSlot then
        player:sendTextMessage(MESSAGE_STATUS_SMALL, "This item cannot be equipped.")
        return false
    end
    
    local equippedItem = player:getSlotItem(targetSlot)
    local itemId = item:getId()
    local itemCount = item:getCount()
    
    if equippedItem then
        local equippedId = equippedItem:getId()
        local equippedCount = equippedItem:getCount()
        
        item:remove()
        equippedItem:remove()
        
        local newEquipped = player:addItem(itemId, itemCount, false, 1, targetSlot)
        container:addItem(equippedId, equippedCount)
        
        if newEquipped then
            return true
        else
            container:addItem(itemId, itemCount)
            player:addItem(equippedId, equippedCount, false, 1, targetSlot)
            player:sendTextMessage(MESSAGE_STATUS_SMALL, "Failed to equip.")
            return false
        end
    else
        item:remove()
        local equipped = player:addItem(itemId, itemCount, false, 1, targetSlot)
        
        if equipped then
            return true
        else
            container:addItem(itemId, itemCount)
            player:sendTextMessage(MESSAGE_STATUS_SMALL, "Failed to equip.")
            return false
        end
    end
end

local autoEquipEvent = CreatureEvent("AutoEquipOpcode")

function autoEquipEvent.onExtendedOpcode(player, opcode, buffer)
    if opcode ~= OPCODE_AUTOEQUIP then
        return false
    end
    
    local status, data = pcall(function() return json.decode(buffer) end)
    if not status or not data then
        return false
    end
    
    if data.type == "autoEquip" then
        autoEquipItem(player, data)
    end
    
    return true
end

autoEquipEvent:register()
