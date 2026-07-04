DUNGEON_OPCODE_DESTROYINFO = 87
DUNGEON_OPCODE_LEVEL = 88
DUNGEON_OPCODE_DIFFICULTY = 89
DUNGEON_OPCODE_MISSIONS = 90
DUNGEON_OPCODE_ITEMS = 91
DUNGEON_OPCODE_INVITE = 92
DUNGEON_OPCODE_TEXT = 182
DUNGEON_OPCODE_ReceiveStart = 184
DUNGEON_OPCODE_PLAYERS_PARTY = 93
DUNGEON_OPCODE_CLOSEWINDOW = 96

DUNGEON = {

x = 333,
y = 334,
z = 335,

}

DUNGEON_LEVELS = {"200", "300", "400"}
DUNGEON_DIFFICULTYS = {"Bosses"}

DUNGEONS_MISSIONCATEGORY = {
    ["Bosses"] = {
        [1] = {
            name = "Black Namekjin",
            players = 1,
			duration = 1,
            looktype = 659,
            recompense_list = {13588, 13587},
            count = {1, 1},
            items = {0},
            count_req = {1},
			areas = {
				[1] = {fromPos={x = 106, y = 187, z = 7}, toPos={x = 110, y = 190, z = 7},teleportPos={x = 108, y = 188, z = 7},summonPos={x = 108, y = 188, z = 7}},
			},
            requiredLevel = 200,
			requiredItem = 2160,
			description = "? necess?rio uma Namekjin Piece para iniciar essa dungeon."
        },
        [2] = {
            name = "Multiversal Gengar",
            players = 2,
			duration = 10,
            looktype = 721,
            recompense_list = {13588, 13587},
            count = {3, 3},
            items = {0},
            count_req = {1},
			areas = {
			},
            requiredLevel = 300,
			requiredItem = 2088,
			description = "? necess?rio um Chap?u de Bruxa para iniciar essa dungeon."
        },
    },
}

local function locale(fromPos, toPos)
    for x = fromPos.x, toPos.x do
        for y = fromPos.y, toPos.y do
            for z = fromPos.z, toPos.z do
                local pos = Position(x, y, z)
                local tile = Tile(pos)
                if tile then
                    local creatureList = tile:getCreatures()
                    for _, creature in ipairs(tile:getCreatures() or {}) do
                        if creature:isPlayer() then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

function destroyInfoDungeon(cid)
    if not cid:isPlayer() then return true end
    local opcodes = {"destroyInfo_levels", "destroyInfo_missions", "destroyInfo_team"}
    for _, opcode in ipairs(opcodes) do
        cid:sendExtendedOpcode(DUNGEON_OPCODE_DESTROYINFO, opcode .. "@")
    end
    return true
end

function sendDungeon(cid, category)
    if not cid:isPlayer() then return true end
    destroyInfoDungeon(cid)

    local tabela = DUNGEONS_MISSIONCATEGORY[category]
    if not tabela then return true end

    for _, level in ipairs(DUNGEON_LEVELS) do
        cid:sendExtendedOpcode(DUNGEON_OPCODE_LEVEL, level .. "@")
    end

    for i, difficulty in ipairs(DUNGEON_DIFFICULTYS) do
        cid:sendExtendedOpcode(DUNGEON_OPCODE_DIFFICULTY, difficulty .. "@" .. i .. "@")
    end

    local data = {}

    for i, mission in ipairs(tabela) do
        for idx, item_id in ipairs(mission.items) do
            local item_count = mission.count_req[idx]
            local clientId = ItemType(item_id):getClientId()
            local realRewards = {}
            for _, reward in pairs(mission.recompense_list) do
                table.insert(realRewards, ItemType(reward):getClientId().. "&"..ItemType(reward):getName())
            end


            local missionData = table.concat({
                mission.looktype,
                mission.name,
                mission.players,
                i,
                clientId,
                item_count,
                mission.requiredLevel,
                ItemType(mission.requiredItem):getClientId(),
                mission.description,
                table.concat(realRewards, ":")
            }, "@")

            table.insert(data, missionData)
        end
    end

    local finalData = table.concat(data, "/")

    cid:sendExtendedOpcode(DUNGEON_OPCODE_MISSIONS, finalData)

    local party = cid:getParty()

    if party then
        for _, member in ipairs(party:getMembers()) do
            member:sendExtendedOpcode(DUNGEON_OPCODE_DESTROYINFO, "destroyInfo_team".."@")

            local leader = party:getLeader()
            if leader then
                member:sendExtendedOpcode(DUNGEON_OPCODE_PLAYERS_PARTY, leader:getName() .. (" (leader)" or "") .. "@" .. leader:getLevel() .. "@" .. leader:getOutfit().lookType .. "@")
            end

            for _, partyMember in ipairs(party:getMembers()) do
                member:sendExtendedOpcode(DUNGEON_OPCODE_PLAYERS_PARTY, partyMember:getName() .. "@" .. partyMember:getLevel() .. "@" .. partyMember:getOutfit().lookType .. "@")
            end
        end

        local leader = party:getLeader()
        if leader then
            leader:sendExtendedOpcode(DUNGEON_OPCODE_DESTROYINFO, "destroyInfo_team".."@")

            leader:sendExtendedOpcode(DUNGEON_OPCODE_PLAYERS_PARTY, leader:getName() .. (" (leader)" or "") .. "@" .. leader:getLevel() .. "@" .. leader:getOutfit().lookType .. "@")

            for _, partyMember in ipairs(party:getMembers()) do
                leader:sendExtendedOpcode(DUNGEON_OPCODE_PLAYERS_PARTY, partyMember:getName() .. "@" .. partyMember:getLevel() .. "@" .. partyMember:getOutfit().lookType .. "@")
            end
        end
    else
        cid:sendExtendedOpcode(DUNGEON_OPCODE_DESTROYINFO, "destroyInfo_team".."@")
        cid:sendExtendedOpcode(DUNGEON_OPCODE_PLAYERS_PARTY, cid:getName() .. "@" .. cid:getLevel() .. "@" .. cid:getOutfit().lookType .. "@")
    end

    return true
