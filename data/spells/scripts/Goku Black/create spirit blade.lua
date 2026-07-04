local config = {
    itemId = 13603,               -- ID do item que será criado
    effect = 9, -- efeito visual no jogador
    cooldown = 30,                -- cooldown em segundos
    storage = STORAGE_ESPECIAL2   -- storage para controlar o exhaustion
}

function onCastSpell(creature, var)
    if not creature or not creature:isPlayer() then
        return false
    end

    local player = creature

    if exhaustion.check(player, config.storage) then
        player:sendCancelMessage("Aguarde " .. exhaustion.get(player, config.storage) .. " segundos para usar este especial novamente.")
        return false
    end

    local addedItem = player:addItem(config.itemId, 1)
    if addedItem then
        player:getPosition():sendMagicEffect(config.effect)
    else
        player:sendCancelMessage("Não foi possível criar o item. Verifique se há espaço na mochila.")
        return false
    end

    exhaustion.set(player, config.storage, config.cooldown)
    return true
end