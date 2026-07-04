-- ============================================================
--  /setlevel  — TESTE: add/remove/seta o LEVEL (via experiencia)
--  Alvo opcional: "nome, ..." mira outro player; sem nome = voce.
--  Uso:
--    /setlevel 300        -> vai pro level 300
--    /setlevel +10 | -10  -> sobe / desce 10 levels
--  Ao mudar, reaplica a TRANSFORMACAO por level na hora (outfits.lua).
--  Obs: descer level mostra a janela de relogin (comportamento do engine).
-- ============================================================

local function parseTarget(self, param)
    local name, val = param:match("^(.-)%s*,%s*(.+)$")
    if name and name ~= "" then
        local t = Player(name)
        if not t then return nil, nil, ("Player '%s' offline."):format(name) end
        return t, val
    end
    return self, param
end

local function calcLevel(cur, val)
    val = (val or ""):lower():gsub("%s+", "")
    if val == "" then return nil end
    if val:sub(1, 1) == "+" then return cur + (tonumber(val:sub(2)) or 1) end
    if val:sub(1, 1) == "-" then return cur - (tonumber(val:sub(2)) or 1) end
    return tonumber(val)
end

-- EXATAMENTE a formula do server (Player::getExpForLevel em player.h):
-- (((lv-6)*lv + 17)*lv - 12) / 6 * 100  (divisao inteira no /6, dps *100)
local function getExpForLevel(level)
    return math.floor((((level - 6) * level + 17) * level - 12) / 6) * 100
end

local function setLevel(target, level)
    level = math.max(1, math.floor(level))
    local cur = target:getLevel()
    if level == cur then return level end
    -- NEUTRALIZA os eventos de exp durante o ajuste, senao o onGainExperience
    -- (player.lua) zera a exp p/ quem tem flag anti-multicliente (storage 20100)
    -- ou multiplica por 1.05 (stream, storage 20000) -> add nao bate o alvo.
    local s201 = target:getStorageValue(20100)
    local s200 = target:getStorageValue(20000)
    target:setStorageValue(20100, 0)
    target:setStorageValue(20000, 0)
    if level > cur then
        target:addExperience(getExpForLevel(level) - target:getExperience(), false) -- dispara onAdvance
    else
        target:removeExperience(target:getExperience() - getExpForLevel(level))      -- refresh manual depois
    end
    target:setStorageValue(20100, s201)  -- restaura os flags
    target:setStorageValue(20000, s200)
    return level
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

    local newLevel = calcLevel(target:getLevel(), val)
    if not newLevel then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, "Use: /setlevel [nome,] <N | +N | -N>")
        return false
    end

    newLevel = setLevel(target, newLevel)
    -- reaplica a transformacao certa pro novo level (sobe e desce)
    if applyVocationTransform then
        pcall(function() applyVocationTransform(target, false) end)
    end

    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format(
        "[SetLevel] %s -> level %d.", target:getName(), target:getLevel()))
    return false
end
