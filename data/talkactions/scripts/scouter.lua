function onSay(player, words, param, channel)
	local scouterIcons = {
		[12767] = 11850,
		[12768] = 11851,
		[12769] = 11852
	}

	local availableIcons = {}

	for scouterId, iconId in pairs(scouterIcons) do
		if player:getItemCount(scouterId) > 0 then
			table.insert(availableIcons, iconId)
		end
	end

	if #availableIcons == 0 then
		player:sendCancelMessage("Você precisa de um Scouter.")
		return false
	end

	if param == "" then
		player:sendCancelMessage("Digite um nome a ser procurado.")
		return false
	end

	local target = Player(param)
	if not target then
		player:sendCancelMessage("Player Offline.")
		return false
	end

	local name = target:getName()
	local level = target:getLevel()
	local magLevel = target:getMagicLevel()
	local maxHealth = target:getMaxHealth()
	local maxMana = target:getMaxMana()
	local vocationName = target:getVocation():getName()
	local guild = target:getGuild()
	local guildName = guild and guild:getName() or "Não Tem"

	local text = "Nick: " .. name .. "\n" ..
	             "Level: " .. level .. "\n" ..
	             "Ki Level: " .. magLevel .. "\n" ..
	             "Health: " .. maxHealth .. "\n" ..
	             "Ki: " .. maxMana .. "\n" ..
	             "Vocation: " .. vocationName .. "\n" ..
	             "Guild: " .. guildName .. "\n"

	local iconId = availableIcons[math.random(#availableIcons)]
	player:showTextDialog(iconId, text)

	return false
end