function onLogin(player)
    player:registerEvent("GuildBuffsKill")
    player:registerEvent("GuildBuffsHealth")
    if GuildBuffs and GuildBuffs.checkConditions then
        GuildBuffs.checkConditions(player)
    end
    return true
end
