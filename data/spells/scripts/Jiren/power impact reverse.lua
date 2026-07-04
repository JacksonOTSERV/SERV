local stun = Condition(CONDITION_STUN)
stun:setParameter(CONDITION_PARAM_TICKS, 3500)

local config = {
	storage = STORAGE_ESPECIAL1,  -- storage do CD
	reuse_delay = 35       		  -- tempo para reutilizar a spell em segundos
}

function onCastSpell(player, var)
    if not player or not player:isPlayer() then
        return false
    end
    local currentTime = os.time()
    local lastCast = player:getStorageValue(config.storage)

    if lastCast > currentTime then
        player:sendCancelMessage("Você precisa esperar " .. (lastCast - currentTime) .. " segundos para usar este especial novamente.")
        return false
    end

    local target = player:getTarget()
    if not target then
        player:sendCancelMessage("Nenhum alvo selecionado.")
        return false
    end

    local targetPos = target:getPosition()
    local playerPos = player:getPosition()
    local playerId = player:getId()
    local targetId = target:getId()
    
    local tile = Tile(targetPos)
    if tile then
        for _, item in ipairs(tile:getItems()) do
            if item:getId() == 1228 or item:getId() == 1230 or item:getId() == 5104 or item:getId() == 6264 or item:getId() == 6266 or item:getId() == 1246 or item:getId() == 1248 or item:getId() == 6906 or item:getId() == 1260 or item:getId() == 1262 then
                player:sendCancelMessage("Você não pode stompar nesse local.")
                return false
            end
        end
    end

    if not playerPos:isSightClear(targetPos) then
        player:sendCancelMessage("O caminho está bloqueado por um obstáculo.")
        return false
    end

    if playerPos:getDistance(targetPos) > 8 then
        player:sendCancelMessage("O alvo está muito distante.")
        return false
    end

    if tile and tile:hasFlag(TILESTATE_PROTECTIONZONE) then
        player:sendCancelMessage("Você não pode stompar em players na zona PZ.")
        return false
    end

    doSendMagicEffect({x = playerPos.x+2, y = playerPos.y, z = playerPos.z}, 287)
    
    local AreaX = 15
    local AreaY = 8

    local spectators = Game.getSpectators(playerPos, false, true, AreaX, AreaX, AreaY, AreaY)
    if #spectators == 0 then
        return false
    end

    for _, spectator in ipairs(spectators) do
        spectator:JumpCreature(playerId, 30, 300, 1)
    end

	local player = Player(playerId)
	local target = Player(targetId)
	if player and target then
		player:teleportTo(targetPos)
		doSendMagicEffect({x = targetPos.x+1, y = targetPos.y+1, z = targetPos.z}, 286)
		target:addCondition(stun)
	end

	local target = Player(targetId) or Creature(targetId)
	local player = Player(playerId)
	if target and target:isMonster() and target:isCreature() then
		player:teleportTo(targetPos)
		doSendMagicEffect({x = targetPos.x+1, y = targetPos.y+1, z = targetPos.z}, 286)
	end
    
    player:setStorageValue(config.storage, currentTime + config.reuse_delay)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(player, "Power impact reverse")
    end
    return true
end