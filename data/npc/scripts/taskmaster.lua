local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

npcHandler:setMessage(MESSAGE_GREET, {
    PT = "Olá |PLAYERNAME|. Você deseja adquirir uma {task}, {task daily}, {reportar} uma task ou fazer {trade} dos seus task coins?",
    EN = "Hello |PLAYERNAME|. Do you want to acquire a {task}, {task daily}, {report} a task or {trade} your task coins?"
})
npcHandler:setMessage(MESSAGE_FAREWELL, {
    PT = "Adeus.",
    EN = "Goodbye."
})
npcHandler:setMessage(MESSAGE_WALKAWAY, {
    PT = "Adeus.",
    EN = "Goodbye."
})

function onCreatureAppear(creature) npcHandler:onCreatureAppear(creature) end
function onCreatureDisappear(creature) npcHandler:onCreatureDisappear(creature) end
function onCreatureSay(creature, type, msg) npcHandler:onCreatureSay(creature, type, msg:lower()) end
function onThink() npcHandler:onThink() end

local talkState = {}

-----------------------------------------------------
-- Constantes e Configurações (Assumindo globais ou definindo aqui para segurança)
-- Se estiverem em lib externa, ok. Mas vou manter a estrutura do script original.
-----------------------------------------------------
-- O script original usava variáveis globais ou externas como sequencialTasks, dailyTaskMonsters.
-- Vou manter o uso delas.

keywordHandler:addKeyword({'trade'}, function(cid)
    local player = Player(cid)
    if not player then return false end

    -- Assumindo que buildTaskTradeModal existe globalmente ou em lib
    if buildTaskTradeModal then
        buildTaskTradeModal():sendToPlayer(player)
    else
        npcHandler:say({PT="Modal de trade não encontrado.", EN="Trade modal not found."}, cid)
    end
    return true
end)

keywordHandler:addKeyword({'reportar', 'report', 'task'}, function(cid)
    local player = Player(cid)
    if not player then return false end
    local currentTime = os.time()

    local messages = {}

    local current = player:getStorageValue(STORAGE_TASK_SEQUENCIAL)
    local taskData = sequencialTasks and sequencialTasks[current]

    if current >= 1 and taskData then
        local kills = player:getStorageValue(STORAGE_TASK_SEQUENCIAL_KILLS) or 0

        if kills >= taskData.killsRequired then
            local nextTask = sequencialTasks[current + 1]
            if nextTask then
                table.insert(messages, {PT="Parabéns! Você completou a task de " .. taskData.name .. "!\nSua próxima task é matar " .. nextTask.killsRequired .. " " .. nextTask.name .. "(s). Boa sorte!", EN="Congratulations! You completed the task of " .. taskData.name .. "!\nYour next task is to kill " .. nextTask.killsRequired .. " " .. nextTask.name .. "(s). Good luck!"})
            else
                table.insert(messages, {PT="Parabéns! Você completou a última task sequencial disponível.", EN="Congratulations! You completed the last available sequential task."})
            end
            player:setStorageValue(STORAGE_TASK_SEQUENCIAL, current + 1)
            player:setStorageValue(STORAGE_TASK_SEQUENCIAL_KILLS, 0)
            local rewardMsg = giveTaskRewards(player, taskData.rewards) -- Assumindo função global
            if rewardMsg ~= "" then
                table.insert(messages, {PT="Você recebeu as seguintes recompensas pela task sequencial:" .. rewardMsg, EN="You received the following rewards for the sequential task:" .. rewardMsg})
            end
        else
            table.insert(messages, {PT="Task: você matou " .. kills .. "/" .. taskData.killsRequired .. " " .. taskData.name .. "(s). Continue caçando!", EN="Task: you killed " .. kills .. "/" .. taskData.killsRequired .. " " .. taskData.name .. "(s). Keep hunting!"})
        end
    end

    if player:getStorageValue(STORAGE_TASK_ACTIVE) == 1 then
        local monsterId = player:getStorageValue(STORAGE_TASK_MONSTER)
        local taskStartTime = player:getStorageValue(STORAGE_TASK_TIME)
        local kills = player:getStorageValue(STORAGE_TASK_KILLS) or 0
        local monsterData = dailyTaskMonsters and dailyTaskMonsters[monsterId]

        if monsterData then
            if currentTime > taskStartTime + TASK_TIME then
                npcHandler:say({PT="Você não entregou a task daily a tempo. Ela expirou.", EN="You did not deliver the daily task in time. It expired."}, cid)
                resetDailyTask(player) -- Assumindo global
                return true
            end

            if kills >= KILLS_REQUIRED then
                npcHandler:say({PT="Parabéns! Você completou a task daily contra " .. monsterData.name .. "!\nAqui está sua recompensa.", EN="Congratulations! You completed the daily task against " .. monsterData.name .. "!\nHere is your reward."}, cid)
                
                local maxLevel = 800
                local rebornLevel = player:getStorageValue(4241) or 0
                if rebornLevel <= 0 then
                    maxLevel = 600
                end
                if player:getLevel() < maxLevel then
                    local levelsToAdd = math.min(2, maxLevel - player:getLevel())
                    player:addLevel(levelsToAdd)
                end

                resetDailyTask(player)
                local rewardMsg = giveTaskRewards(player, monsterData.rewards)
                if rewardMsg ~= "" then
                    npcHandler:say({PT="Você recebeu as seguintes recompensas pela daily task:" .. rewardMsg, EN="You received the following rewards for the daily task:" .. rewardMsg}, cid)
                end
                return true
            else
                npcHandler:say({PT="Você ainda não matou todos os " .. monsterData.name .. ". Você matou " .. kills .. "/" .. KILLS_REQUIRED .. ".", EN="You have not killed all " .. monsterData.name .. ". You killed " .. kills .. "/" .. KILLS_REQUIRED .. "."}, cid)
                return true
            end
        else
            resetDailyTask(player)
            npcHandler:say({PT="Erro: sua task daily não pôde ser encontrada. A task foi resetada.", EN="Error: your daily task could not be found. The task was reset."}, cid)
            return true
        end
    end

    if #messages == 0 then
        table.insert(messages, {PT="Você não possui nenhuma task ativa no momento. Diga {task} para iniciar.", EN="You do not have any active task at the moment. Say {task} to start."})
    end

    -- Processar mensagens para tabela de idiomas
    local finalMsg = {PT="", EN=""}
    for _, msg in ipairs(messages) do
        if type(msg) == "table" then
            finalMsg.PT = finalMsg.PT .. msg.PT .. "\n"
            finalMsg.EN = finalMsg.EN .. msg.EN .. "\n"
        else
            finalMsg.PT = finalMsg.PT .. msg .. "\n"
            finalMsg.EN = finalMsg.EN .. msg .. "\n"
        end
    end
    
    npcHandler:say(finalMsg, cid)
    
    -- Iniciar dialogo para pegar task se nao tiver active
    if player:getStorageValue(STORAGE_TASK_ACTIVE) ~= 1 then
         talkState[cid] = 1
    end
    
    return true
end)

