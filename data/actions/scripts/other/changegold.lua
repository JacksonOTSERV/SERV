function onUse(player, item, fromPosition, target, toPosition, isHotkey)
    local itemId = item:getId()
    local itemCount = item:getCount()

    if itemId == 2160 then
        if itemCount >= 100 then
            if item:remove(100) then
                player:addItem(13599, 1) -- 1 diamond
                player:say("$$$", TALKTYPE_MONSTER_SAY, true)
            end
        else
            if item:remove(1) then
                player:addItem(2152, 100) -- 100 platinum
                player:say("$$$", TALKTYPE_MONSTER_SAY, true)
            end
        end

    elseif itemId == 2152 then
        if itemCount >= 100 then
            if item:remove(100) then
                player:addItem(2160, 1) -- 1 crystal
                player:say("$$$", TALKTYPE_MONSTER_SAY, true)
            end
        end

    elseif itemId == 13599 then
        if item:remove(1) then
            player:addItem(2160, 100) -- 100 crystals
            player:say("$$$", TALKTYPE_MONSTER_SAY, true)
        end
    end

    return true
end