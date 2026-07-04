function onSay(player, words, param)
    local player = Player(player)
    local guild = player:getGuild()
    if not guild then
        player:sendCancelMessage("You need to be in a guild in order to execute this talkaction.")
        return false
    end

    local guild = getPlayerGuildId(player)
    if not guild or (player:getGuildLevel() < 3) then
        player:sendCancelMessage("You cannot execute this talkaction.")
        return false
    end

    local t = string.split(param, ",")
    if not t[2] then
        player:sendChannelMessage("", "Not enough param(s).", TALKTYPE_CHANNEL_R1, CHANNEL_GUILD)
        return false
    end

    local enemy = getGuildId(t[2])
    if not enemy then
        player:sendChannelMessage("", "Guild \"" .. t[2] .. "\" does not exist.", TALKTYPE_CHANNEL_R1, CHANNEL_GUILD)
        return false
    end

    if enemy == guild then
        player:sendChannelMessage("", "You cannot perform war action on your own guild.", TALKTYPE_CHANNEL_R1, CHANNEL_GUILD)
        return false
    end

    local enemyName, tmp = "", db.storeQuery("SELECT `name` FROM `guilds` WHERE `id` = " .. enemy)
    if tmp then
        enemyName = result.getDataString(tmp, "name")
        result.free(tmp)
    end

    if isInArray({"accept", "reject", "cancel"}, t[1]) then
        local query = "`guild1` = " .. enemy .. " AND `guild2` = " .. guild
        if t[1] == "cancel" then
            query = "`guild1` = " .. guild .. " AND `guild2` = " .. enemy
        end

        tmp = db.storeQuery("SELECT `id`, `started`, `ended` FROM `guild_wars` WHERE " .. query .. " AND `status` = 0")
        if not tmp then
            player:sendChannelMessage("", "Currently there's no pending invitation for a war with " .. enemyName .. ".", TALKTYPE_CHANNEL_R1, CHANNEL_GUILD)
            return false
        end

        query = "UPDATE `guild_wars` SET "
        local msg = "accepted " .. enemyName .. " invitation to war."
        if t[1] == "reject" then
            query = query .. "`ended` = " .. os.time() .. ", `status` = 2"
            msg = "rejected " .. enemyName .. " invitation to war."
        elseif t[1] == "cancel" then
            query = query .. "`ended` = " .. os.time() .. ", `status` = 3"
            msg = "canceled invitation to a war with " .. enemyName .. "."
        else
            query = query .. "`started` = " .. os.time() .. ", `ended` = " .. (result.getDataInt(tmp, "ended") > 0 and (os.time() + ((result.getDataInt(tmp, "started") - result.getDataInt(tmp, "ended")) / 86400)) or 0) .. ", `status` = 1"
        end

        query = query .. " WHERE `id` = " .. result.getDataInt(tmp, "id")
        result.free(tmp)
        db.query(query)
        broadcastMessage(getPlayerGuildName(player) .. " has " .. msg, MESSAGE_EVENT_ADVANCE)
        return false
    end

    if t[1] == "invite" then
        local str = ""
        tmp = db.storeQuery("SELECT `guild1`, `status` FROM `guild_wars` WHERE `guild1` IN (" .. guild .. "," .. enemy .. ") AND `guild2` IN (" .. enemy .. "," .. guild .. ") AND `status` IN (0, 1)")
        if tmp then
            if result.getDataInt(tmp, "status") == 0 then
                if result.getDataInt(tmp, "guild1") == guild then
                    str = "You have already invited " .. enemyName .. " to war."
                else
                    str = enemyName .. " has already invited you to war."
                end
            else
                str = "You are already in a war with " .. enemyName .. "."
            end
            result.free(tmp)
        end

        if str ~= "" then
            player:sendChannelMessage("", str, TALKTYPE_CHANNEL_R1, CHANNEL_GUILD)
            return false
        end

        local frags = tonumber(t[3])
        frags = frags and math.max(10, math.min(1000, frags)) or 100

        local begining, ending = os.time(), tonumber(t[4])
        ending = ending and ending ~= 0 and (begining + (ending * 86400)) or 0

        db.query("INSERT INTO `guild_wars` (`guild1`, `guild2`, `started`, `ended`, `frags`, `name1`, `name2`) VALUES (" .. guild .. ", " .. enemy .. ", " .. begining .. ", " .. ending .. ", " .. frags .. ", '" .. getPlayerGuildName(player) .. "', '" .. enemyName .. "');")
        broadcastMessage(getPlayerGuildName(player) .. " has invited " .. enemyName .. " to war till " .. frags .. " frags.", MESSAGE_EVENT_ADVANCE)
        return false
    end

    if not isInArray({"end", "finish"}, t[1]) then
        return false
    end

    local status = t[1] == "end" and 1 or 4
    tmp = db.storeQuery("SELECT `id` FROM `guild_wars` WHERE `guild1` = " .. guild .. " AND `guild2` = " .. enemy .. " AND `status` = " .. status)
    if tmp then
        local query = "UPDATE `guild_wars` SET `ended` = " .. os.time() .. ", `status` = 5 WHERE `id` = " .. result.getDataInt(tmp, "id")
        result.free(tmp)
        db.query(query)
        broadcastMessage(getPlayerGuildName(player) .. " has " .. (status == 4 and "mended fences" or "ended a war") .. " with " .. enemyName .. ".", MESSAGE_EVENT_ADVANCE)
        return false
    end

    player:sendChannelMessage("", "Currently there's no active war with " .. enemyName .. ".", TALKTYPE_CHANNEL_R1, CHANNEL_GUILD)
    return false
end