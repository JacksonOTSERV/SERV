local function isInRange(pos, fromPos, toPos)
    return pos.x >= fromPos.x and pos.x <= toPos.x
       and pos.y >= fromPos.y and pos.y <= toPos.y
       and pos.z == fromPos.z
end

local protectedFrom = Position(1123, 841, 6)
local protectedTo = Position(1131, 847, 6)

local areaTeleportConfig = {
    [1] = {
        monsters = {"Death Dragon"},
        fromPos = Position(1670, 358, 7),
        toPos = Position(1695, 383, 7),
        teleportTo = Position(1682, 326, 7)
    },
    [2] = {
        monsters = {"Hawk"},
        fromPos = Position(647, 820, 3),
        toPos = Position(672, 845, 3),
        teleportTo = Position(646, 841, 3)
    },
    [3] = {
        monsters = {"Warlock"},
        fromPos = Position(637, 837, 3),
        toPos = Position(646, 844, 3),
        teleportTo = Position(644, 832, 1)
    },
    [4] = {
        monsters = {"Titanius"},
        fromPos = Position(449, 1077, 6),
        toPos = Position(469, 1094, 6),
        teleportTo = Position(361, 1103, 5)
    },
    [5] = {
        monsters = {"RB Goku SSJ4"},
        fromPos = Position(340, 252, 15),
        toPos = Position(353, 266, 15),
        teleportTo = Position(366, 259, 15)
    },
    [6] = {
        monsters = {"RB Vegeta SSJ4"},
        fromPos = Position(363, 253, 15),
        toPos = Position(375, 265, 15),
        teleportTo = Position(392, 259, 15)
    },
    [7] = {
        monsters = {"RB Gohan SSJ4"},
        fromPos = Position(389, 253, 15),
        toPos = Position(401, 265, 15),
        teleportTo = Position(415, 259, 15)
    },
    [8] = {
        monsters = {"RB Raditz SSJ4"},
        fromPos = Position(340, 274, 15),
        toPos = Position(352, 286, 15),
        teleportTo = Position(366, 280, 15)
    },
    [9] = {
        monsters = {"RB Broly SSJ4"},
        fromPos = Position(363, 274, 15),
        toPos = Position(375, 286, 15),
        teleportTo = Position(392, 280, 15)
    },
    [10] = {
        monsters = {"RB Turles SSJ4"},
        fromPos = Position(389, 274, 15),
        toPos = Position(401, 286, 15),
        teleportTo = Position(415, 280, 15)
    },
    [11] = {
        monsters = {"RB Bardock SSJ4"},
        fromPos = Position(412, 274, 15),
        toPos = Position(424, 286, 15),
        teleportTo = Position(382, 238, 15)
    },
    [12] = {
        monsters = {"RB Gogeta SSJ4"},
        fromPos = Position(376, 229, 15),
        toPos = Position(388, 241, 15),
        teleportTo = Position(382, 322, 15)
    },
    [13] = {
        monsters = {"Porunga"},
        fromPos = Position(371, 303, 15),
        toPos = Position(393, 325, 15),
        teleportTo = Position(504, 275, 13)
    },
    [14] = {
        monsters = {"RB Trunks SSJ4"},
        fromPos = Position(412, 253, 15),
        toPos = Position(424, 265, 15),
        teleportTo = Position(343, 280, 15)
    },
}

function isInsideProtectedArea(pos)
    return isInRange(pos, protectedFrom, protectedTo)
end

function onKill(creature, target)
    if not target or not target:isMonster() then
        return true
    end

    local targetName = target:getName()
    local targetPos = target:getPosition()

    for _, config in pairs(areaTeleportConfig) do
        if isInRange(targetPos, config.fromPos, config.toPos) then
            for _, name in ipairs(config.monsters) do
                if targetName:lower() == name:lower() then
                    for x = config.fromPos.x, config.toPos.x do
                        for y = config.fromPos.y, config.toPos.y do
                            local tile = Tile(Position(x, y, config.fromPos.z))
                            if tile then
                                local creatures = tile:getCreatures()
                                if creatures then
                                    for _, c in ipairs(creatures) do
                                        if c:isPlayer() then
											c:teleportTo(config.teleportTo)
											config.teleportTo:sendMagicEffect(CONST_ME_TELEPORT)
                                        end
                                    end
                                end
                            end
                        end
                    end
                    return true
                end
            end
        end
    end

    return true
end