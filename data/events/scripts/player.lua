local playerLookCooldown = {}

local COOLDOWN_TIME = 5

function Player:onLook(thing, position, distance)
    local description = ""
    if thing:isPlayer() then
        local STORAGE_LANGUAGE = 45001
        local isEnglish = (self:getStorageValue(STORAGE_LANGUAGE) == 1)
        
        -- Nome / Voce mesmo
        if thing:getId() == self:getId() then
            if isEnglish then
                description = "You see yourself."
            else
                description = "Voc� v� voc� mesmo."
            end
        else
            if isEnglish then
                 description = "You see " .. thing:getName() .. " (Level " .. thing:getLevel() .. ")."
            else
                 description = "Voc� v� " .. thing:getName() .. " (Level " .. thing:getLevel() .. ")."
            end
        end
        
        -- Vocacao
        local pronome = ""
        if thing:getId() == self:getId() then 
            if isEnglish then pronome = "You" else pronome = "Voc�" end
        else
            if thing:getSex() == 0 then
               if isEnglish then pronome = "She" else pronome = "Ela" end
            else
               if isEnglish then pronome = "He" else pronome = "Ele" end
            end
        end
        
        local vocName = thing:getVocation():getName()
        
        if isEnglish then
            if thing:getId() == self:getId() then
                description = description .. " You are a " .. vocName .. "."
            else
                description = description .. " " .. pronome .. " is a " .. vocName .. "."
            end
        else
            description = description .. " " .. pronome .. " � um " .. vocName .. "."
        end
        
        -- Guilda (Consulta Direta ao Banco de Dados)
        local query = "SELECT g.name as gname, r.name as rname FROM guild_membership m LEFT JOIN guilds g ON g.id = m.guild_id LEFT JOIN guild_ranks r ON r.id = m.rank_id WHERE m.player_id = " .. thing:getGuid()
        local resultId = db.storeQuery(query)
        local gname = ""
        local rname = ""
        local rnameEN = "" -- Store original for potential logic
        
        if resultId ~= false then
            gname = result.getString(resultId, "gname")
            rname = result.getString(resultId, "rname")
            rnameEN = rname
            result.free(resultId)
        else
            local ownerCheck = db.storeQuery("SELECT name FROM guilds WHERE ownerid = " .. thing:getGuid())
            if ownerCheck ~= false then
                 gname = result.getString(ownerCheck, "name")
                 rname = "Leader"
                 rnameEN = "Leader"
                 result.free(ownerCheck)
            end
        end
        
        if gname ~= "" then
            if isEnglish then
                local finalRank = rnameEN
                if finalRank == "Leader" then finalRank = "Leader" end -- Just to be sure
                
                if thing:getId() == self:getId() then
                    description = description .. " You are the " .. finalRank .. " of the Guild " .. gname .. "."
                else
                    description = description .. " " .. pronome .. " is the " .. finalRank .. " of the Guild " .. gname .. "."
                end
            else
                -- Portugues
                -- Translation Logic
                local finalRank = rname
                if rname == "Leader" or rname == "the Leader" then 
                    finalRank = "o L�der"
                elseif rname == "Vice-Leader" then
                    finalRank = "o Vice-L�der"
                elseif rname == "Member" then
                    finalRank = "Membro"
                end
                
                if thing:getId() == self:getId() then
                     description = description .. " Voc� � " .. finalRank .. " da Guilda " .. gname .. "."
                else
                     description = description .. " " .. pronome .. " � " .. finalRank .. " da Guilda " .. gname .. "."
                end
            end
        end
        
        self:sendTextMessage(MESSAGE_INFO_DESCR, description)
        return false
    end
    return true
end


function Player:onSay(words, type)
    -- Cooldown is now sent from individual spell scripts after successful execution
    return true
end

-- Slot validation on item movement
-- Inventory slot IDs
local SLOT_HEAD = 1
local SLOT_NECKLACE = 2
local SLOT_BACKPACK = 3
local SLOT_ARMOR = 4
local SLOT_RIGHT = 5
local SLOT_LEFT = 6
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

