-- data/creaturescripts/scripts/others/gameshop_opcode.lua
-- Servidor do Game Shop para OTCv8
-- Opcode: 85
-- Storages: 50001 = Gems | 50002 = Chaves (Keys)

local OPCODE            = 85
local STORAGE_GEMS      = 50001
local STORAGE_KEYS      = 50002

-- ============================================================
--  CONFIGURAÇÃO DO SHOP
--  Edite esta tabela para adicionar/remover itens da loja.
-- ============================================================
local SHOP_ITEMS = {
    -- SERVICES
    {
        uid = 1, type = "service", name = "Blessing Full", price = 50, desc = "Receba todas as blessings instantaneamente.",
        image = "blessing",
        action = function(player)
            for i = 1, 5 do player:addBlessing(i) end
            player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Voce recebeu todas as blessings!")
        end
    },
    {
        uid = 2, type = "service", name = "Stamina Full", price = 100, desc = "Recupera toda a sua stamina.",
        image = "stamina",
        action = function(player)
            player:setStamina(2520) -- 42h = max
            player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Stamina restaurada!")
        end
    },
    {
        uid = 3, type = "service", name = "Resetar Skills", price = 200, desc = "Reseta seus pontos de skill.",
        image = "skillreset",
        action = function(player)
            -- Exemplo: envia mensagem (implemente a logica de reset aqui)
            player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Seus skills foram resetados!")
        end
    },

    -- PACKAGES
    {
        uid = 10, type = "package", name = "Pacote Iniciante", price = 150, desc = "Kit inicial com itens essenciais.",
        image = "package_starter",
        action = function(player)
            player:addItem(2160, 100)  -- gold coins exemplo
            player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Voce recebeu o Pacote Iniciante!")
        end
    },
    {
        uid = 11, type = "package", name = "Pacote Premium", price = 500, desc = "Kit premium com itens exclusivos.",
        image = "package_premium",
        action = function(player)
            player:addItem(2160, 1000) -- gold coins exemplo
            player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Voce recebeu o Pacote Premium!")
        end
    },

    -- COSTUMES
    {
        uid = 20, type = "costume", name = "Outfit Especial", price = 300, desc = "Um outfit exclusivo do shop.",
        image = "outfit_special",
        action = function(player)
            -- player:addOutfit(xxxxx) -- adicione o ID do outfit aqui
            player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Voce recebeu o Outfit Especial!")
        end
    },

    -- SHIPS (exemplo)
    {
        uid = 30, type = "ship", name = "Navio Vanguard", price = 1000, desc = "Um navio rapido e resistente.",
        image = "ship_vanguard",
        action = function(player)
            player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Voce recebeu o Navio Vanguard!")
        end
    },
}

-- ============================================================
--  CONFIGURAÇÃO DAS ROTAÇÕES DE BAÚS (Characters)
--  Cada rotação é uma lista de personagens (nomes de imagem).
-- ============================================================
local CHEST_ROTATIONS = {
    -- Rotação 1
    {"luffy", "zoro", "nami"},
    -- Rotação 2 (custom)
    {"sanji", "robin", "chopper"},
}

local CHEST_TIERS = {
    luffy   = "S",
    zoro    = "A",
    nami    = "B",
    sanji   = "A",
    robin   = "B",
    chopper = "C",
}

-- Custo em keys para abrir 1 bau
local KEY_COST = 1

-- Recompensas de shards ao abrir bau (por personagem)
local SHARD_REWARDS = {
    normal = {min = 5,  max = 20},
    S      = {min = 15, max = 30},
    A      = {min = 10, max = 20},
    B      = {min = 5,  max = 15},
    C      = {min = 3,  max = 10},
}

-- Pity: a cada X chaves gastas no mesmo bau, garante 1 personagem escolhido
local PITY_MAX = {
    ["0"] = 30,   -- bau fixo (todos): 30 chaves
    ["1"] = 20,   -- rotacao 1: 20 chaves
    ["2"] = 20,   -- rotacao 2: 20 chaves
}

-- ============================================================
--  HELPERS
-- ============================================================
local json = nil
pcall(function() json = dofile("data/lib/json.lua") end)
if not json then
    print("[GameShop] ERRO: Nao foi possivel carregar json.lua")
end

local function getGems(player)
    local ok, resultId = pcall(function()
        return db.storeQuery("SELECT `premium_points` FROM `accounts` WHERE `id` = " .. player:getAccountId())
    end)
    if ok and resultId then
        local v = result.getDataInt(resultId, "premium_points")
        result.free(resultId)
        return tonumber(v) or 0
    end
    -- fallback para storage local
    local v = player:getStorageValue(STORAGE_GEMS)
    return v > 0 and v or 0
end

local function setGems(player, amount)
    amount = math.max(0, amount)
    local ok = pcall(function()
        db.query("UPDATE `accounts` SET `premium_points` = " .. amount .. " WHERE `id` = " .. player:getAccountId())
    end)
    if not ok then
        -- fallback para storage local
        player:setStorageValue(STORAGE_GEMS, amount)
    end
