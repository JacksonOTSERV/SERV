local exhaustStorage = 300 -- Storage para controlar o exhaust
local actionCountStorage = 301 -- Storage para contar as ações
local actionTimeStorage = 303 -- Storage para o tempo da última ação

function onStepIn(player, item, position, fromPosition)
    if not player or not player:isPlayer() then
        return true
    end

    local playid = player:getId()
    local currentTime = os.time()
    local lastActionTime = player:getStorageValue(actionTimeStorage)
    local actionCount = player:getStorageValue(actionCountStorage)
    
    if lastActionTime ~= -1 and (currentTime - lastActionTime > 3) then
        actionCount = 0
        player:setStorageValue(actionTimeStorage, currentTime)
    end

    local lastExhaustTime = player:getStorageValue(exhaustStorage)
    if lastExhaustTime ~= -1 and (currentTime - lastExhaustTime < 3) then
        player:sendCancelMessage("Sorry, not possible.")
        player:teleportTo(fromPosition)
        return true
    end

    actionCount = (actionCount == -1) and 1 or (actionCount + 1)
    player:setStorageValue(actionCountStorage, actionCount)
    player:setStorageValue(actionTimeStorage, currentTime)

    if actionCount >= 4 then
        player:setStorageValue(exhaustStorage, currentTime)
        player:setStorageValue(actionCountStorage, 0)
    end

    return true
end
