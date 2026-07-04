-- Storages
local STORAGE_STR = 50003
local STORAGE_RES = 50004
local STORAGE_HEALING = 50005
local STORAGE_CRIT_CHANCE = 50006
local STORAGE_CRIT_DMG = 50007
local STORAGE_LIFE_LEECH = 50008
local STORAGE_MANA_LEECH = 50009
local STORAGE_DODGE = 50010

function onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
    if not creature or not attacker then
        return primaryDamage, primaryType, secondaryDamage, secondaryType
    end

    -- Defense / Dodge (Creature is defending)
    if creature:isPlayer() then
        local dodgeChance = math.max(0, creature:getStorageValue(STORAGE_DODGE))
        if dodgeChance > 0 then
            if math.random(1, 3) <= 1 then -- Dodge every 1-3 hits
                creature:sendTextMessage(MESSAGE_STATUS_SMALL, "DODGE!")
                creature:getPosition():sendMagicEffect(CONST_ME_POFF)
                return 0, primaryType, 0, secondaryType
            end
        end

        local resilience = math.max(0, creature:getStorageValue(STORAGE_RES))
        if resilience > 0 then
            -- Reduce damage by X%
            local reduction = 1 - (resilience / 100)
            primaryDamage = primaryDamage * reduction
            secondaryDamage = secondaryDamage * reduction
        end
    end

    -- Attack / Leech / Crit (Attacker is player)
    if attacker:isPlayer() then
        local strength = math.max(0, attacker:getStorageValue(STORAGE_STR))
        local critChance = math.max(0, attacker:getStorageValue(STORAGE_CRIT_CHANCE))
        local critDmg = math.max(0, attacker:getStorageValue(STORAGE_CRIT_DMG))
        local lifeLeech = math.max(0, attacker:getStorageValue(STORAGE_LIFE_LEECH))
        local manaLeech = math.max(0, attacker:getStorageValue(STORAGE_MANA_LEECH))

        -- Apply Strength
        if strength > 0 then
            local multiplier = 1 + (strength / 100)
            primaryDamage = primaryDamage * multiplier
            secondaryDamage = secondaryDamage * multiplier
        end

        -- Apply Critical
        if critChance > 0 and math.random(1, 100) <= critChance then
            local critMult = 2 -- Base 2x
            if critDmg > 0 then
                critMult = critMult + (critDmg / 100)
            end
            
            primaryDamage = primaryDamage * critMult
            secondaryDamage = secondaryDamage * critMult
            attacker:sendTextMessage(MESSAGE_STATUS_SMALL, "CRITICAL!")
            -- attacker:getPosition():sendMagicEffect(CONST_ME_EXPLOSIONAREA) -- Optional visual
        end
        
        -- Apply Leech (based on final damage)
        local totalDamage = primaryDamage + secondaryDamage
        if totalDamage > 0 then
            if lifeLeech > 0 then
                local heal = totalDamage * (lifeLeech / 100)
                attacker:addHealth(math.floor(heal))
                -- Visual effect for leech?
            end
            
            if manaLeech > 0 then
                local mana = totalDamage * (manaLeech / 100)
                attacker:addMana(math.floor(mana))
            end
        end
        -- Apply Healing Boost
        local healingBoost = math.max(0, attacker:getStorageValue(STORAGE_HEALING))
        if healingBoost > 0 then
            -- Check if primary or secondary type is healing
            if primaryType == COMBAT_HEALING then
                local multiplier = 1 + (healingBoost / 100)
                primaryDamage = math.floor(primaryDamage * multiplier)
            end
            if secondaryType == COMBAT_HEALING then
                local multiplier = 1 + (healingBoost / 100)
                secondaryDamage = math.floor(secondaryDamage * multiplier)
            end
        end

        return primaryDamage, primaryType, secondaryDamage, secondaryType
    end

    return primaryDamage, primaryType, secondaryDamage, secondaryType
end

function onManaChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
    -- Similar logic for Mana Shield or Mana Burn if desired, but usually minimal impact.
    -- Implement if resilience should apply to mana shield damage too.
    return primaryDamage, primaryType, secondaryDamage, secondaryType
end

function onTargetCombat(creature, target)
     -- This event is often used for other checks, but we used onHealthChange.
     return true
end
