-- Guild Wars System
-- Handles War Declarations and Status using TFS guild_wars table

GuildWars = {}

-- Status: 0 = Pending, 1 = Active, 2 = Rejected, 4 = Cancelled, 5 = Ended

-- Declaration - insert into guild_wars with status 0 (pending)
function GuildWars.declare(guildId, guildName, targetName, params)
    -- params: {duration, kills, price, forced}
    
    local targetQuery = db.storeQuery("SELECT `id` FROM `guilds` WHERE `name` = " .. db.escapeString(targetName))
    if not targetQuery then return false, "Guild not found." end
    local targetId = result.getNumber(targetQuery, "id")
    result.free(targetQuery)
    
    if targetId == guildId then return false, "Cannot war against yourself." end
    
    -- Check if war already exists
    local existingWar = db.storeQuery("SELECT `id` FROM `guild_wars` WHERE `status` IN (0, 1) AND (((`guild1` = " .. guildId .. " AND `guild2` = " .. targetId .. ") OR (`guild1` = " .. targetId .. " AND `guild2` = " .. guildId .. ")))")
    if existingWar then
        result.free(existingWar)
        return false, "War already exists with this guild."
    end
    
    local duration = params.duration or 86400 -- 1 day default
    local frags = params.kills or 10
    local startTime = os.time()
    local endTime = startTime + duration
    local status = params.forced and 1 or 0 -- 1 = Active if forced, 0 = Pending if not
    
    -- Insert into guild_wars table
    -- TFS C++ checks for ended = 0 to consider war active!
    local endedValue = status == 1 and 0 or 0 -- Always 0 for active wars
    local insertQuery = "INSERT INTO `guild_wars` (`guild1`, `guild2`, `name1`, `name2`, `status`, `started`, `ended`, `frags`, `payment`) VALUES (" .. 
        guildId .. ", " .. targetId .. ", " .. db.escapeString(guildName) .. ", " .. db.escapeString(targetName) .. ", " .. 
        status .. ", " .. startTime .. ", " .. endedValue .. ", " .. frags .. ", " .. (params.price or 0) .. ")"
    print("[GuildWars] Inserting: " .. insertQuery)
    local success = db.query(insertQuery)
    print("[GuildWars] Insert result: " .. tostring(success))
    
    -- Notify Target via Inbox (they need to accept, so finished=false)
    if GuildInbox then
        GuildInbox.addLog(targetId, 7, guildName .. " has declared war on you!", false)
        -- Declaring guild's log is just informational (finished=true, not actionable)
        GuildInbox.addLog(guildId, 7, "You declared war on " .. targetName, true)
    end
    
    print("[GuildWars] War declared: " .. guildName .. " vs " .. targetName .. " (status: " .. status .. ")")
    
    -- Notify online members of target guild (Refresh Inbox)
    local players = Game.getPlayers()
    local OPCODE = 1
    for _, player in ipairs(players) do
        local g = player:getGuild()
        if g and g:getId() == targetId then
            player:sendExtendedOpcode(OPCODE, json.encode({action = "refreshInbox", data = 0}))
        end
    end
    
    return true
end

-- Accept a war (change status from 0 to 1)
function GuildWars.accept(guildId, enemyGuildId)
    local query = "UPDATE `guild_wars` SET `status` = 1 WHERE `status` = 0 AND `guild2` = " .. guildId .. " AND `guild1` = " .. enemyGuildId
    db.query(query)
    print("[GuildWars] War accepted by guild " .. guildId)
    GuildWars.broadcastEmblems(guildId, enemyGuildId)
    return true
end

-- Reject a war (change status from 0 to 2)
function GuildWars.reject(guildId, enemyGuildId)
    local query = "UPDATE `guild_wars` SET `status` = 2 WHERE `status` = 0 AND `guild2` = " .. guildId .. " AND `guild1` = " .. enemyGuildId
    db.query(query)
    print("[GuildWars] War rejected by guild " .. guildId)
    return true
end

