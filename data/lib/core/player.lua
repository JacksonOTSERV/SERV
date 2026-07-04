-- Sistema de task
STORAGE_TASK_ACTIVE = 50000
STORAGE_TASK_KILLS = 50001
STORAGE_TASK_MONSTER = 50002
STORAGE_TASK_TIME = 50003
STORAGE_TASK_SEQUENCIAL = 50004
STORAGE_TASK_SEQUENCIAL_KILLS = 50005

local foodCondition = Condition(CONDITION_REGENERATION, CONDITIONID_DEFAULT)

function Player.feed(self, food)
	local condition = self:getCondition(CONDITION_REGENERATION, CONDITIONID_DEFAULT)
	if condition then
		condition:setTicks(condition:getTicks() + (food * 1000))
	else
		local vocation = self:getVocation()
		if not vocation then
			return nil
		end

		foodCondition:setTicks(food * 1000)
		foodCondition:setParameter(CONDITION_PARAM_HEALTHGAIN, vocation:getHealthGainAmount())
		foodCondition:setParameter(CONDITION_PARAM_HEALTHTICKS, vocation:getHealthGainTicks() * 1000)
		foodCondition:setParameter(CONDITION_PARAM_MANAGAIN, vocation:getManaGainAmount())
		foodCondition:setParameter(CONDITION_PARAM_MANATICKS, vocation:getManaGainTicks() * 1000)

		self:addCondition(foodCondition)
	end
	return true
end

function Player.addSkillLevel(self, skillId, value)
    local currentSkillLevel = self:getSkillLevel(skillId)
    local sum = 0

    if value > 0 then
        while value > 0 do
            sum = sum + self:getVocation():getRequiredSkillTries(skillId, currentSkillLevel + value)
            value = value - 1
        end

        return self:addSkillTries(skillId, sum - self:getSkillTries(skillId))
    else
        value = math.min(currentSkillLevel, math.abs(value))
        while value > 0 do
            sum = sum + self:getVocation():getRequiredSkillTries(skillId, currentSkillLevel - value + 1)
            value = value - 1
        end

        return self:removeSkillTries(skillId, sum + self:getSkillTries(skillId), true)
    end
end


function Player.JumpCreature(self, creatureID, jumpHeight, jumpDuration, jumpStraight)
    local networkMessage = NetworkMessage()
    networkMessage:addByte(0x36)
    networkMessage:addU32(creatureID)
    networkMessage:addU32(jumpHeight)
    networkMessage:addU32(jumpDuration)
    networkMessage:addByte(jumpStraight)
    networkMessage:sendToPlayer(self)
    networkMessage:delete()
    return true
end

function Player.getClosestFreePosition(self, position, extended)
	if self:getGroup():getAccess() and self:getAccountType() >= ACCOUNT_TYPE_GOD then
		return position
	end
	return Creature.getClosestFreePosition(self, position, extended)
end

function Player.getDepotItems(self, depotId)
	return self:getDepotChest(depotId, true):getItemHoldingCount()
end

function Player.hasFlag(self, flag)
	return self:getGroup():hasFlag(flag)
end

local lossPercent = {
	[0] = 100,
	[1] = 70,
	[2] = 45,
	[3] = 25,
	[4] = 10,
	[5] = 0
}

function Player.getLossPercent(self)
	local blessings = 0
	for i = 1, 5 do
		if self:hasBlessing(i) then
			blessings = blessings + 1
		end
	end
	return lossPercent[blessings]
end

function Player.isPremium(self)
	return self:getPremiumDays() > 0 or configManager.getBoolean(configKeys.FREE_PREMIUM)
end

function Player.sendCancelMessage(self, message)
	if type(message) == "number" then
		message = Game.getReturnMessage(message)
	end
	return self:sendTextMessage(MESSAGE_STATUS_SMALL, message)
end

function Player.isUsingOtClient(self)
	return self:getClient().os >= CLIENTOS_OTCLIENT_LINUX
end

