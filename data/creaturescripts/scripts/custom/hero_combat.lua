-- ============================================================
--  HERO COMBAT — aplica os bonus de evolucao do sistema de vocacoes
--  (game_heroes). Le os storages gravados pelo heroes_opcode.lua:
--    50400 = % de dano extra do personagem ativo (classe damage)
--    50401 = % de chance de dodge (classe tank)
--  Vida/mana sao aplicados via condicao no heroes_opcode (nao aqui).
-- ============================================================

local STORAGE_BONUS_DAMAGE = 50400
local STORAGE_BONUS_DODGE  = 50401

function onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
    if not creature then
        return primaryDamage, primaryType, secondaryDamage, secondaryType
    end

    -- DODGE: defensor (player) tem chance de esquivar TODO o dano
    if creature:isPlayer() and primaryType ~= COMBAT_HEALING then
        local dodge = math.max(0, creature:getStorageValue(STORAGE_BONUS_DODGE))
        if dodge > 0 and math.random(1, 100) <= dodge then
            creature:sendTextMessage(MESSAGE_STATUS_SMALL, "DODGE!")
            -- loga no chat tambem (pra testar/ver) - troque/remova depois se quiser
            creature:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
                string.format("[DODGE %d%%] Voce esquivou o ataque!", dodge))
            creature:getPosition():sendMagicEffect(CONST_ME_POFF)
            return 0, primaryType, 0, secondaryType
        end
    end

    -- DANO: atacante (player) aumenta o dano pelo % do personagem ativo
    if attacker and attacker:isPlayer() and primaryType ~= COMBAT_HEALING then
        local dmg = math.max(0, attacker:getStorageValue(STORAGE_BONUS_DAMAGE))
        if dmg > 0 then
            local mult = 1 + (dmg / 100)
            primaryDamage   = math.floor(primaryDamage * mult)
            secondaryDamage = math.floor(secondaryDamage * mult)
        end
    end

    return primaryDamage, primaryType, secondaryDamage, secondaryType
end