end

local function getKeys(player)
    local v = player:getStorageValue(STORAGE_KEYS)
    return v > 0 and v or 0
end

local function setKeys(player, amount)
    player:setStorageValue(STORAGE_KEYS, math.max(0, amount))
end

local function getPityStorage(player, chestId)
    -- Usa um range de storages: 50010 + chestId
    return 50010 + tonumber(chestId)
end

local function getPityCount(player, chestId)
    local v = player:getStorageValue(getPityStorage(player, chestId))
    return v > 0 and v or 0
end

local function setPityCount(player, chestId, count)
    player:setStorageValue(getPityStorage(player, chestId), count)
end

local function getPityReceivedStorage(player, chestId)
    return 50020 + tonumber(chestId)
end

local function hasPityReceived(player, chestId)
    return player:getStorageValue(getPityReceivedStorage(player, chestId)) == 1
end

local function setPityReceived(player, chestId)
    player:setStorageValue(getPityReceivedStorage(player, chestId), 1)
end

local function resetPityReceived(player, chestId)
    player:setStorageValue(getPityReceivedStorage(player, chestId), 0)
end

local function sendToClient(player, data)
    if not json then return end
    player:sendExtendedOpcode(OPCODE, json.encode(data))
end

local function getShardCount(tier)
    local r = SHARD_REWARDS[tier] or SHARD_REWARDS["C"]
    return math.random(r.min, r.max)
end

local function buildPityTable(player)
    local pity = {}
    for chestId, maxPity in pairs(PITY_MAX) do
        local current = getPityCount(player, chestId)
        if hasPityReceived(player, chestId) then
            pity[chestId] = {current = -1, max = maxPity}
        else
            pity[chestId] = {current = current, max = maxPity}
        end
    end
    return pity
end

local function buildRotationList()
    local result = {}
    for i, rotation in ipairs(CHEST_ROTATIONS) do
        local r = {heroes = {}, tiers = {}}
        for _, heroName in ipairs(rotation) do
            table.insert(r.heroes, heroName)
            r.tiers[heroName] = CHEST_TIERS[heroName] or "C"
        end
        table.insert(result, r)
    end
    return result
end

-- ============================================================
--  HANDLERS DE AÇÃO
-- ============================================================

local function handleOpen(player)
    local gems = getGems(player)
    local keys = getKeys(player)
    local items = {}

    for _, item in ipairs(SHOP_ITEMS) do
        table.insert(items, {
            uid   = item.uid,
            type  = item.type,
            name  = item.name,
            price = item.price,
            desc  = item.desc,
            image = item.image,
        })
    end

    sendToClient(player, {
        action = "init",
        gems   = gems,
        keys   = keys,
        items  = items,
    })
end

local function handleItems(player, data)
    local category = data.category or "service"
    local filtered = {}

    for _, item in ipairs(SHOP_ITEMS) do
        if item.type == category then
            table.insert(filtered, {
                uid   = item.uid,
                type  = item.type,
                name  = item.name,
                price = item.price,
                desc  = item.desc,
                image = item.image,
            })
        end
    end

    sendToClient(player, {
        action = "items",
        items  = filtered,
    })
end

local function handleBuy(player, data)
    local uid = tonumber(data.uid)
    if not uid then
        sendToClient(player, {action = "buy-fail", message = "Item invalido."})
        return
    end

    local item = nil
    for _, v in ipairs(SHOP_ITEMS) do
        if v.uid == uid then
            item = v
            break
        end
    end

    if not item then
        sendToClient(player, {action = "buy-fail", message = "Item nao encontrado."})
        return
    end

    local gems = getGems(player)
    if gems < item.price then
        sendToClient(player, {action = "buy-fail", message = "Gemas insuficientes."})
        return
    end

    setGems(player, gems - item.price)

    if item.action then
        item.action(player)
    end

    local newGems = getGems(player)
    sendToClient(player, {
        action = "buy-ok",
        gems   = newGems,
        keys   = getKeys(player),
    })
    -- atualiza o menu de premium points
    player:sendExtendedOpcode(2, json.encode({type = "updatePoints", points = newGems}))
end

