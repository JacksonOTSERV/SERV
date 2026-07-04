local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

npcHandler:setMessage(MESSAGE_GREET, {
    PT = "Olá |PLAYERNAME|. Pergunte-me sobre {rank} ou {info}.",
    EN = "Hello |PLAYERNAME|. Ask me about {rank} or {info}."
})
npcHandler:setMessage(MESSAGE_FAREWELL, {
    PT = "Adeus.",
    EN = "Goodbye."
})
npcHandler:setMessage(MESSAGE_WALKAWAY, {
    PT = "Adeus.",
    EN = "Goodbye."
})

local eventHours = {11, 13, 15, 17}
local eventDuration = 60 * 60

local function getTimeRemaining()
    local now = os.date("*t")
    local currentTime = now.hour * 3600 + now.min * 60 + now.sec
    local remaining = nil

    for _, hour in ipairs(eventHours) do
        local startTime = hour * 3600
        if currentTime < startTime then
            remaining = startTime - currentTime
            break
        elseif currentTime >= startTime and currentTime < startTime + eventDuration then
            remaining = startTime + eventDuration - currentTime
            break
        end
    end

    if not remaining then
        remaining = (24*3600 - currentTime) + eventHours[1]*3600
    end

    local minutes = math.floor(remaining / 60)
    local seconds = remaining % 60
    return string.format("%02d min %02d sec", minutes, seconds)
end

RankModalId = 20001

local function buildRankModal(player)
    local lang = math.max(0, player:getStorageValue(45001))
    local title = (lang == 1 and "Monster Hunt Ranking" or "Ranking Caça aos Monstros")
    local subtitle = (lang == 1 and "Top players in the current hunt event!" or "Top jogadores no evento de caça atual!")
    local closeText = (lang == 1 and "Close" or "Fechar")
    
    local modal = ModalWindow(RankModalId, title, subtitle)
    modal:addButton(1, closeText)
    modal:setDefaultEscapeButton(1)
    modal:setDefaultEnterButton(1)

    local rankList = {}

    for _, p in ipairs(Game.getPlayers()) do
        local value = p:getStorageValue(23281)
        if value > 0 then
            table.insert(rankList, {name = p:getName(), value = value})
        end
    end

    local resultId = db.storeQuery([[
        SELECT p.name, s.value 
        FROM players p 
        INNER JOIN player_storage s ON p.id = s.player_id 
        WHERE s.key = 23281 AND s.value > 0;
    ]])
    if resultId then
        repeat
            local name = result.getString(resultId, "name")
            local value = result.getNumber(resultId, "value")
            
			if not Player(name) then
				table.insert(rankList, {name = name, value = value})
			end
        until not result.next(resultId)
        result.free(resultId)
    end

    table.sort(rankList, function(a, b) return a.value > b.value end)

    if #rankList == 0 then
        modal:addChoice(1, (lang == 1 and "No players found." or "Nenhum player encontrado."))
    else
        for i = 1, math.min(20, #rankList) do
            local suffix = (lang == 1 and " monsters lvl.2 killed" or " monstros lvl.2 aniquilados")
            modal:addChoice(i, rankList[i].name .. " - " .. rankList[i].value .. suffix)
        end
    end

    return modal
end

local function creatureSayCallback(cid, type, msg)
    if not npcHandler:isFocused(cid) then return false end
    local player = Player(cid)

    msg = msg:lower()

    if msg == "rank" then
        buildRankModal(player):sendToPlayer(player)
    elseif msg:find("saber") or msg:find("info") or msg:find("know") then
        local timeRemaining = getTimeRemaining()
        local lang = math.max(0, player:getStorageValue(45001))
        local message = ""
        
        if lang == 1 then
             message = "The event works simply!\n\n" ..
                       "Every day at:\n" ..
                       "11H, 13H, 15H and 17H the MONSTER HUNT event will start.\n\n" ..
                       "The player who kills the most lvl.2 monsters within ONE HOUR will receive 1x presence points.\n\n" ..
                       "If there is a tie, there will be 5 minutes overtime. If still tied, nobody wins.\n\n" ..
                       "Time remaining for next event: " .. timeRemaining
        else
             message = "O evento funciona de forma simples!\n\n" ..
                        "Todos os dias nos horários:\n" ..
                        "11H, 13H, 15H e 17H o evento MONSTER HUNT irá iniciar.\n\n" ..
                        "O sistema funciona de forma simples e prática, o player dentro de UMA HORA que mais matar monstros lvl.2 receberá 1x presence points.\n\n" ..
                        "Caso dentro dessas uma hora tenha um empate, entrará em prorrogação de mais 5 minutos, caso nesses 5 minutos não tenha vencedor, ninguém vence.\n\n" ..
                        "Tempo restante para o próximo evento: " .. timeRemaining
        end
        player:sendTextMessage(MESSAGE_INFO_DESCR, message)
    end
    return true
end

function onCreatureAppear(cid) npcHandler:onCreatureAppear(cid) end
function onCreatureDisappear(cid) npcHandler:onCreatureDisappear(cid) end
function onCreatureSay(cid, type, msg) npcHandler:onCreatureSay(cid, type, msg) end
function onThink() npcHandler:onThink() end

npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