end

function sendRecompenseToPlayer(player, category, numeration)
    local tabela = DUNGEONS_MISSIONCATEGORY[category]
    if not tabela then
        return true
    end

    tabela = tabela[numeration]
    if not tabela or not tabela.recompense_list then
        return true
    end

    local recompenseData = {}
    for i = 1, #tabela.recompense_list do
        local itemId = tabela.recompense_list[i]
        local itemCount = tabela.count[i]
        local itemName = ItemType(itemId):getName()
        local clientId = ItemType(itemId):getClientId()

        table.insert(recompenseData, itemName .. ":" .. clientId .. ":" .. itemCount)
    end

    local recompenseString = table.concat(recompenseData, ";")

    local dungeonName = tabela.name or "Unknown Dungeon"
    player:sendExtendedOpcode(46, category .. "@" .. numeration .. "@" .. dungeonName .. "@" .. recompenseString)

    return true
end

function changeDungeonCategory(cid, category)
    if not cid:isPlayer() then return true end
    cid:sendExtendedOpcode(DUNGEON_OPCODE_DESTROYINFO, "destroyInfo_missions@")
    
    local tabela = DUNGEONS_MISSIONCATEGORY[category]
    if not tabela then return true end

    for _, mission in ipairs(tabela) do
        for idx, item_id in ipairs(mission.items) do
            local item_count = mission.count_req[idx]
            local item_name = ItemType(item_id):getName()
            local clientId = ItemType(item_id):getClientId()
            cid:sendExtendedOpcode(DUNGEON_OPCODE_MISSIONS, mission.looktype .. "@" .. mission.name .. "@" .. mission.players .. "@" .. idx .. "@" .. clientId .. "@" .. item_count .. "@")
        end
    end
    return true
end

function sendInviteToPlayer(cid, name)
    if not cid:isPlayer() then return true end

    if name == cid:getName() then
        cid:popupFYI("Voc? n?o pode convidar a si mesmo.")
        return true
    end

    local party = cid:getParty()
    if party then
        if party:getLeader() ~= cid then
            cid:popupFYI("Somente o l?der do grupo pode enviar convites.")
            return true
        end
    end

    local AreaX, AreaY = 14, 8
    local spectators = Game.getSpectators(cid:getPosition(), false, true, AreaX, AreaX, AreaY, AreaY)
    local playerFound = false

    for _, spectator in ipairs(spectators) do
        if spectator:isPlayer() and spectator:getName() == name then
            spectator:sendExtendedOpcode(DUNGEON_OPCODE_INVITE, cid:getName() .. "@" .. name .. "@")
            cid:popupFYI("Um convite foi enviado com sucesso para o jogador: " .. name .. ".")
            playerFound = true
            break
        end
    end

    if not playerFound then
        cid:popupFYI("O jogador " .. name .. " n?o est? pr?ximo o suficiente.")
    end

    return true
end

