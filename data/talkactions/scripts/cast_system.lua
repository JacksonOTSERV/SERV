function onSay(player, words, param)
	local defaultParam = param
	param = param:lower()

	if param == '' then
		player:sendCancelMessage("Escolha um parametro entre: !stream on, !stream off ou !stream on, senha")
	elseif param == "on" then
		if not player:isLiveCaster() then
			player:startLiveCast()
			player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Voce iniciou sua transmissao sem senha e agora tem 5% de EXP extra.")
			player:setStorageValue(20000, 1)
		end
	elseif param == "off" then
		if player:isLiveCaster() then
			player:stopLiveCast()
			if player:getStorageValue(20000) > 0 then
				player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Voce encerrou sua transmissao e nao tem mais 5% de EXP extra.")
				player:setStorageValue(20000, 0)
			else
				player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Voce encerrou sua transmissao, caso inicie ela sem senha, tera 5% de EXP extra.")
			end
		end
	else
		if not player:isLiveCaster() then
			player:startLiveCast(defaultParam)
			if player:getStorageValue(20000) > 0 then
				player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Voce iniciou sua transmissao com senha e nao tem mais 5% de EXP extra.")
				player:setStorageValue(20000, 0)
			else
				player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Voce iniciou sua transmissao com senha e nao tem EXP extra, caso inicie sem senha, tera 5% de EXP extra.")
			end
		end
	end
end
