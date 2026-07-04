local npcName = "Monster Hunt"
local spawnPos = Position(103, 186, 7)
local storageKey = 23281
local rewardStorage = 11145
local npcRemoveTime = 60 * 60 * 1000
local prorragacaoAtiva = false
local prorrogacaoTempo = 5

local function spawnNpc()
    local npc = Game.createNpc(npcName, spawnPos)
    if npc then
        npc:setMasterPos(spawnPos)
        npc:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
    end
	MonsterHuntActive.active = true
    for _, player in ipairs(Game.getPlayers()) do
        if player:getStorageValue(storageKey) > 0 then
            player:setStorageValue(storageKey, 0)
        end
    end
    db.query("UPDATE player_storage SET value = 0 WHERE `key` = " .. storageKey .. ";")
	Game.broadcastMessage("[MONSTER HUNT EVENT] O evento acabou de comeùar! aniquile o mùximo de monstros lvl.2 e venùa o evento para receber +1 presence point!", MESSAGE_EVENT_ADVANCE)
end

local function prorrogacaoCountdown(minutosRestantes)
    if minutosRestantes > 0 then
        Game.broadcastMessage("[MONSTER HUNT EVENT] Prorrogaùùo: " .. minutosRestantes .. " minuto(s) restantes!", MESSAGE_EVENT_ADVANCE)
        addEvent(prorrogacaoCountdown, 60 * 1000, minutosRestantes - 1)
    end
end

local function endEvent()
    local topPlayers = {}

    for _, player in ipairs(Game.getPlayers()) do
        local score = player:getStorageValue(storageKey)
        if score > 0 then
            table.insert(topPlayers, {
                id = player:getId(),
                name = player:getName(),
                score = score,
                online = true
            })
        end
    end

    local resultId = db.storeQuery([[
        SELECT p.id, p.name, s.value
        FROM players p
        INNER JOIN player_storage s ON p.id = s.player_id
        WHERE s.key = ]] .. storageKey .. [[ AND s.value > 0
    ]])

    if resultId then
        repeat
            local id = result.getNumber(resultId, "id")
            local name = result.getString(resultId, "name")
            local value = result.getNumber(resultId, "value")
            local alreadyOnline = false
            for _, p in ipairs(topPlayers) do
                if p.id == id then
                    alreadyOnline = true
                    break
                end
            end
            if not alreadyOnline then
                table.insert(topPlayers, {id = id, name = name, score = value, online = false})
            end
        until not result.next(resultId)
        result.free(resultId)
    end

    table.sort(topPlayers, function(a, b) return a.score > b.score end)

	if #topPlayers > 1 
	   and topPlayers[1].score == topPlayers[2].score 
	   and topPlayers[1].score > 0 
	   and topPlayers[1].id ~= topPlayers[2].id then
		   
		if not prorragacaoAtiva then
			prorragacaoAtiva = true
			Game.broadcastMessage("[MONSTER HUNT EVENT] Empate! Prorrogaùùo de " .. prorrogacaoTempo .. " minutos ativada!", MESSAGE_EVENT_ADVANCE)
			prorrogacaoCountdown(prorrogacaoTempo)
			addEvent(endEvent, prorrogacaoTempo * 60 * 1000)
			return
		else
			Game.broadcastMessage("[MONSTER HUNT EVENT] O evento terminou empatado, ninguùm venceu.", MESSAGE_EVENT_ADVANCE)
			local spectators = Game.getSpectators(spawnPos, false, false, 3, 3, 3, 3)
			for _, spec in ipairs(spectators) do
				if spec:isNpc() and spec:getName() == "Monster Hunt [EVENT]" then
					spec:remove()
				end
			end
		end

	elseif #topPlayers > 0 then
		local winner = topPlayers[1]
		if winner.online then
			local player = Player(winner.name)
			if player then
				setPresencePoints(player, 1)
			end
		else
			db.query("INSERT INTO player_storage (player_id, `key`, `value`) VALUES (" .. winner.id .. ", " .. rewardStorage .. ", 1) ON DUPLICATE KEY UPDATE `value` = `value` + 1;")
		end
		Game.broadcastMessage("[MONSTER HUNT EVENT] O jogador " .. winner.name .. " venceu o evento com " .. winner.score .. " monstros lvl.2 aniquilados e recebeu +1 presence point!", MESSAGE_EVENT_ADVANCE)
		local spectators = Game.getSpectators(spawnPos, false, false, 3, 3, 3, 3)
		for _, spec in ipairs(spectators) do
			if spec:isNpc() and spec:getName() == "Monster Hunt [EVENT]" then
				spec:remove()
			end
		end

	else
		Game.broadcastMessage("[MONSTER HUNT EVENT] O evento terminou sem vencedor, ninguùm aniquilou algum monstro lvl.2.", MESSAGE_EVENT_ADVANCE)
		local spectators = Game.getSpectators(spawnPos, false, false, 3, 3, 3, 3)
		for _, spec in ipairs(spectators) do
			if spec:isNpc() and spec:getName() == "Monster Hunt [EVENT]" then
				spec:remove()
			end
		end
	end

	for _, player in ipairs(Game.getPlayers()) do
		player:setStorageValue(storageKey, 0)
	end
    db.query("UPDATE player_storage SET value = 0 WHERE `key` = " .. storageKey .. ";")
	
	MonsterHuntActive.active = false

    if prorragacaoAtiva then
        prorragacaoAtiva = false
        return
    end
end

function onTime(interval)
    spawnNpc()
    addEvent(endEvent, npcRemoveTime)
    return true
end