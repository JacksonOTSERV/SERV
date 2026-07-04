-- ============================================================
--  PERSONAGENS (HEROES) — baseado nas VOCATIONS reais (vocations.xml)
--  Troca de personagem = troca de vocacao (setVocation) + outfit base.
--  Opcode: 101 | Cliente: modules/game_heroes
-- ============================================================

local OPCODE = 101

-- storages
local STORAGE_STARS = 50200   -- base: STORAGE_STARS + vocId = nivel de evolucao (0-5)
local STORAGE_OWNED = 50100   -- base: STORAGE_OWNED + vocId = 1 se desbloqueado
local STORAGE_SKIN  = 50300   -- base: STORAGE_SKIN + vocId = skin cosmetica equipada (1=padrao)
local STORAGE_SKIN_OWNED = 50600  -- base + vocId*100 + skinIdx = 1 se a skin esta desbloqueada
local STORAGE_GEMS  = 50700   -- fallback local de gems (se DB premium_points falhar)

-- ============================================================
--  EVOLUCAO (estrelas)
-- ============================================================
-- evoluir custa DINHEIRO (gold) + COINS (item especial). Custo cresce por nivel.
local EVOLVE_GOLD_BASE = 1800   -- gold base por nivel (1800, 3600, 5400...)
local EVOLVE_COIN_ITEM = 2160   -- item de coin pra evoluir (TROQUE pelo seu item)
local EVOLVE_COIN_BASE = 10     -- qtd de coins base por nivel (10, 20, 30...)
-- 4 tiers (bronze/prata/ouro/lenda), 6 estados cada (0..5 estrelas) = level 0..23.
-- Ao completar 5 de um tier, o proximo evolve ENTRA no tier seguinte em 0 estrelas
-- (transicao - NAO conta como estrela/bonus). So a partir da 1a estrela do novo
-- tier conta. Por isso o BONUS e a CONTAGEM usam "fases" (evoStars, 0..20),
-- que ignoram os estados "0" de transicao. Level interno 0..23 = 0..20 fases.
local STARS_PER_TIER = 5
local MAX_TIERS      = 4
local MAX_STARS      = MAX_TIERS * (STARS_PER_TIER + 1) - 1  -- 23 interno (= 20 fases)

-- ============================================================
--  OBS: as TRANSFORMACOES (forms por level) NAO ficam aqui. Sao tratadas
--  pelo sistema oficial em data/creaturescripts/scripts/custom/outfits.lua
--  (config vocationOutfits em data/lib/custom/outfits.lua), que troca o outfit
--  automaticamente por level e da o bonus de Ki (ml). Aqui so cuidam SKINS
--  cosmeticas e EVOLUCAO (estrelas).
-- ============================================================

-- ============================================================
--  SKINS COSMETICAS por personagem — janela "Mudar roupa".
--  NAO dao bonus; so trocam a aparencia. Desbloqueia com gold OU gems.
--  A 1a e' SEMPRE "Padrao" (gratis, segue a transformacao do level).
--  Cada skin = { name, look, gold, gems }. look=0 na Padrao (usa a form).
-- ============================================================
local VOC_SKINS = {
    [1] = { -- Goku
        { name = "Padrao",     look = 0,   gold = 0,      gems = 0  }, -- segue a transformacao
        { name = "SSJ Blue",   look = 807, gold = 500000, gems = 25 },
        { name = "Black Rose", look = 651, gold = 800000, gems = 40 },
    },
}

-- ============================================================
--  CLASSE de cada personagem (define o bonus por estrela)
--  "tank" = vida + % dodge | "damage" = % dano | "support" = mana
--  Default = "damage". Preencha conforme seu balanceamento.
-- ============================================================
local VOC_CLASS = {
    -- [vocId] = "tank" | "damage" | "support"
    [1] = "damage", -- Goku
    [2] = "tank",   -- Vegeta (teste: +vida e +% dodge por fase)
}

-- bonus POR FASE (estrela visivel acumulada), por classe.
-- 4 tiers x 5 fases = 20 fases no maximo. Ex: damage 1% x 20 = 20% no topo.
local CLASS_BONUS = {
    tank    = { health = 50000, dodge = 3 }, -- +100 vida e +1% dodge por fase
    damage  = { health = 10000, damage = 1 },              -- +1% de dano por fase (20% no max)
    support = { mana = 80 },               -- +80 mana por fase
}

