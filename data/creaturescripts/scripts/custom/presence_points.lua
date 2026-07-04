local function getCustomDayStamp()
    local now = os.time()
    local t = os.date("*t", now)
    if t.hour < 21 then
        now = now - 24 * 3600
        t = os.date("*t", now)
    end
    return tonumber(string.format("%04d%02d%02d", t.year, t.month, t.day))
end

local function updateOnlineTime(player, seconds)
    if not player or not player:isPlayer() then return end

    local storedTime = player:getStorageValue(STORAGE_TIME)
    if storedTime < 0 then storedTime = 0 end

    local newTotalTime = storedTime + seconds
    player:setStorageValue(STORAGE_TIME, newTotalTime)

    local hasReceivedToday = player:getStorageValue(STORAGE_REWARD)
    if hasReceivedToday < 0 then hasReceivedToday = 0 end

    if hasReceivedToday == 0 and newTotalTime >= REWARD_INTERVAL then
        player:setStorageValue(STORAGE_REWARD, 1)
        setPresencePoints(player, 1)

        local totalPresence = player:getStorageValue(STORAGE_PRESENCE_POINTS)
        if totalPresence < 0 then totalPresence = 0 end

        player:sendTextMessage(
            MESSAGE_STATUS_CONSOLE_BLUE,
            "Você recebeu +1 presence point por ficar online por pelo menos 1 hora hoje! Você tem agora: " ..
            totalPresence .. " presence points."
        )
    end
end

local function dailyOnlineLoop(playerId)
    local player = Player(playerId)
    if not player then
        if playerEventIds[playerId] then
            stopEvent(playerEventIds[playerId])
            playerEventIds[playerId] = nil
        end
        return
    end

    updateOnlineTime(player, 60)

    local eventId = addEvent(dailyOnlineLoop, 60 * 1000, playerId)
    playerEventIds[playerId] = eventId
end

local function getDelayToReset()
    local now = os.time()
    local today = os.date("*t", now)

    today.hour = 21
    today.min = 0
    today.sec = 0

    local resetTime = os.time(today)

    if now >= resetTime then
        resetTime = resetTime + 24 * 3600
    end

    return resetTime - now
end

local function scheduleMidnightReset(playerId)
    local player = Player(playerId)
    if not player then return end

    addEvent(function()
        local p = Player(playerId)
        if p then
            p:setStorageValue(STORAGE_DATE, getCustomDayStamp())
            p:setStorageValue(STORAGE_TIME, 0)
            p:setStorageValue(STORAGE_REWARD, 0)
            p:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "Novo dia começou! Sua contagem de presence points foi reiniciada.")
            scheduleMidnightReset(playerId)
        else
            if playerEventIds[playerId] then
                stopEvent(playerEventIds[playerId])
                playerEventIds[playerId] = nil
            end
        end
    end, getDelayToReset() * 1000)
end

function onLogin(player)
    local today = getCustomDayStamp()
    local storedDate = player:getStorageValue(STORAGE_DATE)

    if storedDate ~= today then
        player:setStorageValue(STORAGE_DATE, today)
        player:setStorageValue(STORAGE_TIME, 0)
        player:setStorageValue(STORAGE_REWARD, 0)
    end

    local playerId = player:getId()

    if playerEventIds[playerId] then
        stopEvent(playerEventIds[playerId])
        playerEventIds[playerId] = nil
    end

    playerEventIds[playerId] = addEvent(dailyOnlineLoop, 60 * 1000, playerId)
    scheduleMidnightReset(playerId)

    local presencePoints = player:getStorageValue(STORAGE_PRESENCE_POINTS)
    if presencePoints < 0 then presencePoints = 0 end

    local hasReceivedToday = player:getStorageValue(STORAGE_REWARD)
    if hasReceivedToday < 0 then hasReceivedToday = 0 end

    local receivedToday = (storedDate == today) and (hasReceivedToday == 1)

    local accumulatedTime = player:getStorageValue(STORAGE_TIME)
    if accumulatedTime < 0 then accumulatedTime = 0 end

    local hours = math.floor(accumulatedTime / 3600)
    local minutes = math.floor((accumulatedTime % 3600) / 60)

    local msg = "Você possui atualmente " .. presencePoints .. " presence points. "
    if receivedToday then
        msg = msg .. "Você já recebeu seu presence point hoje. "
    else
        msg = msg .. "Você ainda não recebeu seu presence point hoje. "
    end
    msg = msg .. string.format("Tempo online acumulado hoje: %d hora(s) e %d minuto(s).", hours, minutes)
    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, msg)

    return true
end

function onLogout(player)
    local playerId = player:getId()
    if playerEventIds[playerId] then
        stopEvent(playerEventIds[playerId])
        playerEventIds[playerId] = nil
    end
    return true
end