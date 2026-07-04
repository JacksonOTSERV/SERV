function onThink(interval, lastExecution)
local mensagens ={
[[DBO TAIKAI TV: Se torne um jogador premium para aproveitar 100% da experiencia.
]]
}
Game.broadcastMessage(mensagens[math.random(1,table.maxn(mensagens))], 22)
return true
end