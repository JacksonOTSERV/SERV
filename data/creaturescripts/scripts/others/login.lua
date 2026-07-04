local blessCount = 5
local BUFF_STORAGE = 4343

local function playerHasAllBlessings(player)
    for i = 1, blessCount do
        if not player:hasBlessing(i) then
            return false
        end
    end
    return true
end

function onLogin(player)
	player:registerEvent("ExtendedPing")
	-- Login messages
	player:openChannel(8)
	if player:getLevel() < 500 then
		local weaponLeft = player:getSlotItem(CONST_SLOT_LEFT)
		local weaponRight = player:getSlotItem(CONST_SLOT_RIGHT)
		if weaponLeft and weaponLeft:getId() == 13603 then
			weaponLeft:remove()
		end

		if weaponRight and weaponRight:getId() == 13603 then
			weaponRight:remove()
		end
	end

    local buffLevel = player:getStorageValue(BUFF_STORAGE)
	if buffLevel > 0 then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Seu n�vel de buff upgrade atual �: +" .. buffLevel .. ".")
	end

	if player:isPremium() then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "Aproveite seus benef�cios exclusivos por ser um jogador premium.")
	else
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "Torne-se Premium para obter mais vantagens no jogo.")
	end

	if player:getLevel() < 150 then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "Voc� � um jogador de level menor que 150, portanto, n�o dropa itens e recebeu free blessing. Atente-se.")
		if not playerHasAllBlessings(player) then
			for i = 1, blessCount do
				player:addBlessing(i)
			end
		end
		player:getPosition():sendMagicEffect(14, player)
		player:say("[BLESS]", TALKTYPE_MONSTER_SAY)
	end
	
	if playerHasAllBlessings(player) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Voc� est� protegido com todas as blessings.")
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Aten��o: voc� n�o possui todas as blessings! Considere adquiri-las para evitar perdas.")
	end
	
	local rebornLevel = player:getStorageValue(4241)
	if rebornLevel > 0 then
		local bonusPercent = (rebornLevel / 600) * 25
		if bonusPercent > 25 then
			bonusPercent = 25
		end
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format(
			"Voc� possui um b�nus permanente de %.2f%% de EXP devido ao seu REBORN (feito no level %d). Agora voc� poder� subir at� level 800.",
			bonusPercent, rebornLevel
		))
	else
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, 
			"Sabia que voc� pode dar REBORN a partir do level 400 e ganhar EXP extra para sempre? Exemplo: no level 600, s�o +25% de EXP permanente! Ap�s o reborn, poder� subir at� level 800 (limite sem reborn: 600)."
		)
	end
	
	if DragonOrbs then
		for _, orbData in pairs(DragonOrbs) do
			if orbData and orbData.pos then
				player:sendTextMessage(
					MESSAGE_STATUS_CONSOLE_BLUE,
					"[ESFERA DO DRAG�O] A " .. orbData.orbName ..
					" ainda est� em " .. orbData.areaName .. " pois ningu�m a encontrou ainda!"
				)
			end
		end
	end
	
	if player:getStorageValue(32323) == 1 then
		player:removeOutfit(1265)
		local inbox = player:getInbox()
		inbox:addItem(13579, 1, true, 1)
		inbox:addItem(13580, 1, true, 1)
		inbox:addItem(13581, 1, true, 1)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Voc� foi o Deus da Destrui��o dessa temporada e recebeu o set god of destruction (dura��o de 15 dias) em sua mailbox! use com sabedoria.")
		player:setStorageValue(32323, 0)
	end
	
	if player:getStorageValue(8792) == 1 then	
		local lugares = {
			{681, 397, 7},
			{679, 395, 7},
			{680, 398, 7}
		}
		local lugar = lugares[math.random(1, #lugares)]
		player:teleportTo({x = lugar[1], y = lugar[2], z = lugar[3]}, true)
		player:setStorageValue(8792, 0)
	end

	-- Premium AutoLoot
    if not player:isPremium() then
        local slotsUsed = 0

        for i = AUTOLOOT_STORAGE_START, AUTOLOOT_STORAGE_END do
            if player:getStorageValue(i) > 0 then
                slotsUsed = slotsUsed + 1
            end
        end

        if slotsUsed > 7 then
            for i = AUTOLOOT_STORAGE_START, AUTOLOOT_STORAGE_END do
                player:setStorageValue(i, 0)
            end

            player:sendTextMessage(MESSAGE_STATUS_WARNING, "Voc� n�o � mais premium e tinha mais de 7 itens na sua lista de autoloot. Sua lista foi limpa automaticamente.")
        end
    end
	
	Deus_system(player)

	-- Logout
	player:setStorageValue(1000, 5 + os.time())
	player:setStorageValue(20000, 0)
	
	-- Registros
	player:registerEvent("PlayerDeath")
	player:registerEvent("DropLoot")
	player:registerEvent("PlayerLogout")
	player:registerEvent("Outfits")
	player:registerEvent("DropLoot")
	player:registerEvent("SkullCheck")
	player:registerEvent("AreaMonsterTeleport")
	player:registerEvent("TaskKill")
	player:registerEvent("AntiIk")
	player:registerEvent("Kyushu")
	player:registerEvent("ArenaPvp")
	player:registerEvent("ShenlongDeath")
	player:registerEvent("Monster_hunt")
	player:registerEvent("Dungeon")
	player:registerEvent("DungeonTimer")
	player:registerEvent("GetUUID")
	player:registerEvent("BoostSystem")
	player:registerEvent("AutolootOpcode")
	player:registerEvent("SpellbarOpcode")
	player:registerEvent("EmoteOpcode")
	player:registerEvent("AutoEquipOpcode")
	player:registerEvent("MenuOpcode")
	player:registerEvent("MenuLogin")
	player:registerEvent("PowerUpOpcode")
	player:registerEvent("PowerUpPassiveLogin")
	player:registerEvent("PowerUpPassiveAdvance")
	player:registerEvent("PowerUpCombat")
	player:registerEvent("BankOpcode")
	player:registerEvent("DonationGoalsOpcode")
	player:registerEvent("CraftOpcode")
	player:registerEvent("GameTasksOpcode")
	player:registerEvent("GameTasksKill")
	player:registerEvent("GameTasksLogin")
	player:registerEvent("GameShopOpcode")
	player:registerEvent("GameShopLogin")
	player:registerEvent("LootBoxOpcode")
	player:registerEvent("HeroesOpcode")
	player:registerEvent("OutfitsDeath")
	player:registerEvent("HeroCombat")

	-- reaplica os bonus de evolucao do personagem ativo (condicoes nao
	-- sobrevivem ao logout)
	if heroesReapplyBonuses then
		heroesReapplyBonuses(player)
	end

	return true
end


