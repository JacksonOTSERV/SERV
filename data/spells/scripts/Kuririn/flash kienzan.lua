local exhaustion_time = 60
local exhaustion_storage = STORAGE_ESPECIAL1
local tempo = 4

function onCastSpell(creature, cid, variant)
    if not creature or not creature:isCreature() then
        return false
    end
    
    local player = Player(creature)

    local currentTime = os.time()
    local lastCast = player:getStorageValue(exhaustion_storage)

    if lastCast > currentTime then
        player:sendCancelMessage("Voc� precisa esperar " .. (lastCast - currentTime) .. " segundos para usar este especial novamente.")
        return false
    end

    local target = creature:getTarget()

    if not target:isPlayer() then
        player:sendCancelMessage("Voc� s� pode usar isso em players.")
        return false
    end
	
	if target:getOutfit().lookWings == 157 then
		player:sendCancelMessage("Voc� s� pode usar isso em players que j� n�o est�o sob efeito de um status negativo.")
		return false
	end
	
	doSendMagicEffect({x = player:getPosition().x+1, y = player:getPosition().y, z = player:getPosition().z}, 79)
	
	doSendDistanceShoot(player:getPosition(), target:getPosition(), 70)
	
	local playerPos = target:getPosition()
	local effectPos = {x = playerPos.x, y = playerPos.y, z = playerPos.z}
	doSendMagicEffect(effectPos, 35, currentCreature)

	local playId = target:getId()
	shader.sendShaderOtc(target, "genjutsu", tempo)
	
	target:sendCancelTarget()
	target:setStorageValue(STORAGE_TARGET, tempo + os.time())
	
    local outfit = target:getOutfit() 
    outfit.lookWings = 157
    target:setOutfit(outfit)
	
	addEvent(function()
		local currentPlayer = Player(playId)

		if not currentPlayer then
			return
		end	

		local outfit = currentPlayer:getOutfit() 
		outfit.lookWings = 0
		currentPlayer:setOutfit(outfit)
	end, tempo * 1000)

    player:setStorageValue(exhaustion_storage, currentTime + exhaustion_time)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Flash kienzan")
    end
    return true
end