function onCastSpell(creature, variant)
    local player = creature:getPlayer()
    if not player then return false end
    
    -- Mehah: servidor envia APENAS o ID.
    -- Config visual está em: modules/game_attachedeffects/effects.lua
    player:insertAttachedEffect(2214)

    -- Remove após 10 segundos
    addEvent(function()
        local c = Creature(player:getId())
        if c then
            c:removeAttachedEffect(2214)
        end
    end, 10000)
    
    return true
end