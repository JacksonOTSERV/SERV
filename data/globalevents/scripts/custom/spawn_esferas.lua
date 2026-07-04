local config = {
    areas = {
        {
            name = "Earth",
            fromPos = Position(65, 95, 7),
            toPos = Position(168, 203, 7)
        },
        {
            name = "Earth",
            fromPos = Position(27, 203, 7),
            toPos = Position(124, 255, 7)
        },
        {
            name = "Earth",
            fromPos = Position(29, 271, 7),
            toPos = Position(278, 454, 7)
        },
        {
            name = "Sand city",
            fromPos = Position(230, 824, 7),
            toPos = Position(447, 957, 7)
        },
        {
            name = "Ilha dos dragons",
            fromPos = Position(38, 747, 7),
            toPos = Position(154, 961, 7)
        },
        {
            name = "Namek",
            fromPos = Position(402, 93, 7),
            toPos = Position(621, 170, 7)
        },
        {
            name = "Gardia",
            fromPos = Position(74, 1132, 7),
            toPos = Position(164, 1249, 7)
        },
        {
            name = "Tsufur",
            fromPos = Position(775, 710, 7),
            toPos = Position(967, 969, 7)
        },
        {
            name = "Vegeta",
            fromPos = Position(709, 48, 7),
            toPos = Position(766, 80, 7)
        },
        {
            name = "Vegeta",
            fromPos = Position(800, 86, 7),
            toPos = Position(872, 152, 7)
        },
    },
    itemRange = {13591, 13597},
    extraItemId = 13598,
    removeExtraAfter = 60000,
    maxAttempts = 100,
	dailyRepeatCount = 2,
    dailyRepeatSpawn = 7,
	spawnMinHour = 9,
	spawnMaxHour = 23,
	dayStart = os.date("*t").day
}

spawnedItemsToday = {}

local function isWalkable(position)
    local tile = Tile(position)
    if not tile
        or tile:hasFlag(TILESTATE_PROTECTIONZONE)
        or tile:hasFlag(TILESTATE_BLOCKSOLID)
        or tile:hasFlag(TILESTATE_FLOORCHANGE)
    then
        return false
    end

    local ground = tile:getGround()
    if ground then
        local id = ground:getId()
        if id == 9535 or id == 9536 then
            return false
        end
    end

    if tile:getHouse() then
        return false
    end

    return true
end

local function isTileOccupiedByCreature(position)
    local tile = Tile(position)
    if tile then
        local creature = tile:getTopCreature()
        if creature then
            return true
        end
    end
    return false
end

local directions = {
    {dir = DIRECTION_NORTH, dx = 0, dy = -1},
    {dir = DIRECTION_SOUTH, dx = 0, dy = 1},
    {dir = DIRECTION_WEST,  dx = -1, dy = 0},
    {dir = DIRECTION_EAST,  dx = 1, dy = 0}
}

local function canReallyWalk(fromPos, toPos)
    local dummy = Game.createMonster("Clone", fromPos, true, true)
    if not dummy then
        return false
    end

    local path = dummy:getPathTo(toPos, {
        ignoreMonsters = true,
        ignoreCreatures = true,
        ignoreFields = true
    })

    if not path then
        dummy:remove()
        return false
    end

    for _, dir in ipairs(path) do
        if not dummy:move(dir) then
            dummy:remove()
            return false
        end
    end

    dummy:remove()
    return true
end

local function getRandomValidPosition(area, startPos)
    for _ = 1, config.maxAttempts do
        local x = math.random(area.fromPos.x, area.toPos.x)
        local y = math.random(area.fromPos.y, area.toPos.y)
        local z = math.random(area.fromPos.z, area.toPos.z)
        local pos = Position(x, y, z)

        if isWalkable(pos) and not isTileOccupiedByCreature(pos) and canReallyWalk(startPos, pos) then
            return pos
        end
    end
    return nil
end

local stairsIds = {
    [1387] = true, [1392] = true, [459] = true, [433] = true, [1396] = true, [1394] = true, 
    [1390] = true, [480] = true, [1388] = true, [411] = true, [427] = true, [432] = true, 
    [13125] = true, [5259] = true, [8281] = true, [3688] = true, [4837] = true, [5260] = true, 
    [429] = true, [3685] = true, [8276] = true
}

function resetDailyItems()
    local today = os.date("*t").day
    if today ~= config.dayStart then
        config.dayStart = today
        spawnedItemsToday = {}
    end
end

