local function createAttributesCondition(conditionId, magicLevel, skillFist)
    local condition = Condition(CONDITION_ATTRIBUTES)
    condition:setParameter(CONDITION_PARAM_SUBID, conditionId)
    condition:setParameter(CONDITION_PARAM_TICKS, -1) 
    condition:setParameter(CONDITION_PARAM_STAT_MAGICPOINTS, magicLevel)
    condition:setParameter(CONDITION_PARAM_SKILL_FIST, skillFist)
    return condition
end

local deusAttributes = {
    deus = createAttributesCondition(912, 15, 15),
	primeirokaioshin = createAttributesCondition(913, 12, 12),
	segundokaioshin = createAttributesCondition(914, 8, 8),
}

function getpresencePoints(player)
    return player:getStorageValue(STORAGE_PRESENCE_POINTS)
end

function isTopPlayerInTown(player)
    local presencePoints = getpresencePoints(player)
	local townId = getPlayerTown(player)

	local query = db.storeQuery(string.format("SELECT MAX(`presencePoints`) AS 'maxElo' FROM `players` WHERE `town_id` = %d", townId))
    if query then
        local maxElo = result.getDataInt(query, "maxElo")
        result.free(query)

        return presencePoints >= maxElo
    end
    return false
end

function isTop2PlayerInTown(player)
    local presencePoints = getpresencePoints(player)
    local townId = getPlayerTown(player)

    local query = db.storeQuery(string.format([[
        SELECT `presencePoints` 
        FROM `players` 
        WHERE `town_id` = %d 
        ORDER BY `presencePoints` DESC 
        LIMIT 1 OFFSET 1
    ]], townId))

    if query then
        local secondMax = result.getDataInt(query, "presencePoints")
        result.free(query)

        return presencePoints >= secondMax
    end

    return false
end

function isTop3PlayerInTown(player)
    local presencePoints = getpresencePoints(player)
    local townId = getPlayerTown(player)

    local query = db.storeQuery(string.format([[
        SELECT `presencePoints` 
        FROM `players` 
        WHERE `town_id` = %d 
        ORDER BY `presencePoints` DESC 
        LIMIT 1 OFFSET 2
    ]], townId))

    if query then
        local thirdMax = result.getDataInt(query, "presencePoints")
        result.free(query)

        return presencePoints >= thirdMax
    end

    return false
end

