function onUse(player, item, fromPosition, target, toPosition)
    local boxItemId = 5957

    local vocations = {
        {name = "Tapion", chance = 10},
        {name = "Chilled", chance = 10},
        {name = "Kagome", chance = 10},
        {name = "Zaiko", chance = 10},
        {name = "King Vegeta", chance = 10},
        {name = "Vegetto", chance = 10},
        {name = "Kame", chance = 10},
        {name = "Shenron", chance = 10},
        {name = "Jiren", chance = 10},
        {name = "Goku Black", chance = 7},
        {name = "Zamasu", chance = 7}
    }

    local totalWeight = 0
    for _, v in ipairs(vocations) do
        totalWeight = totalWeight + v.chance
    end

    local roll = math.random(totalWeight)
    local chosen
    local counter = 0
    for _, v in ipairs(vocations) do
        counter = counter + v.chance
        if roll <= counter then
            chosen = v.name
            break
        end
    end

    if chosen then
        local newItem = player:addItem(boxItemId, 1)
        if newItem then
            newItem:setAttribute(ITEM_ATTRIBUTE_NAME, "Scroll contendo a vocation: " .. chosen)
            newItem:setAttribute(ITEM_ATTRIBUTE_DESCRIPTION, "Esta scroll contém a vocation " .. chosen .. ".")
            player:sendTextMessage(MESSAGE_INFO_DESCR, "Você recebeu uma scroll da vocation: " .. chosen)
        end
    end

    item:remove(1)
    return true
end