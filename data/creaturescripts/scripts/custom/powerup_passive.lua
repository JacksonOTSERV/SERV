local STORAGE_HP = 50001
local STORAGE_YP = 50002 -- Mana
local STORAGE_REGEN = 50011

local function updatePassiveStats(player)
    -- Remove old conditions
    player:removeCondition(CONDITION_ATTRIBUTES, CONDITIONID_COMBAT, 100)
    player:removeCondition(CONDITION_REGENERATION, CONDITIONID_DEFAULT, 101)

    local hpPoints = math.max(0, player:getStorageValue(STORAGE_HP))
    local manaPoints = math.max(0, player:getStorageValue(STORAGE_YP))
    local regenPoints = math.max(0, player:getStorageValue(STORAGE_REGEN))

    -- Apply HP/Mana %
    if hpPoints > 0 or manaPoints > 0 then
        local condition = Condition(CONDITION_ATTRIBUTES)
        condition:setParameter(CONDITION_PARAM_TICKS, -1)
        condition:setParameter(CONDITION_PARAM_SUBID, 100)
        
        if hpPoints > 0 then
            -- 1 point = 1%
            condition:setParameter(CONDITION_PARAM_STAT_MAXHITPOINTSPERCENT, 100 + hpPoints)
        end
        
        if manaPoints > 0 then
            -- 1 point = 1%
            condition:setParameter(CONDITION_PARAM_STAT_MAXMANAPOINTSPERCENT, 100 + manaPoints)
        end
        
        player:addCondition(condition)
    end

    -- Apply Regeneration
    if regenPoints > 0 then
        local voc = player:getVocation()
        local baseHealthGain = voc:getHealthGainAmount()
        local baseHealthTicks = voc:getHealthGainTicks() * 1000
        local baseManaGain = voc:getManaGainAmount()
        local baseManaTicks = voc:getManaGainTicks() * 1000

        -- Remove old regen to replace with boosted version
        player:removeCondition(CONDITION_REGENERATION, CONDITIONID_DEFAULT)

        -- Create new regen with base + bonus
        local regenCondition = Condition(CONDITION_REGENERATION)
        regenCondition:setParameter(CONDITION_PARAM_TICKS, -1)
        regenCondition:setParameter(CONDITION_PARAM_HEALTHGAIN, baseHealthGain + (regenPoints * 1000))
        regenCondition:setParameter(CONDITION_PARAM_HEALTHTICKS, baseHealthTicks)
        regenCondition:setParameter(CONDITION_PARAM_MANAGAIN, baseManaGain + (regenPoints * 1000))
        regenCondition:setParameter(CONDITION_PARAM_MANATICKS, baseManaTicks)
        player:addCondition(regenCondition)
    end
end

function onLogin(player)
    updatePassiveStats(player)
    return true
end

function onAdvance(player, skill, oldLevel, newLevel)
    if skill == SKILL_LEVEL then
        updatePassiveStats(player)
    end
    return true
end

-- Export function to be used by powerup.lua when buying stats
function updatePlayerPowerupStats(player)
    updatePassiveStats(player)
end
