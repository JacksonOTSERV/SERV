local configSpell = {
    dashDelay = 50, -- Velocidade do dash em milissegundos
    maxDistance = 5, -- Distância máxima do dash (estava 0!)
    ------------------------------------------------------------------------------------------
    jumpDurationOnMe = 380, -- Duração do efeito de jump em milisegundos em mim
    jumpHeightOnMe = 70, -- Altura do efeito de jump em mim
    ------------------------------------------------------------------------------------------
    jumpDuration = 500, -- Duração do efeito de jump em milisegundos no target
    jumpHeight = 20, -- Altura do efeito de jump no target
    ------------------------------------------------------------------------------------------
    effectHit = 7, -- Efeito visual aplicado nos inimigos quando stunados
    effectHitOffSet = {x = 0, y = 0}, -- Offset do efeito visual de stun em área
    ------------------------------------------------------------------------------------------
    blockedFloorTransitions = {
        {from = 7, to = 8}, -- Bloqueia ir do andar 7 para o 8
        {from = 8, to = 7}  -- Bloqueia ir do andar 8 para o 7
    }
}

-- Função para verificar se a transição de andar é permitida
local function isFloorTransitionAllowed(fromZ, toZ)
    -- Verifica transição direta
    for _, block in ipairs(configSpell.blockedFloorTransitions) do
        if fromZ == block.from and toZ == block.to then
            return false
        end
    end
    
    -- Verifica se está tentando ATRAVESSAR um andar bloqueado
    -- Se está indo de Z menor para Z maior (descendo)
    if toZ > fromZ then
        for z = fromZ + 1, toZ do
            for _, block in ipairs(configSpell.blockedFloorTransitions) do
                -- Se tentar atravessar uma transição bloqueada, bloqueia
                if z - 1 == block.from and z == block.to then
                    return false
                end
            end
        end
    end
    
    -- Se está indo de Z maior para Z menor (subindo)
    if toZ < fromZ then
        for z = fromZ - 1, toZ, -1 do
            for _, block in ipairs(configSpell.blockedFloorTransitions) do
                -- Se tentar atravessar uma transição bloqueada, bloqueia
                if z + 1 == block.from and z == block.to then
                    return false
                end
            end
        end
    end
    
    return true
end

local function doJumpCreature(targetId, casterId)
    if Creature(casterId) and Creature(targetId) then
        local AreaX = 13
        local AreaY = 8 

        local spectators = Game.getSpectators(Creature(casterId):getPosition(), false, true, AreaX, AreaX, AreaY, AreaY)
        if #spectators == 0 then
            return nil
        end

        for index, spectator in ipairs(spectators) do
            if spectator:getId() ~= casterId then
                local targetID = Creature(targetId):getId()
                spectator:JumpCreature(targetID, configSpell.jumpHeight, configSpell.jumpDuration, 0)
            end
        end

        local targetPos = Creature(targetId):getPosition()
        local efeitoDamagePos = Position(
            targetPos.x + configSpell.effectHitOffSet.x,
            targetPos.y + configSpell.effectHitOffSet.y,
            targetPos.z
        )
        efeitoDamagePos:sendMagicEffect(configSpell.effectHit)
    end
end

local function doJumpMe(casterId)
    local caster = Creature(casterId)
    if not caster then return end

    local AreaX = 13
    local AreaY = 8 

    local spectators = Game.getSpectators(caster:getPosition(), false, false, AreaX, AreaX, AreaY, AreaY)
    if #spectators == 0 then
        return nil
    end

    -- Faz o CASTER pular para todos os espectadores verem
    for index, spectator in ipairs(spectators) do
        if spectator:isPlayer() then
            local playerID = caster:getId()
            spectator:JumpCreature(playerID, configSpell.jumpHeightOnMe, configSpell.jumpDurationOnMe, 1)
        end
    end
end

local function checkFrontTarget(creature)
    local dir = creature:getDirection()
    local pos = creature:getPosition()
    local frontPos = nil

    if dir == 0 then frontPos = Position(pos.x, pos.y - 1, pos.z)
    elseif dir == 1 then frontPos = Position(pos.x + 1, pos.y, pos.z)
    elseif dir == 2 then frontPos = Position(pos.x, pos.y + 1, pos.z)
    elseif dir == 3 then frontPos = Position(pos.x - 1, pos.y, pos.z) end

    -- Procura criaturas em diferentes níveis Z (±2 andares)
    for z = frontPos.z - 2, frontPos.z + 2 do
        -- Verifica se a transição de andar é permitida
        if isFloorTransitionAllowed(pos.z, z) then
            local testPos = Position(frontPos.x, frontPos.y, z)
            local tile = Tile(testPos)
            if tile then
                local topCreature = tile:getTopCreature()
                if topCreature and topCreature:isCreature() and not topCreature:isInGhostMode() then
                    return topCreature
                end
            end
        end
    end
    return nil
