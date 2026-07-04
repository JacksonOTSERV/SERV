local config = {
    duration_spell = 10,  -- tempo do buff em segundos
    ml = 30,             -- quanto irá aumentar o skill de KI LEVEL (base)
    reuse_delay = 60     -- tempo para reutilizar a spell em segundos
}

local function createCondition(duration)
    local condition = Condition(CONDITION_ATTRIBUTES)
    condition:setParameter(CONDITION_PARAM_SUBID, 100)
    condition:setParameter(CONDITION_PARAM_STAT_MAGICPOINTS, config.ml)
    condition:setParameter(CONDITION_PARAM_TICKS, duration * 1000)
    return condition
end

local function removeBuff(creatureId)
    local creature = Creature(creatureId)
    if creature then
        local currentTime = os.time()
        local remainingTime = creature:getStorageValue(10289) - currentTime
        if remainingTime <= 0  then
            creature:removeCondition(CONDITION_ATTRIBUTES, 100)
            creature:setStorageValue(10289, 0)
        end
    end
end

function onCastSpell(player, variant)
    if not player then
        return false
    end

    local currentTime = os.time()
    local membersList = player:getParty()

    local lastCast = player:getStorageValue(STORAGE_ESPECIAL1)
    if lastCast > currentTime then
        player:sendCancelMessage("Você precisa esperar " .. (lastCast - currentTime) .. " segundos para usar este especial novamente.")
        return false
    end
	
	local AreaX, AreaY = 15, 8
    local spec = Game.getSpectators(player:getPosition(), false, true, AreaX, AreaX, AreaY, AreaY)
    local playerPos = player:getPosition()

    for _, spectator in ipairs(spec) do
        if spectator:isPlayer() then
            local target = nil

            if membersList then
                if spectator == membersList:getLeader() or table.contains(membersList:getMembers(), spectator) then
                    target = spectator
                end
            elseif spectator == player then
                target = player
            end

            if target and not getCreatureCondition(target, CONDITION_OUTFIT, 125) then
                local remainingTime = math.max(0, target:getStorageValue(10289) - currentTime)
                local newDuration = remainingTime + config.duration_spell

                target:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Você recebeu um buff em +" .. config.ml .. " para ki level. (devido a tecnica especial de um king vegeta)")
				
				doSendAnimatedText(target:getPosition(), "+" .. config.ml .. " Ki Level", TEXTCOLOR_WHITE)
				
                target:setStorageValue(10289, currentTime + newDuration)
                target:removeCondition(CONDITION_ATTRIBUTES, 100)
                target:addCondition(createCondition(newDuration))
                addEvent(removeBuff, newDuration * 1000, target:getId())
            end
        end
    end

    player:setStorageValue(STORAGE_ESPECIAL1, currentTime + config.reuse_delay)

        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(player, "Full unlock ability skill")
    end

    return true
end