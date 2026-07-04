local PROGRESS_TIME = 5 * 1000
local activeExtractions = {}
local playersExtracting = {}

local mailItems = {
    ["Esfera de 1 estrela"] = 13597,
    ["Esfera de 2 estrelas"] = 13596,
    ["Esfera de 3 estrelas"] = 13595,
    ["Esfera de 4 estrelas"] = 13594,
    ["Esfera de 5 estrelas"] = 13593,
    ["Esfera de 6 estrelas"] = 13592,
    ["Esfera de 7 estrelas"] = 13591,
}

function onUse(player, item, fromPosition, itemEx, toPosition)
    local playerId = player:getId()
    local startPos = player:getPosition()
    local endTime = os.mtime() + PROGRESS_TIME
    local itemUid = item:getUniqueId()
    local itemName = ItemType(item.itemid):getName()

    if playersExtracting[playerId] then
        player:sendCancelMessage("Voc� j� est� extraindo algo no momento!")
        return true
    end

    playersExtracting[playerId] = true

    if not activeExtractions[itemUid] then
        activeExtractions[itemUid] = { players = {}, completed = false }
    end
    activeExtractions[itemUid].players[playerId] = true

    player:sendProgressbar(PROGRESS_TIME, true)
    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Voc� come�ou a extrair a " .. itemName .. "...")

    local function cancelExtraction(pl, itemName)
        if pl then
            pl:sendProgressbar(0, true)
            pl:sendTextMessage(MESSAGE_STATUS_WARNING, "Sua extra��o da " .. itemName .. " foi cancelada!")
        end
        playersExtracting[playerId] = nil
    end

    local function checkProgress(pId, startPos, endTime, itemUid)
        local pl = Player(pId)
        local extraction = activeExtractions[itemUid]
        if not pl or not extraction or not extraction.players[pId] then
            playersExtracting[pId] = nil
            return
        end

        if os.mtime() >= endTime then
            if pl:getPosition() == startPos and item:isItem() then
                if not extraction.completed then
					extraction.completed = true
					local areaName = "Desconhecida"
					local itemPos = item:getPosition()
					
					for key, orbData in pairs(DragonOrbs) do
						if orbData and orbData.itemId == item.itemid and
						   orbData.pos.x == itemPos.x and
						   orbData.pos.y == itemPos.y and
						   orbData.pos.z == itemPos.z then
							areaName = orbData.areaName
							
							if orbData.extraItem and orbData.extraItem:isItem() then
								orbData.extraItem:remove()
							end
							
							DragonOrbs[key] = nil
							break
						end
					end

					Game.broadcastMessage(
						"[ESFERA DO DRAG�O] O jogador " .. pl:getName() .. 
						" finalizou a extra��o da " .. itemName .. " em: " .. areaName .. "!",
						MESSAGE_EVENT_ADVANCE
					)

                    local inbox = pl:getInbox()
                    if inbox then
                        local mailItemId = mailItems[itemName]
                        if mailItemId then
                            inbox:addItem(mailItemId, 1, true, 1)
                            pl:sendTextMessage(MESSAGE_INFO_DESCR, "A " .. itemName .. " foi enviada para o seu mailbox!")
							setPresencePoints(pl, 1)
                        end
                    end

                    item:remove()

                    for otherId, _ in pairs(extraction.players) do
                        if otherId ~= pId then
                            cancelExtraction(Player(otherId), itemName)
                        end
                        playersExtracting[otherId] = nil
                    end

                    playersExtracting[pId] = nil
                    activeExtractions[itemUid] = nil
                end
            else
                cancelExtraction(pl, itemName)
                extraction.players[pId] = nil
            end
            return
        end

        if pl:getPosition() ~= startPos then
            cancelExtraction(pl, itemName)
            extraction.players[pId] = nil
            return
        end

        addEvent(checkProgress, 100, pId, startPos, endTime, itemUid)
    end

    addEvent(checkProgress, 100, playerId, startPos, endTime, itemUid)
    return true
end