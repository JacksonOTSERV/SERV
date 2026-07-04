local WARNING_OPCODE = 102
local WARNING_DELAY  = 2000
local PHASE_DELAY    = 450  -- ms between beam phases (4 phases = 1800ms total)

-- Beam tiles per direction, 4 phases expanding outward
-- All offsets relative to caster position
local PHASES = {
    [DIRECTION_EAST] = {
        {{dx=1, dy=0}},
        {{dx=1, dy=0},{dx=2, dy=0}},
        {{dx=1, dy=0},{dx=2, dy=0},{dx=3, dy=0}},
        {{dx=1, dy=0},{dx=2, dy=0},{dx=3, dy=0},{dx=4, dy=0}},
        {{dx=1, dy=0},{dx=2, dy=0},{dx=3, dy=0},{dx=4, dy=0},{dx=5, dy=0}},
    },
    [DIRECTION_WEST] = {
        {{dx=-1,dy=0}},
        {{dx=-1,dy=0},{dx=-2,dy=0}},
        {{dx=-1,dy=0},{dx=-2,dy=0},{dx=-3,dy=0}},
        {{dx=-1,dy=0},{dx=-2,dy=0},{dx=-3,dy=0},{dx=-4,dy=0}},
        {{dx=-1,dy=0},{dx=-2,dy=0},{dx=-3,dy=0},{dx=-4,dy=0},{dx=-5,dy=0}},
    },
    [DIRECTION_SOUTH] = {
        {{dx=0, dy=1}},
        {{dx=0, dy=1},{dx=0, dy=2}},
        {{dx=0, dy=1},{dx=0, dy=2},{dx=0, dy=3}},
        {{dx=0, dy=1},{dx=0, dy=2},{dx=0, dy=3},{dx=0, dy=4}},
        {{dx=0, dy=1},{dx=0, dy=2},{dx=0, dy=3},{dx=0, dy=4},{dx=0, dy=5}},
    },
    [DIRECTION_NORTH] = {
        {{dx=0, dy=-1}},
        {{dx=0, dy=-1},{dx=0, dy=-2}},
        {{dx=0, dy=-1},{dx=0, dy=-2},{dx=0, dy=-3}},
        {{dx=0, dy=-1},{dx=0, dy=-2},{dx=0, dy=-3},{dx=0, dy=-4}},
        {{dx=0, dy=-1},{dx=0, dy=-2},{dx=0, dy=-3},{dx=0, dy=-4},{dx=0, dy=-5}},
    },
}

-- Original kamehameha combats by direction
local c_east = {}
local c_west = {}
local c_south = {}
local c_north = {}

local function makeCombat(effect)
    local c = Combat()
    c:setParameter(COMBAT_PARAM_HITCOLOR, COLOR_LIGHTGREEN)
    c:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
    c:setParameter(COMBAT_PARAM_EFFECT, effect)
    c:setFormula(COMBAT_FORMULA_DAMAGE, -8000, 0, -12000, 0)
    return c
end

-- East beam (effects 129,130,130,131 from original)
c_east[1] = makeCombat(129)
c_east[1]:setArea(createCombatArea({{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{1,2,0,0,0},{0,0,0,0,0},{0,0,0,0,0}}))
c_east[2] = makeCombat(130)
c_east[2]:setArea(createCombatArea({{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,1,0,2},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0}}))
c_east[3] = makeCombat(130)
c_east[3]:setArea(createCombatArea({{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,1,1,0,0,2},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0}}))
c_east[4] = makeCombat(131)
c_east[4]:setArea(createCombatArea({{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{1,0,0,0,0,2},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0}}))