-- storages dos bonus do personagem ATIVO (lidos pelos seus scripts de combate)
local STORAGE_BONUS_DAMAGE = 50400  -- % de dano extra
local STORAGE_BONUS_DODGE  = 50401  -- % de chance de dodge
local HERO_COND_SUBID      = 9911   -- subid da condicao de vida/mana do hero

-- ============================================================
--  PERSONAGENS = vocations 1..N. looktype base de cada um (Form 1),
--  extraido do outfits.xml. Edite aqui se quiser outro outfit/ordem.
-- ============================================================
local HERO_VOCS = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25}

local VOC_LOOKTYPE = {
    [1]  = 1118, -- Goku
    [2]  = 918,  -- Vegeta
    [3]  = 33,   -- Piccolo
    [4]  = 46,   -- C17
    [5]  = 55,   -- Gohan
    [6]  = 906,  -- Trunks
    [7]  = 778,  -- Cell
    [8]  = 794,  -- Freeza
    [9]  = 857,  -- Buu
    [10] = 1117, -- Broly
    [11] = 135,  -- Goten
    [12] = 200,  -- Kuririn
    [13] = 987,  -- Janemba
    [14] = 1211, -- Tapion
    [15] = 1155, -- Chilled
    [16] = 1163, -- Kagome
    [17] = 1229, -- Zaiko
    [18] = 1180, -- King Vegeta
    [19] = 1217, -- Vegetto
    [20] = 1175, -- Kame
    [21] = 1197, -- Shenron
    [22] = 219,  -- Kaioh
    [23] = 651,  -- Goku Black
    [24] = 1110, -- Zamasu
    [25] = 1001, -- Jiren
}

-- Nome do arquivo de avatar por vocacao (data/images/avatars/<x>.png e
-- data/images/avatars_mini/<x>.png). Se o arquivo nao existir, o cliente
-- mostra o outfit (fallback). Default = nome em minusculo sem espacos.
local VOC_AVATAR = {
    -- vocId = arte (data/images/avatars + avatars_mini). Trocar livremente.
    [1]  = "ace",        -- Goku
    [2]  = "akainu",     -- Vegeta
    [3]  = "aokiji",     -- Piccolo
    [4]  = "arlong",     -- C17
    [5]  = "blackbeard", -- Gohan
    [6]  = "brook",      -- Trunks
    [7]  = "buggy",      -- Cell
    [8]  = "chopper",    -- Freeza
    [9]  = "crocodile",  -- Buu
    [10] = "doflamingo", -- Broly
    [11] = "enel",       -- Goten
    [12] = "franky",     -- Kuririn
    [13] = "garp",       -- Janemba
    [14] = "hancock",    -- Tapion
    [15] = "jinbe",      -- Chilled
    [16] = "kid",        -- Kagome
    [17] = "killer",     -- Zaiko
    [18] = "kizaru",     -- King Vegeta
    [19] = "koala",      -- Vegetto
    [20] = "krieg",      -- Kame
    [21] = "bartolomeo", -- Shenron
    [22] = "bonney",     -- Kaioh
    [23] = "carrot",     -- Goku Black
    [24] = "drake",      -- Zamasu
    [25] = "hawkins",    -- Jiren
}

local function sanitizeName(name)
    return string.lower((name:gsub("%s+", "")))
end

-- Se true, TODOS os personagens ficam liberados (troca livre).
-- Se false, so o personagem ATUAL do player + os com storage OWNED=1.
local ALL_UNLOCKED = true

local json = nil
pcall(function() json = dofile("data/lib/json.lua") end)

-- ============================================================
--  HELPERS
-- ============================================================
local function safe(fn)
    local ok, v = pcall(fn)
    if ok then return v end
    return nil
end

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
    if not ok then
        player:setStorageValue(STORAGE_GEMS, math.max(0, cur - amount))
    end
    return true
end

