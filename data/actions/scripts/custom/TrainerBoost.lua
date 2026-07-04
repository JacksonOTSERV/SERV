function onUse(player, item, fromPosition, target, toPosition, isHotkey)
    if not player or not player:isPlayer() then
        return false
    end

    local cooldownTime = player:getStorageValue(4439)
    local currentTime = os.time()

    if cooldownTime > currentTime then
        local remainingCooldown = cooldownTime - currentTime

        local days = math.floor(remainingCooldown / 86400)
        local hours = math.floor((remainingCooldown % 86400) / 3600)
        local minutes = math.floor((remainingCooldown % 3600) / 60)
        local seconds = remainingCooldown % 60

        local msg = "Aguarde "
        if days > 0 then
            msg = msg .. days .. "d "
        end
        if hours > 0 or days > 0 then
            msg = msg .. hours .. "h "
        end
        if minutes > 0 or hours > 0 or days > 0 then
            msg = msg .. minutes .. "m "
        end
        msg = msg .. seconds .. "s antes de usar esse boost."

        player:sendCancelMessage(msg)
        return true
    end

    player:say("Booster TRAINING!", TALKTYPE_ORANGE_1)
    player:setStorageValue(4439, os.time() + 2592000)

    item:remove(1)
    return false
end