function acceptPlayerDungeon(cid, name)
    local player = Player(cid)
    if not player then
        return true
    end

    player:sendExtendedOpcode(DUNGEON_OPCODE_DESTROYINFO, "destroyInfo_team@")
	player:sendExtendedOpcode(DUNGEON_OPCODE_DESTROYINFO, "destroyInfo_dungeonPT".."@")

    local players = {}
    for _, v in ipairs(Game.getPlayers()) do
        if v:getName() == name then
            table.insert(players, v)
        end
    end

    if #players > 0 then
        for _, v in ipairs(players) do
            local party = v:getParty()
            if not party then
                party = Party(v)
            end

            party:addMember(player)
        end
    end

    local party = player:getParty()
    if party then
        local leader = party:getLeader()
        if leader then
            leader:sendExtendedOpcode(DUNGEON_OPCODE_DESTROYINFO, "destroyInfo_team".."@")

            leader:sendExtendedOpcode(DUNGEON_OPCODE_PLAYERS_PARTY, leader:getName() .. (" (leader)" or "") .. "@" .. leader:getLevel() .. "@" .. leader:getOutfit().lookType .. "@")

            for _, partyMember in ipairs(party:getMembers()) do
                if partyMember ~= leader then 
                    leader:sendExtendedOpcode(DUNGEON_OPCODE_PLAYERS_PARTY, partyMember:getName() .. "@" .. partyMember:getLevel() .. "@" .. partyMember:getOutfit().lookType .. "@")
                end
            end
        end

        for _, v in ipairs(party:getMembers()) do
            v:sendExtendedOpcode(DUNGEON_OPCODE_DESTROYINFO, "destroyInfo_team@")

            local leader = party:getLeader()
            if leader then
				v:sendExtendedOpcode(DUNGEON_OPCODE_PLAYERS_PARTY, leader:getName() .. (" (leader)" or "") .. "@" .. leader:getLevel() .. "@" .. leader:getOutfit().lookType .. "@")
            end

            for _, member in ipairs(party:getMembers()) do
                if member ~= leader then
					v:sendExtendedOpcode(DUNGEON_OPCODE_PLAYERS_PARTY, member:getName() .. "@" .. member:getLevel() .. "@" .. member:getOutfit().lookType .. "@")
                end
            end
        end
    end

    return true
end

function denyPlayerDungeon(cid, name)
    local player = Player(cid)
    if not player then
        return true
    end

    local players = {}
    for _, v in ipairs(Game.getPlayers()) do
        if v:getName() == name then
            table.insert(players, v)
        end
    end

    if #players > 0 then
        for _, v in ipairs(players) do
            v:popupFYI("O jogador: " .. player:getName() .. " negou seu pedido de dungeon.")
        end
    end
    return true
end

local function isAreaFree(fromPos, toPos)
    for x = fromPos.x, toPos.x do
        for y = fromPos.y, toPos.y do
            local tile = Tile(Position(x, y, fromPos.z))
            if tile then
                local thing = tile:getTopCreature()
                if thing and thing:isPlayer() then
                    return false
                end
            end
        end
    end
    return true
end

function isInRange(pos, fromPos, toPos)
    return pos.x >= fromPos.x and pos.x <= toPos.x
       and pos.y >= fromPos.y and pos.y <= toPos.y
       and pos.z >= fromPos.z and pos.z <= toPos.z
end

function getAreaKey(area)
    return string.format("%d,%d,%d_%d,%d,%d",
        area.fromPos.x, area.fromPos.y, area.fromPos.z,
        area.toPos.x,   area.toPos.y,   area.toPos.z
    )
end

function startDungeonTimer(areaId, durationMinutes)
    if DungeonTimers[areaId] and DungeonTimers[areaId].event then
        stopEvent(DungeonTimers[areaId].event)
    end

    local duration = durationMinutes * 60
    DungeonTimers[areaId] = {
        remaining = duration,
        event = nil
    }

    local function tick()
        if not DungeonTimers[areaId] then
            return
        end

        DungeonTimers[areaId].remaining = DungeonTimers[areaId].remaining - 1

        if DungeonTimers[areaId].remaining <= 0 then
            DungeonTimers[areaId] = nil
            return
        end

        DungeonTimers[areaId].event = addEvent(tick, 1000)
    end

    DungeonTimers[areaId].event = addEvent(tick, 1000)
end

function getDungeonRemaining(areaId)
    if DungeonTimers[areaId] then
        return DungeonTimers[areaId].remaining
    end
    return 0
end

