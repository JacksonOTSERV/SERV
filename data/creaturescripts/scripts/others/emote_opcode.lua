-- Emote Opcode Handler (Server-Side)
-- Handles communication with modules/game_emote
-- Uses ExtendedOpcode 244 (0xF4) with JSON payload

-- Helper to load JSON
local json = nil
pcall(function()
    json = dofile('data/lib/json.lua')
end)

if not json then
    print("[Error - EmoteOpcode] Could not load 'data/lib/json.lua'.")
end

-- Extended opcodes para enviar ao client
local OPCODE_EMOTE_ORDER = 230  -- Enviar emotes equipados
local OPCODE_EMOTE_LIST = 231   -- Enviar lista de emotes
local OPCODE_EMOTE_RECEIVE = 244 -- Receber do client (0xF4)

-- Storage keys para salvar os emotes equipados (4 slots)
local STORAGE_EMOTE_SLOT = {
    [1] = 80010,
    [2] = 80011,
    [3] = 80012,
    [4] = 80013
}

-- Lista de todos os emotes disponíveis no servidor
-- Format: { id, name, effectId }
local EMOTES_LIST = {
    { id = 1, name = "Rage", effectId = 331 },
    { id = 2, name = "Heart", effectId = 332 },
    { id = 3, name = "Star Burst", effectId = 333 },
    { id = 4, name = "Energy", effectId = 334 }
}

-- Cooldown de uso de emote (em segundos)
local EMOTE_COOLDOWN = 5
local EMOTE_EXHAUSTED = {} -- player guid -> timestamp

-- Envia a lista de emotes equipados (order) para o player
local function sendListEmoteOrder(player)
    if not json then return end
    
    local emotes = {}
    
    for slot = 1, 4 do
        local emoteId = player:getStorageValue(STORAGE_EMOTE_SLOT[slot])
        if emoteId and emoteId > 0 then
            -- Busca os dados do emote
            for _, emote in ipairs(EMOTES_LIST) do
                if emote.id == emoteId then
                    table.insert(emotes, {
                        order = slot,
                        id = emote.id,
                        name = emote.name,
                        effectId = emote.effectId
                    })
                    break
                end
            end
        end
    end
    
    player:sendExtendedOpcode(OPCODE_EMOTE_ORDER, json.encode(emotes))
end

-- Envia a lista completa de emotes disponíveis para o player
local function sendListEmote(player)
    if not json then return end
    
    local emotes = {}
    for _, emote in ipairs(EMOTES_LIST) do
        table.insert(emotes, {
            id = emote.id,
            name = emote.name,
            effectId = emote.effectId
        })
    end
    
    player:sendExtendedOpcode(OPCODE_EMOTE_LIST, json.encode(emotes))
end

-- Usa um emote (mostra o efeito)
local function useEmote(player, emoteId)
    local guid = player:getGuid()
    local now = os.time()
    
    -- Verifica cooldown
    if EMOTE_EXHAUSTED[guid] and EMOTE_EXHAUSTED[guid] > now then
        local remaining = EMOTE_EXHAUSTED[guid] - now
        player:sendCancelMessage("You need to wait " .. remaining .. " seconds to use another emote.")
        return false
    end
    
    -- Busca o emote
    local emoteData = nil
    for _, emote in ipairs(EMOTES_LIST) do
        if emote.id == emoteId then
            emoteData = emote
            break
        end
    end
    
    if not emoteData then
        player:sendCancelMessage("Invalid emote.")
        return false
    end
    
    -- Mostra o efeito
    player:getPosition():sendMagicEffect(emoteData.effectId, player)
    
    -- Define cooldown
    EMOTE_EXHAUSTED[guid] = now + EMOTE_COOLDOWN
    
    return true
end

-- Equipa um emote em um slot
local function equipEmote(player, emoteId, slot)
    if slot < 1 or slot > 4 then
        player:sendCancelMessage("Invalid slot.")
        return false
    end
    
    -- Verifica se o emote existe
    local emoteExists = false
    for _, emote in ipairs(EMOTES_LIST) do
        if emote.id == emoteId then
            emoteExists = true
            break
        end
    end
    
    if not emoteExists then
        player:sendCancelMessage("Invalid emote.")
        return false
    end
    
    -- Remove o emote de outros slots se já estiver equipado
    for s = 1, 4 do
        local currentEmote = player:getStorageValue(STORAGE_EMOTE_SLOT[s])
        if currentEmote == emoteId then
            player:setStorageValue(STORAGE_EMOTE_SLOT[s], -1)
        end
    end
    
    -- Equipa no slot selecionado
    player:setStorageValue(STORAGE_EMOTE_SLOT[slot], emoteId)
    
    -- Envia a lista atualizada
    sendListEmoteOrder(player)
    
    return true
end

function onExtendedOpcode(player, opcode, buffer)
    if opcode ~= OPCODE_EMOTE_RECEIVE then
        return false
    end
    
    if not json then return false end
    
    local status, json_data = pcall(function() return json.decode(buffer) end)
    if not status or type(json_data) ~= 'table' then
        return false
    end
    
    local msgType = json_data.type
    
    if msgType == "listOrder" then
        sendListEmoteOrder(player)
        return true
        
    elseif msgType == "listEmotes" then
        sendListEmote(player)
        return true
        
    elseif msgType == "useEmote" then
        local emoteId = json_data.emoteId
        if type(emoteId) == "string" then emoteId = tonumber(emoteId) end
        if emoteId then
            useEmote(player, emoteId)
        end
        return true
        
    elseif msgType == "equipEmote" then
        local emoteId = json_data.emoteId
        local slot = json_data.slot
        if type(emoteId) == "string" then emoteId = tonumber(emoteId) end
        if type(slot) == "string" then slot = tonumber(slot) end
        if emoteId and slot then
            equipEmote(player, emoteId, slot)
        end
        return true
        
    elseif msgType == "unequipEmote" then
        local slot = json_data.slot
        if type(slot) == "string" then slot = tonumber(slot) end
        if slot and slot >= 1 and slot <= 4 then
            player:setStorageValue(STORAGE_EMOTE_SLOT[slot], -1)
            sendListEmoteOrder(player)
        end
        return true
    end
    
    return false
end


