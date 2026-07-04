-- ============================================================
--  LOOT BOX (CONTAINER REAL) — itens do autoloot vao pra um depot
--  dedicado (persiste sozinho). Botao "Box" abre o container nativo.
--  Opcode: 99 | Cliente: modules/game_lootbox
-- ============================================================

local OPCODE          = 99
local COIN_ITEM       = 2160   -- crystal coin (moeda p/ comprar slots)
local SLOTS_FREE      = 10
local SLOTS_PREMIUM   = 20
local SLOTS_PER_BUY   = 5
local BUY_COST        = 10     -- crystal coins por compra de +5 slots
local STORAGE_BOUGHT  = 50030  -- storage: slots comprados pelo player
local LOOTBOX_DEPOT   = 99     -- depot dedicado do loot box (persiste automatico)

local json = nil
pcall(function() json = dofile("data/lib/json.lua") end)

-- container real do loot box (depot dedicado)
local function getBox(player)
    return player:getDepotChest(LOOTBOX_DEPOT, true)
end

function getLootBoxMaxSlots(player)
    local base   = player:isPremium() and SLOTS_PREMIUM or SLOTS_FREE
    local bought = math.max(0, player:getStorageValue(STORAGE_BOUGHT))
    return base + bought
end

-- adiciona item REAL ao loot box. Empilha stackables (internalAddItem). Respeita slots.
function addToLootBox(player, itemid, count)
    if not player or not itemid then return false end
    local box = getBox(player)
    if not box then return false end
    count = count or 1

    local it = ItemType(itemid)
    -- se ja existe stack do item, empilha sem gastar slot novo
    if it and it:isStackable() and box:getItemCountById(itemid) > 0 then
        box:addItem(itemid, count)
        return true
    end

    if box:getSize() >= getLootBoxMaxSlots(player) then
        return false -- loot box cheio
    end

    box:addItem(itemid, count)
    return true
end

-- ============================================================
--  PROTOCOLO
-- ============================================================

local function sendToClient(player, data)
    if not json then return end
    player:sendExtendedOpcode(OPCODE, json.encode(data))
end

local function sendUpdate(player)
    local box = getBox(player)
    sendToClient(player, {
        action   = "update",
        slots    = box and box:getSize() or 0,
        maxSlots = getLootBoxMaxSlots(player),
        coins    = player:getItemCount(COIN_ITEM),
    })
end

local function buySlot(player)
    if player:getItemCount(COIN_ITEM) < BUY_COST then
        sendToClient(player, { action = "error", message = "Moedas insuficientes (precisa de " .. BUY_COST .. ")." })
        return
    end
    player:removeItem(COIN_ITEM, BUY_COST)
    local bought = math.max(0, player:getStorageValue(STORAGE_BOUGHT))
    player:setStorageValue(STORAGE_BOUGHT, bought + SLOTS_PER_BUY)
    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Voce comprou +" .. SLOTS_PER_BUY .. " slots no loot box!")
end

-- pega tudo: empilhaveis recriados (id+count); pra preservar atributos use drag no container
local function withdrawAll(player)
    local box = getBox(player)
    if not box then return end
    for i = box:getSize() - 1, 0, -1 do
        local item = box:getItem(i)
        if item then
            local id, count = item:getId(), item:getCount()
            if player:addItem(id, count) then
                item:remove()
            end
        end
    end
end

-- reenvia o container ao cliente (workaround: depot chest do loot box nao tem
-- posicao no mapa, entao onAddContainerItem nao notifica via spectators).
-- Chamado apos drop manual no box (Player:onMoveItem).
function resyncLootBox(player)
    if not player then return end
    local box = getBox(player)
    if not box then return end
    box:setAttribute(ITEM_ATTRIBUTE_NAME, "Loot Box")
    player:openContainer(box)
    sendUpdate(player)
end

-- e' o container do loot box? (compara pelo nome setado via setAttribute)
function isLootBoxContainer(thing)
    if not thing then return false end
    local ok, name = pcall(function() return thing:getName() end)
    return ok and name == "Loot Box"
end

function onExtendedOpcode(player, opcode, buffer)
    if opcode ~= OPCODE then return false end
    if not json then return false end

    local ok, data = pcall(function() return json.decode(buffer) end)
    if not ok or type(data) ~= "table" then return false end

    local action = data.action
    if action == "open" then
        -- abre o container REAL (renomeado "Loot Box"); cliente desenha ele
        -- dentro da janela custom. Manda update (slots/moedas) junto.
        local box = getBox(player)
        if box then
            box:setAttribute(ITEM_ATTRIBUTE_NAME, "Loot Box")
            player:openContainer(box)
        end
        sendUpdate(player)
    elseif action == "buy-slot" then
        buySlot(player)
        resyncLootBox(player)
    elseif action == "withdraw-all" then
        withdrawAll(player)
        -- reenvia o container (removal nao notifica via spectators) p/ sumir os itens
        resyncLootBox(player)
    end
    return true
end
