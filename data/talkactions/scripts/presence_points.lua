local RESET_HOUR = 21
local RESET_MIN = 0
local RESET_SEC = 0

local function getLastResetFromDB()
    local database = db.storeQuery("SELECT `value` FROM `system_data` WHERE `key` = '" .. STORAGE_KEY .. "'")
    if database then
        local val = tonumber(result.getDataString(database, "value"))
        result.free(database)
        return val
    end
    return nil
end

local function getPlayerPresencePoints(player)
    local points = player:getStorageValue(STORAGE_PRESENCE_POINTS)
    if points == -1 then
        points = 0
    end
    return points
end

local function formatTime(seconds)
    local days = math.floor(seconds / SECONDS_PER_DAY)
    seconds = seconds % SECONDS_PER_DAY
    local hours = math.floor(seconds / 3600)
    seconds = seconds % 3600
    local minutes = math.floor(seconds / 60)
    seconds = seconds % 60
    return days, hours, minutes, seconds
end

local function getNextResetTimestamp(lastReset)
    local lastDate = os.date("*t", lastReset)

    lastDate.hour = 0
    lastDate.min = 0
    lastDate.sec = 0

    local nextDateTimestamp = os.time(lastDate) + (DAYS_INTERVAL * SECONDS_PER_DAY)

    local nextDate = os.date("*t", nextDateTimestamp)
    nextDate.hour = RESET_HOUR
    nextDate.min = RESET_MIN
    nextDate.sec = RESET_SEC

    return os.time(nextDate)
end

function onSay(player, words, param)
    local now = os.time()
    local lastReset = getLastResetFromDB()
    if not lastReset then
        return false
    end

    local nextResetTimestamp = getNextResetTimestamp(lastReset)
    local timeLeft = nextResetTimestamp - now
    if timeLeft < 0 then
        timeLeft = 0
    end

    local days, hours, minutes, seconds = formatTime(timeLeft)
    local presencePoints = getPlayerPresencePoints(player)

    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, string.format(
        "Faltam %d dias, %d horas, %d minutos e %d segundos para o fim da temporada. Voc tem %d presence points.",
        days, hours, minutes, seconds, presencePoints
    ))

    return false
end