local exhaustion_time = 45
local exhaustion_storage = STORAGE_ESPECIAL1
local duration_spell = 8

local condition = Condition(CONDITION_MANASHIELD)
condition:setParameter(CONDITION_PARAM_TICKS, 8000)

local function buff(creatureId, variant)
    local creature = Creature(creatureId)
    if creature and creature:isPlayer() then
		if getCreatureCondition(creature, CONDITION_ATTRIBUTES, 124) then
			local outfit = creature:getOutfit()
			outfit.lookAura = creature:getStorageValue(STORAGE_BUFF)
			creature:setOutfit(outfit)
		else
			local outfit = creature:getOutfit()
			outfit.lookAura = 0
			creature:setOutfit(outfit)
		end
    end
end

function onCastSpell(player, var)
    if exhaustion.check(player, exhaustion_storage) then
        player:sendCancelMessage("Aguarde " .. tostring(exhaustion.get(player, exhaustion_storage)) .. " segundos para usar este especial novamente.")
        return false
    end
	
	local outfit = player:getOutfit()
	outfit.lookAura = 1271
	player:setOutfit(outfit)

    if isCreature(player) then
        doSendAnimatedText(player:getPosition(), "Ki shield", TEXTCOLOR_WHITE)
    end
	
	player:addCondition(condition)
	addEvent(buff, duration_spell * 1000, player:getId(), variant)
	exhaustion.set(player, exhaustion_storage, exhaustion_time)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(player, "Kinzoku no kawa")
    end
    return true
end