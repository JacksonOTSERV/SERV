-- data/talkactions/scripts/directionalspell.lua

-- CONFIG: Mapeamento de Vários nomes para o mesmo arquivo
local SPELL_SCRIPTS = {
    ["impact"]         = "data/spells/scripts/Canudos/dash impact.lua",
    ["spell cam"]      = "data/spells/scripts/Support/spellcam.lua",
}

function onSay(player, words, param)
    local parts = param:split("|")
    if #parts ~= 2 then
        return false
    end
    
    local spellName = parts[1]:lower() -- Converte para minúsculo
    local angle = tonumber(parts[2]) or 0

    -- DEBUG: Mostra no console do servidor o que chegou
    print(">> Directional Request: [" .. spellName .. "] Angle: " .. angle)
    
    -- 1. Salva o ângulo
    if player.setDirectionalSpellAngle then
        player:setDirectionalSpellAngle(angle)
    else
        player:setStorageValue(999999, angle)
    end
    _directionalAngle = angle  -- global temporário acessível pelo script carregado
    
    -- 2. Identifica e executa o script da spell
    local scriptPath = SPELL_SCRIPTS[spellName]
    
    if scriptPath then
        print(">> Carregando script: " .. scriptPath)
        local f = loadfile(scriptPath)
        if f then
            setfenv(f, getfenv()) 
            f() 
            
            if onCastSpell then
                print(">> Executando onCastSpell...")
                onCastSpell(player, Variant(0))
                player:say(spellName, TALKTYPE_MONSTER_SAY) -- Confirmação visual
            else
                print("[ERRO] Script carregado mas sem onCastSpell: " .. scriptPath)
                player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, "Erro no script da spell (sem onCastSpell)")
            end
            
            onCastSpell = nil
        else
            print("[ERRO] Falha ao ler arquivo: " .. scriptPath)
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, "Arquivo da spell nao encontrado.")
        end
    else
        print(">> Spell nao encontrada no mapa SPELL_SCRIPTS. Fallback para fala normal.")
        doCreatureSay(player, spellName, TALKTYPE_SAY)
    end
    
    return false
end