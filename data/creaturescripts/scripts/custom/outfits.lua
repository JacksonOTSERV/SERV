local STORAGE_LAST_OFFICIAL_OUTFIT = 89812

-- ============================================================
--  AUTO-TRANSFORMACAO por level (porta do heroes p/ o sistema oficial).
--  Sobe de level -> troca AUTOMATICO p/ a transformacao mais alta liberada e
--  ganha o bonus de Ki (ml). Perde level -> volta p/ a transformacao anterior
--  e perde o bonus. Respeita a SKIN cosmetica do heroes (nao sobrescreve look).
-- ============================================================
function applyVocationTransform(player, silent)
    local outfits = vocationOutfits[player:getVocation():getName()]
    if not outfits then return end

    local playerLevel = player:getLevel()

    -- garante outfit base e desbloqueia/remove conforme o level; acha a + alta
    local base = outfits[0]
    if base and not player:hasOutfit(base.id) then player:addOutfit(base.id) end

    local best = nil
    for level, data in pairs(outfits) do
        if playerLevel >= level then
            if not player:hasOutfit(data.id) then player:addOutfit(data.id) end
            if not best or level > best.level then
                best = { id = data.id, ml = data.ml or 0, level = level }
            end
        elseif player:hasOutfit(data.id) then
            player:removeOutfit(data.id)   -- perdeu level: tira a forma alta demais
        end
    end
    if not best then return end

    -- a transformacao atual (look) e' uma forma oficial dessa vocacao?
    local cur = player:getOutfit().lookType
    local curLevel, curIsOfficial
    for level, data in pairs(outfits) do
        if data.id == cur then curIsOfficial = true; curLevel = level; break end
    end

    -- nao troca o look se o player escolheu uma skin cosmetica no heroes
    local hasSkin = (type(heroesHasCosmeticSkin) == "function") and heroesHasCosmeticSkin(player)

    local changed = false
    if not hasSkin then
        -- auto-transforma: vai pra forma mais alta liberada quando a atual nao
        -- e' oficial, ou e' invalida pelo level, ou simplesmente subiu/regrediu
        if (not curIsOfficial) or (curLevel and playerLevel < curLevel) or (best.id ~= cur) then
            local o = player:getOutfit()
            o.lookType = best.id
            player:setOutfit(o)
            changed = (best.id ~= cur)
        end
        player:setStorageValue(STORAGE_LAST_OFFICIAL_OUTFIT, best.id)
    end

    -- bonus de Ki (ml) da forma mais alta liberada (subid 99)
    player:removeCondition(CONDITION_ATTRIBUTES, 99)
    if best.ml and best.ml > 0 then
        local c = Condition(CONDITION_ATTRIBUTES)
        c:setParameter(CONDITION_PARAM_SUBID, 99)
        c:setParameter(CONDITION_PARAM_TICKS, -1)
        c:setParameter(CONDITION_PARAM_STAT_MAGICPOINTS, best.ml)
        player:addCondition(c)
    end

    if not silent and changed then
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format(
            "Voce se transformou! Bonus de +%d Ki Level.", best.ml or 0))
        player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
    end
    return best
end

function onAdvance(player, skill, oldLevel, newLevel)
    if skill ~= SKILL_LEVEL then
        return true
    end
    if not vocationOutfits[player:getVocation():getName()] then
        return true
    end
    -- sobe de level: troca automatico p/ a transformacao mais alta liberada
    applyVocationTransform(player, false)
    return true
end

-- MORTE: removeExperience NAO dispara advance. Reavalia a transformacao depois
-- da penalidade de level (regride p/ a forma anterior e perde o bonus).
function onDeath(player)
    if not vocationOutfits[player:getVocation():getName()] then
        return true
    end
    local pid = player:getId()
    addEvent(function()
        local p = Player(pid)
        if p then applyVocationTransform(p, false) end
    end, 200)
    return true
end

local function isOfficialOutfit(lookType, outfitsTable)
    for _, outfitData in pairs(outfitsTable) do
        if outfitData.id == lookType then
            return true
        end
    end
    return false
end

