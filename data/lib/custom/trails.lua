-- ============================================================
--  CATALOGO DE TRAILS (efeito que sai ATRAS do player ao andar)
--  Lugar UNICO do servidor. Pra ADICIONAR um trail: poe uma linha aqui
--  com o effect ID + nome. (o cliente tem uma lista igual em
--  modules/game_trails/trails.lua que precisa ter os MESMOS ids/effects)
--
--  effect = ID do magic effect (numerico). Ex: CONST_ME_* ou custom (1978...)
-- ============================================================
TrailEffects = {
    [1] = { effect = 1978, name = "Default" }, -- custom
    [2] = { effect = 36,   name = "Red"     }, -- CONST_ME_HITBYFIRE
    [3] = { effect = 12,   name = "Blue"    }, -- CONST_ME_MAGIC_BLUE
    [4] = { effect = 13,   name = "Green"   }, -- CONST_ME_MAGIC_GREEN
    -- [5] = { effect = SEU_EFFECT_ID, name = "Nome" },  <-- adicione aqui
}
