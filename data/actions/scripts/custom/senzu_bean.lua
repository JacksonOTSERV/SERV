local STORAGE = 50043
local WAIT_TIME = 1
local REG_HEALTH = 9000
local REG_MANA = 9000

function onUse(player, item, fromPosition, target, toPosition)
    local now = os.time()
    if player:getStorageValue(STORAGE) > now then
        player:sendCancelMessage("You are exhausted.")
        return false
    end

    local pos = player:getPosition()

    player:addMana(REG_MANA)
    player:addHealth(REG_HEALTH)
    player:say("I feel better!", TALKTYPE_SAY)
    pos:sendMagicEffect(CONST_ME_MAGIC_BLUE)

    player:setStorageValue(STORAGE, now + WAIT_TIME)

    item:remove(1)

    return true
end