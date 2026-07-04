-- ============================================================
--  /herostars  — TESTE: seta as estrelas (level interno) do HEROI ATIVO
--  Alvo opcional: "nome, valor" mira outro player; sem nome = voce mesmo.
--  Uso:
--    /herostars max            -> level interno 23 (lenda 5 = 20 estrelas/fases)
--    /herostars 0 | clear      -> zera
--    /herostars 12             -> level interno 12 (ouro 0 = 10 fases)
--    /herostars +1 | -1        -> evolui / regride 1 (interno)
--    /herostars Fulano, max    -> mira o player "Fulano"
--  level interno: 0..23 (4 tiers x 6 estados). fases que CONTAM: 0..20.
-- ============================================================

local STORAGE_STARS  = 50200
local MAX_STARS      = 23
local STARS_PER_TIER = 5
local TIER_SPAN      = STARS_PER_TIER + 1  -- 6

local function evoStars(level)
    if level < 0 then level = 0 end
    return math.floor(level / TIER_SPAN) * STARS_PER_TIER + (level % TIER_SPAN)
end

-- "nome, valor" -> player alvo + valor; senao = self
local function parseTarget(self, param)
    local name, val = param:match("^(.-)%s*,%s*(.+)$")
    if name and name ~= "" then
        local t = Player(name)
        if not t then return nil, nil, ("Player '%s' offline."):format(name) end
        return t, val
    end
    return self, param
end

-- aplica max/clear/N/+N/-N sobre o valor atual
local function calcValue(cur, val)
    val = (val or ""):lower():gsub("%s+", "")
    if val == "max" then return MAX_STARS end
    if val == "" or val == "clear" then return 0 end
    if val:sub(1, 1) == "+" then return cur + (tonumber(val:sub(2)) or 1) end
    if val:sub(1, 1) == "-" then return cur - (tonumber(val:sub(2)) or 1) end
    return tonumber(val)
end

function onSay(player, words, param)
    local isStaff = false
    pcall(function() isStaff = player:getGroup():getAccess() end)
    if not isStaff then return false end

    local target, val, err = parseTarget(player, (param or ""):trim())
    if not target then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, err)
        return false
    end

    local vocId = target:getVocation():getId()
    local cur = math.max(0, target:getStorageValue(STORAGE_STARS + vocId))
    local newVal = calcValue(cur, val)
    if not newVal then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED,
            "Use: /herostars [nome,] <0-23 | max | clear | +N | -N>")
        return false
    end

    newVal = math.max(0, math.min(MAX_STARS, math.floor(newVal)))
    target:setStorageValue(STORAGE_STARS + vocId, newVal)
    if heroesReapplyBonuses then heroesReapplyBonuses(target) end

    local fases = evoStars(newVal)
    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format(
        "[HeroStars] %s (voc %d): level interno=%d | estrelas que contam=%d | bonus ~+%d%%.",
        target:getName(), vocId, newVal, fases, fases))
    if target ~= player then
        target:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format(
            "Suas estrelas foram ajustadas: %d que contam (+%d%%).", fases, fases))
    end
    return false
end
