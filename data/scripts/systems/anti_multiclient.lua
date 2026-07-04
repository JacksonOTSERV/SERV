-- ============================================================
-- ANTI-MULTICLIENTE (otimizado)
-- HWID recebido via extended opcode 201 (modules/game_hwid).
-- Conta clients ativos por HWID + IP. Extras alem do limite
-- logam mas NAO ganham exp/loot (storage 20100 = 1).
-- Config: config.lua → maxClientsPerHwid / maxClientsPerIp
-- ============================================================

local OPCODE_HWID = 201
local STORAGE_FARMBLOCK = 20100

local MAX_HWID = configManager.getNumber(configKeys.MAX_CLIENTS_PER_HWID)
local MAX_IP   = configManager.getNumber(configKeys.MAX_CLIENTS_PER_IP)
if MAX_HWID <= 0 then MAX_HWID = 2 end
if MAX_IP <= 0 then MAX_IP = 3 end

-- Conta players online com mesmo HWID/IP (exclui self). So roda 1x no login.
local function countSameHWID(player, hwid)
    if not hwid or hwid == "" then return 0 end
    local n, myId = 0, player:getId()
    for _, p in ipairs(Game.getPlayers()) do
        if p:getId() ~= myId and p:getHWID() == hwid then
            n = n + 1
        end
    end
    return n
end

local function countSameIP(player, ip)
    if not ip or ip == 0 then return 0 end
    local n, myId = 0, player:getId()
    for _, p in ipairs(Game.getPlayers()) do
        if p:getId() ~= myId and p:getIp() == ip then
            n = n + 1
        end
    end
    return n
end

local function runAntiMultiCheck(player)
    local hwid = player:getHWID()
    local ip   = player:getIp()

    local hwidCount = countSameHWID(player, hwid)
    local ipCount   = countSameIP(player, ip)

    local blocked = (hwidCount >= MAX_HWID) or (ipCount >= MAX_IP)

    if blocked then
        player:setStorageValue(STORAGE_FARMBLOCK, 1)
        player:sendTextMessage(MESSAGE_STATUS_WARNING,
            "Limite de clients atingido. Este cliente NAO ganhara exp/loot ate fechar os outros.")
    else
        player:setStorageValue(STORAGE_FARMBLOCK, 0)
    end
end

-- Login: zera o estado (so reavalia quando HWID chegar via opcode)
local LoginEvent = CreatureEvent("AntiMultiLogin")

function LoginEvent.onLogin(player)
    player:setStorageValue(STORAGE_FARMBLOCK, 0)
    player:registerEvent("AntiMultiExtended")
    return true
end

-- Recebe HWID via extended opcode → seta + roda check
local ExtEvent = CreatureEvent("AntiMultiExtended")

function ExtEvent.onExtendedOpcode(player, opcode, buffer)
    if opcode ~= OPCODE_HWID then return false end
    player:setHWID(buffer)
    runAntiMultiCheck(player)
    return true
end

LoginEvent:type("login")
LoginEvent:register()
ExtEvent:type("extendedopcode")
ExtEvent:register()

print(string.format("[AntiMulti] Loaded. maxHWID=%d maxIP=%d", MAX_HWID, MAX_IP))
