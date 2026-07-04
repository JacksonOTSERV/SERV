local exhaustion_time = 8
local exhaustion_storage = STORAGE_ESPECIAL1

local function isSamePosition(pos1, pos2)
    return pos1.x == pos2.x and pos1.y == pos2.y and pos1.z == pos2.z
end

local function moveCreatureStepByStep(playerId, targetPosition, attempt)
    attempt = attempt or 1
    local maxAttempts = 4

    local creature = Player(playerId)
    if not creature or creature:isRemoved() or not creature:isPlayer() then return end

    local currentPosition = creature:getPosition()
    if isSamePosition(currentPosition, targetPosition) then return end

    if attempt > maxAttempts then return end

    local moveDelay = 50

    if getCreatureCondition(creature, CONDITION_OUTFIT, 125) then return end

    if getCreatureCondition(creature, CONDITION_STUN) then
        local mover = Condition(CONDITION_MOVE)
        mover:setParameter(CONDITION_PARAM_TICKS, 1)
        creature:addCondition(mover)
    end

    local nextPosition = Position(currentPosition)
    local direction

    if currentPosition.x < targetPosition.x and currentPosition.y < targetPosition.y then
        nextPosition.x = nextPosition.x + 1
        nextPosition.y = nextPosition.y + 1
        direction = DIRECTION_SOUTHEAST
    elseif currentPosition.x > targetPosition.x and currentPosition.y < targetPosition.y then
        nextPosition.x = nextPosition.x - 1
        nextPosition.y = nextPosition.y + 1
        direction = DIRECTION_SOUTHWEST
    elseif currentPosition.x < targetPosition.x and currentPosition.y > targetPosition.y then
        nextPosition.x = nextPosition.x + 1
        nextPosition.y = nextPosition.y - 1
        direction = DIRECTION_NORTHEAST
    elseif currentPosition.x > targetPosition.x and currentPosition.y > targetPosition.y then
        nextPosition.x = nextPosition.x - 1
        nextPosition.y = nextPosition.y - 1
        direction = DIRECTION_NORTHWEST
    elseif currentPosition.x < targetPosition.x then
        nextPosition.x = nextPosition.x + 1
        direction = DIRECTION_EAST
    elseif currentPosition.x > targetPosition.x then
        nextPosition.x = nextPosition.x - 1
        direction = DIRECTION_WEST
    elseif currentPosition.y < targetPosition.y then
        nextPosition.y = nextPosition.y + 1
        direction = DIRECTION_SOUTH
    elseif currentPosition.y > targetPosition.y then
        nextPosition.y = nextPosition.y - 1
        direction = DIRECTION_NORTH
    end

    local tile = Tile(nextPosition)
    local canMove = tile and tile:getGround() and
                    not tile:hasFlag(TILESTATE_BLOCKSOLID) and
                    not tile:hasFlag(TILESTATE_PROTECTIONZONE) and
                    not tile:hasFlag(TILESTATE_HOUSE) and
                    not tile:hasFlag(TILESTATE_FLOORCHANGE) and
                    not tile:hasFlag(TILESTATE_TELEPORT) and
                    not tile:hasFlag(TILESTATE_BLOCKPATH) and
                    not tile:hasFlag(TILESTATE_NOPVPZONE) and
                    tile:getCreatureCount() == 0

    if not canMove then
        local stun = Condition(CONDITION_STUN)
        stun:setParameter(CONDITION_PARAM_TICKS, 3000)
        creature:addCondition(stun)
        doSendMagicEffect(currentPosition, 91, currentCreature)
        return
    end

    doMoveCreature(creature, direction)

    if not isSamePosition(nextPosition, currentPosition) then
        addEvent(function()
            moveCreatureStepByStep(playerId, targetPosition, attempt + 1)
        end, moveDelay)
    end
end

function onCastSpell(creature, variant)
	local player = Player(creature)
	if not player then return false end

	if creature:isRemoved() then
		return false
	end

    if exhaustion.check(creature, exhaustion_storage) then
        creature:sendCancelMessage("Aguarde " .. tostring(exhaustion.get(player, exhaustion_storage)) .. " segundos para usar este especial novamente.")
        return false
    end

    if creature:hasSecureMode() then
        creature:sendCancelMessage("Voce precisa ativar seu PVP para utilizar essa tecnica.")
        return false
    end

    local tile = Tile(creature:getPosition())
    if tile and tile:hasFlag(TILESTATE_NOPVPZONE) then
        creature:sendCancelMessage("Voce nao pode utilizar essa tecnica aqui.")
        return false
    end

	local areaRadius = 2
	local playerPos = player:getPosition()

	for i = 1, 4 do
		for dx = -areaRadius, areaRadius do
			for dy = -areaRadius, areaRadius do
				local checkPos = Position(playerPos.x + dx, playerPos.y + dy, playerPos.z)
				if checkPos ~= playerPos then
					local tile = Tile(checkPos)
					if tile then
						local target = tile:getTopCreature()
						if target and target:isPlayer() and target ~= player then
							local targetPlayer = Player(target)
							if not (player:getParty() and targetPlayer:getParty() and player:getParty() == targetPlayer:getParty()) then
								local offsetX = dx ~= 0 and (dx / math.abs(dx)) or 0
								local offsetY = dy ~= 0 and (dy / math.abs(dy)) or 0
								local maxSteps = 4 - i
								local finalPos = target:getPosition()

								for step = 1, maxSteps do
									local nextPos = Position(finalPos.x + offsetX, finalPos.y + offsetY, finalPos.z)
									local nextTile = Tile(nextPos)
									if nextTile then
										finalPos = nextPos
									else
										break
									end
								end

								local targetId = target:getId()
								if finalPos ~= target:getPosition() then
									moveCreatureStepByStep(targetId, finalPos)
								end
							end
						end
					end
				end
			end
		end
	end
	
	local position = player:getPosition()
    doSendMagicEffect({x = position.x + 1, y = position.y, z = position.z}, 110)
    doSendMagicEffect({x = position.x, y = position.y, z = position.z}, 110)
	doSendMagicEffect({x = position.x, y = position.y + 1, z = position.z}, 110)
	doSendMagicEffect({x = position.x + 1, y = position.y +1, z = position.z}, 110)
	doSendMagicEffect({x = position.x + 1, y = position.y - 1, z = position.z}, 110)
	doSendMagicEffect({x = position.x, y = position.y - 1, z = position.z}, 110)
	
	player:setPzLockTime(0)
	exhaustion.set(player, exhaustion_storage, exhaustion_time)
	    -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Kiai")
    end
	return true
end