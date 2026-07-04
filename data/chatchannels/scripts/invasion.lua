function canJoin(player)
	return player:getVocation():getId() ~= VOCATION_NONE or player:getAccountType() >= ACCOUNT_TYPE_SENIORTUTOR
end

local CHANNEL_HELP = 7

function onSpeak(player, type, message)
    if player:getAccountType() < ACCOUNT_TYPE_TUTOR then
        player:sendCancelMessage("You are not allowed to speak in this channel.")
        return false
    end

    if type == TALKTYPE_CHANNEL_Y then
        return TALKTYPE_CHANNEL_O
    end

    return true
end