function onLogin(player)
    local vocationName = player:getVocation():getName()
    local outfits = vocationOutfits[vocationName]
    if not outfits then
        return true
    end

    local outfitLevel0 = outfits[0]
    if outfitLevel0 and not player:hasOutfit(outfitLevel0.id) then
        player:addOutfit(outfitLevel0.id)
    end

    local playerLevel = player:getLevel()
    local currentLookType = player:getOutfit().lookType
    local lastOfficialLookType = player:getStorageValue(STORAGE_LAST_OFFICIAL_OUTFIT)

    local ml = 0
    local highestValidOutfit = nil
    local hadInvalidOutfit = false

    for level, outfitData in pairs(outfits) do
        if playerLevel < level then
            if player:hasOutfit(outfitData.id) then
                player:removeOutfit(outfitData.id)
            end
            if outfitData.id == lastOfficialLookType then
                hadInvalidOutfit = true
            end
        else
            if not highestValidOutfit or level > highestValidOutfit.level then
                highestValidOutfit = { id = outfitData.id, ml = outfitData.ml or 0, level = level }
            end
        end
    end

    player:removeCondition(CONDITION_ATTRIBUTES, 99)

    -- SKIN cosmetica do heroes equipada: o bonus de Ki segue a FORMA do level
    -- (highestValidOutfit), NUNCA o looktype vestido. Assim skins que reusam
    -- looktype de transformacao NAO dao bonus, e a skin e' preservada (sem
    -- reverter o outfit). Resolve "skin dando bonus por ser outfit de form".
    if type(heroesHasCosmeticSkin) == "function" and heroesHasCosmeticSkin(player) then
        if highestValidOutfit then
            ml = highestValidOutfit.ml or 0
            player:setStorageValue(STORAGE_LAST_OFFICIAL_OUTFIT, highestValidOutfit.id)
        end
        if ml > 0 then
            local c = Condition(CONDITION_ATTRIBUTES)
            c:setParameter(CONDITION_PARAM_SUBID, 99)
            c:setParameter(CONDITION_PARAM_TICKS, -1)
            c:setParameter(CONDITION_PARAM_STAT_MAGICPOINTS, ml)
            player:addCondition(c)
        end
        return true
    end

    if isOfficialOutfit(currentLookType, outfits) then
        local outfitLevel = nil
        for level, outfitData in pairs(outfits) do
            if outfitData.id == currentLookType then
                outfitLevel = level
                ml = outfitData.ml or 0
                break
            end
        end

        if outfitLevel and playerLevel < outfitLevel then
            if highestValidOutfit then
                local outfit = player:getOutfit()
                outfit.lookType = highestValidOutfit.id
                player:setOutfit(outfit)
                player:setStorageValue(STORAGE_LAST_OFFICIAL_OUTFIT, highestValidOutfit.id)
                ml = highestValidOutfit.ml or 0
                player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
                    "Sua transforma��o anterior foi removida por falta de level. Voc� voltou para uma transforma��o anterior.")
                player:setStorageValue(87121, os.time() + 5)
            end
        else
            player:setStorageValue(STORAGE_LAST_OFFICIAL_OUTFIT, currentLookType)
        end
    else
        if hadInvalidOutfit then
            if highestValidOutfit then
                local outfit = player:getOutfit()
                outfit.lookType = highestValidOutfit.id
                player:setOutfit(outfit)
                player:setStorageValue(STORAGE_LAST_OFFICIAL_OUTFIT, highestValidOutfit.id)
                ml = highestValidOutfit.ml or 0
                player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
                    "Sua transforma��o anterior foi removida por falta de level. Voc� voltou para uma transforma��o anterior.")
                player:setStorageValue(87121, os.time() + 5)
            elseif outfitLevel0 then
                local outfit = player:getOutfit()
                outfit.lookType = outfitLevel0.id
                player:setOutfit(outfit)
                player:setStorageValue(STORAGE_LAST_OFFICIAL_OUTFIT, outfitLevel0.id)
                ml = outfitLevel0.ml or 0
            end
        else
            if lastOfficialLookType and lastOfficialLookType > 0 then
                for _, outfitData in pairs(outfits) do
                    if outfitData.id == lastOfficialLookType then
                        ml = outfitData.ml or 0
                        break
                    end
                end
            end
        end
    end

    if ml > 0 then
        local mlBoost = Condition(CONDITION_ATTRIBUTES)
        mlBoost:setParameter(CONDITION_PARAM_SUBID, 99)
        mlBoost:setParameter(CONDITION_PARAM_TICKS, -1)
        mlBoost:setParameter(CONDITION_PARAM_STAT_MAGICPOINTS, ml)
        player:addCondition(mlBoost)

        if player:getStorageValue(87121) < os.time() then
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
                string.format("Sua transforma��o atual concede +%d de Ki Level.", ml))
        end
    else
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
            "Sua transforma��o atual n�o concede b�nus de Ki Level.")
    end
	
    local outfitDeus = player:getOutfit().lookType
    local storageValue = player:getStorageValue(14389)
    if storageValue < 1 then
        player:setStorageValue(14389, player:getOutfit().lookType)
    end

    if (outfitDeus == 1265) and player:getStorageValue(STORAGE_DEUS) < 1 then
        player:removeOutfit(outfitDeus)
        local outfitRemove = player:getOutfit()
        outfitRemove.lookType = storageValue
        player:setOutfit(outfitRemove)
    end
	
	if player:getStorageValue(14312) < 1 then
        local outfitRemove = player:getOutfit()
        outfitRemove.lookType = outfitLevel0.id
        player:setOutfit(outfitRemove)
	end

    return true
end