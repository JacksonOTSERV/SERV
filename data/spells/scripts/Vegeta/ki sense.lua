local FOLLOW_DURATION = 5
local TELEPORT_INTERVAL = 1
local exhaustion_time = 40
local exhaustion_storage = STORAGE_ESPECIAL1

local blockedAreas = {
    [1] = {fromPos = {x = 1023, y = 97, z = 7}, toPos = {x = 1046, y = 120, z = 7}},
    [2] = {fromPos = {x = 1093, y = 97, z = 7}, toPos = {x = 1116, y = 120, z = 7}},
    [3] = {fromPos = {x = 1163, y = 97, z = 7}, toPos = {x = 1186, y = 120, z = 7}},
    [4] = {fromPos = {x = 1233, y = 97, z = 7}, toPos = {x = 1256, y = 120, z = 7}},
    [5] = {fromPos = {x = 1303, y = 97, z = 7}, toPos = {x = 1326, y = 120, z = 7}},
    [6] = {fromPos = {x = 1023, y = 166, z = 7}, toPos = {x = 1046, y = 189, z = 7}},
    [7] = {fromPos = {x = 1093, y = 166, z = 7}, toPos = {x = 1116, y = 189, z = 7}},
    [8] = {fromPos = {x = 1163, y = 166, z = 7}, toPos = {x = 1186, y = 189, z = 7}},
    [9] = {fromPos = {x = 1233, y = 166, z = 7}, toPos = {x = 1256, y = 189, z = 7}},
    [10] = {fromPos = {x = 1303, y = 166, z = 7}, toPos = {x = 1326, y = 189, z = 7}},
}

local function isInBlockedArea(pos)
    for _, area in pairs(blockedAreas) do
        local fromPos, toPos = area.fromPos, area.toPos
        if pos.z == fromPos.z and
           pos.x >= fromPos.x and pos.x <= toPos.x and
           pos.y >= fromPos.y and pos.y <= toPos.y then
            return true
        end
    end
    return false
end

local function invisystemoutfit(player, tempo, restoreHealth)
	if not player or not player:isPlayer() then
		return false
	end

	if player:isInGhostMode() then
		return false
	end

	if tempo <= 0 then
		player:sendCancelMessage("Error.")
		return false
	end
	
	local playId = player:getId()

	if restoreHealth then
		player:addHealth(player:getMaxHealth())
	end

	player:setGhostMode(true)

	addEvent(function()
		local currentPlayer = Player(playId)
		if currentPlayer then
			local playerPosition = currentPlayer:getPosition()
			local tile = Tile(playerPosition)
			if tile then
				local item = tile:getItemById(11398)
				if item then
					item:remove()
				end
			end
			currentPlayer:setGhostMode(false)
		end
	end, tempo * 1000)
	return true
end

local function isSpellAllowed(player, target)
    if not player or not target then
        return false
    end

    if target:getGroup():getId() > 3 then
        player:sendCancelMessage("O jogador n?o foi encontrado.")
        return false
    end

    if getCreatureCondition(target, CONDITION_OUTFIT, 125) or getCreatureCondition(target, CONDITION_OUTFIT, 127) then
        return false
    end

    return true
end

function findPlayerByName(name)
    for _, p in ipairs(Game.getPlayers()) do
        if p:getName():lower() == name:lower() then
            return p
        end
    end
    return nil
end

