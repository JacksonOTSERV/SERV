local function getSkillId(skillName)
	if skillName == "club" then
		return SKILL_CLUB
	elseif skillName == "sword" then
		return SKILL_SWORD
	elseif skillName == "axe" then
		return SKILL_AXE
	elseif skillName:sub(1, 4) == "dist" then
		return SKILL_DISTANCE
	elseif skillName:sub(1, 6) == "shield" then
		return SKILL_SHIELD
	elseif skillName:sub(1, 4) == "fish" then
		return SKILL_FISHING
	else
		return SKILL_FIST
	end
end

local function getExpForLevel(level)
	level = level - 1
	return ((50 * level * level * level) - (150 * level * level) + (400 * level)) / 3
end

function onSay(player, words, param)
	if not player:getGroup():getAccess() then
		return true
	end
	
	local split = param:splitTrimmed(",")
	if not split[2] then
		player:sendCancelMessage("Insufficient parameters.")
		return false
	end

	local target = Player(split[1])
	if not target then
		player:sendCancelMessage("A player with that name is not online.")
		return false
	end

	local levelChange = tonumber(split[3])
	if not levelChange then
		player:sendCancelMessage("Invalid level change value.")
		return false
	end

	local currentLevel = target:getLevel()
	local newLevel = currentLevel + levelChange

	if newLevel < 1 then
		player:sendCancelMessage("Level cannot be lower than 1.")
		return false
	end

	if levelChange > 0 then
		local expToAdd = getExpForLevel(newLevel) - target:getExperience()
		target:addExperience(expToAdd, false)
	else
		local expToRemove = target:getExperience() - getExpForLevel(newLevel)
		target:removeExperience(expToRemove)
	end

	return false
end
