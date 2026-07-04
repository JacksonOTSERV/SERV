exhaustion =
{
	check = function (player, storage)
		if isPlayer(player) and getPlayerFlagValue(player, PLAYERFLAG_HASNOEXHAUSTION) then
			return false
		end

		local storedTime = player:getStorageValue(storage)
		if storedTime == nil or storedTime < os.time() then
			return false
		end

		return true
	end,

	get = function (player, storage)
		if isPlayer(player) and getPlayerFlagValue(player, PLAYERFLAG_HASNOEXHAUSTION) then
			return false
		end

		local exhaust = player:getStorageValue(storage)
		if exhaust == nil then
			return false
		end

		local left = exhaust - os.time()
		if left >= 0 then
			return left
		end

		return false
	end,

	set = function (player, storage, time)
		local currentTime = os.time()
		if currentTime then
			player:setStorageValue(storage, currentTime + time)
		else
			print("Error: os.time() returned nil.")
		end
	end,

	make = function (player, storage, time)
		local exhaust = exhaustion.get(player, storage)
		if not exhaust then
			exhaustion.set(player, storage, time)
			return true
		end

		return false
	end,
	
	message = function (player, storage)
		local timeLeft = getPlayerStorageValue(player, storage) - os.time()
		if timeLeft and timeLeft > 0 then
			return "Aguarde " .. convertTime(timeLeft) .. "."
		else
			return "Não há tempo de espera."
		end
	end
}