local function handleChest(player, data)
    local chestId   = tonumber(data.id) or 0
    local amountKey = tonumber(data.amountKey) or 1

    local keys = getKeys(player)
    local cost = KEY_COST * amountKey

    if keys < cost then
        sendToClient(player, {action = "error", message = "Chaves insuficientes."})
        return
    end

    setKeys(player, keys - cost)

    -- Determina pool de personagens
    local pool = {}
    if chestId == 0 then
        -- Bau fixo: todos os personagens de todas as rotacoes
        for _, rotation in ipairs(CHEST_ROTATIONS) do
            for _, hero in ipairs(rotation) do
                table.insert(pool, hero)
            end
        end
    else
        local rotation = CHEST_ROTATIONS[chestId]
        if rotation then
            for _, hero in ipairs(rotation) do
                table.insert(pool, hero)
            end
        end
    end

    if #pool == 0 then
        sendToClient(player, {action = "error", message = "Sem personagens nesta rotacao."})
        return
    end

    -- Sorteia personagens (1 por chave gasta)
    local characters = {}
    for i = 1, amountKey do
        local hero  = pool[math.random(1, #pool)]
        local tier  = CHEST_TIERS[hero] or "C"
        local count = getShardCount(tier)
        table.insert(characters, {
            heroName    = hero,
            tier        = tier,
            shardsCount = count,
        })
    end

    -- Atualiza pity
    local pityStorage = getPityStorage(player, chestId)
    local currentPity = getPityCount(player, chestId)
    currentPity = currentPity + amountKey
    setPityCount(player, chestId, currentPity)

    -- Verifica pity
    local maxPity = PITY_MAX[tostring(chestId)] or 30
    local pityNow = currentPity

    -- Reseta pity recebido se nova rotação (simplificado: reseta após receber)
    if hasPityReceived(player, chestId) then
        resetPityReceived(player, chestId)
        setPityCount(player, chestId, 0)
    end

    sendToClient(player, {
        action     = "chest",
        keys       = getKeys(player),
        chestId    = chestId,
        characters = characters,
        pity       = math.min(pityNow, maxPity),
    })
end

local function handlePityChest(player, data)
    local chestId       = tonumber(data.id) or 0
    local characterName = data.characterName

    if not characterName then
        sendToClient(player, {action = "error", message = "Personagem nao informado."})
        return
    end

    local currentPity = getPityCount(player, chestId)
    local maxPity     = PITY_MAX[tostring(chestId)] or 30

    if currentPity < maxPity then
        sendToClient(player, {action = "error", message = "Pity ainda nao atingido."})
        return
    end

    if hasPityReceived(player, chestId) then
        sendToClient(player, {action = "error", message = "Pity ja recebido para este bau."})
        return
    end

    -- Concede recompensa
    local tier  = CHEST_TIERS[characterName] or "C"
    local count = SHARD_REWARDS[tier] and math.random(SHARD_REWARDS[tier].min, SHARD_REWARDS[tier].max) or 10

    setPityReceived(player, chestId)
    setPityCount(player, chestId, 0)

    player:sendTextMessage(MESSAGE_EVENT_ADVANCE,
        string.format("Voce recebeu %dx shards de %s como recompensa pity!", count, characterName)
    )

    sendToClient(player, {
        action      = "pity-ok",
        keys        = getKeys(player),
        heroName    = characterName,
        tier        = tier,
        shardsCount = count,
        chestId     = chestId,
    })
end

local function handleRotations(player)
    local rotations = buildRotationList()
    local pity      = buildPityTable(player)

    sendToClient(player, {
        action    = "rotations",
        rotations = rotations,
        pity      = pity,
    })
end

local function handleRequestSales(player)
    -- Personalize o banner de promoção aqui
    sendToClient(player, {
        action = "sales",
        banner = "",  -- URL ou caminho de imagem do banner
    })
end

-- ============================================================
--  ENTRADA DO OPCODE
-- ============================================================

function onExtendedOpcode(player, opcode, buffer)
    if opcode ~= OPCODE then return false end
    if not json then return false end

    local ok, data = pcall(function() return json.decode(buffer) end)
    if not ok or type(data) ~= "table" then
        print("[GameShop] JSON invalido de " .. player:getName() .. ": " .. tostring(buffer))
        return false
    end

    local action = data.action

    if action == "open" then
        handleOpen(player)
    elseif action == "items" then
        handleItems(player, data)
    elseif action == "buy" then
        handleBuy(player, data)
    elseif action == "chest" then
        handleChest(player, data)
    elseif action == "pity-chest" then
        handlePityChest(player, data)
    elseif action == "rotations" then
        handleRotations(player)
    elseif action == "request-sales" then
        handleRequestSales(player)
    elseif action == "get-available-rotation-characters" then
        -- Retorna personagens disponíveis para rotação customizada
        local all = {}
        for _, rotation in ipairs(CHEST_ROTATIONS) do
            for _, hero in ipairs(rotation) do
                table.insert(all, {name = hero, tier = CHEST_TIERS[hero] or "C"})
            end
        end
        sendToClient(player, {action = "rotation-characters", characters = all, maxCharacters = 3})
    else
        print("[GameShop] Acao desconhecida de " .. player:getName() .. ": " .. tostring(action))
    end

    return true
end

function onLogin(player)
    -- Envia saldo de gemas e chaves ao logar
    addEvent(function()
        if player and player:isPlayer() then
            sendToClient(player, {
                action = "currency",
                gems   = getGems(player),
                keys   = getKeys(player),
            })
        end
    end, 1000)
    return true
end
