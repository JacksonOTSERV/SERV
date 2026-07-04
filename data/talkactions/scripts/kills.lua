function onSay(player, words, param)
	local playerId = player:getGuid()
	
	local fragTimeMs = 43200000
	local fragTime = math.floor(fragTimeMs / 1000)
	
	if fragTime <= 0 then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "You do not have any unjustified kill.")
		return false
	end

	local resultId = db.storeQuery("SELECT frag_time FROM player_frags WHERE killer_id = " .. playerId)
	if not resultId then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "You do not have any unjustified kill.")
		return false
	end

	local now = os.time()
	local kills = 0
	local closestExpire = nil
	repeat
		local fragTimestamp = math.floor(result.getDataInt(resultId, "frag_time") / 1000)
		local expireTime = fragTimestamp + fragTime

		if expireTime > now then
			kills = kills + 1
			if not closestExpire or expireTime < closestExpire then
				closestExpire = expireTime
			end
		end
	until not result.next(resultId)
	result.free(resultId)

	if kills == 0 then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "You do not have any unjustified kill.")
		return false
	end

	local remaining = closestExpire - now
	local hours = math.floor(remaining / 3600)
	local minutes = math.floor((remaining % 3600) / 60)
	local seconds = remaining % 60

	local message = "You have " .. kills .. " unjustified kill" .. (kills > 1 and "s" or "") .. ". The amount of unjustified kills will decrease after: "
	if hours > 0 then
		message = message .. hours .. " hour" .. (hours > 1 and "s" or "") .. ", "
	end
	if minutes > 0 then
		message = message .. minutes .. " minute" .. (minutes > 1 and "s" or "") .. " and "
	end
	message = message .. seconds .. " second" .. (seconds ~= 1 and "s" or "") .. "."

	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, message)
	return false
end