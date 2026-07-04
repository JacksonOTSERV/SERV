function onCastSpell(creature, variant)
    if creature:isInGhostMode() then
        creature:sendTextMessage(MESSAGE_STATUS_SMALL, "Can't use yet.")
        return false
    end

    local storage = 12321
    local waittime = 1

    if exhaustion.check(creature, storage) then
        if isPlayer(creature) then
            creature:sendTextMessage(MESSAGE_STATUS_SMALL, "You are exhausted")
        end
        return false
    end

    local summons = creature:getSummons()
    for _, summon in pairs(summons) do
		doSendMagicEffect(getThingPos(summon), 13)
		doRemoveCreature(summon)
    end
    
    exhaustion.set(creature, storage, waittime)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, "Kai")
    end
    return true
end