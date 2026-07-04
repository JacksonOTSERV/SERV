function onStepIn(creature, item, position, fromPosition)
    if not creature:isPlayer() then
        return true
    end

    local player = creature
    local guid = player:getGuid()
    local nome = player:getName()

    local valorPago = TorneioData.pagamentos[guid]
    if valorPago then
        TorneioData.total = math.max(TorneioData.total - valorPago, 0)

        TorneioData.pagamentos[guid] = nil

        player:sendTextMessage(MESSAGE_EVENT_ADVANCE,
            string.format("Voc� saiu da �rea do torneio. Sua inscri��o foi cancelada e %d gold foram enviados ao mailbox.", valorPago))
			
		local inbox = player:getInbox()
		inbox:addItem(13599, 10, true, 1)
    end

    return true
end