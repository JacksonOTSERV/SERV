function onLogout(player)
	player:sendTextMessage(MESSAGE_STATUS_DEFAULT, "Aguarde " .. player:getStorageValue(1000) - os.time().. " segundos para deslogar.")
	if player:getStorageValue(1000)-os.time() < 0 then
		return true
	end
end