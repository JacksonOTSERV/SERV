local config = {
	marks = {
		{mark = MAPMARK_TEMPLE, pos = Position(396, 697, 7), desc = "Esfera De 1 Estrela"},
		{mark = MAPMARK_TEMPLE, pos = Position(428, 567, 7), desc = "Esfera De 2 Estrelas"},
		{mark = MAPMARK_TEMPLE, pos = Position(276, 843, 7), desc = "Esfera De 3 Estrelas"},
		{mark = MAPMARK_TEMPLE, pos = Position(483, 381, 5), desc = "Esfera De 4 Estrelas"},
		{mark = MAPMARK_TEMPLE, pos = Position(178, 350, 5), desc = "Esfera De 5 Estrelas"},
		{mark = MAPMARK_TEMPLE, pos = Position(37, 342, 7), desc = "Esfera De 6 Estrelas"},
		{mark = MAPMARK_TEMPLE, pos = Position(100, 98, 7), desc = "Esfera De 7 Estrelas"}
	}
}

function onUse(player, item, fromPosition, target, toPosition, isHotkey)
	for _, m in pairs(config.marks) do
		player:addMapMark(m.pos, m.mark, m.desc or "")
	end
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Agora você tem as localizações das esferas no seu mini mapa.")
	return true
end