local config = {
    ml = 20,  -- quanto irá aumentar o skill de ML (base)
}

local condition = Condition(CONDITION_ATTRIBUTES)
condition:setParameter(CONDITION_PARAM_SUBID, 66)
condition:setParameter(CONDITION_PARAM_STAT_MAGICPOINTS, config.ml)
condition:setParameter(CONDITION_PARAM_TICKS, 7200 * 1000)

function onUse(player, item, fromPosition, target, toPosition, isHotkey)
    if not player or not player:isPlayer() then
        return false
    end

    local cooldownTime = player:getStorageValue(4441)
    local currentTime = os.time()

    if cooldownTime > currentTime then
        local remainingCooldown = cooldownTime - currentTime
        local hours = math.floor(remainingCooldown / 3600)
        local minutes = math.floor((remainingCooldown % 3600) / 60)
        local seconds = remainingCooldown % 60
        player:sendCancelMessage("Aguarde " .. hours .. "h " .. minutes .. "m " .. seconds .. "s antes de usar esse boost.")
        return true
    end

    player:addCondition(condition)
    player:say("Ki Level God Booster!", TALKTYPE_ORANGE_1)
    player:setStorageValue(4441, os.time() + 7200)
    player:setStorageValue(4443, os.time() + 7200)

    item:remove(1)
    return false
end
