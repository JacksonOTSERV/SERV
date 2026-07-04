local configSpell = {
    storageCd = 685006,
    timeCd = 15,
    stopDuration = 700,
    ------------------------------------------------------------------------
    missileEffect = 102,
    missilePerTile = 50,
    missileOffset = {x = 0, y = 0},
    ------------------------------------------------------------------------
    minMissiles = 1,
    missileInterval = 350,
    ------------------------------------------------------------------------
    -- Configuração dos attached effects
    -- Nota: O sistema C++ atual suporta (EffectID, Front)
    -- Offsets personalizados requerem alteração na source, então usaremos o padrão do efeito.
    attachedEffects = {
        -- Effect 1
        {
            spriteId = 330,  -- Este será usado como ID chave
            front = 1,       -- 1 = Frente, 0 = Trás
            duration = 3000
        },
        -- Effect 2
        {
            spriteId = 328,
            front = 1,
            duration = 3000
        },
        -- Effect 3
        {
            spriteId = 329,
            front = 1,
            duration = 3000
        }
    },
    ------------------------------------------------------------------------
    effectCreature = {
        effectId = 313,
        offset = {x = 1, y = 1},
        duration = 3000,
        followPlayer = true
    },
    newEffect = {
        effectId = 327,
        front = 1,       -- 1 = Frente
        duration = 300,
        followPlayer = true
    },
    ------------------------------------------------------------------------
    damageDelay = 100,
    combatArea = {
        {0, 1, 1, 1, 0},
        {0, 1, 3, 1, 0},
        {0, 1, 1, 1, 0}
    },
    textColor = 89
}

local configMessages = {
    {text = "Levantem as mãos!", delay = 0, offset = {x = 0, y = -1}},
    {text = "Eu preciso da sua ajuda!", delay = 1000, offset = {x = 0, y = -1}},
    {text = "Genki Dama!", delay = 2000, offset = {x = 0, y = -1}}
}

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_HITCOLOR, 89)

function onGetFormulaValues(player, level, maglevel)
    local min = -(1) 
    local max = -(2)
    return min, max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

-- Função para adicionar todos os attached effects simultaneamente
local function addAllAttachedEffects(creature)
    if not creature then return end
    
    for _, effectConfig in ipairs(configSpell.attachedEffects) do
        -- Adaptação: Usa insertAttachedEffect(effectId, front)
        -- Usamos spriteId como o identificador
        creature:insertAttachedEffect(effectConfig.spriteId)
        
        -- Agenda a remoção automática
        if effectConfig.duration and effectConfig.duration > 0 then
            addEvent(function()
                local c = Creature(creature:getId())
                if c then
                    -- Adaptação: removeAttachedEffect remove pelo ID do efeito (spriteId)
                    c:removeAttachedEffect(effectConfig.spriteId)
                end
            end, effectConfig.duration)
        end
    end
end

-- Função para enviar distance shoot com offset (Mantida, pois usa sendDistanceEffect padrão)
local function doSendDistanceShootWithOffset(fromPos, toPos, effectId, offset)
    if not effectId or effectId <= 0 then
        return
    end
    
    local adjustedFromPos = Position(
        fromPos.x + (offset.x or 0), 
        fromPos.y + (offset.y or 0), 
        fromPos.z
    )
    adjustedFromPos:sendDistanceEffect(toPos, effectId)
end

local function doEffectCreature(targetId, casterId)
    local target = Creature(targetId)
    if not target then return end
    
    -- Efeito no target (se configurado)
    if configSpell.effectCreature.effectId > 0 then
        local pos = target:getPosition()
        pos.x = pos.x + (configSpell.effectCreature.offset.x or 0)
        pos.y = pos.y + (configSpell.effectCreature.offset.y or 0)
        pos:sendMagicEffect(configSpell.effectCreature.effectId)
    end
end

