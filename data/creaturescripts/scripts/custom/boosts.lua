function onLogin(player)
    local function createAttributesCondition(conditionId, duracao, magicLevel, skillSword, skillClub)
        local condition = Condition(CONDITION_ATTRIBUTES)
        condition:setParameter(CONDITION_PARAM_SUBID, conditionId)
        condition:setParameter(CONDITION_PARAM_TICKS, duracao * 1000)
        condition:setParameter(CONDITION_PARAM_STAT_MAGICPOINTS, magicLevel)
        condition:setParameter(CONDITION_PARAM_SKILL_SWORD, skillSword)
        condition:setParameter(CONDITION_PARAM_SKILL_CLUB, skillClub)
        return condition
    end

    if player:getStorageValue(4443) > os.time() then
        local duration = player:getStorageValue(4441) - os.time()
        local kiBoost = createAttributesCondition(66, duration, 20, 0, 0)
        player:addCondition(kiBoost)

        local hours = math.floor(duration / 3600)
        local minutes = math.floor((duration % 3600) / 60)
        local seconds = duration % 60

        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
            string.format("Você ainda tem: +20 Ki Level por %02dh %02dm %02ds pelo boost.", hours, minutes, seconds)
        )
    end

    if player:getStorageValue(4444) > os.time() then
        local duration = player:getStorageValue(4440) - os.time()
        local skillBoost = createAttributesCondition(67, duration, 0, 20, 20)
        player:addCondition(skillBoost)

        local hours = math.floor(duration / 3600)
        local minutes = math.floor((duration % 3600) / 60)
        local seconds = duration % 60

        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
            string.format("Você ainda tem: +20 Sword e +20 Club por %02dh %02dm %02ds pelo boost.", hours, minutes, seconds)
        )
    end

    if player:getStorageValue(4439) > os.time() then
        local duration = player:getStorageValue(4439) - os.time()
        local days = math.floor(duration / 86400)
        local hours = math.floor((duration % 86400) / 3600)
        local minutes = math.floor((duration % 3600) / 60)
        local seconds = duration % 60

        local dayStr = ""
        if days > 0 then
            dayStr = string.format("%02dd ", days)
        end

        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
            string.format("Você ainda tem: boost de treino 25%% por %s%02dh %02dm %02ds.", dayStr, hours, minutes, seconds)
        )
    end

    return true
end