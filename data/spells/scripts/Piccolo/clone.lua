local waittime = 40
local storage = STORAGE_ESPECIAL1
	
function onCastSpell(creature, variant)
    local timeLeftSelf = creature:getStorageValue(storage)
    if timeLeftSelf > os.time() then
        creature:sendCancelMessage("Aguarde " .. tostring(timeLeftSelf - os.time()) .. " segundos para usar este especial novamente.")
        return false
    end
    
    local cloth = creature:getOutfit()
    local health = creature:getHealth()
    local maxhealth = creature:getMaxHealth()
    
    local summons = creature:getSummons()
    for _, s in ipairs(summons) do
        if s:getName():lower() == creature:getName() then
            s:remove()
        end
    end
    
    if not hasOtherSummon or #summons == 0 then 
        local pos = creature:getPosition()
        local bpos = {
            {x=pos.x, y = pos.y, z = pos.z},
        } 
        
        local farAwayPos = {x = 485, y = 272, z = 7}
        local position = creature:getPosition()
        for i = 1, (#bpos - #summons) do 
            local summon = Game.createMonster("Clone", farAwayPos, true, false)
            if summon then
                summon:setName(''.. creature:getName() ..'', 'a '.. creature:getName() ..'')
            end
            creature:addSummon(summon)
            summon:setMaxHealth(maxhealth)
            summon:addHealth(health)
            summon:setOutfit(cloth)
            doSendMagicEffect(bpos[i], 112)
            summon:teleportTo(position, true)
            summon:registerEvent('SummonThink')
            creature:setStorageValue(storage, waittime + os.time())
        -- Send cooldown to spellbar
        if sendSpellbarCooldownAuto then
            sendSpellbarCooldownAuto(creature, "Namekian clone")
        end
        end
        return true
    end
end