-- Get wars for a guild, formatted for client
function GuildWars.getWars(guildId)
    local wars = {}
    local query = db.storeQuery("SELECT * FROM `guild_wars` WHERE `status` IN (0, 1) AND (`guild1` = " .. guildId .. " OR `guild2` = " .. guildId .. ")")
    
    if query then
        repeat
            local guild1 = result.getNumber(query, "guild1")
            local guild2 = result.getNumber(query, "guild2")
            local name1 = result.getString(query, "name1")
            local name2 = result.getString(query, "name2")
            local statusVal = result.getNumber(query, "status")
            local started = result.getNumber(query, "started")
            local ended = result.getNumber(query, "ended")
            
            -- Determine enemy guild name based on which guild we are
            local enemyName = (guild1 == guildId) and name2 or name1
            local enemyGuildId = (guild1 == guildId) and guild2 or guild1
            
            -- Map database status to client status
            -- DB: 0 = Pending, 1 = Active
            -- Client config: 0 = DECLARATION, 1 = PREPARING, 2 = STARTED
            local clientStatus = 2 -- STARTED by default (active war)
            if statusVal == 0 then
                clientStatus = 0 -- DECLARATION (pending acceptance)
            elseif statusVal == 1 then
                clientStatus = 2 -- STARTED (active)
            end
            
            -- Get kill counts from guildwar_kills table
            local allyKills = 0
            local enemyKills = 0
            local warId = result.getNumber(query, "id")
            local killQuery = db.storeQuery("SELECT `killerguild`, `targetguild` FROM `guildwar_kills` WHERE `warid` = " .. warId)
            if killQuery then
                repeat
                    local killerGuild = result.getNumber(killQuery, "killerguild")
                    if killerGuild == guildId then
                        allyKills = allyKills + 1
                    else
                        enemyKills = enemyKills + 1
                    end
                until not result.next(killQuery)
                result.free(killQuery)
            end
            
            table.insert(wars, {
                warId = warId,
                name = enemyName,
                enemyGuildId = enemyGuildId,
                duration = (ended > 0) and (ended - started) or 86400, -- Default 1 day
                killsMax = result.getNumber(query, "frags") or 10,
                goldBet = result.getNumber(query, "payment") or 0,
                forced = 0,
                status = clientStatus,
                started = started,
                emblem = 0, -- Default emblem
                allyKills = allyKills,
                enemyKills = enemyKills
            })
        until not result.next(query)
        result.free(query)
    end
    
    return wars
end

-- Broadcast emblem updates to online players of the two guilds
function GuildWars.broadcastEmblems(guildId1, guildId2)
    local players = Game.getPlayers()
    local guild1Players = {}
    local guild2Players = {}
    local guild1MemberIds = {}
    local guild2MemberIds = {}
    
    print("[GuildWars] Broadcasting Emblems for Guilds " .. guildId1 .. " vs " .. guildId2)
    
    -- Sorting players into guilds
    for _, player in ipairs(players) do
        local guild = player:getGuild()
        if guild then
            if guild:getId() == guildId1 then
                table.insert(guild1Players, player)
                table.insert(guild1MemberIds, player:getId())
            elseif guild:getId() == guildId2 then
                table.insert(guild2Players, player)
                table.insert(guild2MemberIds, player:getId())
            end
        end
    end
    
    local OPCODE = 1 -- Guild Management Opcode
    
    -- Helper to send JSON packet
    local function sendPacket(player, action, data)
        player:sendExtendedOpcode(OPCODE, json.encode({action = action, data = data}))
    end

    -- Send updates to Guild 1 Members
    for _, player in ipairs(guild1Players) do
        -- My guild (Guild 1) -> Green (1)
        if #guild1MemberIds > 0 then
            sendPacket(player, "emblems", {players = guild1MemberIds, emblem = 1})
        end
        -- Enemy guild (Guild 2) -> Red (2)
        if #guild2MemberIds > 0 then
            sendPacket(player, "emblems", {players = guild2MemberIds, emblem = 2})
        end
    end
    
    -- Send updates to Guild 2 Members
    for _, player in ipairs(guild2Players) do
        -- My guild (Guild 2) -> Green (1)
        if #guild2MemberIds > 0 then
            sendPacket(player, "emblems", {players = guild2MemberIds, emblem = 1})
        end
        -- Enemy guild (Guild 1) -> Red (2)
        if #guild1MemberIds > 0 then
            sendPacket(player, "emblems", {players = guild1MemberIds, emblem = 2})
        end
    end
    
    -- Optional: Notify others? Standard war systems usually don't highlight for neutrals unless using global war modes.
end

-- Check if two guilds are at war
function GuildWars.areAtWar(guildId1, guildId2)
    local query = db.storeQuery("SELECT `id` FROM `guild_wars` WHERE `status` = 1 AND (((`guild1` = " .. guildId1 .. " AND `guild2` = " .. guildId2 .. ") OR (`guild1` = " .. guildId2 .. " AND `guild2` = " .. guildId1 .. ")))")
    if query then
        result.free(query)
        return true
    end
    return false
end

-- Ensure DB columns exist (Check individually to avoid issues if partially applied)
local checkFrags = db.storeQuery("SELECT `frags` FROM `guild_wars` LIMIT 1")
if checkFrags == false then
    print("[GuildWars] Adding 'frags' column to guild_wars table...")
    db.query("ALTER TABLE `guild_wars` ADD COLUMN `frags` INT NOT NULL DEFAULT 10")
else
    result.free(checkFrags)
end

local checkPayment = db.storeQuery("SELECT `payment` FROM `guild_wars` LIMIT 1")
if checkPayment == false then
    print("[GuildWars] Adding 'payment' column to guild_wars table...")
    db.query("ALTER TABLE `guild_wars` ADD COLUMN `payment` BIGINT NOT NULL DEFAULT 0")
else
    result.free(checkPayment)
end

print("[GuildWars] System loaded (using guild_wars table).")
