local VIEW_OPCODE  = 105
local MISSILE_RANGE = 50        -- sqm de alcance
local TILE_FLIGHT_MS = 20     -- ms por tile (match velocidade missile native TFS)
local MISSILE_EFFECT = 70  -- visual missile (energy bolt)
local HIT_EFFECT     = CONST_ME_ENERGYHIT

local function dirOffsets(dir)
    if dir == DIRECTION_NORTH then return  0, -1
    elseif dir == DIRECTION_SOUTH then return  0,  1
    elseif dir == DIRECTION_EAST  then return  1,  0
    elseif dir == DIRECTION_WEST  then return -1,  0
    end
    return 0, 1
end

local function findEndPos(startPos, dir, maxRange)
    local dx, dy = dirOffsets(dir)
    local last = Position(startPos.x, startPos.y, startPos.z)
    for i = 1, maxRange do
        local px = startPos.x + dx * i
        local py = startPos.y + dy * i
        local tile = Tile(Position(px, py, startPos.z))
        if not tile then break end
        if tile:hasProperty(CONST_PROP_BLOCKPROJECTILE) then break end
        last = Position(px, py, startPos.z)
    end
    return last
end

local function sendViewOpcode(player, sPos, ePos, durationMs)
    if not player:isPlayer() then return end
    local payload = sPos.x .. ',' .. sPos.y .. ',' .. sPos.z .. ';'
                 .. ePos.x .. ',' .. ePos.y .. ',' .. ePos.z .. ';'
                 .. durationMs
    player:sendExtendedOpcode(VIEW_OPCODE, payload)
end

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_ENERGYDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, HIT_EFFECT)
combat:setFormula(COMBAT_FORMULA_DAMAGE, -300, 0, -600, 0)

function onCastSpell(creature, variant)
    if not creature then return false end
    local origin = creature:getPosition()
    local dir    = creature:getDirection()
    local target = findEndPos(origin, dir, MISSILE_RANGE)
    local dist   = math.max(math.abs(target.x - origin.x), math.abs(target.y - origin.y))
    if dist <= 0 then return false end

    local duration = dist * TILE_FLIGHT_MS

    -- spell view UI
    sendViewOpcode(creature, origin, target, duration)

    -- missile em chunks: TFS renderiza distance effect natural entre cada par
    local dx, dy = dirOffsets(dir)
    local CHUNK_SIZE = 5  -- tiles por chunk (mais visível)
    local chunks = math.ceil(dist / CHUNK_SIZE)
    for i = 1, chunks do
        local fromTile = (i - 1) * CHUNK_SIZE
        local toTile   = math.min(i * CHUNK_SIZE, dist)
        local fromPos = Position(origin.x + dx * fromTile, origin.y + dy * fromTile, origin.z)
        local toPos   = Position(origin.x + dx * toTile,   origin.y + dy * toTile,   origin.z)
        addEvent(function()
            fromPos:sendDistanceEffect(toPos, MISSILE_EFFECT)
        end, (i - 1) * CHUNK_SIZE * TILE_FLIGHT_MS)
    end

    -- damage at landing
    addEvent(function()
        local c = Creature(creature:getId())
        if not c then return end
        local tile = Tile(target)
        if not tile then return end
        local creatures = tile:getCreatures()
        for _, t in ipairs(creatures or {}) do
            if t:getId() ~= c:getId() then
                combat:execute(c, Variant(t:getId()))
            end
        end
        target:sendMagicEffect(HIT_EFFECT)
    end, duration)

    return true
end
