-- ============================================================
-- MONSTER LEVEL SYSTEM (otimizado)
-- Player so pode atacar monsters dentro de [level - DOWN, level + UP]
-- Lookup O(1) por nome. Sem mexer no .xml do monster.
-- ============================================================

-- Faixa relativa ao level do player (editavel — reload scripts)
MLEVEL_RANGE_DOWN = 50  -- pode matar ate 50 niveis ABAIXO do seu
MLEVEL_RANGE_UP   = 50  -- pode matar ate 50 niveis ACIMA do seu

-- Anti-spam da mensagem de bloqueio (segundos)
MLEVEL_MSG_COOLDOWN = 30

-- Tabela nome→level. Monster fora da tabela = sem restricao (level 0).
-- Adicione seus monsters aqui.
MONSTER_LEVELS = {
     ["Rat"]        = 1,
     ["Wolf"]       = 10,
     ["Dragon"]     = 80,
     ["Shenlong"]   = 300,
}

-- ts do ultimo aviso por player (anti-spam, em memoria)
MLEVEL_LASTMSG = MLEVEL_LASTMSG or {}

-- Retorna true se player pode atacar o monster (ou se monster sem level).
-- Otimizado: 1 lookup + 2 compares, early-out.
function canAttackMonsterLevel(player, monsterName)
    local mlvl = MONSTER_LEVELS[monsterName]
    if not mlvl then
        return true -- monster sem level definido = livre
    end
    local plvl = player:getLevel()
    return mlvl >= (plvl - MLEVEL_RANGE_DOWN) and mlvl <= (plvl + MLEVEL_RANGE_UP), mlvl
end

-- Aviso com cooldown anti-spam
function notifyMonsterLevelBlock(player, monsterName, mlvl)
    local pid = player:getId()
    local now = os.time()
    local last = MLEVEL_LASTMSG[pid]
    if last and (now - last) < MLEVEL_MSG_COOLDOWN then
        return
    end
    MLEVEL_LASTMSG[pid] = now
    player:sendTextMessage(MESSAGE_STATUS_WARNING,
        string.format("Esse %s (nivel %d) esta fora da sua faixa. Voce so pode atacar monsters entre nivel %d e %d.",
            monsterName, mlvl,
            math.max(0, player:getLevel() - MLEVEL_RANGE_DOWN),
            player:getLevel() + MLEVEL_RANGE_UP))
end