-- West beam (effects 129,130,130,131)
c_west[1] = makeCombat(131)
c_west[1]:setArea(createCombatArea({{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{2,1,0,0,0},{0,0,0,0,0},{0,0,0,0,0}}))
c_west[2] = makeCombat(130)
c_west[2]:setArea(createCombatArea({{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,2,0,1,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0}}))
c_west[3] = makeCombat(130)
c_west[3]:setArea(createCombatArea({{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{2,0,0,1,1,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0}}))
c_west[4] = makeCombat(129)
c_west[4]:setArea(createCombatArea({{0,0,0,0,0,0,0},{0,0,0,0,0,0,0},{0,0,0,0,0,0,0},{0,0,0,0,0,0,0},{0,0,0,0,0,0,0},{0,0,0,0,0,0,0},{0,0,0,0,0,0,0},{0,0,0,0,0,0,0},{2,0,0,0,0,1,0},{0,0,0,0,0,0,0},{0,0,0,0,0,0,0},{0,0,0,0,0,0,0},{0,0,0,0,0,0,0},{0,0,0,0,0,0,0}}))

-- South beam (2=caster, 1 acima na matrix = Y maior = sul)
c_south[1] = makeCombat(132)
c_south[1]:setArea(createCombatArea({{0,0,0,0,0},{0,0,0,1,0},{0,0,0,2,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0}}))
c_south[2] = makeCombat(133)
c_south[2]:setArea(createCombatArea({{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,1,0,0},{0,0,0,0,0},{0,0,2,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0}}))
c_south[3] = makeCombat(133)
c_south[3]:setArea(createCombatArea({{0,0,0,0,0,0},{0,0,1,0,0,0},{0,0,1,0,0,0},{0,0,0,0,0,0},{0,0,2,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0}}))
c_south[4] = makeCombat(133)
c_south[4]:setArea(createCombatArea({{0,0,0,0,0,0},{0,0,1,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,2,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0}}))
c_south[5] = makeCombat(134)
c_south[5]:setArea(createCombatArea({{0,0,1,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,2,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0}}))

-- North beam (espelho do south: 2 em cima, 1 abaixo)
c_north[1] = makeCombat(134)
c_north[1]:setArea(createCombatArea({{0,0,0,0,0},{0,0,0,2,0},{0,0,0,1,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0}}))
c_north[2] = makeCombat(133)
c_north[2]:setArea(createCombatArea({{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,2,0,0},{0,0,0,0,0},{0,0,1,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0}}))
c_north[3] = makeCombat(133)
c_north[3]:setArea(createCombatArea({{0,0,0,0,0,0},{0,0,2,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,1,0,0,0},{0,0,1,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0}}))
c_north[4] = makeCombat(133)
c_north[4]:setArea(createCombatArea({{0,0,2,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,1,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0}}))
c_north[5] = makeCombat(132)
c_north[5]:setArea(createCombatArea({{0,0,2,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,1,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0}}))

local DIR_COMBATS = {
    [DIRECTION_EAST]  = c_east,
    [DIRECTION_WEST]  = c_west,
    [DIRECTION_SOUTH] = c_south,
    [DIRECTION_NORTH] = c_north,
}

local function buildPayload(origin, dir)
    local phases = PHASES[dir] or PHASES[DIRECTION_SOUTH]
    local groups = {}
    for _, phase in ipairs(phases) do
        local parts = {}
        for _, o in ipairs(phase) do
            parts[#parts+1] = (origin.x + o.dx) .. ',' .. (origin.y + o.dy) .. ',' .. origin.z
        end
        groups[#groups+1] = table.concat(parts, '|')
    end
    -- format: "totalDelay;dir;startX,startY,z;endX,endY,z"
    -- use only first and last tile of final phase for fluid fill
    local final = phases[#phases]
    local first = final[1]
    local last  = final[#final]
    local startTile = (origin.x + first.dx) .. ',' .. (origin.y + first.dy) .. ',' .. origin.z
    local endTile   = (origin.x + last.dx)  .. ',' .. (origin.y + last.dy)  .. ',' .. origin.z
    return WARNING_DELAY .. ';' .. dir .. ';' .. startTile .. ';' .. endTile
end

function onCastSpell(creature, variant)
    if not creature then return false end

    local origin = creature:getPosition()
    local dir    = creature:getDirection()

    local freezeCond = Condition(CONDITION_MOVE)
    freezeCond:setParameter(CONDITION_PARAM_TICKS, WARNING_DELAY)
    creature:addCondition(freezeCond)

    local payload = buildPayload(origin, dir)
    local spectators = Game.getSpectators(origin, false, true, 9, 9, 7, 7)
    for _, player in ipairs(spectators) do
        if player:isPlayer() then
            player:sendExtendedOpcode(WARNING_OPCODE, payload)
        end
    end

    local combats = DIR_COMBATS[dir] or c_south
    local creatureId = creature:getId()
    addEvent(function()
        local c = Creature(creatureId)
        if not c then return end
        local currentPos = c:getPosition()
        local currentDir = c:getDirection()
        c:teleportTo(Position(origin.x, origin.y, origin.z), true)
        c:setDirection(dir)
        local selfVariant = Variant(creatureId)
        for _, cb in ipairs(combats) do
            cb:execute(c, selfVariant)
        end
        c:teleportTo(currentPos, true)
        c:setDirection(currentDir)
        c:say("Haa!", TALKTYPE_ORANGE_1)
    end, WARNING_DELAY)

    return true
end