local function spawnRandomItem()
	resetDailyItems()
	
    local area = config.areas[math.random(#config.areas)]
    local startPos = area.fromPos

    local chosenPos = getRandomValidPosition(area, startPos)
    if not chosenPos then
        return true
    end
	
    local positions = {
        {x = chosenPos.x + 2, y = chosenPos.y - 8, z = chosenPos.z},
    }

    for _, fromPos in ipairs(positions) do
        doSendDistanceShoot(fromPos, chosenPos, 101)
    end

    local missileDelay = 300

    addEvent(function()
		local posEffect = chosenPos
		local effectPos = {x = posEffect.x + 2, y = posEffect.y, z = posEffect.z}
		doSendMagicEffect(effectPos, 287)
		
        local itemId
        if #spawnedItemsToday < config.dailyRepeatCount then
            if #spawnedItemsToday > 0 then
                itemId = spawnedItemsToday[math.random(#spawnedItemsToday)]
            else
                itemId = math.random(config.itemRange[1], config.itemRange[2])
            end
        else
            itemId = math.random(config.itemRange[1], config.itemRange[2])
        end

        table.insert(spawnedItemsToday, itemId)
		
		local sidePos = Position(chosenPos.x + 2, chosenPos.y + 1, chosenPos.z)
		
		local createdItem = Game.createItem(itemId, 1, chosenPos)
		local extraItem = Game.createItem(config.extraItemId, 1, sidePos)

		if createdItem then
			DragonOrbsCounter = DragonOrbsCounter + 1
			local key = DragonOrbsCounter

			DragonOrbs[key] = {
				itemId = itemId,
				pos = createdItem:getPosition(),
				areaName = area.name,
				orbName = ItemType(itemId):getName(),
				extraItem = extraItem
			}
		end

        local sideTile = Tile(sidePos)
        if sideTile then
            local ground = sideTile:getGround()
            if ground and stairsIds[ground:getId()] then
                Game.broadcastMessage("[ESFERA DO DRAG�O] A " .. ItemType(itemId):getName() ..
                    " apareceu em: " .. area.name .. ", boa sorte na procura!", MESSAGE_EVENT_ADVANCE)
                return true
            end
        end

        Game.broadcastMessage("[ESFERA DO DRAG�O] A " .. ItemType(itemId):getName() ..
            " apareceu em: " .. area.name .. ", boa sorte na procura!", MESSAGE_EVENT_ADVANCE)
    end, missileDelay)

    return true
end

local function incrementDailyCount()
    local today = os.date("%Y-%m-%d")
    local resultId = db.storeQuery("SELECT id, count FROM daily_spawns WHERE date = '" .. today .. "' LIMIT 1")
    if resultId ~= false then
        local count = result.getNumber(resultId, "count")
        db.query("UPDATE daily_spawns SET count = " .. (count + 1) .. " WHERE id = " .. result.getNumber(resultId, "id"))
        result.free(resultId)
    else
        db.query("INSERT INTO daily_spawns (date, count) VALUES ('" .. today .. "', 1)")
    end
end

local function spawnWrapper()
    spawnRandomItem()
    incrementDailyCount()
end

local function inTable(t, val)
    for _, v in ipairs(t) do
        if v == val then
            return true
        end
    end
    return false
end

local function generateRandomTimes()
    local times = {}
    local now = os.date("*t")
    local currentSec = (now.hour * 3600) + (now.min * 60) + now.sec

    local startSec = math.max(config.spawnMinHour * 3600, currentSec)
    local endSec = config.spawnMaxHour * 3600

    if endSec <= startSec then
        print("[SPAWN SYSTEM] ERRO: hor�rio final menor que o atual")
        return times
    end

    local totalWindow = endSec - startSec
    local blockSize = math.floor(totalWindow / config.dailyRepeatSpawn)

    for i = 1, config.dailyRepeatSpawn do
        local blockStart = startSec + math.floor((i - 1) * totalWindow / config.dailyRepeatSpawn)
        local blockEnd   = startSec + math.floor(i * totalWindow / config.dailyRepeatSpawn) - 1
        if i == config.dailyRepeatSpawn then
            blockEnd = endSec
        end

        if blockEnd < blockStart then
            blockEnd = blockStart
        end

        local totalSeconds = math.random(blockStart, blockEnd)
        table.insert(times, totalSeconds)
    end

    table.sort(times)
    return times
end

local function scheduleDailySpawns()
    local today = os.date("%Y-%m-%d")
    db.query("DELETE FROM daily_spawns WHERE date = '" .. today .. "'")
    db.query("INSERT INTO daily_spawns (date, count) VALUES ('" .. today .. "', 0)")

    local times = generateRandomTimes()
    for _, t in ipairs(times) do
        local now = os.date("*t")
        local currentSec = (now.hour * 3600) + (now.min * 60) + now.sec
        local delay = (t - currentSec) * 1000
        if delay > 0 then
            addEvent(spawnWrapper, delay)
            print(string.format("[SPAWN SYSTEM] Esfera agendada para %02d:%02d:%02d",
                math.floor(t/3600), math.floor((t%3600)/60), t%60))
        end
    end
end

function onStartup()
    scheduleDailySpawns()

    local function checkNewDay()
        local today = os.date("*t").day
        if today ~= config.dayStart then
            config.dayStart = today
            spawnedItemsToday = {}
            scheduleDailySpawns()
            print("[SPAWN SYSTEM] Novo dia detectado, spawns resetados e reagendados.")
        end
        addEvent(checkNewDay, 60000)
    end
    addEvent(checkNewDay, 60000)

    return true
end