local condition = Condition(CONDITION_OUTFIT)
condition:setParameter(CONDITION_PARAM_SUBID, 125)
condition:setOutfit({lookType = 157})
condition:setTicks(4 * 1000)
	
local muted = Condition(CONDITION_MUTED)
muted:setTicks(4 * 1000)
	
local stun = Condition(CONDITION_STUN)
stun:setParameter(CONDITION_PARAM_TICKS, 4 * 1000)

function repeatEffect(playerId, remainingTime)
	if remainingTime <= 0 then return end

	local player = Player(playerId)
	if player then
		doSendMagicEffect(player:getPosition(), 120)
	end

	addEvent(repeatEffect, 350, playerId, remainingTime - 350)
end

function repeatEffectShenron(playerId, remainingTime)
	if remainingTime <= 0 then return end

	local player = Player(playerId)
	if player then
		doSendMagicEffect(player:getPosition(), 265)
	end

	addEvent(repeatEffectShenron, 350, playerId, remainingTime - 350)
end

local extraSkills = Condition(CONDITION_ATTRIBUTES)
extraSkills:setParameter(CONDITION_PARAM_SUBID, 436)
extraSkills:setParameter(CONDITION_PARAM_STAT_MAGICPOINTS, 10)
extraSkills:setParameter(CONDITION_PARAM_SKILL_CLUB, 10)
extraSkills:setParameter(CONDITION_PARAM_SKILL_SWORD, 10)
extraSkills:setParameter(CONDITION_PARAM_TICKS, 6 * 1000)

function onPrepareDeath(creature, killer)
    if not creature:isPlayer() then
        return true
    end

    local player = creature:getPlayer()
    local reviveTime = player:getStorageValue(STORAGE_REVIVE)
	local pid = player:getId()

    if reviveTime > os.time() and creature:getVocation():getId() == 7 then
		player:addHealth(player:getMaxHealth())
		player:addCondition(stun)
		player:addCondition(condition)
		player:addCondition(muted)
		player:setStorageValue(STORAGE_TARGET, 4 + os.time())
		player:sendCancelTarget()
		player:setGhostMode(true)
		repeatEffect(pid, 3000)
		for i = 1, 3 do
			local delay = i * 1000
			addEvent(function()
				local currentPlayer = Player(pid)
				if not currentPlayer then return end

				doSendAnimatedText(currentPlayer:getPosition(), tostring(i), TEXTCOLOR_LIGHTGREEN)

				if i == 3 then
					doRemoveCondition(currentPlayer, CONDITION_OUTFIT, 125)
					doRemoveCondition(currentPlayer, CONDITION_MUTED)
					doRemoveCondition(currentPlayer, CONDITION_STUN)
					currentPlayer:setStorageValue(STORAGE_TARGET, 0)
					currentPlayer:setStorageValue(STORAGE_REVIVE, 0)
					player:setGhostMode(false)
				end
			end, delay)
		end
		return false
	end
	
    if reviveTime > os.time() and creature:getVocation():getId() == 21 then
		player:addHealth(player:getMaxHealth())
		player:addCondition(stun)
		player:addCondition(condition)
		player:addCondition(muted)
		player:setStorageValue(STORAGE_TARGET, 4 + os.time())
		player:sendCancelTarget()
		player:setGhostMode(true)
		repeatEffectShenron(pid, 3000)
		for i = 1, 3 do
			local delay = i * 1000
			addEvent(function()
				local currentPlayer = Player(pid)
				if not currentPlayer then return end

				doSendAnimatedText(currentPlayer:getPosition(), tostring(i), TEXTCOLOR_PURPLE)

				if i == 3 then
					doRemoveCondition(currentPlayer, CONDITION_OUTFIT, 125)
					doRemoveCondition(currentPlayer, CONDITION_MUTED)
					doRemoveCondition(currentPlayer, CONDITION_STUN)
					currentPlayer:setStorageValue(STORAGE_TARGET, 0)
					currentPlayer:setGhostMode(false)
					currentPlayer:addCondition(extraSkills)
					currentPlayer:setStorageValue(STORAGE_REVIVE, 0)
					currentPlayer:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Você agora tem 8 segundos de +10 all skills e retornou à vida.")
				end
			end, delay)
		end
		return false
	end
	
	if player:getStorageValue(STORAGE_REVIVE2) > os.time() then
		local healAmount = math.floor(player:getMaxHealth() * 0.5)
		player:addHealth(healAmount)
		doSendMagicEffect({x = player:getPosition().x+1, y = player:getPosition().y, z = player:getPosition().z}, 266)
		player:setGhostMode(true)
			addEvent(function()
				local currentPlayer = Player(pid)
				if not currentPlayer then return end
				currentPlayer:setGhostMode(false)
			end, 1000)
		return false
	end

    return true
end