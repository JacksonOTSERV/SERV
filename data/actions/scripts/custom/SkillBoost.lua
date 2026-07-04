local config = {
    sword = 20,  -- quanto irá aumentar o skill de SWORD (base)
    club = 20,   -- quanto irá aumentar o skill de CLUB (base)
}

local condition = Condition(CONDITION_ATTRIBUTES)
condition:setParameter(CONDITION_PARAM_SUBID, 67)
condition:setParameter(CONDITION_PARAM_SKILL_SWORD, config.sword)
condition:setParameter(CONDITION_PARAM_SKILL_CLUB, config.club)
condition:setParameter(CONDITION_PARAM_TICKS, 7200 * 1000)

function onUse(player, item, fromPosition, target, toPosition, isHotkey)
    if not player or not player:isPlayer() then
        return false
    end

    local cooldownTime = player:getStorageValue(4440)
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
    player:say("Skill God Booster!", TALKTYPE_ORANGE_1)
    player:setStorageValue(4440, os.time() + 7200)
    player:setStorageValue(4444, os.time() + 7200)

    item:remove(1)
    return false
end