-- Battle Pass XP Boost Item
-- Consumable item that gives 2x EXP for 1 hour

local STORAGE_PASS_BOOST = 80006  -- Stores boost expiration timestamp
local STORAGE_PASS_BOOST_MULTIPLIER = 80007  -- Stores boost multiplier

local XP_BOOST_ITEM_ID = 26391    -- Change this to your item ID
local BOOST_DURATION = 3600       -- 1 hour in seconds
local BOOST_MULTIPLIER = 2        -- 2x EXP

local xpBoostAction = Action()

function xpBoostAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
    local currentBoost = player:getStorageValue(STORAGE_PASS_BOOST)
    local now = os.time()
    
    -- Check if already has active boost
    if currentBoost > now then
        local remaining = currentBoost - now
        local minutes = math.ceil(remaining / 60)
        player:sendTextMessage(MESSAGE_STATUS_SMALL, "Voce ja tem um XP Boost ativo! Tempo restante: " .. minutes .. " minutos.")
        return true
    end
    
    -- Activate boost
    player:setStorageValue(STORAGE_PASS_BOOST, now + BOOST_DURATION)
    player:setStorageValue(STORAGE_PASS_BOOST_MULTIPLIER, BOOST_MULTIPLIER)
    
    -- Remove item
    item:remove(1)
    
    -- Visual effect
    player:getPosition():sendMagicEffect(CONST_ME_MAGIC_GREEN, player)
    
    -- Notification
    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "XP Boost ativado! Voce ganha " .. BOOST_MULTIPLIER .. "x EXP de Battle Pass por " .. (BOOST_DURATION / 60) .. " minutos!")
    
    print("[PassBoost] " .. player:getName() .. " activated XP Boost (2x for 1 hour)")
    
    return true
end

xpBoostAction:id(XP_BOOST_ITEM_ID)
xpBoostAction:register()

-- Helper function to check if player has active boost
function hasPassBoost(player)
    local boostEnd = player:getStorageValue(STORAGE_PASS_BOOST)
    return boostEnd > os.time()
end

-- Helper function to get boost multiplier
function getPassBoostMultiplier(player)
    if not hasPassBoost(player) then
        return 1
    end
    local multiplier = player:getStorageValue(STORAGE_PASS_BOOST_MULTIPLIER)
    return multiplier > 0 and multiplier or 1
end

_G.hasPassBoost = hasPassBoost
_G.getPassBoostMultiplier = getPassBoostMultiplier
_G.STORAGE_PASS_BOOST = STORAGE_PASS_BOOST
