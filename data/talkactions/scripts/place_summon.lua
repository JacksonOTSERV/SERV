function onSay(player, words, param)
	if not player:getGroup():getAccess() then
		return true
	end

	local position = player:getPosition()
	local monster = Game.createMonster(param, position, false, false, player:getInstanceId())
	if monster then
		player:addSummon(monster)
	else
		player:sendCancelMessage("There is not enough room.")
	end
	return false
end
