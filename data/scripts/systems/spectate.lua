-- DBO stream system port (UI DBO + backend PokeMonster setSpectating)
-- Opcodes:
--   33  client → server (JSON): openHosting/closeHosting/spectate/requestPage/stopSpectate
--   82  server → client (JSON): canStart/hosting/update
--   198 server → client (binary): onConnectStream/updateStream/stopWatching

local CODE_STREAM_IN         = 33
local CODE_STREAM_JSON_OUT   = 82
local CODE_STREAM_BINARY_OUT = 198

local CHANNEL_ID             = 23
local TV_ITEM_ID             = 18449
local STORAGE_STREAM_BONUS   = 20000
local PAGE_SIZE              = 12

Hosts = Hosts or {}

local function tableSize(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function isAdmin(player)
    local group = player:getGroup()
    return group and group:getId() >= 4
end

local function sendStreamJSON(player, data)
    player:sendExtendedOpcode(CODE_STREAM_JSON_OUT, json.encode(data))
end

local function sendStreamBinary(player, updateType, streamName, spectatorCount, uptime, hostCid)
    local msg = NetworkMessage()
    msg:addByte(CODE_STREAM_BINARY_OUT)
    msg:addString(updateType)
    msg:addString(streamName or "")
    msg:addU16(spectatorCount or 0)
    if uptime then
        msg:addU32(uptime)
        msg:addU32(hostCid or 0)
    end
    msg:sendToPlayer(player, false)
    msg:delete()
end

local function buildStreamList(query)
    local list = {}
    for cid, host in pairs(Hosts) do
        local hostPlayer = Player(cid)
        if hostPlayer then
            local name = host.name or hostPlayer:getName()
            local charName = hostPlayer:getName()
            if not query or query == "" or
               name:lower():find(query:lower(), 1, true) or
               charName:lower():find(query:lower(), 1, true) then
                table.insert(list, {
                    name = name,
                    characterName = charName,
                    level = hostPlayer:getLevel(),
                    spectators = host.viewers or 0,
                    passwordProtected = (host.password and host.password:len() > 0),
                    itemid = host.itemId or TV_ITEM_ID,
                })
            end
        end
    end
    table.sort(list, function(a, b) return a.spectators > b.spectators end)
    return list
end

local function paginate(list, page)
    local totalPages = math.max(1, math.ceil(#list / PAGE_SIZE))
    page = math.max(1, math.min(page or 1, totalPages))
    local out = {}
    local first = (page - 1) * PAGE_SIZE + 1
    local last = math.min(first + PAGE_SIZE - 1, #list)
    for i = first, last do
        table.insert(out, list[i])
    end
    return out, page, totalPages
end

local function sendUpdate(player, page, query)
    local list = buildStreamList(query)
    local pageList, p, totalPages = paginate(list, page)
    sendStreamJSON(player, {
        type = "update",
        streams = pageList,
        page = p,
        totalPages = totalPages,
        isAdmin = isAdmin(player),
    })
end

local function broadcastHostUpdate(host)
    if not host then return end
    local cid = host:getId()
    if not Hosts[cid] then return end
    local hostData = Hosts[cid]
    local count = hostData.viewers or 0
    -- envia pro HOST (atualiza hostingWindow.views)
    sendStreamBinary(host, "updateStream", hostData.name, count)
    -- envia pra todos spectators (atualiza spectatingWindow.views)
    for _, spec in ipairs(host:getInGameSpectators()) do
        if spec then
            sendStreamBinary(spec, "updateStream", hostData.name, count)
        end
    end
end

-- ============ Player API ============

function Player.streamStartHost(self, data)
    if Hosts[self:getId()] then
        self:popupFYI("Voce ja esta transmitindo.")
        return
    end
    if self:isSpectator() then
        self:popupFYI("Voce nao pode transmitir enquanto assiste.")
        return
    end

    local cid = self:getId()
    Hosts[cid] = {
        name = (data.name and data.name:len() > 0) and data.name or self:getName(),
        description = "",
        password = data.password,
        viewers = 0,
        banned = {},
        startTime = os.time(),
        itemId = self:getStreamPendingItem() or TV_ITEM_ID,
    }

    -- 5% exp bonus se sem senha
    if not data.password or data.password:len() == 0 then
        self:setStorageValue(STORAGE_STREAM_BONUS, 1)
        self:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
            "Voce iniciou sua stream sem senha e agora tem +5% de EXP extra.")
    else
        self:setStorageValue(STORAGE_STREAM_BONUS, 0)
        self:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
            "Voce iniciou sua stream com senha. Sem bonus de EXP (inicie sem senha p/ +5%).")
    end

    self:registerEvent("StreamPreDeath")
    self:openChannel(CHANNEL_ID)
    sendStreamJSON(self, {
        type = "hosting",
        name = Hosts[cid].name,
        itemid = Hosts[cid].itemId,
    })
end

function Player.streamStopHost(self, clear)
    local cid = self:getId()
    if Hosts[cid] then
        local hadBonus = self:getStorageValue(STORAGE_STREAM_BONUS) == 1
        self:unregisterEvent("StreamPreDeath")
        Hosts[cid] = nil
        self:setStorageValue(STORAGE_STREAM_BONUS, 0)
        self:closeChannel(CHANNEL_ID)
        if hadBonus then
            self:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
                "Voce encerrou sua stream. Bonus de +5% EXP removido.")
        end
    end
    if clear then
        for _, spec in ipairs(self:getInGameSpectators()) do
            if spec then
                spec:popupFYI("O streamer encerrou a transmissao.")
                spec:setSpectating(nil)
                spec:setMovementBlocked(false)
                spec:closeChannel(CHANNEL_ID)
                sendStreamBinary(spec, "stopWatching", "", 0)
            end
        end
    end
end

function Player.streamSpectate(self, data)
    if Hosts[self:getId()] then
        self:popupFYI("Voce nao pode assistir enquanto transmite.")
        return
    end

    local target = Player(data.name)
    if not target then
        self:popupFYI("Streamer nao encontrado.")
        return
    end
    local cid = target:getId()
    if self:getId() == cid then
        self:popupFYI("Voce nao pode assistir a si mesmo.")
        return
    end

    if not Hosts[cid] then
        self:popupFYI("Esse jogador nao esta transmitindo.")
        return
    end

    if isInArray(Hosts[cid].banned, self:getAccountId()) then
        self:popupFYI("Voce esta banido desta transmissao.")
        return
    end

    if Hosts[cid].password and Hosts[cid].password:len() > 0 then
        if data.password ~= Hosts[cid].password then
            self:popupFYI("Senha incorreta.")
            return
        end
    end

    -- Se ja estava assistindo outro, troca direto (sem stop overlay)
    local previousHost = self:getSpectating()
    if previousHost then
        local pcid = previousHost:getId()
        if Hosts[pcid] then
            Hosts[pcid].viewers = math.max(0, (Hosts[pcid].viewers or 0) - 1)
            broadcastHostUpdate(previousHost)
        end
    else
        self:setMovementBlocked(true)
    end

    self:setSpectating(target)
    self:openChannel(CHANNEL_ID)
    Hosts[cid].viewers = (Hosts[cid].viewers or 0) + 1

    local uptime = os.time() - (Hosts[cid].startTime or os.time())
    sendStreamBinary(self, "onConnectStream", Hosts[cid].name, Hosts[cid].viewers, uptime, target:getId())
    broadcastHostUpdate(target)
end

function Player.streamStopSpectate(self)
    local spectating = self:getSpectating()
    if spectating then
        local cid = spectating:getId()
        if Hosts[cid] then
            Hosts[cid].viewers = math.max(0, (Hosts[cid].viewers or 0) - 1)
        end
    end
    self:setSpectating(nil)
    self:setMovementBlocked(false)
    self:closeChannel(CHANNEL_ID)
    sendStreamBinary(self, "stopWatching", "", 0)
    if spectating then
        broadcastHostUpdate(spectating)
    end
end

-- ============ Storage temporario p/ itemId do TV usado ============

local pendingItem = {}

function Player.setStreamPendingItem(self, id)
    pendingItem[self:getId()] = id
end

function Player.getStreamPendingItem(self)
    return pendingItem[self:getId()]
end

-- ============ Events ============

local LoginEvent = CreatureEvent("StreamLogin")

function LoginEvent.onLogin(player)
    player:registerEvent("StreamExtended")
    player:registerEvent("StreamLogout")
    return true
end

local LogoutEvent = CreatureEvent("StreamLogout")

function LogoutEvent.onLogout(player)
    if player:isSpectator() then
        player:streamStopSpectate()
    end
    if Hosts[player:getId()] then
        player:streamStopHost(true)
    end
    pendingItem[player:getId()] = nil
    return true
end

local PrepareDeath = CreatureEvent("StreamPreDeath")

function PrepareDeath.onPrepareDeath(target)
    if Hosts[target:getId()] then
        target:streamStopHost(true)
    end
    return true
end

local ExtendedEvent = CreatureEvent("StreamExtended")

function ExtendedEvent.onExtendedOpcode(player, opcode, buffer)
    if opcode ~= CODE_STREAM_IN then return false end

    local ok, data = pcall(function() return json.decode(buffer) end)
    if not ok or not data then return false end

    local t = data.type
    if t == "openHosting" then
        player:streamStartHost(data)
    elseif t == "closeHosting" then
        player:streamStopHost(true)
    elseif t == "spectate" then
        player:streamSpectate(data)
    elseif t == "stopSpectate" then
        player:streamStopSpectate()
    elseif t == "requestPage" then
        sendUpdate(player, data.page or 1, data.query)
    end
    return true
end

-- ============ Item TV Action ============

local TVAction = Action()

function TVAction.onUse(player, item)
    if Hosts[player:getId()] then
        sendUpdate(player, 1, nil)
        return true
    end
    if player:isSpectator() then
        sendUpdate(player, 1, nil)
        return true
    end
    -- Sem stream e sem host = abre lista + canStart pra opcao de host
    player:setStreamPendingItem(item:getId())
    sendUpdate(player, 1, nil)
    sendStreamJSON(player, {type = "canStart", itemid = item:getId()})
    return true
end

TVAction:id(TV_ITEM_ID)
TVAction:register()
LoginEvent:type("login")
LoginEvent:register()
LogoutEvent:type("logout")
LogoutEvent:register()
PrepareDeath:type("preparedeath")
PrepareDeath:register()
ExtendedEvent:type("extendedopcode")
ExtendedEvent:register()

print(string.format("[Stream] DBO system loaded. TV item: %d", TV_ITEM_ID))