function invisiblesystem(player, lookType, tempo, restoreHealth)
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
	
	local condition = Condition(CONDITION_OUTFIT)
	condition:setOutfit({lookType = lookType})
	condition:setParameter(CONDITION_PARAM_SUBID, 772)
	condition:setTicks(tempo * 1000)

	if restoreHealth then
		player:addHealth(player:getMaxHealth())
	end

	player:setGhostMode(true)
	player:addCondition(condition)
	player:sendCancelTarget()
	player:setStorageValue(STORAGE_TARGET, tempo + os.time())
	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Voc? est? invis?vel por " .. tempo .. " segundos por uma tecnica especial.")

	addEvent(function()
		local currentPlayer = Player(playId)
		if currentPlayer then
			local playerPosition = currentPlayer:getPosition()
			local tile = Tile(playerPosition)
			if tile then
				local item = tile:getItemById(13576)
				if item then
					item:remove()
				end
			end
			currentPlayer:setGhostMode(false)
			doRemoveCondition(currentPlayer, CONDITION_OUTFIT, 772)
            local remaining = currentPlayer:getStorageValue(6612) - os.time()
            if remaining > 0 then
                local outfitCondition = Condition(CONDITION_OUTFIT)
                outfitCondition:setTicks(remaining * 1000)
                outfitCondition:setOutfit({lookType = 944})
                currentPlayer:addCondition(outfitCondition)
			end
			local attrCondition = currentPlayer:getCondition(CONDITION_ATTRIBUTES, CONDITIONID_COMBAT, 135)
			if attrCondition then
				local vocationId = currentPlayer:getVocation():getId()
				local lookType
				if vocationId == 1 then
					lookType = 729
				elseif vocationId == 5 then
					lookType = 56
				else
					lookType = currentPlayer:getOutfit().lookType
				end
				local remaining = currentPlayer:getStorageValue(89201) - os.time()
                local outfitCondition = Condition(CONDITION_OUTFIT)
                outfitCondition:setTicks(remaining * 1000)
                outfitCondition:setOutfit({lookType = lookType})
                currentPlayer:addCondition(outfitCondition)
				
				local speed = Condition(CONDITION_PARALYZE)
				speed:setParameter(CONDITION_PARAM_TICKS, remaining * 1000)
				speed:setParameter(CONDITION_PARAM_SPEED, 5000)
				currentPlayer:addCondition(speed)
			end
		end
	end, tempo * 1000)
	return true
end

function Player.sendExtendedOpcode(self, opcode, buffer)
	if not self:isUsingOtClient() then
		return false
	end

	local networkMessage = NetworkMessage()
	networkMessage:addByte(0x32)
	networkMessage:addByte(opcode)
	networkMessage:addString(buffer)
	networkMessage:sendToPlayer(self, false)
	networkMessage:delete()
	return true
end

APPLY_SKILL_MULTIPLIER = true
local addSkillTriesFunc = Player.addSkillTries
function Player.addSkillTries(...)
	APPLY_SKILL_MULTIPLIER = false
	local ret = addSkillTriesFunc(...)
	APPLY_SKILL_MULTIPLIER = true
	return ret
end

local addManaSpentFunc = Player.addManaSpent
function Player.addManaSpent(...)
	APPLY_SKILL_MULTIPLIER = false
	local ret = addManaSpentFunc(...)
	APPLY_SKILL_MULTIPLIER = true
	return ret
end

function Player.depositMoney(self, amount)
    if not self:removeMoney(amount) then
        return false
    end
 
    self:setBankBalance(self:getBankBalance() + amount)
    return true
end
 
function Player.withdrawMoney(self, amount)
    local balance = self:getBankBalance()
    if amount > balance or not self:addMoney(amount) then
        return false
    end
 
    self:setBankBalance(balance - amount)
    return true
end

function Player.sendCancelTarget(self)
    local msg = NetworkMessage()
    msg:addByte(0xA3)
    msg:addU32(0x00)
    msg:sendToPlayer(self)
    msg:delete()
end
 
function Player.transferMoneyTo(self, target, amount)
    local balance = self:getBankBalance()
    if amount > balance then
        return false
    end
 
    local targetPlayer = Player(target)
    if targetPlayer then
        targetPlayer:setBankBalance(targetPlayer:getBankBalance() + amount)
    else
        if not playerExists(target) then
            return false
        end
        db.query("UPDATE `players` SET `balance` = `balance` + '" .. amount .. "' WHERE `name` = " .. db.escapeString(target))
    end
 
    self:setBankBalance(self:getBankBalance() - amount)
    return true
end