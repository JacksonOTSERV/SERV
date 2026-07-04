local noLootAreas = {
	{fromPos = {x = 293, y = 1149, z = 7}, toPos = {x = 512, y = 1290, z = 7}},
	{fromPos = {x = 293, y = 1149, z = 6}, toPos = {x = 512, y = 1290, z = 6}},
	{fromPos = {x = 401, y = 1044, z = 7}, toPos = {x = 512, y = 1290, z = 7}},
	{fromPos = {x = 1457, y = 401, z = 7}, toPos = {x = 1679, y = 519, z = 7}},
	{fromPos = {x = 721, y = 79, z = 11}, toPos = {x = 738, y = 108, z = 11}},
	{fromPos = {x = 177, y = 342, z = 8}, toPos = {x = 247, y = 390, z = 8}},
	{fromPos = {x = 315, y = 1057, z = 10}, toPos = {x = 494, y = 1126, z = 10}},
	{fromPos = {x = 315, y = 1057, z = 9}, toPos = {x = 494, y = 1126, z = 9}},
	{fromPos = {x = 400, y = 1135, z = 10}, toPos = {x = 572, y = 1295, z = 10}},
	{fromPos = {x = 41, y = 1064, z = 10}, toPos = {x = 310, y = 1231, z = 10}},
	{fromPos = {x = 427, y = 204, z = 8}, toPos = {x = 556, y = 271, z = 8}},
	{fromPos = {x = 523, y = 753, z = 8}, toPos = {x = 602, y = 823, z = 8}},
	{fromPos = {x = 602, y = 794, z = 7}, toPos = {x = 713, y = 866, z = 7}},
	{fromPos = {x = 602, y = 794, z = 6}, toPos = {x = 713, y = 866, z = 6}},
	{fromPos = {x = 602, y = 794, z = 5}, toPos = {x = 713, y = 866, z = 5}},
	{fromPos = {x = 602, y = 794, z = 4}, toPos = {x = 713, y = 866, z = 4}},
	{fromPos = {x = 602, y = 794, z = 3}, toPos = {x = 713, y = 866, z = 3}},
}

local function isInNoLootArea(pos)
	for _, area in ipairs(noLootAreas) do
		if pos.z == area.fromPos.z and
		   pos.x >= area.fromPos.x and pos.x <= area.toPos.x and
		   pos.y >= area.fromPos.y and pos.y <= area.toPos.y then
			return true
		end
	end
	return false
end

local monsters = {
    [1] = {name = "Li Shenron Max"},
    [2] = {name = "King Vegeta"},
    [3] = {name = "Frontal Cyborg"},
    [4] = {name = "Evil Vegetto"},
    [5] = {name = "Evil Tsuful"},
    [6] = {name = "Uu Shenlong"},
    [7] = {name = "Hell Janemba"},
	[8] = {name = "Evil Janemba"}
}

local sequencialTasks = {
    [1] = {name = "Namekjin", killsRequired = 50},
    [2] = {name = "Tank", killsRequired = 60},
    [3] = {name = "Robotron", killsRequired = 70},
    [4] = {name = "Namekjin Warrior", killsRequired = 80},
    [5] = {name = "Tsuful", killsRequired = 90},
    [6] = {name = "Dragon", killsRequired = 100},
    [7] = {name = "Atlantid", killsRequired = 100},
    [8] = {name = "Humanoid Cyborg", killsRequired = 110},
    [9] = {name = "Ancestral Guardian", killsRequired = 120},
    [10] = {name = "Black Dragon", killsRequired = 130},
    [11] = {name = "Paikuhan", killsRequired = 400},
    [12] = {name = "Super Paikuhan", killsRequired = 400},
    [13] = {name = "Li Shenron Max", killsRequired = 500},
    [14] = {name = "King Vegeta", killsRequired = 550},
    [15] = {name = "Frontal Cyborg", killsRequired = 580},
    [16] = {name = "Evil Vegetto", killsRequired = 620},
    [17] = {name = "Evil Tsuful", killsRequired = 660},
    [18] = {name = "Uu Shenlong", killsRequired = 720},
    [19] = {name = "Hell Janemba", killsRequired = 800}
}

local KILLS_REQUIRED = 1000

local function formatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

function onKill(creature, target)
    local player = creature:getPlayer()
    if not player or not target:isMonster() then
        return true
    end
	
    if isInNoLootArea(target:getPosition()) then
        return true
    end

    local targetName = string.lower(target:getName())

    if player:getStorageValue(STORAGE_TASK_ACTIVE) == 1 then
        local taskEndTime = player:getStorageValue(STORAGE_TASK_TIME)
        local timeLeft = taskEndTime - os.time()

        if timeLeft <= 0 then
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "[DAILY TASK] O tempo da task acabou!")
            player:setStorageValue(STORAGE_TASK_ACTIVE, -1)
            return true
        end

        local monsterId = player:getStorageValue(STORAGE_TASK_MONSTER)
        local monsterName = monsters[monsterId] and string.lower(monsters[monsterId].name) or ""

        if targetName == monsterName then
            local kills = player:getStorageValue(STORAGE_TASK_KILLS) + 1
            player:setStorageValue(STORAGE_TASK_KILLS, kills)
            local timeFormatted = formatTime(timeLeft)

            if kills >= KILLS_REQUIRED then
                player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "[DAILY TASK] Você completou a task! Vá até o NPC entregar e receber sua recompensa. - Tempo restante para entregar: " .. timeFormatted)
				player:setStorageValue(STORAGE_TASK_KILLS, KILLS_REQUIRED)
            else
                player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "[DAILY TASK] " .. kills .. "/" .. KILLS_REQUIRED .. " " .. monsterName .. "(s) - Tempo restante: " .. timeFormatted)
            end
        end
    end

    local currentTaskId = player:getStorageValue(STORAGE_TASK_SEQUENCIAL)
    if currentTaskId > 0 then
        local taskData = sequencialTasks[currentTaskId]
        if taskData then
            local taskMonsterName = string.lower(taskData.name)
            local killsRequired = taskData.killsRequired or 500

            if targetName == taskMonsterName then
                local kills = player:getStorageValue(STORAGE_TASK_SEQUENCIAL_KILLS) + 1
                player:setStorageValue(STORAGE_TASK_SEQUENCIAL_KILLS, kills)

                if kills >= killsRequired then
                    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "[TASK] Você completou a task! Vá até o NPC entregar e receber sua recompensa.")
                else
                    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "[TASK] " .. kills .. "/" .. killsRequired .. " " .. taskMonsterName .. "(s).")
                end
            end
        end
    end

    return true
end
