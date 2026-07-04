function Game.broadcastMessage(message, messageType)
	if not messageType then
		messageType = MESSAGE_STATUS_WARNING
	end

	for _, player in ipairs(Game.getPlayers()) do
		player:sendTextMessage(messageType, message)
	end
end

function giveRewardOncePerHWID(player, chestId, rewardFunc, cooldownHours)
    local uuid = HWID_SESSIONS[player:getId()]
    if not uuid then
        player:sendTextMessage(MESSAGE_STATUS_SMALL, "Seu HWID n�o foi detectado ainda.")
        return true
    end

    local now = os.time()
    local cooldown = (cooldownHours or 24) * 3600

    local resultId = db.storeQuery(string.format(
        "SELECT expire_time FROM hwid_rewards WHERE uuid = %s AND chest_id = %d",
        db.escapeString(uuid), chestId
    ))

    if resultId ~= false then
        local expireTime = result.getDataInt(resultId, "expire_time")
        result.free(resultId)

		if expireTime > now then
			local remaining = expireTime - now

			local hours = math.floor(remaining / 3600)
			local minutes = math.floor((remaining % 3600) / 60)
			local seconds = remaining % 60

			player:sendTextMessage(
				MESSAGE_STATUS_WARNING,
				string.format(
					"Voc� j� pegou a recompensa deste ba�. Tente novamente em %02d horas, %02d minutos e %02d segundos.",
					hours, minutes, seconds
				)
			)
			return true
		end

        db.query(string.format(
            "UPDATE hwid_rewards SET expire_time = %d WHERE uuid = %s AND chest_id = %d",
            now + cooldown, db.escapeString(uuid), chestId
        ))
    else
        db.query(string.format(
            "INSERT INTO hwid_rewards (uuid, chest_id, expire_time) VALUES (%s, %d, %d)",
            db.escapeString(uuid), chestId, now + cooldown
        ))
    end

    if rewardFunc then
        rewardFunc(player)
    end

	

    return true
end

function Game.convertIpToString(ip)
	local band = bit.band
	local rshift = bit.rshift
	return string.format("%d.%d.%d.%d",
		band(ip, 0xFF),
		band(rshift(ip, 8), 0xFF),
		band(rshift(ip, 16), 0xFF),
		rshift(ip, 24)
	)
end

function Game.getReverseDirection(direction)
	if direction == WEST then
		return EAST
	elseif direction == EAST then
		return WEST
	elseif direction == NORTH then
		return SOUTH
	elseif direction == SOUTH then
		return NORTH
	elseif direction == NORTHWEST then
		return SOUTHEAST
	elseif direction == NORTHEAST then
		return SOUTHWEST
	elseif direction == SOUTHWEST then
		return NORTHEAST
	elseif direction == SOUTHEAST then
		return NORTHWEST
	end
	return NORTH
end

function Game.getSkillType(weaponType)
	if weaponType == WEAPON_CLUB then
		return SKILL_CLUB
	elseif weaponType == WEAPON_SWORD then
		return SKILL_SWORD
	elseif weaponType == WEAPON_AXE then
		return SKILL_AXE
	elseif weaponType == WEAPON_DISTANCE then
		return SKILL_DISTANCE
	elseif weaponType == WEAPON_SHIELD then
		return SKILL_SHIELD
	end
	return SKILL_FIST
end

if not globalStorageTable then
	globalStorageTable = {}
end

function Game.getStorageValue(key)
	return globalStorageTable[key]
end

function Game.setStorageValue(key, value)
	globalStorageTable[key] = value
end

function getMoneyCount(string)
	local b,
	e = string:find("%d+")
	local money = b and e and tonumber(string:sub(b, e)) or -1
	if isValidMoney(money) then
		return money
	end
	return -1
end

function getBankMoney(cid, amount)
	local player = Player(cid)
	if player:getBankBalance() >= amount then
		player:setBankBalance(player:getBankBalance() - amount)
		player:sendTextMessage(MESSAGE_INFO_DESCR, "Paid " .. amount .. " gold from bank account. Your account balance is now " .. player:getBankBalance() .. " gold.")
		return true
	end
	return false
end

function getMoneyWeight(money)
	local gold = money

	local diamond = math.floor(gold / 1000000)
	gold = gold - diamond * 1000000

	local crystal = math.floor(gold / 10000)
	gold = gold - crystal * 10000

	local platinum = math.floor(gold / 100)
	gold = gold - platinum * 100

	return (ItemType(13599):getWeight() * diamond) +
	       (ItemType(2160):getWeight() * crystal) +
	       (ItemType(2152):getWeight() * platinum) +
	       (ItemType(2148):getWeight() * gold)
end

function isValidMoney(money)
	return isNumber(money) and money > 0 and money < 4294967296
end

function isNumber(str)
	return tonumber(str) ~= nil
end