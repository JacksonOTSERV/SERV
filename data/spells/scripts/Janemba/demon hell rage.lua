local config = {
    storage = STORAGE_ESPECIAL1,
	storage_mundo = 6888,
    tempo = 75,
	duration_spell = 8,
    areas = {
        [1] = {fromPos = {x = 1023, y = 97, z = 7}, toPos = {x = 1046, y = 120, z = 7}, playerPos = {x = 1035, y = 108, z = 7}, targetPos = {x = 1035, y = 109, z = 7}},
        [2] = {fromPos = {x = 1093, y = 97, z = 7}, toPos = {x = 1116, y = 120, z = 7}, playerPos = {x = 1105, y = 108, z = 7}, targetPos = {x = 1105, y = 109, z = 7}},
        [3] = {fromPos = {x = 1163, y = 97, z = 7}, toPos = {x = 1186, y = 120, z = 7}, playerPos = {x = 1175, y = 108, z = 7}, targetPos = {x = 1175, y = 109, z = 7}},
        [4] = {fromPos = {x = 1233, y = 97, z = 7}, toPos = {x = 1256, y = 120, z = 7}, playerPos = {x = 1245, y = 108, z = 7}, targetPos = {x = 1245, y = 109, z = 7}},
		[5] = {fromPos = {x = 1303, y = 97, z = 7}, toPos = {x = 1326, y = 120, z = 7}, playerPos = {x = 1315, y = 108, z = 7}, targetPos = {x = 1315, y = 109, z = 7}},
		[6] = {fromPos = {x = 1023, y = 166, z = 7}, toPos = {x = 1046, y = 189, z = 7}, playerPos = {x = 1035, y = 177, z = 7}, targetPos = {x = 1035, y = 178, z = 7}},
		[7] = {fromPos = {x = 1093, y = 166, z = 7}, toPos = {x = 1116, y = 189, z = 7}, playerPos = {x = 1105, y = 177, z = 7}, targetPos = {x = 1105, y = 178, z = 7}},
		[8] = {fromPos = {x = 1163, y = 166, z = 7}, toPos = {x = 1186, y = 189, z = 7}, playerPos = {x = 1175, y = 177, z = 7}, targetPos = {x = 1175, y = 178, z = 7}},
		[9] = {fromPos = {x = 1233, y = 166, z = 7}, toPos = {x = 1256, y = 189, z = 7}, playerPos = {x = 1245, y = 177, z = 7}, targetPos = {x = 1245, y = 178, z = 7}},
		[10] = {fromPos = {x = 1303, y = 166, z = 7}, toPos = {x = 1326, y = 189, z = 7}, playerPos = {x = 1315, y = 177, z = 7}, targetPos = {x = 1315, y = 178, z = 7}},
    },
}

local condition = Condition(CONDITION_ATTRIBUTES)
condition:setParameter(CONDITION_PARAM_SUBID, 434)
condition:setParameter(CONDITION_PARAM_STAT_MAGICPOINTS, 60)
condition:setParameter(CONDITION_PARAM_SKILL_CLUB, 60)
condition:setParameter(CONDITION_PARAM_SKILL_SWORD, 60)
condition:setParameter(CONDITION_PARAM_TICKS, config.duration_spell * 1000)

function isAreaFree(fromPos, toPos)
    for x = fromPos.x, toPos.x do
        for y = fromPos.y, toPos.y do
            for z = fromPos.z, toPos.z do
                local tile = Tile(Position(x, y, z))
                if tile then
                    local thing = tile:getTopCreature()
                    if thing and thing:isPlayer() then
                        return false
                    end
                end
            end
        end
    end
    return true
end

local function isInArea(pos, fromPos, toPos)
    return pos.x >= fromPos.x and pos.x <= toPos.x
       and pos.y >= fromPos.y and pos.y <= toPos.y
       and pos.z == fromPos.z and pos.z == toPos.z
end

local fromPosGlobal = {x = 1000, y = 75, z = 7}
local toPosGlobal = {x = 1349, y = 212, z = 7}

function Teleport_Player(playerId, originalPos)
    local player = Player(playerId)
    if not player then return end

    if not isInArea(player:getPosition(), fromPosGlobal, toPosGlobal) then
        return
    end

    player:teleportTo(originalPos)
end

function Teleport_Target(targetId, originalPos)
    local target = Player(targetId)
    if not target then return end

    if not isInArea(target:getPosition(), fromPosGlobal, toPosGlobal) then
        return
    end

    target:teleportTo(originalPos)
end

function onCastSpell(creature, var)
    local player = Player(creature)
	local target = player:getTarget()
	
    local currentTime = os.time()
    local lastCast = player:getStorageValue(config.storage)

    if lastCast > currentTime then
        player:sendCancelMessage("Você precisa esperar " .. (lastCast - currentTime) .. " segundos para usar este especial novamente.")
        return false
    end
	
	local tile = Tile(player:getPosition())
	if tile and tile:hasFlag(TILESTATE_PVPZONE) then
		player:addCondition(condition)
		player:setStorageValue(config.storage, currentTime + config.tempo)
		return false
	end
	
	if not target then
        return false
    end
	
    if not target:isPlayer() then
        player:sendCancelMessage("Você só pode usar isso em players.")
        return false
    end
	
	if isInArea(player:getPosition(), fromPosGlobal, toPosGlobal) or isInArea(target:getPosition(), fromPosGlobal, toPosGlobal) then
		player:sendCancelMessage("Não é possível usar o especial dentro desta área.")
		return false
	end
	
	if target:getStorageValue(config.storage_mundo) > currentTime then
		player:sendCancelMessage("Você precisa esperar " .. (target:getStorageValue(config.storage_mundo) - currentTime) .. " segundos para puxar essa pessoa para outro mundo.")
		return false
	end
	
    if target:hasCondition(CONDITION_MANASHIELD) then
        player:sendCancelMessage("Você não pode usar isso em uma Kagome sob efeito do Kinzoku no kawa.")
        return false
    end
	
    local playerPos = player:getPosition()
    local targetPos = target:getPosition()
	
	doSendMagicEffect({x = player:getPosition().x, y = player:getPosition().y, z = player:getPosition().z}, 85)
	doSendMagicEffect({x = player:getPosition().x, y = player:getPosition().y, z = player:getPosition().z}, 9)
	doSendMagicEffect({x = target:getPosition().x, y = target:getPosition().y, z = target:getPosition().z}, 85)
	doSendMagicEffect({x = target:getPosition().x, y = target:getPosition().y, z = target:getPosition().z}, 9)

    local teleportSuccess = false
    for _, area in ipairs(config.areas) do
        if isAreaFree(area.fromPos, area.toPos) then
            player:teleportTo(area.playerPos)
            target:teleportTo(area.targetPos)
			player:addCondition(condition)
            teleportSuccess = true
            break
        end
    end

    if not teleportSuccess then
        player:sendCancelMessage("Desculpe, não é possível.")
        return false
    end

    addEvent(Teleport_Player, config.duration_spell * 1000, player:getId(), playerPos)
    addEvent(Teleport_Target, config.duration_spell * 1000, target:getId(), targetPos)
	player:setStorageValue(config.storage, currentTime + config.tempo)
	target:setStorageValue(config.storage_mundo, currentTime + 16)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Demon hell rage")
    end
    return true
end