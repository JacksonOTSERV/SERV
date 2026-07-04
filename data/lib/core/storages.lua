-- Storage do Servidor
STORAGEVALUE_PROMOTION = 30018
STORAGEVALUE_DELAY_LARGE_SEASHELL = 30019

-- Sistema de task
STORAGE_TASK_ACTIVE = 40000
STORAGE_TASK_KILLS = 40001
STORAGE_TASK_MONSTER = 40002
STORAGE_TASK_TIME = 40003
STORAGE_TASK_SEQUENCIAL = 40004
STORAGE_TASK_SEQUENCIAL_KILLS = 40005

-- Storages especiais/tecnicas
STORAGE_ESPECIAL1 = 2223
STORAGE_ESPECIAL2 = 2224
STORAGE_ESPECIAL3 = 2225
STORAGE_BUFF = 2226
STORAGE_TARGET = 1980
STORAGE_REVIVE = 7767
STORAGE_REVIVE2 = 7768

-- Storage presence points e deus da destruição
STORAGE_TIME = 891
STORAGE_DATE = 892
STORAGE_REWARD = 893
STORAGE_PRESENCE_POINTS = 11145
STORAGE_DEUS = 11146
REWARD_INTERVAL = 3600
STORAGE_KEY = 'presence_points_last_reset'
DAYS_INTERVAL = 15
SECONDS_PER_DAY = 86400
playerEventIds = {} or 0

function getLastResetFromDB()
    local database = db.storeQuery("SELECT `value` FROM `system_data` WHERE `key` = '" .. STORAGE_KEY .. "'")
    if database then
        local val = tonumber(result.getDataString(database, "value"))
        result.free(database)
        return val
    end
    return nil
end

function setLastResetToDB(timestamp)
    local database = db.storeQuery("SELECT 1 FROM `system_data` WHERE `key` = '" .. STORAGE_KEY .. "'")
    if database then
        result.free(database)
        db.query(string.format("UPDATE `system_data` SET `value` = %d WHERE `key` = '%s'", timestamp, STORAGE_KEY))
    else
        db.query(string.format("INSERT INTO `system_data` (`key`, `value`) VALUES ('%s', %d)", STORAGE_KEY, timestamp))
    end
end

-- Monster hunt event
MonsterHuntActive = {}

-- Esferas
DragonOrbs = DragonOrbs or {}
DragonOrbsCounter = DragonOrbsCounter or 0

-- Dungeons
originalPositions = {}
DungeonTimers = DungeonTimers or {}
HWID_SESSIONS = HWID_SESSIONS or {}
HWID_CLAIMED = HWID_CLAIMED or {}

-- Torneio PVP
TorneioData = {
    pagamentos = {},
    total = 0
}

function TorneioData.registrarPagamento(player, valor)
    local guid = player:getGuid()

    if not TorneioData.pagamentos[guid] then
        TorneioData.pagamentos[guid] = valor
        TorneioData.total = TorneioData.total + valor
    end
end

function TorneioData.reset()
    TorneioData.pagamentos = {}
    TorneioData.total = 0
end

function TorneioData.getTotal()
    return TorneioData.total
end