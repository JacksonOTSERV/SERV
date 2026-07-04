function onKill(creature, target)
    if GuildBuffs and GuildBuffs.onKill then
        GuildBuffs.onKill(creature, target)
    end
    return true
end
