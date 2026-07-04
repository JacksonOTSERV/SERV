
local OPCODE = 1
local GUILD_STORAGE_BASE = 50000
local WAR_STORAGE = 50500

-- Ensure JSON library is loaded
if not json then
    local status, lib = pcall(dofile, 'data/lib/json.lua')
    if status then
        json = lib
    else
        print("ERROR: Failed to load json.lua: " .. tostring(lib))
    end
end

-- Ensure GuildInbox/GuildWars are loaded
if not GuildInbox then
    pcall(dofile, 'data/scripts/guild_inbox.lua')
end
if not GuildWars then
    pcall(dofile, 'data/scripts/guild_wars.lua')
end
if not GuildBuffs then
    pcall(dofile, 'data/scripts/guild_buffs.lua')
end
if not GuildInbox then
    local status, lib = pcall(dofile, 'data/scripts/guild_inbox.lua')
    if not status then
        print("ERROR: Failed to load guild_inbox.lua")
        -- Fallback mock to prevent crashes
        GuildInbox = {
            sendInvite = function() return false, "Inbox Error" end,
            getPlayerInvites = function() return {} end,
            removeInvite = function() return false end,
            addLog = function() end,
            getLogs = function() return {} end
        }
    end
end

-- Ensure guilds table has persistence columns
local resultId = db.storeQuery("SELECT `level` FROM `guilds` LIMIT 1")
if resultId == false then
    db.query("ALTER TABLE `guilds` ADD COLUMN `level` INT NOT NULL DEFAULT 1")
    db.query("ALTER TABLE `guilds` ADD COLUMN `balance` BIGINT NOT NULL DEFAULT 0")
    db.query("ALTER TABLE `guilds` ADD COLUMN `pacifism` INT NOT NULL DEFAULT 0")
else
    result.free(resultId)
end

-- Ensure Guild Buffs Table exists
db.query("CREATE TABLE IF NOT EXISTS `guild_buffs` (`guild_id` INT NOT NULL, `buff_id` INT NOT NULL, `expiry` BIGINT NOT NULL, KEY (`guild_id`))")

-- Ensure Guild Metadata Table exists (Level, etc.)
db.query("CREATE TABLE IF NOT EXISTS `guild_metadata` (`guild_id` INT NOT NULL, `level` INT NOT NULL DEFAULT 1, `balance` BIGINT NOT NULL DEFAULT 0, `pacifism` INT NOT NULL DEFAULT 0, PRIMARY KEY (`guild_id`))")

-- Configuration
local config = {
    guildLevelPrice = 100000, -- Multiplier for level up cost
    maxMembers = 100,
    createLevel = 100,
    createPrice = 0,
    createPrice = 0,
    minActionInterval = 500, -- ms
    pacifismDuration = 14 * 86400, -- 14 Days
    advancement = {
        level = {2, 4, 6, 8, 10, 12, 14, 16, 18},
        price = {100000, 200000, 300000, 400000, 500000, 600000, 700000, 800000, 900000}
    }
}

local STORAGE = {
    EMBLEM = 1,
    LANGUAGE = 2,
    STATUS = 3, -- 1 = Public, 2 = Invite Only
    REQ_LEVEL = 4,
    MOTD = 5,
    PERMISSIONS = 6, -- Base permissions
    BUFFS = 7, -- JSON
    BUFFS_SAVE = 8,
    PACIFISM = 9,
    LEVEL = 10,
}

local JOIN_STATUS = {
    PUBLIC = 1,
    INVITE_ONLY = 2
}

-- DB Helpers for Guild Data
local function getGuildLevel(guildId)
    local q = db.storeQuery("SELECT `level` FROM `guild_metadata` WHERE `guild_id` = " .. guildId)
    if q then
        local lvl = result.getNumber(q, "level")
        result.free(q)
        return lvl
    end
    -- If not found, insert default
    db.query("INSERT INTO `guild_metadata` (`guild_id`, `level`) VALUES (" .. guildId .. ", 1)")
    return 1
end

local function setGuildLevel(guildId, level)
    local q = db.storeQuery("SELECT `guild_id` FROM `guild_metadata` WHERE `guild_id` = " .. guildId)
    if q then
        result.free(q)
        db.query("UPDATE `guild_metadata` SET `level` = " .. level .. " WHERE `guild_id` = " .. guildId)
    else
        db.query("INSERT INTO `guild_metadata` (`guild_id`, `level`) VALUES (" .. guildId .. ", " .. level .. ")")
    end
end

local function getGuildPacifism(guildId)
    local q = db.storeQuery("SELECT `pacifism` FROM `guild_metadata` WHERE `guild_id` = " .. guildId)
    if q then
        local val = result.getNumber(q, "pacifism")
        result.free(q)
        return val
    end
    return 0 
end

local function setGuildPacifism(guildId, state)
    local q = db.storeQuery("SELECT `guild_id` FROM `guild_metadata` WHERE `guild_id` = " .. guildId)
    if q then
        result.free(q)
        db.query("UPDATE `guild_metadata` SET `pacifism` = " .. state .. " WHERE `guild_id` = " .. guildId)
    else
        db.query("INSERT INTO `guild_metadata` (`guild_id`, `pacifism`) VALUES (" .. guildId .. ", " .. state .. ")")
    end
end

local function getGuildExtra(guildId, key, default)
    -- Kept for non-critical/legacy storage (like MOTD, Emblem if not in DB yet)
    local val = Game.getStorageValue(GUILD_STORAGE_BASE + (guildId * 100) + key)
    if val == nil or val == -1 then return default end
    return val
end

local function setGuildExtra(guildId, key, value)
    Game.setStorageValue(GUILD_STORAGE_BASE + (guildId * 100) + key, value)
end

local PACKETS = {
    FETCH = "fetch",
    SETTINGS = "settings",
    MEMBERS = "members",
    RANKS = "ranks",
    INBOX = "inbox",
    TOP = "top",
    CREATE = "create",
    INVITE = "invite",
    KICK = "kick",
    LEAVE = "leave",
    DONATE = "donate",
    LEVEL_UP = "levelUp",
    BUFFS = "buffs",
    SAVE_RANKS = "saveRanks",
    SET_RANK = "setRank",
    PASS_LEADER = "passLeader",
    DECLARATION = "declaration", -- War
    PACIFIST = "pacifist", -- War
    SURRENDER = "surrender", -- War
    REVOKE = "revoke", -- War
    ACCEPT = "accept", -- Inbox
    REJECT = "reject" -- Inbox
}

-- Helpers
local function sendJSON(player, data)
    player:sendExtendedOpcode(OPCODE, json.encode(data))
end