-- monta dados de uma vocacao (nome + stats reais)
local function getVocData(vocId)
    local voc = Vocation(vocId)
    if not voc then return nil end
    local name = safe(function() return voc:getName() end)
    if not name or name == "" or name == "None" then return nil end
    return {
        name     = name,
        health   = safe(function() return voc:getHealthGain() end) or 0,
        ki       = safe(function() return voc:getManaGain() end) or 0,
        capacity = safe(function() return voc:getCapacityGain() end) or 0,
        speed    = safe(function() return voc:getBaseSpeed() end) or 0,
    }
end

local function getActiveVoc(player)
    local voc = player:getVocation()
    return voc and voc:getId() or 0
end

local function ownsHero(player, vocId)
    if ALL_UNLOCKED then return true end
    if getActiveVoc(player) == vocId then return true end
    return player:getStorageValue(STORAGE_OWNED + vocId) == 1
end

local function getStars(player, vocId)
    return math.max(0, player:getStorageValue(STORAGE_STARS + vocId))
end

-- converte o LEVEL interno (0..23) em FASES/estrelas que CONTAM (0..20).
-- Ignora o estado "0" de cada tier (transicao). Ex: bronze5(5)=5, prata0(6)=5,
-- prata1(7)=6, ..., lenda5(23)=20. Usado p/ bonus E p/ a contagem mostrada.
local TIER_SPAN = STARS_PER_TIER + 1  -- 6 (0..5)
local function evoStars(level)
    if level < 0 then level = 0 end
    return math.floor(level / TIER_SPAN) * STARS_PER_TIER + (level % TIER_SPAN)
end

local function getClass(vocId)
    return VOC_CLASS[vocId] or "damage"
end

-- ----- TRANSFORMACAO ATUAL (looktype base) -----
-- O look "Padrao" segue a TRANSFORMACAO por level (sistema oficial), NUNCA a
-- skin cosmetica equipada. Calcula a forma mais alta liberada pelo level a
-- partir do vocationOutfits (lib/custom/outfits.lua); fallback p/ VOC_LOOKTYPE.
local function getBaseLook(player, vocId)
    local nm = (getVocData(vocId) or {}).name
    local outfits = nm and rawget(_G, "vocationOutfits") and _G.vocationOutfits[nm]
    if outfits then
        local lvl = player:getLevel()
        local bestId, bestLevel = nil, nil
        for level, data in pairs(outfits) do
            if lvl >= level and (not bestLevel or level > bestLevel) then
                bestLevel = level
                bestId = data.id
            end
        end
        if bestId then return bestId end
    end
    return VOC_LOOKTYPE[vocId]
end

-- ----- SKINS COSMETICAS -----
-- skin equipada (1 = Padrao = segue a transformacao)
local function getSkinIndex(player, vocId)
    local v = player:getStorageValue(STORAGE_SKIN + vocId)
    return v > 1 and v or 1
end

local function isSkinUnlocked(player, vocId, idx)
    if idx <= 1 then return true end  -- Padrao sempre liberada
    return player:getStorageValue(STORAGE_SKIN_OWNED + vocId * 100 + idx) == 1
end

-- looktype final: skin cosmetica equipada (se liberada) OU a transformacao
local function getLooktype(player, vocId)
    local sidx = getSkinIndex(player, vocId)
    local skins = VOC_SKINS[vocId]
    if sidx > 1 and skins and skins[sidx] and skins[sidx].look > 0
       and isSkinUnlocked(player, vocId, sidx) then
        return skins[sidx].look
    end
    return getBaseLook(player, vocId)
end

-- true se o personagem ATIVO tem uma skin cosmetica equipada (e liberada).
-- Usado pelo outfits.lua p/ NAO sobrescrever o look com a transformacao.
function heroesHasCosmeticSkin(player)
    local vocId = getActiveVoc(player)
    if not vocId or vocId == 0 then return false end
    local sidx = getSkinIndex(player, vocId)
    local skins = VOC_SKINS[vocId]
    return sidx > 1 and skins ~= nil and skins[sidx] ~= nil
           and (skins[sidx].look or 0) > 0 and isSkinUnlocked(player, vocId, sidx)
end

