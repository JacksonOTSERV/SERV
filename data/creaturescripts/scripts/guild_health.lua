function onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
    if GuildBuffs and GuildBuffs.onHealthChange then
        return GuildBuffs.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
    end
    return primaryDamage, primaryType, secondaryDamage, secondaryType
end