local function doAnimatedTexts(creatureId)
    for _, msg in ipairs(configMessages) do
        addEvent(function()
            local c = Creature(creatureId)
            if not c then return end
            local pos = c:getPosition()
            pos.x = pos.x + (msg.offset and msg.offset.x or 0)
            pos.y = pos.y + (msg.offset and msg.offset.y or 0)
            Game.sendAnimatedText(msg.text, pos, configSpell.textColor)
        end, msg.delay)
    end
end

local function doMissile(casterId, targetId, var)
    if not casterId or not targetId then return end
    local caster = Creature(casterId)
    local target = Creature(targetId)
    if not caster or not target then return end

    -- ADICIONA TODOS OS ATTACHED EFFECTS
    addAllAttachedEffects(caster)

    -- Calcula a duração máxima dos effects
    local maxDuration = 0
    for _, effectConfig in ipairs(configSpell.attachedEffects) do
        if effectConfig.duration > maxDuration then
            maxDuration = effectConfig.duration
        end
    end

    -- MISSILE
    addEvent(function()
        local casterCheck = Creature(casterId)
        local targetCheck = Creature(targetId)
        if not casterCheck or not targetCheck then return end

        local currentCasterPos = casterCheck:getPosition()
        local targetPos = targetCheck:getPosition()
        
        doSendDistanceShootWithOffset(currentCasterPos, targetPos, 
                                     configSpell.missileEffect, 
                                     configSpell.missileOffset)

        local distance = currentCasterPos:getDistance(targetPos)
        local missileTravelDelay = math.max(100, distance * configSpell.missilePerTile)

        -- HIT
        addEvent(function()
            local casterFinal = Creature(casterId)
            local targetFinal = Creature(targetId)
            if not casterFinal or not targetFinal then return end

            addEvent(function()
                doCombat(casterFinal, combat, positionToVariant(targetFinal:getPosition()))
                
                -- Efeito no target usando ATTACHED EFFECT
                if configSpell.newEffect.effectId > 0 then
                    targetFinal:insertAttachedEffect(
                        configSpell.newEffect.effectId
                    )
                    
                    -- Remove o effect do target após a duração
                    if configSpell.newEffect.duration and configSpell.newEffect.duration > 0 then
                        addEvent(function()
                            local t = Creature(targetId)
                            if t then
                                t:removeAttachedEffect(configSpell.newEffect.effectId)
                            end
                        end, configSpell.newEffect.duration)
                    end
                end
                
            end, configSpell.damageDelay)
        end, missileTravelDelay)
    end, maxDuration + 200) 
end

function onTargetCreature(caster, target)
    doEffectCreature(target:getId(), caster:getId())
end

combat:setCallback(CALLBACK_PARAM_TARGETCREATURE, "onTargetCreature")

local area = createCombatArea(configSpell.combatArea)
combat:setArea(area)

function onCastSpell(creature, variant)
    local creature = Creature(creature)
    if not creature then return false end
    
    local player = creature:getPlayer()
    if not player then return false end
    
    local now = os.time()
    local remaining = player:getStorageValue(configSpell.storageCd) - now
    if remaining > 0 then
        player:sendCancelMessage(string.format("Espere [%.2f] segundos para usar esta habilidade novamente.", remaining))
        return false
    end

    local casterId = creature:getId()
    local target = creature:getTarget()
    
    if not target then
        player:sendCancelMessage("Você precisa de um alvo para usar esta habilidade.")
        return false
    end

    doAnimatedTexts(casterId)

    for k = 1, configSpell.minMissiles do
        addEvent(function(cId, tId)
            local casterCheck = Creature(cId)
            local targetCheck = Creature(tId)
            if casterCheck and targetCheck then
                doMissile(cId, tId, variant)
            end
        end, 1 + ((k - 1) * configSpell.missileInterval), casterId, target:getId())
    end

    player:setStorageValue(configSpell.storageCd, now + configSpell.timeCd)
    return true
end