-- true se `look` e' o looktype da SKIN cosmetica equipada no personagem ATIVO.
-- Usado pelo onChangeOutfit (events/creature.lua) p/ NAO tratar a skin como
-- transformacao (sem bonus de Ki, sem mensagem).
function heroesIsSkinLook(player, look)
    local vocId = getActiveVoc(player)
    if not vocId or vocId == 0 or not look then return false end
    local sidx = getSkinIndex(player, vocId)
    if sidx <= 1 then return false end
    local skins = VOC_SKINS[vocId]
    local sk = skins and skins[sidx]
    return sk ~= nil and (sk.look or 0) == look and isSkinUnlocked(player, vocId, sidx)
end

-- aplica bonus de evolucao: vida/mana via condicao permanente;
-- dano/dodge gravados em storage p/ os scripts de combate lerem.
-- bonus de EVOLUCAO (estrelas) por classe. NAO inclui transformacao (= outfits.lua).
local function applyHeroBonuses(player, vocId)
    local stars = evoStars(getStars(player, vocId))  -- fases que contam (0..20)
    local b = CLASS_BONUS[getClass(vocId)] or {}

    player:removeCondition(CONDITION_ATTRIBUTES, CONDITIONID_COMBAT, HERO_COND_SUBID)
    local hp = (b.health or 0) * stars
    local mp = (b.mana or 0) * stars
    if hp > 0 or mp > 0 then
        local cond = Condition(CONDITION_ATTRIBUTES)
        cond:setParameter(CONDITION_PARAM_SUBID, HERO_COND_SUBID)
        cond:setParameter(CONDITION_PARAM_TICKS, -1)
        if hp > 0 then cond:setParameter(CONDITION_PARAM_STAT_MAXHITPOINTS, hp) end
        if mp > 0 then cond:setParameter(CONDITION_PARAM_STAT_MAXMANAPOINTS, mp) end
        player:addCondition(cond)
    end

    player:setStorageValue(STORAGE_BONUS_DAMAGE, (b.damage or 0) * stars)
    player:setStorageValue(STORAGE_BONUS_DODGE,  (b.dodge or 0) * stars)
end

-- aplica o looktype atual (skin equipada OU transformacao) no player
local function applyLooktype(player, vocId)
    local lt = getLooktype(player, vocId)
    if lt then
        local o = player:getOutfit()
        o.lookType = lt
        player:setOutfit(o)
    end
end

-- aplica o personagem: troca vocacao + outfit + bonus de evolucao (estrelas).
-- A TRANSFORMACAO por level (outfit oficial + bonus de Ki) e' aplicada pelo
-- sistema oficial; chamamos applyVocationTransform (outfits.lua) se existir.
local function applyHero(player, vocId)
    player:setVocation(vocId)
    -- aplica a transformacao oficial da nova vocacao (outfit + ml) por level
    if type(applyVocationTransform) == "function" then
        safe(function() applyVocationTransform(player, true) end)
    end
    -- se o player tem uma skin cosmetica equipada, ela sobrepoe o look
    if getSkinIndex(player, vocId) > 1 then
        applyLooktype(player, vocId)
    end
    applyHeroBonuses(player, vocId)
    return true
end

-- global: reaplica os bonus de EVOLUCAO (estrelas) do personagem ATIVO no login
-- (a condicao de vida/mana nao sobrevive ao logout). A transformacao/ml e'
-- reaplicada pelo proprio outfits.lua (OutfitsLogin).
function heroesReapplyBonuses(player)
    local vocId = getActiveVoc(player)
    if vocId and vocId > 0 then
        applyHeroBonuses(player, vocId)
    end
end

