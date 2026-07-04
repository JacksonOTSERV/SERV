local waittime = 1 -- Tempo de exhaustion
local storage = 3945 -- Storage do exhaustion

function onCastSpell(player, var)
    if player:isInGhostMode() then
        player:sendCancelMessage("Can't use yet.")
        return false
    end
    if player:getStorageValue(storage) - os.time() > 0 then
        return false
    end

    local mana = player:getMana()

    if player:addMana(-mana) then
        if player:addManaSpent(mana) then
            player:getPosition():sendMagicEffect(25, player)
            return true
        else
            player:addMana(mana)
        end
    end
	
    player:setStorageValue(storage, waittime + os.time())
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(player, "Powerdown")
    end
    return true
end