function creatureSayCallback(cid, type, msg)
    local player = Player(cid)
    if not player then return false end

    msg = msg:lower():gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")

    if talkState[cid] == 1 then
        local monsterId = eliteMonsterNameToId and eliteMonsterNameToId[msg]
        if not monsterId then
            npcHandler:say({PT="Esse monstro não está disponível. Tente novamente.", EN="This monster is not available. Try again."}, cid)
            -- Nao resetar talkState para permitir tentar de novo? Ou resetar? O original resetava.
            talkState[cid] = nil
            return true
        end

        local monster = dailyTaskMonsters[monsterId]
        if not monster then
            npcHandler:say({PT="Erro interno: monstro não encontrado na lista.", EN="Internal error: monster not found in list."}, cid)
            talkState[cid] = nil
            return true
        end

        if player:getLevel() < monster.minLevel then
            npcHandler:say({PT="Você precisa ser pelo menos level " .. monster.minLevel .. " para pegar essa task daily.", EN="You need to be at least level " .. monster.minLevel .. " to take this daily task."}, cid)
            talkState[cid] = nil
            return true
        end

        if player:getItemCount(2160) < COST then
            npcHandler:say({PT="Você precisa de " .. COST .. " gold bars para começar essa task daily.", EN="You need " .. COST .. " gold bars to start this daily task."}, cid)
            talkState[cid] = nil
            return true
        end

        player:removeItem(2160, COST)
        player:setStorageValue(STORAGE_TASK_ACTIVE, 1)
        player:setStorageValue(STORAGE_TASK_MONSTER, monsterId)
        player:setStorageValue(STORAGE_TASK_KILLS, 0)
        player:setStorageValue(STORAGE_TASK_TIME, os.time() + TASK_TIME)

        npcHandler:say({PT="Sua task daily foi iniciada. Mate " .. KILLS_REQUIRED .. " " .. monster.name .. "(s) em até 24 horas. Boa sorte!", EN="Your daily task has started. Kill " .. KILLS_REQUIRED .. " " .. monster.name .. "(s) within 24 hours. Good luck!"}, cid)
        talkState[cid] = nil
        return true
    end

    return false
end

npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
