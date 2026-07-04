local function resetPlayerStorageOnline(player)
    local presencePoints = getpresencePoints(player)
    local playerId = player:getGuid()
    player:setStorageValue(STORAGE_PRESENCE_POINTS, 0)
    db.query(string.format("UPDATE `players` SET `presencePoints` = 0 WHERE id = %d", playerId))
    player:setStorageValue(STORAGE_DEUS, 0)
    Deus_system(player)
end

local function resetOnlinePlayers()
    for _, player in ipairs(Game.getPlayers()) do
        resetPlayerStorageOnline(player)
    end
end

local function resetOfflinePlayers()
    local onlineIds = {}
    for _, player in ipairs(Game.getPlayers()) do
        table.insert(onlineIds, player:getGuid())
    end
    local idsString = ""
    if #onlineIds > 0 then
        idsString = table.concat(onlineIds, ",")
    else
        idsString = "0"
    end

    db.query(string.format("UPDATE `players` SET `presencePoints` = 0 WHERE `presencePoints` > 0 AND `id` NOT IN (%s)", idsString))
    db.query(string.format("UPDATE `player_storage` SET `value` = 0 WHERE `key` = %d AND `player_id` NOT IN (%s) AND `value` > 0", STORAGE_PRESENCE_POINTS, idsString))
end

local function setPlayerStorageOffline(playerId, key, value)
    local updateQuery = string.format(
        "UPDATE `player_storage` SET `value` = %d WHERE `player_id` = %d AND `key` = %d",
        value, playerId, key
    )
    db.query(updateQuery)

    local insertQuery = string.format(
        "INSERT IGNORE INTO `player_storage` (`player_id`, `key`, `value`) VALUES (%d, %d, %d)",
        playerId, key, value
    )
    db.query(insertQuery)
end

local function printPlayerWithMostPresencePoints()
    local query = db.storeQuery("SELECT `id`, `name`, `presencePoints` FROM `players` WHERE `presencePoints` >= 10 ORDER BY `presencePoints` DESC LIMIT 1")
    if not query then
        return
    end

    local id = result.getDataInt(query, "id")
    local points = result.getDataInt(query, "presencePoints")
    result.free(query)
    if not id then
        return
    end

    local creature = Player(id)
    db.query("DELETE FROM `deus_system` WHERE `town_deus` = 1")

    if creature then
        pcall(function()
            doRemoveCondition(creature, CONDITION_ATTRIBUTES, 912)
            doRemoveCondition(creature, CONDITION_REGENERATION, 913)
            local storageValue = creature:getStorageValue(14389)
            if storageValue > 0 then
                local outfit = creature:getOutfit()
                outfit.lookType = storageValue
                creature:setOutfit(outfit)
            end
            creature:removeOutfit(1265)
            local inbox = creature:getInbox()
            inbox:addItem(13579, 1, true, 1)
            inbox:addItem(13580, 1, true, 1)
            inbox:addItem(13581, 1, true, 1)
            creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Voc? foi o Deus da Destrui??o dessa temporada e recebeu o set god of destruction (dura??o de 15 dias) em sua mailbox! use com sabedoria.")
        end)
    else
        db.query("DELETE FROM `player_storage` WHERE `key`="..STORAGE_DEUS.." AND `player_id`=" .. id .. ";")
        setPlayerStorageOffline(id, 32323, 1)
    end
end

function onTime(interval)
    local now = os.time()
    local lastReset = getLastResetFromDB()

    if not lastReset then
        setLastResetToDB(now)
        lastReset = now
    end

    local lastResetDate = os.date("*t", lastReset)
    local nowDate = os.date("*t", now)

    lastResetDate.hour = 0
    lastResetDate.min = 0
    lastResetDate.sec = 0
    nowDate.hour = 0
    nowDate.min = 0
    nowDate.sec = 0

    local daysPassed = math.floor((os.time(nowDate) - os.time(lastResetDate)) / SECONDS_PER_DAY)

    if daysPassed >= DAYS_INTERVAL then
        printPlayerWithMostPresencePoints()
        resetOnlinePlayers()
        resetOfflinePlayers()
        setLastResetToDB(now)
        Game.broadcastMessage('Uma nova temporada de presence points foi iniciada (ap?s ' .. DAYS_INTERVAL .. ' dias)! Todos os pontos foram resetados, seja voc? o pr?ximo deus da destrui??o!', MESSAGE_STATUS_WARNING)
    end

    return true
end