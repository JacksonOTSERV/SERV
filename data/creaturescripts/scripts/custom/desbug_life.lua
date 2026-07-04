local function getExpForLevel(level)
    level = level - 1
    return ((50 * level * level * level) - (150 * level * level) + (400 * level)) / 3
end

local STORAGE_LEVEL_RESET_DONE = 212385

function onLogin(player)
    if player:getStorageValue(STORAGE_LEVEL_RESET_DONE) ~= -1 then
        return true
    end
	
    if player:getLevel() == 1 then
        player:setStorageValue(STORAGE_LEVEL_RESET_DONE, 1)
        return true
    end

    player:setStorageValue(STORAGE_LEVEL_RESET_DONE, 1)

    local originalLevel = player:getLevel()

    if player:getLevel() > 1 then
        local levelsToRemove = player:getLevel() - 1
        player:addLevel(-levelsToRemove)
    end

    player:setMaxHealth(500)
    player:setMaxMana(400)

    local finalLevel = math.min(originalLevel, 800)

    if finalLevel > 1 then
        player:addLevel(finalLevel - 1)
    end

    player:remove()

    return true
end