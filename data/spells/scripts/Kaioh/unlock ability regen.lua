local config = {
    duration_spell = 10,   -- Tempo do buff em segundos
    effect = 87,          -- Effect do buff
    reuse_delay = 50,      -- Tempo para reutilizar a spell em segundos
    storage = STORAGE_ESPECIAL1, 
    heal_interval = 1000   -- Tempo entre curas (1 segundo)
}

local lastHealTime = {}

local function doAddHealBuff(player)
    if getCreatureHealth(player) == getCreatureMaxHealth(player) then
        return false
    end

    local healing = math.random(getCreatureMaxHealth(player) * 0.08, getCreatureMaxHealth(player) * 0.08)
    doCreatureAddHealth(player, healing)
    doSendMagicEffect({x = player:getPosition().x, y = player:getPosition().y, z = player:getPosition().z}, config.effect, player)
    return healing
end

local function isPlayerOnScreen(player, targetPlayer)
    local playerPosition = player:getPosition()
    local spectators = Game.getSpectators(playerPosition, true, true, 15, 8)
    for _, spectator in ipairs(spectators) do
        if spectator:getId() == targetPlayer:getId() then
            return true
        end
    end
    return false
end

local function applyHealingLoop(partyMembers, endTime, playerId)
    local player = Player(playerId)
    if not player then
        return
    end

    if os.time() >= endTime then
        return
    end

    for _, member in ipairs(partyMembers) do
        if member and member:isPlayer() then
            local targetPlayer = Player(member:getId())
            if targetPlayer and isPlayerOnScreen(player, targetPlayer) and not targetPlayer:isInGhostMode() then
                if not lastHealTime[member:getId()] or os.time() - lastHealTime[member:getId()] >= config.heal_interval / 1000 then
                    doAddHealBuff(member)
                    lastHealTime[member:getId()] = os.time()
                end
            end
        end
    end

    addEvent(applyHealingLoop, config.heal_interval, partyMembers, endTime, playerId)
end

function onCastSpell(creature, variant)
    if not creature or not creature:isPlayer() then
        return false
    end

    if exhaustion.check(creature, config.storage) then
        creature:sendCancelMessage("Aguarde " .. tostring(exhaustion.get(creature, exhaustion_storage)) .. " segundos para usar este especial novamente.")
        return false
    end

    local tile = Tile(creature:getPosition())
    if tile and tile:hasFlag(TILESTATE_NOPVPZONE) then
        creature:sendCancelMessage("Voc� n�o pode utilizar essa tecnica aqui.")
        return false
    end

    local player = Player(creature)
    if not player then
        return false
    end

    local partyMembers = {player}
    local party = player:getParty()
    local playerId = player:getId()

    if party then
        local leader = party:getLeader()
        if leader and leader:getId() ~= playerId then
            table.insert(partyMembers, leader)
        end

        for _, member in ipairs(party:getMembers()) do
            local onlineMember = Player(member:getId())
            if onlineMember and onlineMember:getId() ~= playerId then
                table.insert(partyMembers, onlineMember)
            end
        end
    end

    for _, member in ipairs(partyMembers) do
        if member and member:isPlayer() then
            doAddHealBuff(member)
            member:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Voc� recebeu regenera��o extra de 1 em 1 segundo.")
        end
    end

    local endTime = os.time() + config.duration_spell
    addEvent(applyHealingLoop, config.heal_interval, partyMembers, endTime, playerId)

    exhaustion.set(player, config.storage, config.reuse_delay)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Unlock ability regen")
    end
    return true
end