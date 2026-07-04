-- ============================================================
--  /herokeys  — TESTE: add/remove KEYS (50002) ou GEMS (50001)
--  Alvo opcional: "nome, ..." mira outro player; sem nome = voce.
--  Uso:
--    /herokeys 10            -> seta keys = 10
--    /herokeys +5 | -5       -> add / remove 5 keys
--    /herokeys clear         -> zera keys
--    /herokeys gems 10       -> seta gems = 10
--    /herokeys gems +5 | -5  -> add / remove gems
--    /herokeys Fulano, +5    -> +5 keys no "Fulano"
-- ============================================================

local STORAGE_KEYS = 50002
local STORAGE_GEMS = 50001

local function parseTarget(self, param)
    local name, val = param:match("^(.-)%s*,%s*(.+)$")
    if name and name ~= "" then
        local t = Player(name)
        if not t then return nil, nil, ("Player '%s' offline."):format(name) end
        return t, val
    end
    return self, param
end

local function calcValue(cur, val)
    val = (val or ""):lower():gsub("%s+", "")
    if val == "" or val == "clear" then return 0 end
    if val:sub(1, 1) == "+" then return cur + (tonumber(val:sub(2)) or 1) end
    if val:sub(1, 1) == "-" then return cur - (tonumber(val:sub(2)) or 1) end
    return tonumber(val)
end

function onSay(player, words, param)
    local isStaff = false
    pcall(function() isStaff = player:getGroup():getAccess() end)
    if not isStaff then return false end

    local target, rest, err = parseTarget(player, (param or ""):trim())
    if not target then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, err)
        return false
    end

    -- "gems ..." muda pra storage de gems
    local storage, label = STORAGE_KEYS, "keys"
    local g = rest:match("^[gG][eE][mM][sS]%s+(.+)$")
    if g then storage, label, rest = STORAGE_GEMS, "gems", g end

    local cur = math.max(0, target:getStorageValue(storage))
    local newVal = calcValue(cur, rest)
    if not newVal then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED,
            "Use: /herokeys [nome,] [gems] <N | clear | +N | -N>")
        return false
    end

    newVal = math.max(0, math.floor(newVal))
    target:setStorageValue(storage, newVal)

    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format(
        "[HeroKeys] %s: %s = %d.", target:getName(), label, newVal))
    if target ~= player then
        target:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format(
            "Seus %s foram ajustados para %d.", label, newVal))
    end
    return false
end
