function onCastSpell(creature, spell)
    if not creature or not creature:isPlayer() then
        return true
    end

    local spellName = spell:getName()
    -- Use the helper function from lib/custom/spellbar.lua to send cooldown
    -- This relies on spell_data_cache.lua for accurate cooldowns
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(creature, spellName)
    end
    
    return true
end