function enterDungeon(cid, category, numeration)
    if not cid or not cid:isPlayer() then
        return false
    end

    local tabela = DUNGEONS_MISSIONCATEGORY[category]
    if not tabela then return false end

    tabela = tabela[numeration]
    if not tabela then return false end

    local requiredLevel = tabela.requiredLevel
    if cid:getLevel() < requiredLevel then
		cid:popupFYI("Voc? precisa de level " .. requiredLevel .. " para entrar nesta dungeon.")
        return false
    end

    local tile = Tile(cid:getPosition())
    if tile and not tile:hasFlag(TILESTATE_PROTECTIONZONE) then
		cid:popupFYI("Voc? n?o est? em uma ?rea protegida (PZ).")
        return false
    end
    
    if cid:getItemCount(tabela.requiredItem) < 1 then
		cid:popupFYI("Voc? precisa possuir o item: " .. getItemNameById(tabela.requiredItem) .. " para iniciar esta dungeon.")
        return false
    end

    local party = cid:getParty()
    local requiredPlayers = tabela.players
    local AreaX, AreaY = 14, 8

    local membersNearby = {}
    if not party then
        table.insert(membersNearby, cid)
    else
        local spectators = Game.getSpectators(cid:getPosition(), false, true, AreaX, AreaX, AreaY, AreaY)
        for _, spec in ipairs(spectators) do
            if spec:isPlayer() and spec:getParty() == party then
                table.insert(membersNearby, spec)
            end
        end
    end

    for _, member in ipairs(membersNearby) do
        if member:getItemCount(tabela.requiredItem) < 1 then
			cid:popupFYI("O " .. member:getName() .. " n?o possui o item necess?rio: " .. getItemNameById(tabela.requiredItem))
            return false
        end
        if member:getLevel() < requiredLevel then
			cid:popupFYI("O " .. member:getName() .. " precisa de level " .. requiredLevel .. " para entrar na dungeon.")
            return false
        end
        local memberTile = Tile(member:getPosition())
        if not (memberTile and memberTile:hasFlag(TILESTATE_PROTECTIONZONE)) then
			cid:popupFYI("O " .. member:getName() .. " precisa estar em uma ?rea protegida (PZ) para entrar na dungeon.")
            return false
        end
    end

    if #membersNearby > requiredPlayers then
		cid:popupFYI("O limite de players para iniciar essa dungeon ? de ".. requiredPlayers ..".")
        return false
    end

    local chosenArea = nil
    for _, area in ipairs(tabela.areas) do
        if isAreaFree(area.fromPos, area.toPos) then
            chosenArea = area
            break
        end
    end

    if not chosenArea then
		cid:popupFYI("Todas as inst?ncias desta dungeon est?o ocupadas. Aguarde um espa?o livre.")
        return false
    end

    local memberIds = {}
    for _, member in ipairs(membersNearby) do
        member:removeItem(tabela.requiredItem, 1)
        originalPositions[member:getId()] = member:getPosition()
        table.insert(memberIds, member:getId())
    end

    for _, memberId in ipairs(memberIds) do
        local member = Player(memberId)
        if member then
            member:teleportTo(chosenArea.teleportPos)
            member:sendTextMessage(MESSAGE_INFO_DESCR, "Voc? entrou na dungeon: " .. tabela.name .."")
        end
    end

    if tabela.looktype then
        Game.createMonster(tabela.name, chosenArea.summonPos, true, true)
    end

    local dungeonDuration = tabela.duration or 15
    local durationSeconds = dungeonDuration * 60
    local areaKey = getAreaKey(chosenArea)

    if DungeonTimers[areaKey] and DungeonTimers[areaKey].event then
        stopEvent(DungeonTimers[areaKey].event)
    end

    startDungeonTimer(areaKey, dungeonDuration)

    for _, memberId in ipairs(memberIds) do
        local member = Player(memberId)
        if member then
            member:sendExtendedOpcode(DUNGEON_OPCODE_TEXT, "Dungeon iniciada!")
            local minutes = math.floor(durationSeconds / 60)
            local seconds = durationSeconds % 60
            member:sendExtendedOpcode(DUNGEON_OPCODE_ReceiveStart, string.format("%02d:%02d", minutes, seconds))
        end
    end

    DungeonTimers[areaKey].event = addEvent(function()
        for _, memberId in ipairs(memberIds) do
            local member = Player(memberId)
            if member and member:isPlayer() then
                local pos = member:getPosition()
                if isInRange(pos, chosenArea.fromPos, chosenArea.toPos) then
                    local originalPos = originalPositions[memberId]
                    if originalPos then
                        member:teleportTo(originalPos)
                        member:sendTextMessage(MESSAGE_EVENT_ADVANCE, "O tempo da dungeon expirou.")
                    end
                end
            end
        end
        DungeonTimers[areaKey] = nil
    end, durationSeconds * 1000)

    return true
end