end

local function getJumpDestination(creature)
    local dir = creature:getDirection()
    local pos = creature:getPosition()
    local originalZ = pos.z
    
    local targetPos = nil
    local lastValidPos = nil
    
    for i = 1, configSpell.maxDistance do
        local checkPos = Position(pos.x, pos.y, originalZ)
        if dir == 0 then checkPos.y = checkPos.y - i
        elseif dir == 1 then checkPos.x = checkPos.x + i
        elseif dir == 2 then checkPos.y = checkPos.y + i
        elseif dir == 3 then checkPos.x = checkPos.x - i end
        
        local foundValidZ = false
        
        -- Prioridade Z: Mesmo Nivel (1), Abaixo (2)
        -- Removemos a verificação "Acima" (originalZ - 1) para evitar que o player escale paredes/casas
        local zOrders = {
            {z = originalZ,     check = true},
            {z = originalZ + 1, check = true}
        }
        
        for _, zData in ipairs(zOrders) do
            local z = zData.z
            if z >= 0 and z <= 15 and isFloorTransitionAllowed(originalZ, z) then
                local testPos = Position(checkPos.x, checkPos.y, z)
                local tile = Tile(testPos)
                
                -- Se tiver um target ali, podemos pular nele!
                if tile then
                    local topCreature = tile:getTopCreature()
                    if topCreature and topCreature:isCreature() and not topCreature:isInGhostMode() then
                        targetPos = {pos = testPos, target = topCreature}
                        return targetPos
                    end
                end
                
                -- Checa se o tile eh um destino de POUSO valido (chao, andável)
                -- (Não tem flag BLOCKSOLID e possui chão de suporte)
                if tile and tile:getGround() and not tile:hasFlag(TILESTATE_BLOCKSOLID) and not tile:hasFlag(TILESTATE_BLOCKPATH) then
                    lastValidPos = testPos
                    foundValidZ = true
                    break
                end
            end
        end
        
        -- Condição de parada do raycast
        local checkTile = Tile(checkPos)
        if checkTile then
            -- Se batermos numa parede fechada (que bloqueia projéteis), o pulo é cancelado.
            -- A água não bloqueia projéteis (apesar de bloquear pathing/caminhada normal).
            if checkTile:hasFlag(TILESTATE_BLOCKPROJECTILE) then
                return nil
            end
            
            -- Outra checagem forte: itens que bloqueiam sólidos mas não podem ser movidos
            local ground = checkTile:getGround()
            if ground and ground:hasProperty(CONST_PROP_BLOCKPROJECTILE) then
                return nil
            end
            
            local items = checkTile:getItems()
            if items then
                for _, item in ipairs(items) do
                    -- Magic walls e Paredes
                    if item:hasProperty(CONST_PROP_BLOCKPROJECTILE) then
                        return nil
                    end
                end
            end
        end
    end
    
    if lastValidPos then
        return {pos = lastValidPos, target = nil}
    end
    
    return nil
end

-- Armazena informações do dash ativo
local activeDashes = {}

function onCastSpell(creature, variant)
    local creatureId = creature:getId()
    
    -- Previne múltiplos dashes simultâneos
    if activeDashes[creatureId] then
        return false
    end
    
    local destInfo = getJumpDestination(creature)
    if not destInfo then
        -- Não tem pra onde pular
        return false
    end
    
    activeDashes[creatureId] = true
    
    -- Aplica o efeito visual PRIMEIRO
    doJumpMe(creatureId)
    
    local startDelay = 100 -- Delay inicial para ver o efeito de jump
    
    addEvent(function()
        local caster = Creature(creatureId)
        if not caster then 
            activeDashes[creatureId] = nil
            return 
        end
        
        if destInfo.target then
            -- Achou um alvo! Para o dash no alvo e aplica o efeito nele
            doJumpCreature(destInfo.target:getId(), creatureId)
            -- Teleporta colado nele
            local dir = caster:getDirection()
            local targetPos = destInfo.target:getPosition()
            local landPos = Position(targetPos.x, targetPos.y, targetPos.z)
            if dir == 0 then landPos.y = landPos.y + 1
            elseif dir == 1 then landPos.x = landPos.x - 1
            elseif dir == 2 then landPos.y = landPos.y - 1
            elseif dir == 3 then landPos.x = landPos.x + 1 end
            
            local landTile = Tile(landPos)
            if landTile and landTile:isWalkable() then
               caster:teleportTo(landPos)
            else
               caster:teleportTo(destInfo.pos)
            end
        else
            -- Pula pro chão vazio mais longe possível
            caster:teleportTo(destInfo.pos)
        end
        
        activeDashes[creatureId] = nil
    end, startDelay + configSpell.dashDelay)
    
    return true
end