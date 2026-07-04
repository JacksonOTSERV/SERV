function onDeath(creature, killer)
    if creature:getName():lower() ~= "shenlong" then
        return true
    end

    local damageMap = creature:getDamageMap()
    local mostDamageCreature = nil
    local highestDamage = 0

    for cid, info in pairs(damageMap) do
        if info.total > highestDamage then
            highestDamage = info.total
            mostDamageCreature = Creature(cid)
        end
    end

    if mostDamageCreature then
        local topPlayer = mostDamageCreature:getPlayer() or mostDamageCreature:getMaster()
        if topPlayer and topPlayer:isPlayer() then
            local inbox = topPlayer:getInbox()
            if inbox then
                inbox:addItem(5920, 1, true, 1)

                if topPlayer:getStorageValue(4241) > 0 then
                    local ID_REFINE = 8300
                    local ID_BUFFUPGRADE = 13575 

                    local rand = math.random(2)
                    if rand == 1 then
                        inbox:addItem(ID_REFINE, 1, true, 1)
                        Game.broadcastMessage(
                            "[SHENLONG INVADER] O grande guerreiro que causou mais dano no Shenlong foi: " ..
                            topPlayer:getName() .. " e recebeu uma Shenlong Scale e 1x Refine em seu mailbox por ser um jogador reborn!",
                            MESSAGE_EVENT_ADVANCE
                        )
                    else
                        inbox:addItem(ID_BUFFUPGRADE, 1, true, 1)
                        Game.broadcastMessage(
                            "[SHENLONG INVADER] O grande guerreiro que causou mais dano no Shenlong foi: " ..
                            topPlayer:getName() .. " e recebeu uma Shenlong Scale e 1x Buff Upgrader em seu mailbox por ser um jogador reborn!",
                            MESSAGE_EVENT_ADVANCE
                        )
                    end
                else
                    Game.broadcastMessage(
                        "[SHENLONG INVADER] O grande guerreiro que causou mais dano no Shenlong foi: " ..
                        topPlayer:getName() .. " e recebeu uma Shenlong Scale em seu mailbox!",
                        MESSAGE_EVENT_ADVANCE
                    )
                end
            end
        end
    end

    for cid, info in pairs(damageMap) do
        local participant = Creature(cid)
        if participant then
            local player = participant:getPlayer() or participant:getMaster()
            if player and player:isPlayer() then
				local maxLevel = 800
				local rebornLevel = player:getStorageValue(4241) or 0

				if rebornLevel <= 0 then
					maxLevel = 600
				end

				if player:getLevel() < maxLevel then
					local levelsToAdd = math.min(5, maxLevel - player:getLevel())
					player:addLevel(levelsToAdd)
				end
                setPresencePoints(player, 1)
            end
        end
    end

    return true
end