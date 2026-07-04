local config = {
    reuse_delay = 75,      -- Tempo para reutilizar a spell em segundos
    storage = STORAGE_ESPECIAL1, 
}

local globalCooldowns = {}

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

function onCastSpell(creature, variant)
    if not creature or not creature:isPlayer() then
        return false
    end

    if exhaustion.check(creature, config.storage) then
        creature:sendCancelMessage("Aguarde " .. tostring(exhaustion.get(creature, config.storage)) .. " segundos para usar este especial novamente.")
        return false
    end

    local tile = Tile(creature:getPosition())
    if tile and tile:hasFlag(TILESTATE_NOPVPZONE) then
        creature:sendCancelMessage("Você não pode utilizar essa tecnica aqui.")
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
            local targetPlayer = Player(member:getId())
            if targetPlayer and isPlayerOnScreen(player, targetPlayer) and not targetPlayer:isInGhostMode() then
                local pid = targetPlayer:getId()
                local now = os.time()

                if not globalCooldowns[pid] or globalCooldowns[pid] < now then
                    targetPlayer:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Se você morrer dentro de 5 segundos, você irá renascer. (devido ao especial de um Zamasu)")
					targetPlayer:setStorageValue(STORAGE_REVIVE2, 5 + os.time())
					targetPlayer:say("Divine god slicer!", TALKTYPE_ORANGE_1)
                    globalCooldowns[pid] = now + config.reuse_delay
                end
            end
        end
    end

    exhaustion.set(player, config.storage, 0)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Divine god slicer")
    end
    return true
end