local BUFF_STORAGE = 4343
local MAX_BUFF_LEVEL = 15

local chances = {
    [0] = 100, [1] = 90, [2] = 80, [3] = 70, [4] = 60,
    [5] = 50, [6] = 40, [7] = 35, [8] = 30, [9] = 25,
    [10] = 20, [11] = 15, [12] = 10, [13] = 5, [14] = 3, [15] = 0
}

function onUse(player, item, fromPosition, itemEx, toPosition)
    local currentLevel = player:getStorageValue(BUFF_STORAGE)
    if currentLevel < 0 then
        currentLevel = 0
    end

    if currentLevel >= MAX_BUFF_LEVEL then
        player:sendCancelMessage("Seu buff já está no nível máximo de upgrade.")
        return true
    end
	
    if not player:removeMoney(10000000) then
      player:sendCancelMessage("Você precisa de 10.000.000 de money para tentar o upgrade.")
      return true
    end

    local chance = chances[currentLevel] or 0
    if math.random(1, 100) <= chance then
        player:setStorageValue(BUFF_STORAGE, currentLevel + 1)
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "Parabéns! Seu buff foi aprimorado para +" .. (currentLevel + 1) .. ".")
        doSendMagicEffect(player:getPosition(), 122)
    else
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "O upgrade falhou. Tente novamente.")
        doSendMagicEffect(player:getPosition(), 121)
    end

    item:remove(1)
    return true
end
