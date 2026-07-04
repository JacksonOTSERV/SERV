local STORAGE_LANGUAGE = 45001

function onSay(player, words, param)
    local lang = param:lower()
    
    if lang == "pt" or lang == "portugues" or lang == "br" then
        player:setStorageValue(STORAGE_LANGUAGE, 0)
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Idioma alterado para Portugues.")
        return false
    elseif lang == "en" or lang == "english" or lang == "ingles" then
        player:setStorageValue(STORAGE_LANGUAGE, 1)
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Language changed to English.")
        return false
    else
        player:sendTextMessage(MESSAGE_STATUS_SMALL, "Command usage: !language PT or !language EN")
        return false
    end
end
