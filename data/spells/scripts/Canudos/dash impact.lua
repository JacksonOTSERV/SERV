local dashDistance = 4   
local dashDelay = 1      
local damagePercent = 5     

-- Compatibilidade local para doTargetCombatHealth
local function doTargetCombatHealthCompat(creature, target, combatType, min, max, effect)
    if doTargetCombatHealth then
        doTargetCombatHealth(creature, target, combatType, min, max, effect)
    else
        if target then
            target:addHealth(min)
            target:getPosition():sendMagicEffect(effect, target)
        end
    end
end

local function broadcastJump(targetId, position, height, duration, straight)
    -- Busca todos os players (apenas players) na tela (alcance de visão)
    local spectators = Game.getSpectators(position, false, true, 13, 13, 9, 9)
    if not spectators then return end
    
    for _, spectator in ipairs(spectators) do
        local msg = NetworkMessage()
        msg:addByte(0x36)       -- Opcode do Jump
        msg:addU32(targetId)    -- ID da criatura que vai pular
        msg:addU32(height)
        msg:addU32(duration)
        msg:addByte(straight)
        
        msg:sendToPlayer(spectator) -- Manda pro espectador
        msg:delete()
    end
end

local function executeDashStep(cid, direction, remainingSteps)
    local creature = Creature(cid)
    if not creature then return end
    if remainingSteps <= 0 then return end

    local currentPos = creature:getPosition()
    local nextPos = Position(currentPos.x, currentPos.y, currentPos.z)
    
    -- Calculo manual de posição para 8 direções
    if direction == DIRECTION_NORTH then
        nextPos.y = nextPos.y - 1
    elseif direction == DIRECTION_EAST then
        nextPos.x = nextPos.x + 1
    elseif direction == DIRECTION_SOUTH then
        nextPos.y = nextPos.y + 1
    elseif direction == DIRECTION_WEST then
        nextPos.x = nextPos.x - 1
    elseif direction == DIRECTION_NORTHEAST then
        nextPos.x = nextPos.x + 1
        nextPos.y = nextPos.y - 1
    elseif direction == DIRECTION_SOUTHEAST then
        nextPos.x = nextPos.x + 1
        nextPos.y = nextPos.y + 1
    elseif direction == DIRECTION_SOUTHWEST then
        nextPos.x = nextPos.x - 1
        nextPos.y = nextPos.y + 1
    elseif direction == DIRECTION_NORTHWEST then
        nextPos.x = nextPos.x - 1
        nextPos.y = nextPos.y - 1
    end

    local tile = Tile(nextPos)

    -- Verifica parede e protecao
    if not tile or tile:hasFlag(TILESTATE_BLOCKSOLID) or tile:hasFlag(TILESTATE_BLOCKPATH) or tile:hasFlag(TILESTATE_PROTECTIONZONE) then
        return
    end

    -- DETECÇÃO 3x3 (1 SQM de raio em torno do nextPos)
    -- Game.getSpectators(position, multifloor, onlyPlayers, minRangeX, maxRangeX, minRangeY, maxRangeY)
    local spectators = Game.getSpectators(nextPos, false, false, 1, 1, 1, 1)
    
    if spectators then
        for _, target in ipairs(spectators) do
            -- Nao atinge o proprio caster e nao atinge Npcs
            if target:getId() ~= cid and not target:isNpc() then
                
                -- Broadcast do Jump
                broadcastJump(target:getId(), target:getPosition(), 35., 425, 1)
                
                local maxHealth = target:getMaxHealth()
                local damage = math.ceil(maxHealth * (damagePercent / 100))
                
                doTargetCombatHealthCompat(creature, target, COMBAT_PHYSICALDAMAGE, -damage, -damage, 2193)
            end
        end
    end

    doMoveCreature(creature, direction)
    creature:getPosition():sendMagicEffect(2200)
    
    addEvent(executeDashStep, dashDelay, cid, direction, remainingSteps - 1)
end

function onCastSpell(creature, variant)
    local angle = 0
    if creature.getDirectionalSpellAngle then
        angle = creature:getDirectionalSpellAngle()
    else
        angle = creature:getStorageValue(999999) or 0
    end
    
    local normalizedAngle = angle % 360
    local dir = DIRECTION_NORTH
    
    -- Mapeamento preciso de 8 direções
    if (normalizedAngle >= 337.5 or normalizedAngle < 22.5) then
        dir = DIRECTION_EAST
    elseif (normalizedAngle >= 22.5 and normalizedAngle < 67.5) then
        dir = DIRECTION_SOUTHEAST
    elseif (normalizedAngle >= 67.5 and normalizedAngle < 112.5) then
        dir = DIRECTION_SOUTH
    elseif (normalizedAngle >= 112.5 and normalizedAngle < 157.5) then
        dir = DIRECTION_SOUTHWEST
    elseif (normalizedAngle >= 157.5 and normalizedAngle < 202.5) then
        dir = DIRECTION_WEST
    elseif (normalizedAngle >= 202.5 and normalizedAngle < 247.5) then
        dir = DIRECTION_NORTHWEST
    elseif (normalizedAngle >= 247.5 and normalizedAngle < 292.5) then
        dir = DIRECTION_NORTH
    elseif (normalizedAngle >= 292.5 and normalizedAngle < 337.5) then
        dir = DIRECTION_NORTHEAST
    end

    executeDashStep(creature:getId(), dir, dashDistance)
    return true
end