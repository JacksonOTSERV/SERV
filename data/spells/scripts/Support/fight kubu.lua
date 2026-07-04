local exhaustion_time = 45
local exhaustion_storage = STORAGE_ESPECIAL2
local distance = 6
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
	
    if creature:isInGhostMode() then
        creature:sendCancelMessage("Can't use yet.")
        return false
    end
	
    if creature:getStorageValue(4241) <= 0 then
        creature:sendCancelMessage("Esta tecnica esta disponivel somente para jogadores Reborn.")
        return false
    end

    if creature:isRemoved() then
        return false
    end
	
    if exhaustion.check(creature, exhaustion_storage) then
        creature:sendCancelMessage("Aguarde " .. tostring(exhaustion.get(creature, exhaustion_storage)) .. " segundos para usar este especial novamente.")
        return false
    end

    local playerId = creature:getId()
    local direction = creature:getDirection()
	
    invisiblesystem(creature, 157, 2, true)

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

            if not player:move(direction) then
                player:sendCancelMessage("You cannot move there.")
                return
            end

            local effect = {
                [DIRECTION_SOUTH] = {id = 11, pos = Position(pos.x, pos.y, pos.z)},
                [DIRECTION_NORTH] = {id = 11, pos = Position(pos.x, pos.y, pos.z)},
                [DIRECTION_WEST]  = {id = 11, pos = Position(pos.x, pos.y, pos.z)},
                [DIRECTION_EAST]  = {id = 11, pos = Position(pos.x, pos.y, pos.z)}
            }

            local fx = effect[dir]
            if fx then
                fx.pos:sendMagicEffect(fx.id)
            end
        end, i * speed)
    end
    exhaustion.set(creature, exhaustion_storage, exhaustion_time)
    -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Fight kubu")
    end
    return true
end
