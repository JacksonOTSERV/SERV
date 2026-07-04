local STORAGE_LAST_OFFICIAL_OUTFIT = 89812

-- Monster level system → data/lib/custom/monster_level.lua

function Creature:onChangeOutfit(newOutfit)
    local player = self
    if not player:isPlayer() then
        return true
    end

    local vocationName = player:getVocation():getName()
    local outfits = vocationOutfits[vocationName]
    if not outfits then
        return true
    end

    local currentLookType = player:getOutfit().lookType
    local newLookType = newOutfit.lookType

    if currentLookType == newLookType then
        return true
    end

    -- SKIN cosmetica do heroes: e' so visual. NAO mexe no bonus de Ki nem
    -- manda mensagem de transformacao (o bonus segue a forma do level).
    if type(heroesIsSkinLook) == "function" and heroesIsSkinLook(player, newLookType) then
        return true
    end

    local lastOfficialLook = player:getStorageValue(STORAGE_LAST_OFFICIAL_OUTFIT)
    if lastOfficialLook == newLookType then
        return true
    end

    local newML = 0
    local isNewOfficial = false
    for _, outfitData in pairs(outfits) do
        if outfitData.id == newLookType then
            newML = outfitData.ml or 0
            isNewOfficial = true
            break
        end
    end

    if isNewOfficial then
        player:setStorageValue(STORAGE_LAST_OFFICIAL_OUTFIT, newLookType)

        local cond = getCreatureCondition(player, CONDITION_ATTRIBUTES, 99)
        local currentML = 0
        if type(cond) == "table" then
            currentML = cond:getParameter(CONDITION_PARAM_STAT_MAGICPOINTS) or 0
        end

		doRemoveCondition(player, CONDITION_ATTRIBUTES, 99)

        if newML > 0 then
            local mlBoost = Condition(CONDITION_ATTRIBUTES)
            mlBoost:setParameter(CONDITION_PARAM_SUBID, 99)
            mlBoost:setParameter(CONDITION_PARAM_TICKS, -1)
            mlBoost:setParameter(CONDITION_PARAM_STAT_MAGICPOINTS, newML)
            player:addCondition(mlBoost)
        end
		
		if newML < 1 then
			player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
			"Sua nova transformação não concede bônus de Ki Level.")
		end

		if newML ~= currentML then
			if newML > 0 then
				player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
				string.format("Sua nova transformação concede +%d de Ki Level.", newML))
			end
		end
		if newOutfit.lookType ~= 1265 then
			player:setStorageValue(14389, newLookType)
		end
    end
	
	local blockedLooks = {
		[56] = true,
		[729] = true,
		[157] = true,
		[944] = true,
		[1265] = true
	}

	if not blockedLooks[newOutfit.lookType] then
		player:setStorageValue(14312, newOutfit.lookType)
	end

    return true
end

function Creature:onAreaCombat(tile, isAggressive)
	return RETURNVALUE_NOERROR
end

local function CancelKiSense(playerId, pos, target)
	local player = Player(playerId)
	local target = Creature(target)
	
	if not player or not target then
		return
	end
	
	if player and target then
		player:teleportTo(pos)
		doRemoveCondition(player, CONDITION_OUTFIT, 127)
		doCreatureSetHideHealth(player, false)
		doCreatureSetLookDirection(player, getCreatureLookDirection(target))
		target:remove()
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Você foi interrompido durante o Ki Sense e retornou.")
		player:setGhostMode(false)
		shader.sendShaderOtc(player, "Default", 1)

		if player:getStorageValue(10289) - os.time() > 0 then
			local outfit = player:getOutfit()
			outfit.lookAura = 11
			player:setOutfit(outfit)
		end
	end
end

function Creature:onTargetCombat(target)
    if not self then
        return true
    end
	
    if self:isPlayer() and target:isMonster() then
        local name = target:getName()
        local allowed, mlvl = canAttackMonsterLevel(self, name)
        if not allowed then
            self:setTarget(nil)
            notifyMonsterLevelBlock(self, name, mlvl)
            return RETURNVALUE_YOUMAYNOTATTACKTHISCREATURE
        end
    end
	
	if self:isPlayer() and target:isPlayer() then
		if self:hasSecureMode() then
			self:setTarget(nil)
			return RETURNVALUE_YOUMAYNOTATTACKTHISCREATURE
		end
	end
	
	if self:isPlayer() and target:isMonster() and target:getOutfit().lookAura == 157 then
		if self:getPosition():getDistance(target:getPosition()) > 1 then
			return RETURNVALUE_NOTPOSSIBLE
		end

		local targetOutfit = target:getOutfit()
		if targetOutfit.lookAura == 157 then
			local targetName = target:getName()
			local players = Game.getPlayers()

			for _, player in ipairs(players) do
				if player:getName() == targetName then
					addEvent(CancelKiSense, 100, player:getId(), target:getPosition(), target:getId())
					return RETURNVALUE_NOTPOSSIBLE
				end
			end
		end
	end
	
	if self:isPlayer() and target:isPlayer() then
		local selfPlayer = self:getPlayer()
		local targetPlayer = target:getPlayer()
		if selfPlayer and targetPlayer then
		local selfParty = selfPlayer:getParty()
		local targetParty = targetPlayer:getParty()
			if selfParty and targetParty and selfParty == targetParty then
				self:setTarget(nil)
				self:sendCancelTarget()
				return RETURNVALUE_YOUMAYNOTATTACKTHISCREATURE
			end
		end
	end
	
    if self:isPlayer() then
        if self:getStorageValue(STORAGE_TARGET) - os.time() > 0 then
            self:setTarget(nil)
            return RETURNVALUE_YOUMAYNOTATTACKTHISCREATURE
        end
    end
end
