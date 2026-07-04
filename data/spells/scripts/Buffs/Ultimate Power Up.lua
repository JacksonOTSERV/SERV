local config = {
    duration_spell = 60,  -- tempo do buff em segundos
    aura = 1263,          -- looktype (aura do buff)
    healthRegen = 6000    -- health gain por segundo no buff
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

    if getCreatureCondition(creature, CONDITION_ATTRIBUTES, 124) then
        creature:sendCancelMessage("Sorry, you are transformed.")
        return false
    end

    local storageValue = creature:getStorageValue(4343)
    if storageValue < 0 then storageValue = 0 end
    local bonus = 5 + storageValue

    local blockedLooks = {
        [56] = true,
        [729] = true,
        [157] = true,
        [944] = true
	}

    local function getLookAuraByVocation(player)
        local vocationName = player:getVocation():getName():lower()

        local aura964 = {goku=true, gohan=true, ["king vegeta"]=true, goten=true, kagome=true, trunks=true, vegetto=true, kame=true}
        local aura970 = {janemba=true, cell=true, freeza=true, buu=true, chilled=true, ["goku black"]=true}
        local aura966 = {zaiko=true, shenron=true, zamasu=true, kaioh=true, broly=true}
        local aura963 = {jiren=true, tapion=true, c17=true}

        if aura964[vocationName] then
            return 1274
        elseif aura970[vocationName] then
            return 1272
        elseif aura966[vocationName] then
            return 1273
        elseif aura963[vocationName] then
            return 1275
        else
            return 1263
        end
    end

    local lookAura = getLookAuraByVocation(creature)
    local currentOutfit = creature:getOutfit()
    if not blockedLooks[currentOutfit.lookType] then
        currentOutfit.lookAura = lookAura
        creature:setOutfit(currentOutfit)
    end

    creature:setStorageValue(STORAGE_BUFF, lookAura)

    local condition = Condition(CONDITION_ATTRIBUTES)
    condition:setParameter(CONDITION_PARAM_SUBID, 124)
    condition:setParameter(CONDITION_PARAM_STAT_MAGICPOINTS, bonus)
    condition:setParameter(CONDITION_PARAM_SKILL_CLUB, bonus)
    condition:setParameter(CONDITION_PARAM_SKILL_SWORD, bonus)
    condition:setParameter(CONDITION_PARAM_TICKS, config.duration_spell * 1000)
    condition:setParameter(CONDITION_PARAM_BUFF_SPELL, true)

    creature:addCondition(condition)
    creature:addCondition(regen)

    if isCreature(creature) then
        doSendAnimatedText(creature:getPosition(), "+" .. bonus .. " Club", TEXTCOLOR_WHITE)
        doSendAnimatedText(creature:getPosition(), "+" .. bonus .. " Sword", TEXTCOLOR_WHITE)
        doSendAnimatedText(creature:getPosition(), "+" .. bonus .. " Ki Level", TEXTCOLOR_WHITE)
    end

    addEvent(buff, config.duration_spell * 1000, creature:getId(), variant)

        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Ultimate power up")
    end

    return true
end