function getAccountPointsTrade(cid)
	local accountId = Player(cid):getAccountId()
	local resultId = db.storeQuery("SELECT `premium_points` FROM `accounts` WHERE `id` = " .. accountId)
	if resultId then
		local points = result.getNumber(resultId, "premium_points")
		result.free(resultId)
		return tonumber(points)
	end
	return 0
end

function doAccountAddPointsTrade(cid, count)
	local current = getAccountPointsTrade(cid)
	local accountId = Player(cid):getAccountId()
	return db.query("UPDATE `accounts` SET `premium_points` = " .. (current + count) .. " WHERE `id` = " .. accountId)
end

function doAccountRemovePointsTrade(cid, count)
	local current = getAccountPointsTrade(cid)
	local accountId = Player(cid):getAccountId()
	return db.query("UPDATE `accounts` SET `premium_points` = " .. (current - count) .. " WHERE `id` = " .. accountId)
end

function getPremiumPoints(cid)
	local accountId = Player(cid):getAccountId()
	local resultId = db.storeQuery("SELECT `premium_points` FROM `accounts` WHERE `id` = " .. accountId)
	if resultId then
		local points = result.getNumber(resultId, "premium_points")
		result.free(resultId)
		return points
	end
	return 0
end

function setPremiumPoints(cid, amount)
	local accountId = Player(cid):getAccountId()
	return db.query("UPDATE `accounts` SET `premium_points` = " .. amount .. " WHERE `id` = " .. accountId)
end

function getPlayerPPoints(cid)
	local accountId = Player(cid):getAccountId()
	local resultId = db.storeQuery("SELECT `premium_points` FROM `accounts` WHERE `id` = " .. accountId)
	if resultId then
		local points = result.getNumber(resultId, "premium_points")
		result.free(resultId)
		return points
	end
	return 0
end