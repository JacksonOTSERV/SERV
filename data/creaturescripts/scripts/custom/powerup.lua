local POWERUP_OPCODE = 33
local POWERUP_OPCODE_SEND = 111
dofile('data/creaturescripts/scripts/custom/powerup_passive.lua')

-- Config
local config = {
    pointsPerLevel = 1, -- Points gained per level
    
    stats = {
        ["Health"] = {
            storage = 50001,
            maxPoints = 35, -- 35%
            cost = 1,
            bonusPerPoint = 1, -- 1%
            color = "#FF0000", -- Red
            description = "Aumenta a vida maxima do personagem em porcentagem.",
            apply = function(player, points) 
                -- Handled by login/stats scripts
            end
        },
        ["Mana"] = {
            storage = 50002,
            maxPoints = 35, -- 35%
            cost = 1,
            bonusPerPoint = 1, -- 1%
            color = "#0000FF", -- Blue
            description = "Aumenta a mana maxima do personagem em porcentagem.",
            apply = function(player, points)
                -- Handled by login/stats scripts
            end
        },
        ["Strength"] = {
            storage = 50003,
            maxPoints = 15, -- 15%
            cost = 1,
            bonusPerPoint = 1, -- 1%
            color = "#8B0000", -- Dark Red
            description = "Aumenta a porcentagem de dano causado por armas e magias.",
            apply = function(player, points)
                -- Handled by combat scripts
            end
        },
        ["Resilience"] = {
            storage = 50004,
            maxPoints = 15, -- 15%
            cost = 1,
            bonusPerPoint = 1, -- 1%
            color = "#C0C0C0", -- Silver/Gray
            description = "Aumenta a defesa percentual contra danos de jogadores e monstros.",
            apply = function(player, points)
                -- Handled by combat scripts
            end
        },
        ["Healing"] = {
            storage = 50005,
            maxPoints = 20, -- 20%
            cost = 1,
            bonusPerPoint = 1, -- 1%
            color = "#FF69B4", -- HotPink
            description = "Aumenta a cura total realizada pelo personagem (magias, habilidades e efeitos).",
            apply = function(player, points)
                -- Handled by healing scripts
            end
        },
        ["Critical"] = {
            storage = 50006,
            maxPoints = 30, -- 30%
            cost = 1,
            bonusPerPoint = 1, -- 1%
            color = "#FFA500", -- Orange
            description = "Aumenta a chance de acerto critico.",
            apply = function(player, points)
                -- Handled by combat scripts
            end
        },
        ["Critical Damage"] = {
            storage = 50007,
            maxPoints = 25, -- 25%
            cost = 1,
            bonusPerPoint = 1, -- 1%
            color = "#800000", -- Maroon
            description = "Aumenta o dano causado em acertos criticos.",
            apply = function(player, points)
                -- Handled by combat scripts
            end
        },
        ["Life Leech"] = {
            storage = 50008,
            maxPoints = 6, -- 6%
            cost = 1,
            bonusPerPoint = 1, -- 1%
            color = "#DC143C", -- Crimson
            description = "Concede roubo de vida, recuperando HP proporcional ao dano causado.",
            apply = function(player, points)
                -- Handled by combat scripts
            end
        },
        ["Mana Leech"] = {
            storage = 50009,
            maxPoints = 8, -- 8%
            cost = 1,
            bonusPerPoint = 1, -- 1%
            color = "#800080", -- Purple
            description = "Concede roubo de mana, recuperando mana proporcional ao dano causado.",
            apply = function(player, points)
                -- Handled by combat scripts
            end
        },
        ["Dodge"] = {
            storage = 50010,
            maxPoints = 20, -- 20%
            cost = 1,
            bonusPerPoint = 1, -- 1%
            color = "#32CD32", -- LimeGreen
            description = "Aumenta a chance de esquiva, evitando completamente ataques inimigos.",
            apply = function(player, points)
                -- Handled by combat scripts
            end
        },
        ["Regeneration"] = {
            storage = 50011,
            maxPoints = 20, -- 20%
            cost = 1,
            bonusPerPoint = 1, -- 1%
            color = "#006400", -- DarkGreen
            description = "Aumenta a regeneracao de vida e mana por segundo.",
            apply = function(player, points)
                -- Handled by regeneration scripts
            end
        }
    }
}

-- Helper function to get player total used points
local function getUsedPoints(player)
    local used = 0
    for name, stat in pairs(config.stats) do
        local points = math.max(0, player:getStorageValue(stat.storage))
        used = used + (points * stat.cost)
    end
    return used
end

-- Helper function to get available points
local function getAvailablePoints(player)
    local totalPoints = math.floor(player:getLevel() * config.pointsPerLevel)
    local usedPoints = getUsedPoints(player)
    return math.max(0, totalPoints - usedPoints)
end

-- Helper function to send data to client
local function sendPowerUpData(player)
    local statsData = {}
    
    -- Sort keys to ensure consistent order if needed, but pairs order is random.
    -- Better to insert and sort by name or specific order.
    -- For now, consistent insertion based on manual list order is hard with pairs.
    -- Let's construct a list.
    
    local orderedStats = {
        "Health", "Mana", "Strength", "Resilience", "Healing", 
        "Critical", "Critical Damage", "Life Leech", "Mana Leech", 
        "Dodge", "Regeneration"
    }

    for _, name in ipairs(orderedStats) do
        local stat = config.stats[name]
        if stat then
            local points = math.max(0, player:getStorageValue(stat.storage))
            table.insert(statsData, {
                name = name,
                color = stat.color,
                description = stat.description,
                statspoints = points, 
                limit = stat.maxPoints,
                nextPoints = stat.cost
            })
        end
    end

    local data = {
        type = "update",
        playerpoints = getAvailablePoints(player),
        statsData = statsData
    }
    
    player:sendExtendedOpcode(POWERUP_OPCODE_SEND, json.encode(data))
end

function onExtendedOpcode(player, opcode, buffer)
    if opcode == POWERUP_OPCODE then
        local status, json_data = pcall(function() return json.decode(buffer) end)
        if not status then return false end

        if json_data.type == "doPlayerSendOpenPowerUp" then
            sendPowerUpData(player)
            
        elseif json_data.type == "doPlayerAddPowerUpBonus" then
            local category = json_data.category
            local stat = config.stats[category]
            
            if stat then
                local currentPoints = math.max(0, player:getStorageValue(stat.storage))
                local availablePoints = getAvailablePoints(player)
                
                if currentPoints < stat.maxPoints then
                    if availablePoints >= stat.cost then
                        player:setStorageValue(stat.storage, currentPoints + 1)
                        if updatePlayerPowerupStats then
                            updatePlayerPowerupStats(player)
                        end
                        sendPowerUpData(player)
                        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "You upgraded " .. category .. "!")
                    else
                        player:sendTextMessage(MESSAGE_STATUS_SMALL, "You don't have enough points.")
                    end
                else
                    player:sendTextMessage(MESSAGE_STATUS_SMALL, "This stat is already at maximum level.")
                end
            end
            
        elseif json_data.type == "doResetPowerUp" then
            for name, stat in pairs(config.stats) do
                player:setStorageValue(stat.storage, 0)
            end
            sendPowerUpData(player)
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Your powerup points have been reset.")
        end
    end
    return true
end
