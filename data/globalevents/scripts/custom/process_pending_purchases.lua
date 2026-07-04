local db = db

local transformationOutfits = {
    [100000] = {name = "Tapion",       lookType = 1211, vocationId = 14},
    [100001] = {name = "Chilled",      lookType = 1155, vocationId = 15},
    [100002] = {name = "Kagome",       lookType = 1163, vocationId = 16},
    [100003] = {name = "Zaiko",        lookType = 1229, vocationId = 17},
    [100004] = {name = "King Vegeta",  lookType = 1180, vocationId = 18},
    [100005] = {name = "Vegetto",      lookType = 1217, vocationId = 19},
    [100006] = {name = "Kame",         lookType = 1175, vocationId = 20},
    [100007] = {name = "Shenron",      lookType = 1197, vocationId = 21},
	[100008] = {name = "Jiren",        lookType = 1001, vocationId = 25}
}

local outfitSkins = {
    [200001] = {outfitId = 1245, name = "Goku Justice"},
    [200002] = {outfitId = 1254, name = "Vegeta Justice"},
    [200003] = {outfitId = 1243, name = "Piccolo Justice"},
    [200004] = {outfitId = 1240, name = "C17 Justice"},
    [200005] = {outfitId = 1244, name = "Gohan Justice"},
    [200006] = {outfitId = 1253, name = "Trunks Justice"},
    [200007] = {outfitId = 1242, name = "Cell Justice"},
    [200008] = {outfitId = 1248, name = "Freeza Justice"},
    [200009] = {outfitId = 1238, name = "Buu Justice"},
    [200010] = {outfitId = 1241, name = "Broly Justice"},
    [200011] = {outfitId = 1246, name = "Goten Justice"},
    [200012] = {outfitId = 1250, name = "Kuririn Justice"},
    [200013] = {outfitId = 1247, name = "Janemba Justice"},
    [200014] = {outfitId = 1252, name = "Tapion Justice"},
    [200015] = {outfitId = 1258, name = "Chilled Justice"},
    [200016] = {outfitId = 1239, name = "Kagome Justice"},
    [200017] = {outfitId = 1256, name = "Zaiko Justice"},
    [200018] = {outfitId = 1249, name = "King Vegeta Justice"},
    [200019] = {outfitId = 1255, name = "Vegetto Justice"},
    [200020] = {outfitId = 1251, name = "Kame Justice"},
    [200021] = {outfitId = 1257, name = "Shenron Justice"},
	[200022] = {outfitId = 1280, name = "Kaioh Justice"},
	[200023] = {outfitId = 1267, name = "Black Justice"},
	[200024] = {outfitId = 1268, name = "Zamasu Justice"},
	[200025] = {outfitId = 1269, name = "Jiren Justice"}
}

function onThink(interval)
    local resultId = db.storeQuery("SELECT id, player_name, item_id FROM pending_purchases")
    if not resultId then
        return true
    end

    repeat
        local id = result.getNumber(resultId, "id")
        local playerName = result.getString(resultId, "player_name")
        local itemId = result.getNumber(resultId, "item_id")

        local player = Player(playerName)
        if player then
            if itemId == 0 or itemId == 1 or itemId == 2 then
                local days = itemId == 0 and 30 or (itemId == 1 and 60 or 90)
                player:addPremiumDays(days)
                db.query("DELETE FROM pending_purchases WHERE id = " .. id)
                player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Voc? recebeu +" .. days .. " dias de premium account adquiridos no shop!")

            elseif transformationOutfits[itemId] then
                local data = transformationOutfits[itemId]
                local vocationId = data.vocationId
                local lookType = data.lookType
                local currentVocationName = player:getVocation():getName()

				if vocationOutfits[currentVocationName] then
					for _, outfitData in pairs(vocationOutfits[currentVocationName]) do
						if type(outfitData) == "table" and player:hasOutfit(outfitData.id) then
							player:removeOutfit(outfitData.id)
						end
					end
				end

                doPlayerSetVocation(player, vocationId)
                doCreatureChangeOutfit(player, {lookType = lookType})
                player:setStorageValue(14389, lookType)

				local newVocationName = player:getVocation():getName()
				if vocationOutfits[newVocationName] then
					local playerLevel = player:getLevel()
					for level, outfitData in pairs(vocationOutfits[newVocationName]) do
						if type(outfitData) == "table" and playerLevel >= level and not player:hasOutfit(outfitData.id) then
							player:addOutfit(outfitData.id)
						end
					end
				end
			
				local weaponLeft = player:getSlotItem(CONST_SLOT_LEFT)
				local weaponRight = player:getSlotItem(CONST_SLOT_RIGHT)
				if weaponLeft and weaponLeft:getId() == 13603 then
					weaponLeft:remove()
				end

				if weaponRight and weaponRight:getId() == 13603 then
					weaponRight:remove()
				end

                player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Voc? foi transformado em " .. data.name .. "!")
                db.query("DELETE FROM pending_purchases WHERE id = " .. id)

			elseif itemId >= 200001 and itemId <= 200025 then
				local skinData = outfitSkins[itemId]
				if skinData then
					local outfitId = skinData.outfitId
					local skinName = skinData.name

					if outfitId ~= 0 then
						if not player:hasOutfit(outfitId) then
							player:addOutfit(outfitId)
							player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Voc? recebeu a skin " .. skinName .. " no seu menu de roupas!")
						else
							local accountId = player:getAccountId()
							db.query("UPDATE accounts SET premium_points = premium_points + 10 WHERE id = " .. accountId)
							player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Voc? j? possui a skin " .. skinName .. ". Seus 10 premium points foram devolvidos.")
						end
					else
						player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "A skin " .. skinName .. " ainda n?o est? dispon?vel.")
					end
					db.query("DELETE FROM pending_purchases WHERE id = " .. id)
				end

            else
                local item = player:getInbox():addItem(itemId, 1, true, 1)
                if item then
                    db.query("DELETE FROM pending_purchases WHERE id = " .. id)
                    local itemName = ItemType(itemId):getName() or "desconhecido"
                    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Voc? recebeu o item " .. itemName .. " adquirido no shop dentro da sua mailbox (fica no depot)!")
                end
            end
        end
    until not result.next(resultId)

    result.free(resultId)
    return true
end