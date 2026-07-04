local exhaustion_time = 35
local exhaustion_storage = STORAGE_ESPECIAL1

function onCastSpell(creature, variant)
    if not creature or not creature:isPlayer() then
        return false
    end

    if creature:isRemoved() then
        return false
    end

    if exhaustion.check(creature, exhaustion_storage) then
        creature:sendCancelMessage("Aguarde " .. tostring(exhaustion.get(creature, exhaustion_storage)) .. " segundos para usar este especial novamente.")
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
	
	if creature:isInGhostMode() then
		return false
	end

    local playerId = creature:getId()
	local playerPos = creature:getPosition()
	
	doCreatureSetHideHealth(creature, true)

	local AreaX = 15
	local AreaY = 8

	local spectators = Game.getSpectators(playerPos, false, true, AreaX, AreaX, AreaY, AreaY)
	if #spectators == 0 then
		return false
	end

	for _, spectator in ipairs(spectators) do
		spectator:JumpCreature(playerId, 100, 1000, 1)
	end
	
	addEvent(function()
		local currentPlayer = Player(playerId)
		if currentPlayer then
				doCreatureSetHideHealth(currentPlayer, false)
				shader.sendShaderOtc(currentPlayer, 'pulse', 1)
				local pos = currentPlayer:getPosition()
				if pos then
					doSendMagicEffect({x = pos.x + 3, y = pos.y + 3, z = pos.z}, 296, currentPlayer)
				end
				local casterParty = currentPlayer:getParty()
				local nearbyPlayers = Game.getSpectators(pos, false, true, 2, 2, 2, 2)
				for _, spec in ipairs(nearbyPlayers) do
					if spec:isPlayer() and spec:getId() ~= playerId then
						local otherParty = spec:getParty()
						if not (casterParty and otherParty and casterParty == otherParty) then
							local tile = Tile(spec:getPosition())
							if tile and not tile:hasFlag(TILESTATE_PROTECTIONZONE) and not tile:hasFlag(TILESTATE_NOPVPZONE) then
								local stun = Condition(CONDITION_STUN)
								stun:setParameter(CONDITION_PARAM_TICKS, 3500)
								spec:addCondition(stun)
								shader.sendShaderOtc(spec, 'pulse', 1)
								doSendAnimatedText(spec:getPosition(), "Stunned!", TEXTCOLOR_YELLOW)
							end
						end
					end
				end
			end
		end, 1 * 1000)
		creature:setPzLockTime(0)
		exhaustion.set(creature, exhaustion_storage, exhaustion_time)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Mafuba effect")
    end
    return true
end