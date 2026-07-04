local VALOR_INSCRICAO = 10000000
local LEVEL_MINIMO = 300
local TORNEIO_POS_INICIAL = Position(1350, 600, 7)
local POS_EXCLUSAO = Position(95, 187, 7)
local TOURNAMENT_MODAL_ID = 30001

local TournamentChoices = {}

function buildTournamentModal()
    local modal = ModalWindow(TOURNAMENT_MODAL_ID, "Inscrição Torneio PvP", "Pague o valor da inscrição!")

    modal:addButton(1, "Confirmar")
    modal:addButton(2, "Fechar")
    modal:setDefaultEscapeButton(2)
    modal:setDefaultEnterButton(1)

    TournamentChoices = {}
    local choiceText = string.format("%d money -> Participar do torneio", VALOR_INSCRICAO)
    modal:addChoice(1, choiceText)
    TournamentChoices[1] = 1

    return modal
end

local creatureEvent = CreatureEvent("torneioModal")
function creatureEvent.onModalWindow(player, modalId, buttonId, choiceId)
    if modalId ~= TOURNAMENT_MODAL_ID then
        return true
    end

    if buttonId == 1 then
        local tradeIndex = TournamentChoices[choiceId]
        if tradeIndex then
            if TorneioData.pagamentos[player:getGuid()] then
                player:sendTextMessage(MESSAGE_STATUS_WARNING, "Você já está inscrito no torneio!")
                return true
            end

            if player:getMoney() < VALOR_INSCRICAO then
                player:sendTextMessage(MESSAGE_STATUS_WARNING, "Você não possui dinheiro suficiente para se inscrever no torneio.")
                return true
            end

            player:removeMoney(VALOR_INSCRICAO)

            TorneioData.registrarPagamento(player, VALOR_INSCRICAO)

            if player:getLevel() < LEVEL_MINIMO then
                player:teleportTo(POS_EXCLUSAO)
                player:sendCancelMessage("Seu level é menor que 300. Você não pode participar do evento.")
            else
                player:teleportTo(TORNEIO_POS_INICIAL)
                player:sendTextMessage(MESSAGE_EVENT_ADVANCE,
                    "Você se inscreveu no torneio PvP! Aguarde o início do evento.")
            end
        end
    end

    return true
end
creatureEvent:register()

local loginEvent = CreatureEvent("torneioRegisterModal")
function loginEvent.onLogin(player)
    player:registerEvent("torneioModal")
    return true
end
loginEvent:register()