-- ============================================================
--  PROTOCOLO
-- ============================================================
local function sendList(player)
    if not json then return end
    local active = getActiveVoc(player)
    local list = {}
    for _, vocId in ipairs(HERO_VOCS) do
        local d = getVocData(vocId)
        if d then
            local stars  = getStars(player, vocId)        -- level interno (0..23) p/ display
            local phases = evoStars(stars)                 -- fases que contam (0..20) p/ bonus
            local cb = CLASS_BONUS[getClass(vocId)] or {}
            list[#list + 1] = {
                id     = vocId,
                name   = d.name,
                avatar = VOC_AVATAR[vocId] or sanitizeName(d.name),
                outfit = { type = getLooktype(player, vocId) },
                stats  = {
                    damage = (cb.damage or 0) * phases,   -- % de dano (1% x fase)
                    dodge  = (cb.dodge or 0) * phases,    -- % de esquiva (por fase)
                    health = player:getMaxHealth(),       -- vida TOTAL do player
                    speed  = player:getSpeed(),           -- velocidade TOTAL do player
                },
                owned  = ownsHero(player, vocId),
                stars  = stars,
                maxStars = MAX_STARS,
                class  = getClass(vocId),
                skins  = (VOC_SKINS[vocId] and #VOC_SKINS[vocId]) or 1,
                count  = 1,
            }
        end
    end

    player:sendExtendedOpcode(OPCODE, json.encode({
        action = "list",
        active = active,
        heroes = list,
    }))
end

local function sendError(player, msg)
    if not json then return end
    player:sendExtendedOpcode(OPCODE, json.encode({ action = "error", message = msg }))
end

-- envia a lista de SKINS COSMETICAS de um personagem (janela "Mudar roupa")
local function sendSkins(player, vocId)
    if not json then return end
    local d = getVocData(vocId)
    local skins = VOC_SKINS[vocId] or {}
    local cur = getSkinIndex(player, vocId)
    local list = {}
    for i, sk in ipairs(skins) do
        -- look de preview: Padrao usa o look base/atual; senao a skin
        local look = (i == 1 or not sk.look or sk.look == 0) and getBaseLook(player, vocId) or sk.look
        list[#list + 1] = {
            idx      = i,
            name     = sk.name or ("Skin " .. i),
            outfit   = { type = look },
            gold     = sk.gold or 0,
            gems     = sk.gems or 0,
            unlocked = isSkinUnlocked(player, vocId, i),
            equipped = (i == cur),
        }
    end
    player:sendExtendedOpcode(OPCODE, json.encode({
        action = "skins",
        id     = vocId,
        name   = d and d.name or "",
        gold   = player:getMoney(),
        gems   = getGems(player),
        skins  = list,
    }))
end

function onExtendedOpcode(player, opcode, buffer)
    if opcode ~= OPCODE then return false end
    if not json then return false end

    local ok, data = pcall(function() return json.decode(buffer) end)
    if not ok or type(data) ~= "table" then return false end

    if data.action == "open" then
        sendList(player)

    elseif data.action == "select" then
        local id = tonumber(data.id)
        if not id or not getVocData(id) then
            sendError(player, "Personagem invalido.")
            return true
        end
        if not ownsHero(player, id) then
            sendError(player, "Voce nao possui esse personagem.")
            return true
        end
        applyHero(player, id)
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Agora voce esta usando: " .. getVocData(id).name .. "!")
        sendList(player)

    elseif data.action == "evolve" then
        local id = tonumber(data.id)
        if not id or not getVocData(id) then
            sendError(player, "Personagem invalido.")
            return true
        end
        if not ownsHero(player, id) then
            sendError(player, "Voce nao possui esse personagem.")
            return true
        end
        local stars = getStars(player, id)
        if stars >= MAX_STARS then
            sendError(player, "Personagem ja esta no maximo de estrelas.")
            return true
        end
        local mult = stars + 1
        local goldCost = EVOLVE_GOLD_BASE * mult
        local coinCost = EVOLVE_COIN_BASE * mult
        local coinName = ItemType(EVOLVE_COIN_ITEM):getName()
        local hasGold  = player:getMoney() >= goldCost
        local hasCoins = player:getItemCount(EVOLVE_COIN_ITEM) >= coinCost
        if not hasGold or not hasCoins then
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, string.format(
                "Pra evoluir %s voce precisa de %d gold + %d %s.",
                getVocData(id).name, goldCost, coinCost, coinName))
            return true
        end
        player:removeMoney(goldCost)
        player:removeItem(EVOLVE_COIN_ITEM, coinCost)
        player:setStorageValue(STORAGE_STARS + id, stars + 1)
        -- se for o personagem ativo, reaplica os bonus na hora
        if getActiveVoc(player) == id then
            applyHeroBonuses(player, id)
        end
        local newLevel = stars + 1
        local nm = getVocData(id).name
        if newLevel % TIER_SPAN == 0 then
            -- transicao: entrou no proximo tier em 0 estrelas (NAO conta estrela)
            player:sendTextMessage(MESSAGE_EVENT_ADVANCE,
                nm .. " avancou de tier! (continua com " .. evoStars(newLevel) .. " estrelas)")
        else
            player:sendTextMessage(MESSAGE_EVENT_ADVANCE,
                nm .. " evoluiu para " .. evoStars(newLevel) .. " estrelas!")
        end

        -- PROMOCAO DE CLASSE: ao ENTRAR no tier LEGEND, sobe TODOS os personagens
        -- da mesma classe pro maximo (legend). Acontece uma vez (na entrada).
        local LEGEND_TIER = MAX_TIERS - 1                      -- 3 (bronze0..legend3)
        local oldTier = math.floor(stars    / TIER_SPAN)
        local newTier = math.floor(newLevel / TIER_SPAN)
        if newTier >= LEGEND_TIER and oldTier < LEGEND_TIER then
            local cls = getClass(id)
            local promoted = 0
            for _, vid in ipairs(HERO_VOCS) do
                if getClass(vid) == cls and getStars(player, vid) < MAX_STARS then
                    player:setStorageValue(STORAGE_STARS + vid, MAX_STARS)
                    if getActiveVoc(player) == vid then applyHeroBonuses(player, vid) end
                    promoted = promoted + 1
                end
            end
            player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format(
                "Classe %s alcancou LEGEND! %d personagem(s) da classe foram maximizados.",
                cls, promoted))
        end

        sendList(player)

    -- abre a janela de skins cosmeticas do personagem
    elseif data.action == "skins-open" then
        local id = tonumber(data.id)
        if not id or not getVocData(id) then
            sendError(player, "Personagem invalido.")
            return true
        end
        if not ownsHero(player, id) then
            sendError(player, "Voce nao possui esse personagem.")
            return true
        end
        sendSkins(player, id)

    -- desbloqueia uma skin pagando com gold OU gems (premium points)
    elseif data.action == "skin-unlock" then
        local id  = tonumber(data.id)
        local idx = tonumber(data.idx)
        local cur = data.currency  -- "gold" | "gems"
        local skins = id and VOC_SKINS[id]
        if not skins or not idx or not skins[idx] then
            sendError(player, "Skin invalida.")
            return true
        end
        if isSkinUnlocked(player, id, idx) then
            sendError(player, "Voce ja possui essa skin.")
            return true
        end
        local sk = skins[idx]
        if cur == "gems" then
            local cost = sk.gems or 0
            if cost <= 0 then sendError(player, "Essa skin nao pode ser comprada com gems.") return true end
            if not removeGems(player, cost) then
                sendError(player, string.format("Voce precisa de %d gems pra liberar %s.", cost, sk.name))
                return true
            end
        else
            local cost = sk.gold or 0
            if cost <= 0 then sendError(player, "Essa skin nao pode ser comprada com gold.") return true end
            if player:getMoney() < cost then
                sendError(player, string.format("Voce precisa de %d gold pra liberar %s.", cost, sk.name))
                return true
            end
            player:removeMoney(cost)
        end
        player:setStorageValue(STORAGE_SKIN_OWNED + id * 100 + idx, 1)
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Skin liberada: " .. (sk.name or "") .. "!")
        sendSkins(player, id)
        sendList(player)

    -- equipa uma skin ja desbloqueada (ou volta pra Padrao)
    elseif data.action == "skin-equip" then
        local id  = tonumber(data.id)
        local idx = tonumber(data.idx)
        local skins = id and VOC_SKINS[id]
        if not skins or not idx or not skins[idx] then
            sendError(player, "Skin invalida.")
            return true
        end
        if not isSkinUnlocked(player, id, idx) then
            sendError(player, "Essa skin ainda esta bloqueada.")
            return true
        end
        player:setStorageValue(STORAGE_SKIN + id, idx)
        -- se for o personagem ativo, troca o outfit agora
        if getActiveVoc(player) == id then
            applyLooktype(player, id)
        end
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE,
            idx == 1 and "Skin padrao equipada." or ("Skin equipada: " .. (skins[idx].name or "") .. "!"))
        sendSkins(player, id)
        sendList(player)
    end

    return true
end
