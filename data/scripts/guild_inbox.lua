-- Guild Inbox System
-- Handles Guild Logs, Join Requests, and Player Invites

GuildInbox = {}

local INBOX_DIR = "data/inbox"
local PLAYERS_DIR = INBOX_DIR .. "/players"
local GUILDS_DIR = INBOX_DIR .. "/guilds"

-- Ensure directories exist
if not io.open(INBOX_DIR, "r") then os.execute("mkdir " .. INBOX_DIR) end
if not io.open(PLAYERS_DIR, "r") then os.execute("mkdir " .. PLAYERS_DIR) end
if not io.open(GUILDS_DIR, "r") then os.execute("mkdir " .. GUILDS_DIR) end

-- Storage Helper
local function loadJson(path)
    if not io.open(path, "r") then return {} end
    local file = io.open(path, "r")
    local content = file:read("*a")
    file:close()
    local status, data = pcall(json.decode, content)
    return status and data or {}
end

local function saveJson(path, data)
    local file = io.open(path, "w")
    if file then
        file:write(json.encode(data))
        file:close()
        return true
    end
    return false
end

-- ========================================================
-- PLAYER INVITES (Guild invites Player)
-- ========================================================

function GuildInbox.sendInvite(guildId, guildName, targetGuid, senderName)
    local path = PLAYERS_DIR .. "/" .. targetGuid .. ".json"
    local invites = loadJson(path)
    
    -- Check duplicate
    for _, inv in ipairs(invites) do
        if inv.guildId == guildId then return false, "Already invited." end
    end
    
    table.insert(invites, {
        type = "invite",
        guildId = guildId,
        guildName = guildName,
        sender = senderName,
        date = os.time()
    })
    
    return saveJson(path, invites)
end

function GuildInbox.getPlayerInvites(playerGuid)
    local path = PLAYERS_DIR .. "/" .. playerGuid .. ".json"
    return loadJson(path)
end

function GuildInbox.removeInvite(playerGuid, guildId)
    local path = PLAYERS_DIR .. "/" .. playerGuid .. ".json"
    local invites = loadJson(path)
    local found = false
    
    local newInvites = {}
    for _, inv in ipairs(invites) do
        if inv.guildId ~= guildId then
            table.insert(newInvites, inv)
        else
            found = true
        end
    end
    
    if found then
        saveJson(path, newInvites)
    end
    return found
end

-- ========================================================
-- GUILD LOGS / HISTORY
-- ========================================================
-- Message Types:
-- 1: JOIN_INVITATION
-- 2: KICKED_OUT
-- 3: JOIN_REQUEST
-- 4: MEMBER_JOINED
-- 5: MEMBER_LEFT
-- 6: GOLD_DEPOSIT
-- 7: WAR_DECLARATION

function GuildInbox.addLog(guildId, typeId, text, finished)
    local path = GUILDS_DIR .. "/" .. guildId .. ".json"
    local logs = loadJson(path)
    
    table.insert(logs, 1, { -- Prepend
        type = typeId,
        text = text,
        date = os.time(),
        finished = finished or false
    })
    
    -- Limit log size
    if #logs > 50 then
        table.remove(logs, #logs)
    end
    
    saveJson(path, logs)
end

function GuildInbox.getLogs(guildId)
    local path = GUILDS_DIR .. "/" .. guildId .. ".json"
    return loadJson(path)
end

function GuildInbox.markLogFinished(guildId, typeId)
    local path = GUILDS_DIR .. "/" .. guildId .. ".json"
    local logs = loadJson(path)
    local found = false
    
    for _, log in ipairs(logs) do
        if log.type == typeId and not log.finished then
            log.finished = true
            found = true
            break
        end
    end
    
    if found then
        saveJson(path, logs)
    end
    return found
end

print("[GuildInbox] System loaded.")
