-- /instancia <id>               -- coloca voce na instancia
-- /instancia <id> <nome>        -- coloca outro player na instancia
-- /instancia 0                  -- volta ao mundo normal
-- /instancia 0 <nome>           -- tira outro player da instancia

function onSay(player, words, param)
	if not player:getGroup():getAccess() then
		return false
	end

	if param == "" then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Uso: /instancia <id> [nome do player]")
		return false
	end

	local parts = param:split(" ")
	local id = tonumber(parts[1])
	if not id then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Uso: /instancia <id> [nome do player]")
		return false
	end

	local target
	if parts[2] then
		local name = table.concat(parts, " ", 2)
		target = Player(name)
		if not target then
			player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Player '" .. name .. "' nao encontrado.")
			return false
		end
	else
		target = player
	end

	-- Remove summons antes de mudar a instancia para evitar bug de instanceID errado
	local summons = target:getSummons()
	for _, summon in ipairs(summons) do
		summon:remove()
	end

	-- setInstanceId cuida de tudo: remove/add criaturas nos clientes afetados
	-- e notifica monsters proximos para re-escanear targets
	target:setInstanceId(id)

	local msg = id == 0 and "voltou ao mundo normal" or ("entrou na instancia " .. id)

	if target == player then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Voce " .. msg .. ".")
	else
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, target:getName() .. " " .. msg .. ".")
		target:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Voce " .. msg .. ".")
	end

	return false
end
