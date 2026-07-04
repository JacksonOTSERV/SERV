function onUse(player, item, fromPosition, target, toPosition, isHotkey)
    return giveRewardOncePerHWID(player, 1, function(p)
        p:addItem(2160, 10)
    end, 24)
end