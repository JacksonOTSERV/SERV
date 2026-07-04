local OPCODE_MONSTER_TARGET = 155

local function broadcastMonsterTargets()
    local players = Game.getPlayers()
    if #players == 0 then return true end

    -- Get all spectators once per player, but skip players with no nearby monsters
    -- to reduce dispatcher load (was running every 500ms, now 2000ms).
    for _, player in ipairs(players) do
        local playerPos = player:getPosition()
        local spectators = Game.getSpectators(playerPos, false, false, 8, 8, 8, 8)

        if #spectators > 0 then
            local targets = {}
            local playerId = player:getId()

            for _, creature in ipairs(spectators) do
                if creature:isMonster() then
                    local target = creature:getTarget()
                    if target and target:isPlayer() and target:getId() == playerId then
                        table.insert(targets, creature:getId())
                    end
                end
            end

            if #targets > 0 then
                local jsonPayload = "[" .. table.concat(targets, ",") .. "]"
                player:sendExtendedOpcode(OPCODE_MONSTER_TARGET, jsonPayload)
            end
        end
    end
    return true
end

-- Otimização: Intervalo controlado pelo XML
function onThink(interval)
    broadcastMonsterTargets()
    return true
end