-- Main Handler
local function handleGuildAction(player, action, data)
    local guild = player:getGuild()
    
    -- Fallback: If C++ guild object is missing but DB has it (e.g. just created)
    if not guild then
        local checkId = db.storeQuery("SELECT `id`, `name` FROM `guilds` WHERE `ownerid` = " .. player:getGuid())
        if checkId ~= false then
            local fid = result.getNumber(checkId, "id")
            local fname = result.getString(checkId, "name")
            result.free(checkId)
            
            guild = {
                 id = fid,
                 name = fname,
                 getId = function(s) return s.id end,
                 getName = function(s) return s.name end,
                 getBankBalance = function(s) return Guild.getBankBalance(s) end,
                 getMembers = function(s) return Guild.getMembers(s) end,
                 getRankByLevel = function(s, l) return nil end,
                 removeMember = function(s, p) end, -- Mock
                 setBankBalance = function(s, b) end -- Mock
            }
            print("DEBUG: Using Fake Guild Object for " .. fname)
        end
    end

    local guildId = guild and guild:getId() or 0
    
    if action == PACKETS.FETCH or action == "general" then
        local configData = {
           maxMembers = 100,
           advancement = config.advancement,
           MESSAGE_TYPES = {
             JOIN_INVITATION = 1,
             KICKED_OUT = 2,
             JOIN_REQUEST = 3,
             MEMBER_JOINED = 4,
             MEMBER_LEFT = 5,
             GOLD_DEPOSIT = 6,
             WAR_DECLARATION = 7
           },
           PERMISSIONS = {
             INVITE_MEMBERS = 0,
             EDIT_MEMBERS = 1,
             EDIT_ROLES = 2,
             EDIT_SETTINGS = 3,
             MANAGE_GOLD = 4,
             MANAGE_WARS = 5,
             MANAGE_BUFFS = 6,
             ALL = 127,
             LAST = 6
           },
           WARS = {
             DURATION = {MIN = 1, MAX = 7},
             KILLS = {MIN = 10, MAX = 1000},
             GOLD_BET = {MIN = 0, MAX = 1000000},
             PREP_TIME = {WEEKS = 0, DAYS = 0, HOURS = 24}, -- Default 24h prep
             STATUS = {DECLARATION=0, PREPARING=1, STARTED=2, ENDED=3},
             FORCED_COST = {CRYSTAL=10, PLATINUM=0, GOLD=0}
           },
           PACIFISM = {
             ACTIVE = 1, INACTIVE = 0, EXHAUSTED = 2,
             COST = {CRYSTAL=5, PLATINUM=0, GOLD=0}
           },
           BUFFS_SAVE_DELAY = {WEEKS=0, DAYS=0, HOURS=24, MINUTES=0, SECONDS=0}
        }
        sendJSON(player, {action = "config", data = configData})

        if not guild then
            sendJSON(player, {action = "general", data = false}) -- Show No Guild UI
            return
        end

        local currentLevel = getGuildLevel(guildId)
        local nextCost = config.advancement.price[currentLevel] or 0
        
        local generalData = {
            name = guild:getName(),
            level = currentLevel,
            members = {#guild:getMembers(), config.maxMembers}, 
            gold = guild:getBankBalance(),
            next = nextCost, -- Gold for next level
            exp = {guild:getBankBalance(), nextCost},
            motd = getGuildExtra(guildId, STORAGE.MOTD, "Welcome to our guild!"),
            emblem = getGuildExtra(guildId, STORAGE.EMBLEM, 0),
            language = getGuildExtra(guildId, STORAGE.LANGUAGE, 1),
            joinStatus = getGuildExtra(guildId, STORAGE.STATUS, JOIN_STATUS.INVITE_ONLY),
            reqLevel = getGuildExtra(guildId, STORAGE.REQ_LEVEL, 0),
            permissions = 127, -- Admin permissions for now
            leader = guild:getRankByLevel(3) and guild:getRankByLevel(3).name or "Leader", -- Rough guess
            buffs = {0,0,0,0,0,0,0,0,0}, 
            lastBuffSave = 0,
            pacifismStatus = (getGuildPacifism(guildId) > os.time()) and 1 or 0, -- Boolean-like for status icon
            pacifism = getGuildPacifism(guildId) * 1000, -- Timestamp for date display (MS)
            wars = GuildWars and GuildWars.getWars(guildId) or {},
            serverTime = os.time()*1000
        }
        
        -- Populate Active Buffs from DB
        local buffsQuery = db.storeQuery("SELECT `buff_id`, `expiry` FROM `guild_buffs` WHERE `guild_id` = " .. guildId)
        if buffsQuery then
            repeat
                local bid = result.getNumber(buffsQuery, "buff_id")
                local expiry = result.getNumber(buffsQuery, "expiry")
                
                if expiry > os.time() then
                    -- Map ID (1-18) to Row (1-9) + Choice (1 or 2)
                    -- Formula: Row = ceil(bid / 2)
                    -- Choice: if bid odd -> 1, if bid even -> 2
                    local row = math.ceil(bid / 2)
                    local choice = (bid % 2 == 1) and 1 or 2
                    
                    if row >= 1 and row <= 9 then
                        generalData.buffs[row] = choice
                    end
                end
            until not result.next(buffsQuery)
            result.free(buffsQuery)
        end
        
        -- Try to find real leader name and build members list from DB
        local membersData = {}
        local leaderName = "Leader"
        local membersQuery = db.storeQuery([[
            SELECT p.id, p.name, p.level, p.vocation, p.lastlogin, gm.rank_id, gr.name as rank_name, gr.level as rank_level
            FROM guild_membership gm
            JOIN players p ON p.id = gm.player_id
            LEFT JOIN guild_ranks gr ON gr.id = gm.rank_id
            WHERE gm.guild_id = ]] .. guildId)
        
        if membersQuery then
            repeat
                local pname = result.getString(membersQuery, "name")
                local plevel = result.getNumber(membersQuery, "level")
                local pvoc = result.getNumber(membersQuery, "vocation")
                local plastlogin = result.getNumber(membersQuery, "lastlogin")
                local prankname = result.getString(membersQuery, "rank_name") or "Member"
                local pranklevel = result.getNumber(membersQuery, "rank_level") or 1
                
                -- Check if online
                local isOnline = Player(pname) ~= nil
                
                table.insert(membersData, {
                    name = pname,
                    level = plevel,
                    voc = pvoc,
                    rank = prankname,
                    online = isOnline,
                    last = plastlogin,
                    contribution = 0
                })
                
                -- Find leader (rank level 3)
                if pranklevel == 3 then
                    leaderName = pname
                end
            until not result.next(membersQuery)
            result.free(membersQuery)
        end
        
        -- Build ranks list from DB
        local ranksData = {}
        local ranksQuery = db.storeQuery("SELECT `id`, `name`, `level` FROM `guild_ranks` WHERE `guild_id` = " .. guildId .. " ORDER BY `level` DESC")
        if ranksQuery then
            repeat
                local rankId = result.getNumber(ranksQuery, "id")
                local rankName = result.getString(ranksQuery, "name")
                local rankLevel = result.getNumber(ranksQuery, "level")
                
                local rankData = {
                    id = rankId,
                    name = rankName,
                    permissions = (rankLevel >= 2) and 127 or 0
                }
                
                if rankLevel == 3 then
                    rankData.leader = true
                elseif rankLevel == 1 then
                    rankData.default = true
                end
                
                table.insert(ranksData, rankData)
            until not result.next(ranksQuery)
            result.free(ranksQuery)
        end
        
        generalData.leader = leaderName
        generalData.membersList = membersData
        generalData.ranksList = ranksData
        generalData.members = {#membersData, config.maxMembers}

        sendJSON(player, {action = "general", data = generalData})
        
    elseif action == "members" then
        if not guild then print("[Members] No guild object") return end
        local membersData = {}
        local guildId = guild:getId()
        print("[Members] Fetching members for guild ID: " .. guildId)
        
        -- Fetch members from DB
        local query = db.storeQuery([[
            SELECT p.id, p.name, p.level, p.vocation, p.lastlogin, gm.rank_id, gr.name as rank_name
            FROM guild_membership gm
            JOIN players p ON p.id = gm.player_id
            LEFT JOIN guild_ranks gr ON gr.id = gm.rank_id
            WHERE gm.guild_id = ]] .. guildId)
        
        if query then
            repeat
                local pid = result.getNumber(query, "id")
                local pname = result.getString(query, "name")
                local plevel = result.getNumber(query, "level")
                local pvoc = result.getNumber(query, "vocation")
                local plastlogin = result.getNumber(query, "lastlogin")
                local prankname = result.getString(query, "rank_name") or "Member"
                
                -- Check if online
                local isOnline = Player(pname) ~= nil
                
                table.insert(membersData, {
                    name = pname,
                    level = plevel,
                    voc = pvoc,
                    rank = prankname,
                    online = isOnline,
                    last = plastlogin,
                    contribution = 0
                })
            until not result.next(query)
            result.free(query)
        end
        
        sendJSON(player, {action = "members", data = membersData})
        
    elseif action == "ranks" then
         if not guild then return end
         local ranksData = {}
         local guildId = guild:getId()
         
         -- Fetch ranks from DB
         local rankQuery = db.storeQuery("SELECT `id`, `name`, `level` FROM `guild_ranks` WHERE `guild_id` = " .. guildId .. " ORDER BY `level` DESC")
         if rankQuery then
            repeat
                local rankId = result.getNumber(rankQuery, "id")
                local rankName = result.getString(rankQuery, "name")
                local rankLevel = result.getNumber(rankQuery, "level")
                
                local rankData = {
                    id = rankId,
                    name = rankName,
                    permissions = (rankLevel >= 2) and 127 or 0 -- Leaders and Vice get full permissions
                }
                
                if rankLevel == 3 then
                    rankData.leader = true
                elseif rankLevel == 1 then
                    rankData.default = true
                end
                
                table.insert(ranksData, rankData)
            until not result.next(rankQuery)
            result.free(rankQuery)
         end
         
         sendJSON(player, {action = "ranks", data = ranksData})

    elseif action == "settings" then
        if not guild then return end
        -- if not hasPermission... TODO
        setGuildExtra(guildId, STORAGE.STATUS, data.status)
        setGuildExtra(guildId, STORAGE.REQ_LEVEL, data.reqLevel)
        setGuildExtra(guildId, STORAGE.LANGUAGE, data.language)
        setGuildExtra(guildId, STORAGE.EMBLEM, data.emblem)
        setGuildExtra(guildId, STORAGE.MOTD, data.motd)
        
        sendJSON(player, {action = "settings", data = data}) -- Confirm update
    

    elseif action == "donate" then
        if not guild then return end
        local amount = tonumber(data)
        if not amount or amount < 0 then return end
        if player:getMoney() >= amount then
             player:removeMoney(amount)
             
             -- Secure DB Balance Check
             local currentBalance = 0
             local balQuery = db.storeQuery("SELECT `balance` FROM `guilds` WHERE `id` = " .. guild:getId())
             if balQuery then
                 currentBalance = result.getNumber(balQuery, "balance")
                 result.free(balQuery)
             end
             
             local newBalance = currentBalance + amount
             
             -- Update both DB and Object
             db.query("UPDATE `guilds` SET `balance` = " .. newBalance .. " WHERE `id` = " .. guild:getId())
             guild:setBankBalance(newBalance)
             
             GuildInbox.addLog(guildId, 6, player:getName() .. " deposited " .. amount .. " gold.")
             sendJSON(player, {action = "contribution", data = amount}) -- Update UI
             sendJSON(player, {action = "gold", data = {gold = newBalance, next = 100000}})
        else
             sendJSON(player, {action = "error", data = "Not enough money."})
        end

    elseif action == "create" then
         print("DEBUG: Received create guild request from " .. player:getName())
         
         local name = data.name
         if not name or name:len() < 4 or name:len() > 30 then
             print("DEBUG: Invalid name length")
             sendJSON(player, {action = "error", data = "Invalid guild name length."})
             return
         end
         
         local ownerId = player:getGuid()

         -- ZOMBIE GUILD CLEANUP: Check if player already owns a guild in DB
         -- We do this BEFORE blocking, because if it's a zombie, we want to kill it.
         local zombieCheck = db.storeQuery("SELECT `id` FROM `guilds` WHERE `ownerid` = " .. ownerId)
         if zombieCheck ~= false then
             local oldGuildId = result.getNumber(zombieCheck, "id")
             result.free(zombieCheck)
             print("DEBUG: Found zombie/existing guild (ID: " .. oldGuildId .. ") for player. Deleting to allow new creation...")
             db.query("DELETE FROM `guild_membership` WHERE `guild_id` = " .. oldGuildId)
             db.query("DELETE FROM `guild_ranks` WHERE `guild_id` = " .. oldGuildId)
             db.query("DELETE FROM `guilds` WHERE `id` = " .. oldGuildId)
             
             -- If we had a fake guild object loaded, it's now invalid.
             guild = nil
             player:setGuild(nil)
         end

         local resultId = db.storeQuery("SELECT `id` FROM `guilds` WHERE `name` = " .. db.escapeString(name))
         if resultId ~= false then
             result.free(resultId)
             print("DEBUG: Guild name exists")
             sendJSON(player, {action = "error", data = "Guild name already exists."})
             return
         end
         
         local ownerId = player:getGuid()
         local creationTime = os.time()
         
         print("DEBUG: Inserting guild into DB...")
         local queryStr = "INSERT INTO `guilds` (`name`, `ownerid`, `creationdata`, `motd`) VALUES (" .. db.escapeString(name) .. ", " .. ownerId .. ", " .. creationTime .. ", 'Welcome to our guild.')"
         if not db.query(queryStr) then
             print("DEBUG: DB Insert failed: " .. queryStr)
             sendJSON(player, {action = "error", data = "Database error."})
             return 
         end
         print("DEBUG: DB Insert success")
         
         resultId = db.storeQuery("SELECT `id` FROM `guilds` WHERE `name` = " .. db.escapeString(name))
         if resultId == false then
             print("DEBUG: Failed to get new ID")
             sendJSON(player, {action = "error", data = "Failed to retrieve new guild ID."})
             return
         end
         local guildId = result.getNumber(resultId, "id")
         result.free(resultId)
         print("DEBUG: New Guild ID: " .. guildId)
         
         -- Trigger automatically creates ranks 1, 2, 3. We need rank 3 (Leader).
         local rankId = 0
         resultId = db.storeQuery("SELECT `id` FROM `guild_ranks` WHERE `guild_id` = " .. guildId .. " AND `level` = 3")
         if resultId ~= false then
             rankId = result.getNumber(resultId, "id")
             result.free(resultId)
             print("DEBUG: Found Rank ID: " .. rankId)
         else 
             print("DEBUG: Rank not found. Trigger might have failed.")
             sendJSON(player, {action = "error", data = "Rank creation failed."})
             return
         end
         
         db.query("INSERT INTO `guild_membership` (`player_id`, `guild_id`, `rank_id`, `nick`) VALUES (" .. ownerId .. ", " .. guildId .. ", " .. rankId .. ", '')")
         print("DEBUG: Added player to membership")
         
         setGuildExtra(guildId, STORAGE.STATUS, data.status)
         setGuildExtra(guildId, STORAGE.REQ_LEVEL, data.reqLevel)
         setGuildExtra(guildId, STORAGE.LANGUAGE, data.lang)
         setGuildExtra(guildId, STORAGE.EMBLEM, data.emblem)
         
         local newGuild = Guild(guildId)
         if not newGuild then
             newGuild = Guild(name)
         end

         if newGuild then
             print("DEBUG: Guild object loaded")
             newGuild:addMember(player)
             -- Force update internal player guild pointer if addMember didn't do it enough
             if player.setGuild then player:setGuild(newGuild) end
             
             if player.setGuildRank then
                 player:setGuildRank(newGuild:getRankById(rankId))
             end
         else
             print("DEBUG: Failed to load Guild object (ID and Name)")
             -- Attempt reload?
             -- if doReloadInfo then doReloadInfo(RELOAD_GUILDS) end
         end
         
         print("DEBUG: Sending success response")
         GuildInbox.addLog(guildId, 4, "Guild created by " .. player:getName())
         sendJSON(player, {action = "create", data = {success=true}})
         handleGuildAction(player, "fetch", nil) 
         handleGuildAction(player, "general", nil)

    elseif action == "invite" then
         -- data = playerName
         if not guild then return end
         -- Check permission in a real scenario
         
         local targetPlugin = Player(data)
         if targetPlugin then
             if targetPlugin:getGuild() then
                 sendJSON(player, {action = "error", data = "Player is already in a guild."})
             else
                 local guildId = guild:getId()
                 local guildName = guild:getName()
                 local success, err = GuildInbox.sendInvite(guildId, guildName, targetPlugin:getGuid(), player:getName())
                 
                  
                  if success then
                       GuildInbox.addLog(guildId, 1, "Invited " .. targetPlugin:getName())
                       sendJSON(player, {action = "invite", data = targetPlugin:getName()}) -- Notify success
                       targetPlugin:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "You have been invited to join the guild " .. guildName .. ".")
                       
                       -- Real-time Inbox Refresh for Target
                       handleGuildAction(targetPlugin, "inbox", nil)
                  else
                       sendJSON(player, {action = "error", data = err or "Failed to send invite."})
                  end
             end
         else
             sendJSON(player, {action = "error", data = "Player not found."})
         end

    elseif action == "kick" then
         -- data = playerName
         if not guild then return end
         
         -- Check Kicker Permissions
         -- Use DB to be 100% sure of Rank Level (3 = Leader, 2 = Vice, 1 = Member)
         local kickerLevel = 0
         local rankId = 0
         
         if player.getGuildRank then
            local rankObj = player:getGuildRank()
            rankId = rankObj and rankObj:getId() or 0
         end

         -- Fallback: If getGuildRank failed or returned 0, try getting rank ID from DB directly
         if rankId == 0 then
             local dbRankQuery = db.storeQuery("SELECT `rank_id` FROM `guild_membership` WHERE `player_id` = " .. player:getGuid())
             if dbRankQuery then
                 rankId = result.getNumber(dbRankQuery, "rank_id")
                 result.free(dbRankQuery)
             end
         end
         
         if rankId > 0 then
            local rankQuery = db.storeQuery("SELECT `level` FROM `guild_ranks` WHERE `id` = " .. rankId)
            if rankQuery then
                kickerLevel = result.getNumber(rankQuery, "level")
                result.free(rankQuery)
            end
         end
         
         print("[GuildKick] Kicker: " .. player:getName() .. " RankID: " .. rankId .. " Level: " .. kickerLevel)
         
         if kickerLevel < 2 then
             sendJSON(player, {action = "error", data = "Kick Denied. Rank Level: " .. kickerLevel})
             return 
         end
         
         local targetMember = nil
         -- Find member even if offline (if possible via db, but for now basic online check stuff)
         local targetPlugin = Player(data) 
         
         if targetPlugin and targetPlugin:getGuild():getId() == guild:getId() then
             -- Check Target Rank
             if targetPlugin:getGuildLevel() >= 3 then
                 sendJSON(player, {action = "error", data = "The Guild Leader cannot be kicked."})
                 return
             end
             
             -- Optional: Vice cannot kick another Vice?
             if targetPlugin:getGuildLevel() >= player:getGuildLevel() then
                 sendJSON(player, {action = "error", data = "You cannot kick a member with equal or higher rank."})
                 return
             end

             -- Manually remove from DB to ensure persistence
             db.query("DELETE FROM `guild_membership` WHERE `player_id` = " .. targetPlugin:getGuid())
             
             guild:removeMember(targetPlugin)
             
             -- Recalculate stats for client update
             local totalLevels = 0
             local memberCount = 0
             local statsQuery = db.storeQuery("SELECT COUNT(*) as count, SUM(p.level) as total FROM guild_membership gm JOIN players p ON p.id = gm.player_id WHERE gm.guild_id = " .. guild:getId())
             if statsQuery then
                 memberCount = result.getNumber(statsQuery, "count")
                 totalLevels = result.getNumber(statsQuery, "total")
                 result.free(statsQuery)
             end
             
             sendJSON(player, {action = "kicked", data = {name = data, members = {memberCount, config.maxMembers}, levels = totalLevels}}) -- Notify kick
             
             -- Notify target
             targetPlugin:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, "You have been kicked from the guild.")
             if targetPlugin.setGuild then targetPlugin:setGuild(nil) end -- Force update
         else
              -- If offline, we might need DB query, but let's stick to safe basic API
              sendJSON(player, {action = "error", data = "Player must be online to be kicked (Basic Mode)."})
         end
    
    elseif action == "leave" then
         if not guild then return end
         
         -- Check if leader using DB (Safe for Fake Guilds)
         local isLeader = false
         local guildId = guild:getId()
         
         local ownerCheck = db.storeQuery("SELECT `ownerid` FROM `guilds` WHERE `id` = " .. guildId)
         if ownerCheck ~= false then
             local dbOwner = result.getNumber(ownerCheck, "ownerid")
             result.free(ownerCheck)
             if dbOwner == player:getGuid() then
                 isLeader = true
             end
         end
         
         if isLeader then
             -- WAR CLEANUP: End all active wars first
             if GuildWars then
                  local activeWars = db.storeQuery("SELECT `id`, `guild1`, `guild2`, `name1`, `name2` FROM `guild_wars` WHERE `status` IN (0, 1) AND (`guild1` = " .. guildId .. " OR `guild2` = " .. guildId .. ")")
                  if activeWars then
                      repeat
                          local warId = result.getNumber(activeWars, "id")
                          local g1 = result.getNumber(activeWars, "guild1")
                          local g2 = result.getNumber(activeWars, "guild2")
                          local n1 = result.getString(activeWars, "name1")
                          local n2 = result.getString(activeWars, "name2")
                          local enemyId = (g1 == guildId) and g2 or g1
                          local disbandedName = (g1 == guildId) and n1 or n2
                          
                          -- End War (Status 4 = Cancelled/Disbanded)
                          db.query("UPDATE `guild_wars` SET `status` = 4, `ended` = " .. os.time() .. " WHERE `id` = " .. warId)
                          
                          -- Send warEnd packet to enemy guild players (clears their emblems)
                          local players = Game.getPlayers()
                          local OPCODE = 1
                          for _, p in ipairs(players) do
                              local pg = p:getGuild()
                              if pg and pg:getId() == enemyId then
                                  p:sendExtendedOpcode(OPCODE, json.encode({action = "warEnd", data = {warId = warId, enemyName = disbandedName, reason = "disbanded"}}))
                              end
                          end
                      until not result.next(activeWars)
                      result.free(activeWars)
                  end
             end

             db.query("DELETE FROM `guild_membership` WHERE `guild_id` = " .. guildId)
             db.query("DELETE FROM `guild_ranks` WHERE `guild_id` = " .. guildId)
             db.query("DELETE FROM `guilds` WHERE `id` = " .. guildId)
             
             guild:removeMember(player)
             if player.setGuild then player:setGuild(nil) end
             -- Clean up Fake Guild if active
             if type(guild) == "table" and guild.fake then guild = nil end
             
             sendJSON(player, {action = "left", data = {success=true}})
         else
             guild:removeMember(player)
             if player.setGuild then player:setGuild(nil) end
             sendJSON(player, {action = "left", data = {success=true}})
         end
    elseif action == "inbox" then
        -- Build inbox array combining logs and invites in client expected format
        local inbox = {}
        local msgId = 1

        
        -- Guild Logs (if in guild)
        if guild then
            local logs = GuildInbox.getLogs(guild:getId())
            for _, log in ipairs(logs) do
                -- Determine if this message should be actionable
                -- WAR_DECLARATION (type 7) is only actionable if:
                -- 1. log.finished is NOT true (not processed yet)
                -- 2. There's actually a pending war in the database (status = 0)
                local isFinished = 1 -- Default: not actionable
                if log.type == 7 then
                    -- War declaration - check if already accepted/rejected
                    if log.finished == true then
                        isFinished = 1 -- Already processed
                    else
                        -- Also check database - if no pending war exists, this log is stale
                        local pendingCheck = db.storeQuery("SELECT `id` FROM `guild_wars` WHERE `status` = 0 AND `guild2` = " .. guild:getId() .. " LIMIT 1")
                        if pendingCheck then
                            result.free(pendingCheck)
                            isFinished = 0 -- Still pending, can accept/reject
                        else
                            isFinished = 1 -- No pending war found, mark as finished
                            -- Also update the log to avoid this check next time
                            GuildInbox.markLogFinished(guild:getId(), 7)
                        end
                    end
                end
                
                table.insert(inbox, {
                    id = msgId,
                    type = log.type,
                    date = log.date,
                    text = log.text,
                    guildId = guild:getId(),
                    targetId = 0,
                    finished = isFinished
                })
                msgId = msgId + 1
            end
        end
        
        -- Player Invites (always, for players without guild)
        local invites = GuildInbox.getPlayerInvites(player:getGuid())
        for _, inv in ipairs(invites) do
            table.insert(inbox, {
                id = msgId,
                type = 1, -- JOIN_INVITATION
                date = inv.date,
                text = inv.guildName .. " invited you. Sent by " .. inv.sender,
                guildId = inv.guildId,
                targetId = player:getGuid(),
                finished = 0 -- Actionable
            })
            msgId = msgId + 1
        end
        
        sendJSON(player, {action = "inbox", data = {inbox = inbox, size = #inbox, last = #inbox}})
        
    elseif action == "revoke" then
        if not guild then return end
        
        local targetGuildId = nil
        if type(data) == "table" then
            targetGuildId = tonumber(data.guildId)
        else
            targetGuildId = tonumber(data)
        end
        
        if GuildWars then
             local guildId = guild:getId()
             local queryStr = "SELECT `id`, `guild2` FROM `guild_wars` WHERE `status` = 0 AND `guild1` = " .. guildId
             
             if targetGuildId then
                 queryStr = queryStr .. " AND `guild2` = " .. targetGuildId
             end
             
             queryStr = queryStr .. " LIMIT 1"
             
             local warQuery = db.storeQuery(queryStr)
             
             if warQuery then
                 local warId = result.getNumber(warQuery, "id")
                 local targetGid = result.getNumber(warQuery, "guild2")
                 result.free(warQuery)
                 
                 -- Revoke means Cancelled (Status 4)
                 db.query("UPDATE `guild_wars` SET `status` = 4, `ended` = " .. os.time() .. " WHERE `id` = " .. warId)
                 
                 print("[GuildWars] War " .. warId .. " revoked by guild " .. guildId)
                 
                 -- Broadcast emblem update (Neutralize)
                 if GuildWars.broadcastEmblems then
                     GuildWars.broadcastEmblems(guildId, targetGid)
                 end
                 
                 sendJSON(player, {action = "revoke", data = {success=true}})
                 handleGuildAction(player, "fetch", nil) 
             else
                 sendJSON(player, {action = "error", data = "No pending war declaration found."})
             end
        else
             sendJSON(player, {action = "error", data = "War system not loaded."})
        end

    elseif action == "surrender" then
        if not guild then return end
        
        -- Check if war exists
        if GuildWars then
             -- Find active war (status 1)
             local guildId = guild:getId()
             local warQuery = db.storeQuery("SELECT `id`, `guild1`, `guild2` FROM `guild_wars` WHERE `status` = 1 AND (`guild1` = " .. guildId .. " OR `guild2` = " .. guildId .. ") LIMIT 1")
             
             if warQuery then
                 local warId = result.getNumber(warQuery, "id")
                 local g1 = result.getNumber(warQuery, "guild1")
                 local g2 = result.getNumber(warQuery, "guild2")
                 local enemyGuildId = (g1 == guildId) and g2 or g1
                 result.free(warQuery)
                 
                 -- End the war (Status 5 = Ended)
                 db.query("UPDATE `guild_wars` SET `status` = 5, `ended` = " .. os.time() .. " WHERE `id` = " .. warId)
                 
                 print("[GuildWars] War " .. warId .. " surrendered by guild " .. guildId)
                 
                 GuildWars.broadcastEmblems(guildId, enemyGuildId)

                 sendJSON(player, {action = "surrender", data = {success=true}})
                 handleGuildAction(player, "fetch", nil) -- Refresh UI
             else
                 sendJSON(player, {action = "error", data = "No active war found to surrender."})
             end
        else
             sendJSON(player, {action = "error", data = "War system not loaded."})
        end

    elseif action == "accept" then
        -- data = {id, type, targetId, guildId} from client OR plain guildId
        print("[DEBUG] Accept action called! Data: " .. (data and json.encode(data) or "nil"))
        local guildId
        local msgType
        if type(data) == "table" then
            guildId = tonumber(data.guildId)
            msgType = tonumber(data.type)
            print("[DEBUG] Table data - guildId: " .. tostring(guildId) .. ", msgType: " .. tostring(msgType))
        else
            guildId = tonumber(data)
            msgType = 1 -- Default to JOIN_INVITATION
            print("[DEBUG] Plain data - guildId: " .. tostring(guildId) .. ", msgType: 1 (default)")
        end
        
        -- Handle WAR_DECLARATION (type 7)
        if msgType == 7 then
            if not guild then
                sendJSON(player, {action = "error", data = "You need to be in a guild to accept war declarations."})
                return
            end
            
            -- Accept the war - activate it in GuildWars database
            if GuildWars then
                -- Find the declaring guild from pending wars (status = 0) where we are guild2
                local myGuildId = guild:getId()
                local pendingQuery = db.storeQuery("SELECT `id`, `guild1` FROM `guild_wars` WHERE `status` = 0 AND `guild2` = " .. myGuildId .. " LIMIT 1")
                
                if pendingQuery then
                    local warId = result.getNumber(pendingQuery, "id")
                    local enemyGuildId = result.getNumber(pendingQuery, "guild1")
                    result.free(pendingQuery)
                    
                    -- Use shared logic to accept and broadcast emblems
                    GuildWars.accept(myGuildId, enemyGuildId)
                    
                    sendJSON(player, {action = "accept", data = {success=true}})
                    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "War declaration accepted! The war is now active.")
                    
                    -- Mark log entry as finished
                    GuildInbox.markLogFinished(myGuildId, 7)
                else
                    sendJSON(player, {action = "error", data = "No pending war declaration found."})
                end
            else
                sendJSON(player, {action = "error", data = "War system not loaded."})
            end
            return
        end
        
        -- Original JOIN_INVITATION handling
        if player:getGuild() then
            sendJSON(player, {action = "error", data = "You are already in a guild."})
            return
        end
        
        local invites = GuildInbox.getPlayerInvites(player:getGuid())
        local valid = false
        for _, inv in ipairs(invites) do
            if inv.guildId == guildId then
                valid = true
                break
            end
        end
        
        if valid then
            -- Check if guild exists in DB
            local guildCheck = db.storeQuery("SELECT `name` FROM `guilds` WHERE `id` = " .. guildId)
            if guildCheck then
                local guildName = result.getString(guildCheck, "name")
                result.free(guildCheck)
                
                -- Get default rank
                local rankQuery = db.storeQuery("SELECT `id` FROM `guild_ranks` WHERE `guild_id` = " .. guildId .. " ORDER BY `level` ASC LIMIT 1")
                local rankId = 0
                if rankQuery then
                    rankId = result.getNumber(rankQuery, "id")
                    result.free(rankQuery)
                end
                
                -- Insert player into guild_membership
                db.query("INSERT INTO `guild_membership` (`player_id`, `guild_id`, `rank_id`, `nick`) VALUES (" .. player:getGuid() .. ", " .. guildId .. ", " .. rankId .. ", '')")
                
                -- Remove invite and log
                GuildInbox.removeInvite(player:getGuid(), guildId)
                GuildInbox.addLog(guildId, 4, player:getName() .. " joined the guild.")
                
                sendJSON(player, {action = "accept", data = {success=true, name=guildName}})
                
                -- Update Player Object immediately if possible
                local newGuild = Guild(guildId)
                if newGuild then
                    newGuild:addMember(player) -- Update C++ Cache
                    
                    if player.setGuild then
                        player:setGuild(newGuild) 
                    end
                    if player.setGuildRank and rankId > 0 then
                        player:setGuildRank(newGuild:getRankById(rankId))
                    end
                    
                    -- Refresh UI for the accept-er
                    handleGuildAction(player, "fetch", nil) 
                    handleGuildAction(player, "general", nil)
                    
                    -- Notify Online Guild Members to Refresh
                    for _, member in ipairs(Game.getPlayers()) do
                         if member:getGuild() and member:getGuild():getId() == guildId and member:getName() ~= player:getName() then
                             handleGuildAction(member, "members", nil) -- Refresh member list
                             handleGuildAction(member, "general", nil) -- Refresh general (count)
                         end
                    end
                end

                player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "You joined " .. guildName .. "!")
            else
                sendJSON(player, {action = "error", data = "Guild not found."})
            end
        else
             sendJSON(player, {action = "error", data = "Invite not found."})
        end

    elseif action == "reject" then
        -- data = {id, type, targetId, guildId} from client OR plain guildId
        local guildId
        local msgType
        if type(data) == "table" then
            guildId = tonumber(data.guildId)
            msgType = tonumber(data.type)
        else
            guildId = tonumber(data)
            msgType = 1 -- Default to JOIN_INVITATION
        end
        
        -- Handle WAR_DECLARATION rejection (type 7)
        if msgType == 7 then
            if not guild then
                sendJSON(player, {action = "error", data = "You need to be in a guild to reject war declarations."})
                return
            end
            
            local myGuildId = guild:getId()
            -- Find and reject pending war
            local pendingQuery = db.storeQuery("SELECT `id`, `guild1` FROM `guild_wars` WHERE `status` = 0 AND `guild2` = " .. myGuildId .. " LIMIT 1")
            if pendingQuery then
                local enemyGuildId = result.getNumber(pendingQuery, "guild1")
                result.free(pendingQuery)
                
                -- Use shared logic to reject
                GuildWars.reject(myGuildId, enemyGuildId)
                
                -- Mark log entry as finished
                GuildInbox.markLogFinished(myGuildId, 7)
                
                sendJSON(player, {action = "reject", data = {success=true}})
                player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "War declaration rejected.")
            else
                sendJSON(player, {action = "error", data = "No pending war declaration found."})
            end
            return
        end
        
        -- Original player invite rejection
        GuildInbox.removeInvite(player:getGuid(), guildId)
        sendJSON(player, {action = "reject", data = {success=true}})
    elseif action == "declaration" then
        -- data = {guildId, forced, duration, kills, goldBet}
        if not guild then return end
        
        -- Get target guild info
        local targetGuildId = tonumber(data.guildId)
        local targetName = nil
        
        if targetGuildId then
            local check = db.storeQuery("SELECT `name` FROM `guilds` WHERE `id` = " .. targetGuildId)
            if check then
                targetName = result.getString(check, "name")
                result.free(check)
            end
        end
        
        if not targetName then
            sendJSON(player, {action = "error", data = "Target guild not found."})
            return
        end
        
        local duration = tonumber(data.duration) or 86400 -- 1 day in seconds
        local kills = tonumber(data.kills) or 10
        local price = tonumber(data.goldBet) or 0
        local forced = data.forced or false
        
        -- Check Pacifism
        local myPacifism = getGuildPacifism(guildId)
        if myPacifism > os.time() then
             sendJSON(player, {action = "error", data = "You cannot declare war while in Pacifist Mode."})
             return
        end
        
        local targetPacifism = getGuildPacifism(targetGuildId)
        if targetPacifism > os.time() then
             sendJSON(player, {action = "error", data = "Target guild is in Pacifist Mode."})
             return
        end
        
        -- Check Logic in GuildWars
        if GuildWars then
             local success, err = GuildWars.declare(guild:getId(), guild:getName(), targetName, {duration=duration, kills=kills, price=price, forced=forced})
             if success then
                 sendJSON(player, {action = "declaration", data = {success=true}})
                 handleGuildAction(player, "fetch", nil) 
             else
                 sendJSON(player, {action = "error", data = err or "Declaration failed."})
             end
        else
             sendJSON(player, {action = "error", data = "War system not loaded."})
        end

    elseif action == "pacifist" then
        if not guild then return end
        
        -- Check permissions (Leader only usually, or Vice?)
        if player:getGuildLevel() < 3 then
             sendJSON(player, {action = "error", data = "Only the Guild Leader can manage Pacifist Mode."})
             return
        end
        
        -- Calculate Cost
        -- Ideally this should match client calculation or be passed from config
        -- Hardcoded example based on typical values or config if available
        -- Assuming a fixed cost or retrieving from config if defined
        local cost = 0
        -- Simple heuristic: if client sends gold check, we should verify on server
        -- Using a safe default or checking config if available in scope
        -- Let's assume a fixed cost for now or try to use config.pacifismCost if it exists
        
        -- Default cost if not in config
        local pacifismPrice = 1000000 -- 1kk default example
        
        if guild:getBankBalance() < pacifismPrice then
             sendJSON(player, {action = "error", data = "Guild bank does not have enough funds."})
             return
        end

         -- Toggle Pacifism (DB persistence)
         local current = getGuildPacifism(guildId)
         local now = os.time()
         
         local newState = 0
         if current < now then
             -- Activate Pacifism (Set to 14 days from now as default)
             local duration = config.pacifismDuration or (14 * 86400)
             newState = now + duration
             
             -- Deduct Gold
             guild:setBankBalance(guild:getBankBalance() - pacifismPrice)
             GuildInbox.addLog(guildId, 6, "Pacifist Mode ACTIVATED by " .. player:getName() .. " (-" .. pacifismPrice .. " gold)")
         else
             -- Deactivate
             newState = 0 -- Reset to 0 (inactive)
             
             -- Deduct Gold (Same value as activation, per user request)
             guild:setBankBalance(guild:getBankBalance() - pacifismPrice)
             GuildInbox.addLog(guildId, 6, "Pacifist Mode DEACTIVATED by " .. player:getName() .. " (-" .. pacifismPrice .. " gold)")
         end
         
         setGuildPacifism(guildId, newState)
         
         -- Refund UI update
         sendJSON(player, {action = "gold", data = {gold = guild:getBankBalance(), next = 100000}})
         sendJSON(player, {action = "pacifist", data = {active = (newState > now)}})
         handleGuildAction(player, "fetch", nil)
         handleGuildAction(player, "general", nil)
         setGuildExtra(guildId, STORAGE.PACIFISM, newState)
         sendJSON(player, {action = "pacifist", data = newState})
         handleGuildAction(player, "fetch", nil) 
    
    elseif action == "levelUp" then
        if not guild then return end
        
        local currentLevel = getGuildLevel(guildId)
        print("DEBUG: Processing Level Up for Guild " .. guildId .. ". Current Level: " .. currentLevel)
        
        local priceTable = config.advancement.price
        local maxLevel = #priceTable + 1
        
        if currentLevel >= maxLevel then
             sendJSON(player, {action = "error", data = "Guild is already at max level."})
             return
        end
        
        local cost = priceTable[currentLevel]
        
        -- Secure DB Balance Check
        local currentBalance = 0
        local balQuery = db.storeQuery("SELECT `balance` FROM `guilds` WHERE `id` = " .. guild:getId())
        if balQuery then
             currentBalance = result.getNumber(balQuery, "balance")
             result.free(balQuery)
        end
        
        print("DEBUG: Cost: " .. cost .. " | Balance (DB): " .. currentBalance)
        
        if currentBalance >= cost then
             local newBalance = currentBalance - cost
             db.query("UPDATE `guilds` SET `balance` = " .. newBalance .. " WHERE `id` = " .. guild:getId())
             guild:setBankBalance(newBalance)
             
             setGuildLevel(guildId, currentLevel + 1)
             print("DEBUG: Level Up SUCCESS. New Level: " .. (currentLevel + 1))
             
             GuildInbox.addLog(guildId, 6, player:getName() .. " leveled up the guild to Level " .. (currentLevel + 1))
             sendJSON(player, {action = "success", data = "Guild leveled up!"})
             
             handleGuildAction(player, "fetch", nil) 
             handleGuildAction(player, "general", nil)
        else
             print("DEBUG: Level Up FAILED. Not enough gold.")
             sendJSON(player, {action = "error", data = "Not enough gold. Needed: " .. cost})
        end

    elseif action == "buffs" then
        if not guild then return end
        
        -- Client sends a list of buffs {1=ID, 2=ID, ...}
        if type(data) ~= "table" then 
            sendJSON(player, {action = "error", data = "Invalid buff data."})
            return 
        end
        
        local successCount = 0
        local failCount = 0
        local lastError = ""
        
        if GuildBuffs then
             for slot, buffId in pairs(data) do
                 local bid = tonumber(buffId)
                 if bid and bid > 0 then
                     -- Map (Row, Choice) to Unique ID (1-18)
                     -- Slot is the Row Index (1-9)
                     local uniqueId = (tonumber(slot) - 1) * 2 + bid
                     
                     local success, err = GuildBuffs.buy(guild, uniqueId)
                     if success then
                         successCount = successCount + 1
                     else
                         failCount = failCount + 1
                         lastError = err
                     end
                 end
             end
             
             if successCount > 0 then
                 sendJSON(player, {action = "success", data = successCount .. " buffs updated!"})
                 handleGuildAction(player, "fetch", nil) 
                 handleGuildAction(player, "general", nil)
             else
                 if failCount > 0 then
                     sendJSON(player, {action = "error", data = lastError or "Failed to update buffs."})
                 end
             end
        else
             sendJSON(player, {action = "error", data = "Buff system not loaded."})
        end
    
    elseif action == "setRank" then
        if not guild then return end
        
        -- data = {name="playername", rankId=ID}
        if not data.name or not data.rankId then return end
        
        -- Check if player is leader (or has edit permission)
        local canEdit = false
        if player:getGuildLevel() == 3 then
            canEdit = true
        else
            -- Check for Vice with permission? For now let's stick to Leader or Vice
            -- But we can stick to native Guild Levels: 3 (Leader), 2 (Vice), 1 (Member)
            -- If Kicker is 3, they can set anyone (except themselves usually or logic handled by UI)
            if player:getGuildLevel() > 1 then
                canEdit = true
            end
        end
        
        if not canEdit then
             sendJSON(player, {action = "error", data = "No permission."})
             return
        end
        
        local targetName = data.name
        local targetRankId = tonumber(data.rankId)
        
        -- Verify Target is in guild
        local checkMember = db.storeQuery("SELECT `player_id`, `rank_id` FROM `guild_membership` WHERE `guild_id` = " .. guild:getId() .. " AND `player_id` = (SELECT `id` FROM `players` WHERE `name` = " .. db.escapeString(targetName) .. ")")
        if checkMember then
            local pid = result.getNumber(checkMember, "player_id")
            result.free(checkMember)
            
            -- Update DB
            db.query("UPDATE `guild_membership` SET `rank_id` = " .. targetRankId .. " WHERE `player_id` = " .. pid .. " AND `guild_id` = " .. guild:getId())
            
            -- Fetch rank name for UI update
            local rankName = "Member"
            local getRankName = db.storeQuery("SELECT `name` FROM `guild_ranks` WHERE `id` = " .. targetRankId)
            if getRankName then
                rankName = result.getString(getRankName, "name")
                result.free(getRankName)
            end
            
            sendJSON(player, {action = "memberRank", data = {name = targetName, rank = rankName}})
            
            local targetPlugin = Player(targetName)
            if targetPlugin then
                if targetPlugin.setGuildRank then
                    targetPlugin:setGuildRank(guild:getRankById(targetRankId))
                end
                targetPlugin:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Your guild rank has been updated to " .. rankName .. ".")
            end
        else
            sendJSON(player, {action = "error", data = "Member not found."})
        end

    elseif action == "passLeader" then
        if not guild then return end
        
        -- Strictly Leader Only (Level 3) using safe DB check or object
        if player:getGuildLevel() < 3 then
             sendJSON(player, {action = "error", data = "Only the leader can pass leadership."})
             return 
        end
        
        local targetName = data
        local targetGuid = 0
        
        -- Verify target is in guild
        local checkMember = db.storeQuery("SELECT `player_id` FROM `guild_membership` WHERE `guild_id` = " .. guild:getId() .. " AND `player_id` = (SELECT `id` FROM `players` WHERE `name` = " .. db.escapeString(targetName) .. ")")
        if checkMember then
             targetGuid = result.getNumber(checkMember, "player_id")
             result.free(checkMember)
        else
             sendJSON(player, {action = "error", data = "Target member not found in guild."})
             return
        end
        
        if targetGuid == player:getGuid() then
             sendJSON(player, {action = "error", data = "You are already the leader."})
             return
        end
        
        -- Get Rank IDs
        -- We need Rank 3 (Leader) ID and a default Member Rank ID (usually Level 1)
        local leaderRankId = 0
        local memberRankId = 0
        
        local ranks = db.storeQuery("SELECT `id`, `level` FROM `guild_ranks` WHERE `guild_id` = " .. guild:getId())
        if ranks then
            repeat
                local rid = result.getNumber(ranks, "id")
                local rlevel = result.getNumber(ranks, "level")
                if rlevel == 3 then leaderRankId = rid end
                if rlevel == 1 and memberRankId == 0 then memberRankId = rid end -- Pick first level 1 found
            until not result.next(ranks)
            result.free(ranks)
        end
        
        if leaderRankId == 0 or memberRankId == 0 then
             sendJSON(player, {action = "error", data = "Failed to identify ranks."})
             return
        end
        
        -- 1. Demote current leader (Player) -> Member
        db.query("UPDATE `guild_membership` SET `rank_id` = " .. memberRankId .. " WHERE `player_id` = " .. player:getGuid())
        
        -- 2. Promote target -> Leader
        db.query("UPDATE `guild_membership` SET `rank_id` = " .. leaderRankId .. " WHERE `player_id` = " .. targetGuid)
        
        -- 3. Update Guild Owner
        db.query("UPDATE `guilds` SET `ownerid` = " .. targetGuid .. " WHERE `id` = " .. guild:getId())
        
        -- 4. Handle Online Objects
        if player.setGuildRank then
            player:setGuildRank(guild:getRankById(memberRankId))
        end
        
        local targetPlugin = Player(targetName)
        if targetPlugin then
            if targetPlugin.setGuildRank then
                targetPlugin:setGuildRank(guild:getRankById(leaderRankId))
            end
            targetPlugin:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, "You are now the Leader of " .. guild:getName() .. "!")
        end
        
        -- 5. Notify UI
        local leaderRankName = "Leader"
        local memberRankName = "Member" -- Should fetch query but acceptable defaults for response
        
        sendJSON(player, {action = "newLeader", data = {
            newLeader = targetName, 
            newLeaderRank = leaderRankName,
            oldLeader = player:getName(),
            oldLeaderRank = memberRankName
        }})
        
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "You have passed leadership to " .. targetName .. ".")

    elseif action == "top" then
        -- Return list of all guilds for war declaration

        local guildsData = {}
        local offset = tonumber(data) or 0
        
        local query = db.storeQuery([[
            SELECT g.id, g.name, 
                   (SELECT COUNT(*) FROM guild_membership WHERE guild_id = g.id) as memberCount,
                   (SELECT SUM(p.level) FROM guild_membership gm JOIN players p ON p.id = gm.player_id WHERE gm.guild_id = g.id) as totalLevels
            FROM guilds g
            ORDER BY g.name ASC
            LIMIT 20 OFFSET ]] .. offset)
        
        if query then
            repeat
                local gid = result.getNumber(query, "id")
                local gname = result.getString(query, "name")
                local members = result.getNumber(query, "memberCount")
                local totalLvls = result.getNumber(query, "totalLevels") or 0
                local avgLevel = members > 0 and math.floor(totalLvls / members) or 0
                
                table.insert(guildsData, {
                    id = gid,
                    name = gname,
                    level = 1,
                    members = {members, 100}, -- current, max
                    total = totalLvls,
                    avgLevel = avgLevel,
                    emblem = 0,
                    leader = "Leader",
                    won = 0,
                    language = 1,
                    status = 1, -- Open
                    reqLevel = 0,
                    pacifismStatus = 0 -- Not pacifist
                })
            until not result.next(query)
            result.free(query)
        end
        

        sendJSON(player, {action = "top", data = {top = guildsData, size = #guildsData, last = offset + #guildsData, new = (offset == 0)}})
    end
end

local function onExtendedOpcode(player, opcode, buffer)
    if opcode ~= OPCODE then return end

    local status, json_data = pcall(function() return json.decode(buffer) end)
    if not status then 
        return 
    end
    
    local action = json_data.action
    local data = json_data.data
    
    local status, err = pcall(handleGuildAction, player, action, data)
    if not status then
        print("[GuildManagement] Error in handleGuildAction: " .. tostring(err))
    end
end

-- Register
local opcodeEvent = CreatureEvent("GuildManagementOpcode")
opcodeEvent:type("extendedopcode")
function opcodeEvent.onExtendedOpcode(player, opcode, buffer)
    onExtendedOpcode(player, opcode, buffer)
end
opcodeEvent:register()

local loginEvent = CreatureEvent("GuildManagementLogin")
loginEvent:type("login")
function loginEvent.onLogin(player)
     player:registerEvent("GuildManagementOpcode")
     return true
end
loginEvent:register()