function onCastSpell(player, variant)
    local targetName = variant:getString()
    local target = findPlayerByName(targetName)
	local playerId = player:getId()
    local targetId = target:getId()

    if not target then
        player:sendCancelMessage("O jogador n?o foi encontrado.")
        return false
    end
	
    if exhaustion.check(player, exhaustion_storage) then
        player:sendCancelMessage("Aguarde " .. tostring(exhaustion.get(player, exhaustion_storage)) .. " segundos para usar este especial novamente.")
        return false
    end
	
    if isInBlockedArea(player:getPosition()) or isInBlockedArea(target:getPosition()) then
        player:sendCancelMessage("Voc? n?o pode usar esta t?cnica nesta ?rea.")
        return false
    end

    if target == player then
        player:sendCancelMessage("Voc? n?o pode usar essa tecnica em si mesmo.")
        return false
    end
	
    if target:getLevel() >= player:getLevel() + 100 then
        player:sendCancelMessage("Voc? n?o pode visualizar jogadores que possuem 100 leveis a mais que voc?.")
        return false
    end
	
	if not isSpellAllowed(player, target) then
		return false
	end
	
	if player:isInGhostMode() then
		return false
	end
	
    local playerParty = player:getParty()
    if playerParty and playerParty == target:getParty() then
        player:sendCancelMessage("Voc? n?o pode usar essa tecnica em membros da sua party.")
        return false
    end
	
	player:setStorageValue(1000, 6 + os.time())
    local cloth = player:getOutfit()
    local health = player:getHealth()
    local maxhealth = player:getMaxHealth()
	local position = player:getPosition()
    local MaximoSummon = 1
    local targetDirection = getCreatureLookDirection(player)
    
    local summons = player:getSummons()
    local hasOtherSummon = false

    local originalPosition = player:getPosition()
    local lastTargetPosition = target:getPosition()
	
	addEvent(function()
	local player = Player(playerId)
	local target = Player(targetId)
		if player and target then
			player:teleportTo(target:getPosition())
			shader.sendShaderOtc(player, "grayscale", 6)
		end
	end, 50)
	
	local function removeMonstro(nomeMonstro)
		for x = position.x, position.x do
			for y = position.y, position.y do
				local tile = Tile(Position(x, y, position.z))
				if tile then
					local creature = tile:getTopCreature()
					if creature and creature:isMonster() and creature:getName() == player:getName() then
						creature:remove()
					end
				end
			end
		end
	end

	local function hasMonsterWithPlayerName(player)
		for x = position.x, position.x do
			for y = position.y, position.y do
				local tile = Tile(Position(x, y, position.z))
				if tile then
					local creature = tile:getTopCreature()
					if creature and creature:isMonster() and creature:getName() == player:getName() then
						return true
					end
				end
			end
		end
		return false
	end

    local function followTarget(playerId, targetId, remainingTime, originalPos, lastPos)
        local player = Player(playerId)
        local target = Player(targetId)

        if not player or not target then
            if player and hasMonsterWithPlayerName(player) then
				removeMonstro("".. player:getName() .."")
                player:teleportTo(originalPos, true)
                doCreatureSetHideHealth(player, false)
                doRemoveCondition(player, CONDITION_OUTFIT, 127)
				player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "O jogador deslogou. Voc? voltou para o local que utilizou a tecnica.")
				doCreatureSetLookDirection(player, targetDirection)
				if player:getStorageValue(10289) - os.time() > 0 then
					local outfit = player:getOutfit() 
					outfit.lookAura = 11
					player:setOutfit(outfit)
				end
				shader.sendShaderOtc(player, "Default", 1)
            end
            return
        end
		
		if remainingTime <= 0 and hasMonsterWithPlayerName(player) then
			if hasMonsterWithPlayerName(player) then
				removeMonstro(player:getName())
			end
			player:teleportTo(originalPos, true)
			doRemoveCondition(player, CONDITION_OUTFIT, 127)
			doCreatureSetHideHealth(player, false)
			doCreatureSetLookDirection(player, targetDirection)
			if player:getStorageValue(10289) - os.time() > 0 then
				local outfit = player:getOutfit() 
				outfit.lookAura = 11
				player:setOutfit(outfit)
			end
			shader.sendShaderOtc(player, "Default", 1)
			return
		end
		
		local mover = Condition(CONDITION_MOVE)
		mover:setParameter(CONDITION_PARAM_TICKS, 1)
		player:addCondition(mover)

        if target:getPosition().x ~= lastPos.x or target:getPosition().y ~= lastPos.y or target:getPosition().z ~= lastPos.z then
            player:teleportTo(target:getPosition(), true)
            lastPos = target:getPosition()
        end
        addEvent(followTarget, 1, playerId, targetId, remainingTime - 1, originalPos, lastPos)
    end
	
    doCreatureSetHideHealth(player, true)
    local outfitCondition = Condition(CONDITION_OUTFIT)
    outfitCondition:setParameter(CONDITION_PARAM_SUBID, 127)
    outfitCondition:setTicks(6 * 1000)
    outfitCondition:setOutfit({lookType = 157})
    
    player:addCondition(outfitCondition)
	
    addEvent(followTarget, TELEPORT_INTERVAL, player:getId(), target:getId(), (FOLLOW_DURATION * 1000) / TELEPORT_INTERVAL, originalPosition, lastTargetPosition)
	target:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Voc? est? sendo spectado.")
	
	local pos = player:getPosition()
	local bpos = {
		{x=pos.x, y = pos.y, z = pos.z},
	} 
        
	local farAwayPos = {x = 485, y = 272, z = 7}
	local summon = Game.createMonster("Vegeta", farAwayPos, true, false)
	if summon then
		summon:setName(''.. player:getName() ..'', 'a '.. player:getName() ..'')
	end
	summon:setOutfit(cloth)
	local stun = Condition(CONDITION_STUN)
	stun:setParameter(CONDITION_PARAM_TICKS, 5 * 1000)
    player:addCondition(stun)
	
	local outfit = summon:getOutfit() 
	outfit.lookAura = 157
	summon:setOutfit(outfit)
	summon:teleportTo(position, true)
	doCreatureSetLookDirection(summon, targetDirection)
	invisystemoutfit(player, 5, true)
	exhaustion.set(player, exhaustion_storage, exhaustion_time)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(player, "Ki sense")
    end
    return true
end