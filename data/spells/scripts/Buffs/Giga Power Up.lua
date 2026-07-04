local config = {
    duration_spell = 45,  -- tempo do buff em segundos
    aura = 1262,            -- looktype (aura do buff)
	healthRegen = 4000   -- health gain por segundo no buff
}

local regen = Condition(CONDITION_REGENERATION)
regen:setParameter(CONDITION_PARAM_SUBID, 122)
regen:setParameter(CONDITION_PARAM_TICKS, config.duration_spell * 1000) 
regen:setParameter(CONDITION_PARAM_MANAGAIN, config.healthRegen)
regen:setParameter(CONDITION_PARAM_MANATICKS, 1000)
regen:setParameter(CONDITION_PARAM_HEALTHGAIN, config.healthRegen)
regen:setParameter(CONDITION_PARAM_HEALTHTICKS, 1000)

local function buff(creatureTwo, variant)
    local creature = Creature(creatureTwo)
    if creature then
        local blockedLooks = {
            [56] = true,
            [729] = true,
            [157] = true,
            [944] = true,
            [1265] = true
        }

        local function safeSetOutfit(creature, lookAura)
            local outfit = creature:getOutfit()
            if not blockedLooks[outfit.lookType] then
                outfit.lookAura = lookAura
                creature:setOutfit(outfit)
            end
        end

        if creature:getStorageValue(STORAGE_ESPECIAL3) - os.time() == 0 and creature:getStorageValue(10289) - os.time() == 0 then
            safeSetOutfit(creature, 0)
            doRemoveCondition(creature, CONDITION_ATTRIBUTES, 124)
            creature:setStorageValue(STORAGE_ESPECIAL3, 0)
        end

        if creature:getStorageValue(10289) - os.time() > 0 then
            safeSetOutfit(creature, 11)
            doRemoveCondition(creature, CONDITION_ATTRIBUTES, 124)
            return
        end

        if not getCreatureCondition(creature, CONDITION_ATTRIBUTES, 100) then
            safeSetOutfit(creature, 0)
            doRemoveCondition(creature, CONDITION_ATTRIBUTES, 124)
        end
    end
end

function onCastSpell(creature, variant)
    if not creature then
        return false
    end

    if not getCreatureCondition(creature, CONDITION_ATTRIBUTES, 124) then
        local storageValue = creature:getStorageValue(4343)
        if storageValue < 0 then storageValue = 0 end

        local blockedLooks = {
            [56] = true,
            [729] = true,
            [157] = true,
            [944] = true,
            [1265] = true
        }

        if creature:getOutfit().lookAura ~= 1264 and creature:getOutfit().lookAura ~= 1271 then
            local currentOutfit = creature:getOutfit()
            if not blockedLooks[currentOutfit.lookType] then
                currentOutfit.lookAura = config.aura
                creature:setOutfit(currentOutfit)
            end
        end
        creature:setStorageValue(STORAGE_BUFF, config.aura)

        local condition = Condition(CONDITION_ATTRIBUTES)
        condition:setParameter(CONDITION_PARAM_SUBID, 124)
        condition:setParameter(CONDITION_PARAM_STAT_MAGICPOINTS, storageValue)
        condition:setParameter(CONDITION_PARAM_SKILL_CLUB, storageValue)
        condition:setParameter(CONDITION_PARAM_SKILL_SWORD, storageValue)
        condition:setParameter(CONDITION_PARAM_TICKS, config.duration_spell * 1000)
        condition:setParameter(CONDITION_PARAM_BUFF_SPELL, true)

        creature:addCondition(condition)
        creature:addCondition(regen)

        if isCreature(creature) then
            if storageValue > 0 then
                doSendAnimatedText(creature:getPosition(), "+" .. storageValue .. " Club", TEXTCOLOR_WHITE)
                doSendAnimatedText(creature:getPosition(), "+" .. storageValue .. " Sword", TEXTCOLOR_WHITE)
                doSendAnimatedText(creature:getPosition(), "+" .. storageValue .. " Ki Level", TEXTCOLOR_WHITE)
            end
        end

        addEvent(buff, config.duration_spell * 1000, creature:getId(), variant)
    else
        creature:sendCancelMessage("Sorry, you are transformed.")
        return false
    end
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Giga power up")
    end
    return true
end