function Deus_system(player)
    local rankDeus = { {town = 1, condition = deusAttributes.deus, outfitId = 1265, rankName = "Deus da destruio", rank = 1} }
    local primeiroKaioshin = { {town = 1, condition = deusAttributes.primeirokaioshin, rankName = "Primeiro Kaioshin", rank = 2} }
    local segundoKaioshin = { {town = 1, condition = deusAttributes.segundokaioshin, rankName = "Segundo Kaioshin", rank = 3} }

    if player:getStorageValue(STORAGE_PRESENCE_POINTS) == -1 then
        player:setStorageValue(STORAGE_PRESENCE_POINTS, 0)
    end

    local presencePoints = getpresencePoints(player)
    local playerId = player:getGuid()
    local town = getPlayerTown(player)

    db.query(string.format("UPDATE `players` SET `presencePoints` = %d WHERE id = %d", presencePoints, playerId))

    local function removeAllDeusConditions(target)
        if not target then return end
        doRemoveCondition(target, CONDITION_ATTRIBUTES, 912)
        doRemoveCondition(target, CONDITION_ATTRIBUTES, 913)
        doRemoveCondition(target, CONDITION_ATTRIBUTES, 914)
    end

    local newRank
    if isTopPlayerInTown(player) and presencePoints >= 10 then
        newRank = 1
    elseif isTop2PlayerInTown(player) and presencePoints >= 10 then
        newRank = 2
    elseif isTop3PlayerInTown(player) and presencePoints >= 10 then
        newRank = 3
    else
        return nil
    end

    if newRank == 1 then
        local database = db.storeQuery("SELECT `player_id` FROM `deus_system` WHERE `town_deus` = " .. town .. " AND `rank` = 1;")
        local validou
        if database then
            validou = result.getDataInt(database, "player_id")
            result.free(database)
        end

        if validou and validou ~= playerId then
            db.query("DELETE FROM `deus_system` WHERE `town_deus` = " .. rankDeus[1].town)

            local CreatureKageAnt = Player(validou)
            if not isCreature(CreatureKageAnt) then
                db.query("DELETE FROM `player_storage` WHERE `key`="..STORAGE_DEUS.." AND `player_id`=" .. validou .. ";")
            else
                CreatureKageAnt:setStorageValue(STORAGE_DEUS, 0)
                CreatureKageAnt:removeOutfit(rankDeus[1].outfitId)
            end
        end
    end

    db.query("DELETE FROM `deus_system` WHERE `player_id` = " .. playerId .. " AND `town_deus` = " .. town)
    db.query("INSERT INTO `deus_system` (`player_id`, `town_deus`, `rank`) VALUES (" .. playerId .. "," .. town .. "," .. newRank .. ")")

    local function updateTopConditions(townId)
        local topPlayers = {}
        for offset = 0, 2 do
            local query = db.storeQuery(string.format([[
                SELECT id FROM players
                WHERE town_id = %d
                ORDER BY presencePoints DESC
                LIMIT 1 OFFSET %d
            ]], townId, offset))
            if query then
                topPlayers[offset + 1] = result.getDataInt(query, "id")
                result.free(query)
            else
                topPlayers[offset + 1] = nil
            end
        end

        local ranksAttributes = {
            [1] = {condition = deusAttributes.deus, outfitId = 1265},
            [2] = {condition = deusAttributes.primeirokaioshin},
            [3] = {condition = deusAttributes.segundokaioshin}
        }

        for rank = 1, 3 do
            local pid = topPlayers[rank]
            if pid then
                local p = Player(pid)
                if isCreature(p) then
                    removeAllDeusConditions(p)
                    p:addCondition(ranksAttributes[rank].condition)
                    if rank == 1 and ranksAttributes[rank].outfitId then
                        p:addOutfit(ranksAttributes[rank].outfitId)
                        p:setStorageValue(STORAGE_DEUS, 1)
                    elseif rank == 2 then
                        local storageValue = p:getStorageValue(14389)
                        if storageValue > 0 and p:getStorageValue(STORAGE_DEUS) < 1 then
                            local outfit = p:getOutfit()
                            outfit.lookType = storageValue
                            p:setOutfit(outfit)
                        end
                    end
                    p:save()
                else
                    if rank == 1 then
                        db.query("DELETE FROM `player_storage` WHERE `key`=" .. STORAGE_DEUS .. " AND `player_id`=" .. pid .. ";")
                    end
                end

                db.query("UPDATE `deus_system` SET `rank` = " .. rank .. " WHERE `player_id` = " .. pid .. " AND `town_deus` = " .. townId .. ";")
            end
        end
    end

    updateTopConditions(town)

    if newRank == 1 then return "Deus da destruio"
    elseif newRank == 2 then return "Primeiro Kaioshin"
    elseif newRank == 3 then return "Segundo Kaioshin" end

    return nil
end

function setPresencePoints(player, value)
    if value <= 0 then return end

    local playerId = player:getGuid()

    local query = db.storeQuery(string.format("SELECT town_id, presencePoints FROM players WHERE id = %d", playerId))
    local townId, currentPresencePoints = nil, 0
    if query then
        townId = result.getDataInt(query, "town_id")
        currentPresencePoints = result.getDataInt(query, "presencePoints")
        result.free(query)
    end
    if not townId then return end

    local topQuery = db.storeQuery(string.format([[
        SELECT id, presencePoints FROM players 
        WHERE town_id = %d 
        ORDER BY presencePoints DESC LIMIT 3
    ]], townId))

    local topPlayers = {}
    if topQuery then
        for i = 1, 3 do
            local pid = result.getDataInt(topQuery, "id")
            local points = result.getDataInt(topQuery, "presencePoints")
            topPlayers[i] = {id = pid, points = points}
            if not result.next(topQuery) then break end
        end
        result.free(topQuery)
    end

    local newPresencePoints = currentPresencePoints + value
    local adjusted = false

    local exists
    repeat
        exists = false
        for _, top in ipairs(topPlayers) do
            if top.id ~= playerId and newPresencePoints == top.points then
                newPresencePoints = newPresencePoints + 1
                adjusted = true
                exists = true
            end
        end
    until not exists

    db.query(string.format("UPDATE players SET presencePoints = %d WHERE id = %d", newPresencePoints, playerId))
    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Voc recebeu: +" .. value .. " presence point.")

    if adjusted then
        local bonus = newPresencePoints - (currentPresencePoints + value)
    end

    player:setStorageValue(STORAGE_PRESENCE_POINTS, newPresencePoints)
    Deus_system(player)
end