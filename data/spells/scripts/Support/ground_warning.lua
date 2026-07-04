-- ground_warning spell
-- Draws AoE warning tiles on target player's client, then executes damage.

local WARNING_OPCODE = 102
local WARNING_DELAY  = 1500  -- ms before damage lands
local DAMAGE_MIN     = 100
local DAMAGE_MAX     = 200

-- AoE shape relative offsets (4x4 with top-left 2x2 missing):
-- . . X X
-- . . X X
-- X X X X
-- X X X X
local SHAPE = {
    {dx= 0, dy=-1}, {dx= 1, dy=-1},
    {dx= 0, dy= 0}, {dx= 1, dy= 0},
    {dx=-2, dy= 1}, {dx=-1, dy= 1}, {dx= 0, dy= 1}, {dx= 1, dy= 1},
    {dx=-2, dy= 2}, {dx=-1, dy= 2}, {dx= 0, dy= 2}, {dx= 1, dy= 2},
}

-- rotate offset by direction (mob facing)
local function rotateOffset(dx, dy, dir)
    -- dir: NORTH=0,EAST=1,SOUTH=2,WEST=3 (TFS constants)
    if dir == DIRECTION_NORTH then
        return dx, dy
    elseif dir == DIRECTION_EAST then
        return -dy, dx
    elseif dir == DIRECTION_SOUTH then
        return -dx, -dy
    elseif dir == DIRECTION_WEST then
        return dy, -dx
    end
    return dx, dy
end

local function buildTileList(origin, dir)
    local parts = {}
    for _, o in ipairs(SHAPE) do
        local rx, ry = rotateOffset(o.dx, o.dy, dir)
        local x = origin.x + rx
        local y = origin.y + ry
        local z = origin.z
        parts[#parts+1] = x .. ',' .. y .. ',' .. z
    end
    return table.concat(parts, '|')
end

local function applyDamage(origin, dir, caster)
    for _, o in ipairs(SHAPE) do
        local rx, ry = rotateOffset(o.dx, o.dy, dir)
        local pos = {x = origin.x + rx, y = origin.y + ry, z = origin.z}
        local tile = Tile(pos)
        if tile then
            for _, creature in ipairs(tile:getCreatures()) do
                if creature:isPlayer() then
                    local dmg = math.random(DAMAGE_MIN, DAMAGE_MAX)
                    creature:addHealth(-dmg)
                    creature:addDamageCondition(caster, CONDITION_BLEEDING, ORIGIN_MELEE, dmg, 0, 1)
                end
            end
        end
        -- ground effect
        doSendMagicEffect(pos, CONST_ME_FIREAREA)
    end
end

function onCastSpell(creature, variant)
    if not creature then return false end

    local origin = creature:getPosition()
    local dir    = creature:getDirection()

    -- send warning to all players in visible range
    local tileStr = buildTileList(origin, dir)
    local payload = WARNING_DELAY .. ':' .. tileStr
    local spectators = Game.getSpectators(origin, false, true, 9, 9, 7, 7)
    for _, player in ipairs(spectators) do
        if player:isPlayer() then
            player:sendExtendedOpcode(WARNING_OPCODE, payload)
        end
    end

    -- schedule actual damage
    addEvent(function()
        applyDamage(origin, dir, creature)
    end, WARNING_DELAY)

    return true
end
