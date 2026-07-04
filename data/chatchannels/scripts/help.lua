function canJoin(player)
	return player:getVocation():getId() ~= VOCATION_NONE or player:getAccountType() >= ACCOUNT_TYPE_SENIORTUTOR
end

local CHANNEL_HELP = 7

function onSpeak(player, type, message)
	if player:getAccountType() >= ACCOUNT_TYPE_TUTOR then
		if type == TALKTYPE_CHANNEL_Y then
			return TALKTYPE_CHANNEL_O
		end
		return true
	end
	
	if player:getStorageValue(1040)-os.time() > 0 then
		player:sendCancelMessage("You can only ask for help in " .. player:getStorageValue(1040) - os.time().. " seconds.")
		return false
	end
	
	if player:getGroup(1) then
	player:setStorageValue(1040, 120+os.time())
	end
	
	if type == TALKTYPE_CHANNEL_O then
		if player:getAccountType() < ACCOUNT_TYPE_TUTOR then
			type = TALKTYPE_CHANNEL_Y
		end
	elseif type == TALKTYPE_CHANNEL_R1 then
		if not player:hasFlag(PlayerFlag_CanTalkRedChannel) then
			type = TALKTYPE_CHANNEL_Y
		end
	end
	return type
end
