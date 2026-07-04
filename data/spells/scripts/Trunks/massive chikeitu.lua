local exhaustion_time = 60
local exhaustion_storage = STORAGE_ESPECIAL1
local distance = 5
local speed = 10

local function walk(position)
    local tile = Tile(position)
    if not tile then
        return false
    end

    if not tile:isWalkable() then
        return false
    end

    if tile:hasFlag(TILESTATE_PROTECTIONZONE) or tile:hasFlag(TILESTATE_BLOCKSOLID) or tile:hasFlag(TILESTATE_FLOORCHANGE) then
        return false
    end

    local ground = tile:getGround()
    if ground then
        local id = ground:getId()
        if id == 9535 or id == 9536 then
            return false
        end
    end

    if tile:getHouse() then
        return false
    end

    if tile:getTopCreature() then
        return false
    end

    return true
end

function onCastSpell(creature, variant)
    if not creature or not creature:isCreature() then
        return false
    end

    if creature:isRemoved() then
        return false
    end
	
    if exhaustion.check(creature, exhaustion_storage) then
        creature:sendCancelMessage("Aguarde " .. tostring(exhaustion.get(creature, exhaustion_storage)) .. " segundos para usar este especial novamente.")
        return false
    end

    if creature:hasSecureMode() then
        creature:sendCancelMessage("Voce precisa ativar seu PVP para utilizar essa tecnica.")
        return false
    end

    local tile = Tile(creature:getPosition())
    if tile and tile:hasFlag(TILESTATE_NOPVPZONE) then
        creature:sendCancelMessage("Voce nao pode utilizar essa tecnica aqui.")
        return false
    end

    local playerId = creature:getId()
    local direction = creature:getDirection()
    local casterParty = creature:getParty()

    for i = 0, distance do
        addEvent(function()
            local player = Creature(playerId)
            if not player then return end

            local dir = player:getDirection()
            local pos = player:getPosition()
            local nextPos = Position(pos)
            nextPos:getNextPosition(direction)

            if not walk(nextPos) then
                player:sendCancelMessage("You cannot move there.")
                return
            end

            local checkPositions = {}

            local frontPos = Position(nextPos)
            table.insert(checkPositions, frontPos)

            if direction == DIRECTION_NORTH or direction == DIRECTION_SOUTH then
                table.insert(checkPositions, Position(nextPos.x - 1, nextPos.y, nextPos.z)) -- esquerda
                table.insert(checkPositions, Position(nextPos.x + 1, nextPos.y, nextPos.z)) -- direita
            elseif direction == DIRECTION_EAST or direction == DIRECTION_WEST then
                table.insert(checkPositions, Position(nextPos.x, nextPos.y - 1, nextPos.z)) -- cima
                table.insert(checkPositions, Position(nextPos.x, nextPos.y + 1, nextPos.z)) -- baixo
            end

            for _, checkPos in ipairs(checkPositions) do
                local tile = Tile(checkPos)
                if tile then
                    local creatures = tile:getCreatures() or {}
                    for _, thing in ipairs(creatures) do
                        if thing:isPlayer() then
                            local otherPlayer = thing:getPlayer()
                            if otherPlayer and not otherPlayer:hasCondition(CONDITION_MANASHIELD) then
                                local otherParty = otherPlayer:getParty()
                                if not casterParty or not otherParty or casterParty ~= otherParty then
                                    local position = otherPlayer:getPosition()
                                    position.x = position.x + 2
                                    doSendMagicEffect(position, 287, currentCreature)
                                    otherPlayer:setStorageValue(STORAGE_ESPECIAL1, os.time() + 5)
                                    local AreaX = 15
                                    local AreaY = 8
                                    local IdJump = otherPlayer:getId()
                                    local spectators = Game.getSpectators(otherPlayer:getPosition(), false, true, AreaX, AreaX, AreaY, AreaY) or {}

                                    if #spectators > 0 then
                                        for _, spectator in ipairs(spectators) do
                                            spectator:JumpCreature(IdJump, 80, 800, 1)
                                        end
                                    end
                                end
                            end
                        end
                    end -- for things
                end -- if tile
            end -- for checkPositions

            player:move(direction)

            local effect = {
                [DIRECTION_SOUTH] = {id = 10, pos = Position(pos.x, pos.y, pos.z)},
                [DIRECTION_NORTH] = {id = 10, pos = Position(pos.x, pos.y, pos.z)},
                [DIRECTION_WEST]  = {id = 10, pos = Position(pos.x, pos.y, pos.z)},
                [DIRECTION_EAST]  = {id = 10, pos = Position(pos.x, pos.y, pos.z)}
            }

            local fx = effect[dir]
            if fx then
                fx.pos:sendMagicEffect(fx.id)
            end
        end, i * speed)
    end
	creature:setPzLockTime(0)
    exhaustion.set(creature, exhaustion_storage, exhaustion_time)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Massive chikeitu")
    end
    return true
end