-- Check if item can be placed in the specified slot
-- NOTE: In this server, slot 5 = SHIELD slot, slot 6 = WEAPON slot
local function canItemGoToSlot(item, toSlot)
    local itemType = ItemType(item:getId())
    if not itemType then
        return true -- Allow if we can't check
    end
    
    local weaponType = itemType:getWeaponType()
    local slotPosition = itemType:getSlotPosition()
    
    -- Check based on destination slot
    if toSlot == SLOT_HEAD then
        return bit.band(slotPosition, 1) ~= 0 -- SLOTP_HEAD
    elseif toSlot == SLOT_NECKLACE then
        return bit.band(slotPosition, 2) ~= 0 -- SLOTP_NECKLACE
    elseif toSlot == SLOT_BACKPACK then
        return bit.band(slotPosition, 4) ~= 0 -- SLOTP_BACKPACK
    elseif toSlot == SLOT_ARMOR then
        return bit.band(slotPosition, 8) ~= 0 -- SLOTP_ARMOR
    elseif toSlot == SLOT_RIGHT then
        -- Slot 5 = SHIELD slot - ONLY shields can go here
        if weaponType == WEAPON_SHIELD then 
            return true 
        end
        return false
    elseif toSlot == SLOT_LEFT then
        -- Slot 6 = WEAPON slot - only weapons can go here
        if weaponType == WEAPON_SWORD or weaponType == WEAPON_CLUB or 
           weaponType == WEAPON_AXE or weaponType == WEAPON_DISTANCE or
           weaponType == WEAPON_WAND then
            return true
        end
        -- Also allow two-handed items
        if bit.band(slotPosition, 4096) ~= 0 then return true end -- SLOTP_TWO_HAND
        return false
    elseif toSlot == SLOT_LEGS then
        return bit.band(slotPosition, 64) ~= 0 -- SLOTP_LEGS
    elseif toSlot == SLOT_FEET then
        return bit.band(slotPosition, 128) ~= 0 -- SLOTP_FEET
    elseif toSlot == SLOT_RING then
        return bit.band(slotPosition, 256) ~= 0 -- SLOTP_RING
    elseif toSlot == SLOT_AMMO then
        return bit.band(slotPosition, 512) ~= 0 or weaponType == WEAPON_AMMO -- SLOTP_AMMO
    end
    
    return true
end

-- Stream 5% exp bonus + anti-multicliente
---@diagnostic disable-next-line: duplicate-set-field
function Player:onGainExperience(_source, exp, _rawExp)
    -- Anti-multicliente: extras nao ganham exp (storage 20100 = 1)
    if self:getStorageValue(20100) == 1 then
        return 0
    end
    -- Stream 5% bonus sem senha (storage 20000 = 1)
    if self:getStorageValue(20000) == 1 then
        exp = math.floor(exp * 1.05)
    end
    return exp
end

function Player:onMoveItem(item, count, fromPos, toPos, fromCylinder, toCylinder)
    -- Check if moving to inventory slot (toPos.x == 0xFFFF and toPos.y is slot number)
    if toPos.x == 65535 and toPos.y >= 1 and toPos.y <= 10 then
        local targetSlot = toPos.y

        if not canItemGoToSlot(item, targetSlot) then
            self:sendTextMessage(MESSAGE_STATUS_SMALL, "You cannot equip this item in that slot.")
            return false
        end
    end

    -- Loot Box: depot chest do loot box nao tem posicao no mapa, entao o update
    -- incremental nao chega ao cliente. Reenvia o container apos o drop.
    if isLootBoxContainer and (isLootBoxContainer(toCylinder) or isLootBoxContainer(fromCylinder)) then
        local pid = self:getId()
        addEvent(function()
            local p = Player(pid)
            if p and resyncLootBox then resyncLootBox(p) end
        end, 50)
    end

    return true
end
