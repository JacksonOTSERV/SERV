local combat = Combat()
combat:setParameter(COMBAT_PARAM_CREATEITEM, 13576)
combat:setParameter(COMBAT_PARAM_AGGRESSIVE, false)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, 38)

local ret = nil

function onCastSpell(creature, variant)
    local waittime = 1
    local storage = 208
    local player = Player(creature)

    if player:getStorageValue(storage) - os.time() > 0 then
        return false
    end

    if player:getItemCount(13578) >= 1 then
        ret = combat:execute(creature, variant)
        if ret then
            local mWall = Tile(variant:getPosition()):getItemById(13576)
            if mWall then
                player:setStorageValue(storage, os.time() + waittime)
                return ret and player:removeItem(13578, 1)
            end
        end
    end
    return false
end
