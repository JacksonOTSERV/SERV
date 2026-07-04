local VIP_VOCATIONS = {
    [14] = true, -- Tapion
    [15] = true, -- Chilled
    [16] = true, -- Kagome
    [17] = true, -- Zaiko
    [18] = true, -- King Vegeta
    [19] = true, -- Vegetto
    [20] = true, -- Kame
    [21] = true,  -- Shenron
	[23] = true,  -- Goku Black
	[24] = true,  -- Zamasu
	[25] = true  -- Jiren
}

local STORAGE_REFLECT = 9000               -- Storage que guarda o tempo final do efeito
local REFLECT_EFFECT = 67 				   -- Efeito visual ao refletir
local STORAGE_BROLY_IMMUNE = 6612          -- Storage que ativa a imunidade de 5s

function onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType)
    local timing = os.time()
    local blockedActive = creature:getStorageValue(STORAGE_BROLY_IMMUNE) or 0

    if creature:isPlayer() and blockedActive >= timing and primaryType ~= COMBAT_HEALING then
        doSendAnimatedText(creature:getPosition(), "Blocked!", TEXTCOLOR_LIGHTGREEN)
        return 0, primaryType, 0, secondaryType
    end

    if not attacker then
        return primaryDamage, primaryType, secondaryDamage, secondaryType
    end
	
    if attacker:isPlayer() and VIP_VOCATIONS[attacker:getVocation():getId()] then
        primaryDamage = math.floor(primaryDamage * 1.05)
        secondaryDamage = math.floor(secondaryDamage * 1.05)
    end

	if primaryType == COMBAT_PHYSICALDAMAGE then
		local currentTime = os.time()
		local reflectActive = creature:isPlayer() and creature:getStorageValue(STORAGE_REFLECT) or 0
		local attackerImmune = attacker and attacker:isPlayer() and attacker:getStorageValue(STORAGE_BROLY_IMMUNE) or 0

		if reflectActive >= currentTime and primaryType ~= COMBAT_HEALING and attackerImmune < timing then
			local reducedPrimary = math.floor(primaryDamage * 0.5)
			local reducedSecondary = math.floor(secondaryDamage * 0.5)
			local totalReflect = reducedPrimary + reducedSecondary

			if attacker and attacker:isCreature() then
				doCreatureAddHealth(attacker, -totalReflect)
			end

			doSendAnimatedText(creature:getPosition(), "Reflect!", TEXTCOLOR_RED)
			local position = creature:getPosition()
			position.x = position.x + 2
			position.y = position.y + 2
			doSendMagicEffect(position, REFLECT_EFFECT)

			return reducedPrimary, primaryType, reducedSecondary, secondaryType
		end
	end
	
    if creature:isPlayer() and attacker:isPlayer() and attacker:getLevel() >= 250 and primaryType ~= COMBAT_HEALING then
        local attackers = Combat.getAttackers(creature) or {}
        local activeAttackers = 0

        for _, guid in pairs(attackers) do
            local p = Player(guid)
            if p and p:getLevel() >= 250 then
                activeAttackers = activeAttackers + 1
            end
        end

        if activeAttackers > 1 then
            local healPercent = 0.005 * (activeAttackers - 1)
            local healAmount = math.floor(creature:getMaxHealth() * healPercent)
            if healAmount > 0 then
                creature:addHealth(healAmount)
            end

            local drainPercent = 0.005 * (activeAttackers - 1)
            local drainAmount = math.floor(creature:getMaxHealth() * drainPercent)
            if drainAmount > 0 then
                creature:addHealth(-drainAmount)
            end
        end
    end
    return primaryDamage, primaryType, secondaryDamage, secondaryType
end