function onUse(player, item, fromPosition, target, toPosition)
    local rewards = {
        {id = 13548, name = "Golden Coat", chance = 10},
        {id = 13550, name = "Golden Legs", chance = 10},
        {id = 13549, name = "Golden Boots", chance = 10},
        {id = 13555, name = "Potara",      chance = 3}
    }

    local totalWeight = 0
    for _, r in ipairs(rewards) do
        totalWeight = totalWeight + r.chance
    end

    local roll = math.random(totalWeight)
    local chosen
    local counter = 0
    for _, r in ipairs(rewards) do
        counter = counter + r.chance
        if roll <= counter then
            chosen = r
            break
        end
    end

    if chosen then
        local newItem = player:addItem(chosen.id, 1)
        if newItem then
            player:sendTextMessage(MESSAGE_INFO_DESCR, "Você recebeu: " .. chosen.name .. "!")
        end
    end

    item:remove(1)
    return true
end