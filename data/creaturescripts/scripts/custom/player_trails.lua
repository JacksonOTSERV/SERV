-- Player Trails — rastro de effect atras do player. Desbloqueio com GEMS.
-- Opcode 156 (JSON): open / buy / use
--   client -> {action="open"}            : pede o estado (gems + trails owned)
--   client -> {action="buy", id=N}       : compra o trail N com gems
--   client -> {action="use", id=N}       : ativa (0 = desativa) se for dono
--   server -> {gems=G, active=A, trails={ {id,name,gems,owned}, ... }}

OPCODE_TRAILS       = 156
STORAGE_TRAIL_KEY   = 87651   -- trail ativo (0 = nenhum)
STORAGE_TRAIL_OWNED = 87660   -- base: STORAGE_TRAIL_OWNED + id = 1 se desbloqueado
local STORAGE_GEMS  = 50700   -- fallback local de gems

-- Catalogo: id => { effect, name, gems }. gems=0 => gratis (sempre liberado).
TRAILS = {
    [1] = { effect = 1978, name = "Default", gems = 0  },
    [2] = { effect = 36,   name = "Red",     gems = 30 },
    [3] = { effect = 12,   name = "Blue",    gems = 30 },
    [4] = { effect = 13,   name = "Green",   gems = 50 },
}

local json = nil
pcall(function() json = dofile("data/lib/json.lua") end)

-- ----- GEMS (premium_points da conta; fallback storage local) -----
local function getGems(player)
    local ok, resultId = pcall(function()
        return db.storeQuery("SELECT `premium_points` FROM `accounts` WHERE `id` = " .. player:getAccountId())
    end)
    if ok and resultId then
        local v = result.getDataInt(resultId, "premium_points")
        result.free(resultId)
        return tonumber(v) or 0
    end
    local v = player:getStorageValue(STORAGE_GEMS)
    return v > 0 and v or 0
end

local function removeGems(player, amount)
    local cur = getGems(player)
    if cur < amount then return false end
    local ok = pcall(function()
        db.query("UPDATE `accounts` SET `premium_points` = " .. (cur - amount) ..
                 " WHERE `id` = " .. player:getAccountId())
    end)
    if not ok then player:setStorageValue(STORAGE_GEMS, math.max(0, cur - amount)) end
    return true
end

local function isOwned(player, id)
    local t = TRAILS[id]
    if not t then return false end
    if (t.gems or 0) <= 0 then return true end  -- gratis
    return player:getStorageValue(STORAGE_TRAIL_OWNED + id) == 1
end

local function sendState(player)
    if not json then return end
    local active = player:getStorageValue(STORAGE_TRAIL_KEY)
    if active < 0 then active = 0 end
    local list = {}
    for id, t in pairs(TRAILS) do
        list[#list + 1] = {
            id = id, name = t.name, effect = t.effect,
            gems = t.gems or 0, owned = isOwned(player, id),
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    player:sendExtendedOpcode(OPCODE_TRAILS, json.encode({
        gems = getGems(player), active = active, trails = list,
    }))
end

function onLogin(player)
    player:registerEvent("PlayerTrailsOpcode")
    return true
end

function onExtendedOpcode(player, opcode, buffer)
    if opcode ~= OPCODE_TRAILS then return false end
    if not json then return false end

    local ok, data = pcall(function() return json.decode(buffer) end)
    if not ok or type(data) ~= "table" then return false end

    if data.action == "open" then
        sendState(player)

    elseif data.action == "buy" then
        local id = tonumber(data.id)
        local t = id and TRAILS[id]
        if not t then return true end
        if isOwned(player, id) then
            sendState(player); return true
        end
        local cost = t.gems or 0
        if not removeGems(player, cost) then
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED,
                string.format("Voce precisa de %d gems pra comprar o trail %s.", cost, t.name))
            return true
        end
        player:setStorageValue(STORAGE_TRAIL_OWNED + id, 1)
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Trail comprado: " .. t.name .. "!")
        sendState(player)

    elseif data.action == "use" then
        local id = tonumber(data.id) or 0
        if id == 0 then
            player:setStorageValue(STORAGE_TRAIL_KEY, 0)
        elseif TRAILS[id] and isOwned(player, id) then
            player:setStorageValue(STORAGE_TRAIL_KEY, id)
        else
            sendState(player); return true
        end
        sendState(player)
    end

    return true
end
