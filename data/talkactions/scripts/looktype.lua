function onSay(player, words, param)
	if not player:getGroup():getAccess() then
		return true
	end
	
    local lookType = tonumber(param)
    
    if lookType and lookType >= 0 and lookType < 3500 then
        local playerOutfit = player:getOutfit()
        playerOutfit.lookType = lookType
        player:setOutfit(playerOutfit)
    else
        player:sendCancelMessage("A look type with that id does not exist.")
    end
    
    return false
end
