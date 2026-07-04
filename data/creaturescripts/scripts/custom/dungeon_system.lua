function string:explode(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

function onExtendedOpcode(player, opcode, buffer)
    if opcode == 44 then
        local param = buffer:explode("@")
        local type = tostring(param[1])
        sendDungeon(player, type)
    elseif opcode == 48 then
        local param = buffer:explode("@")
        local name = tostring(param[1])
        acceptPlayerDungeon(player, name)
    elseif opcode == 45 then
        local param = buffer:explode("@")
        local category = tostring(param[1])
        changeDungeonCategory(player, category)
    elseif opcode == 49 then
        local param = buffer:explode("@")
        local name = tostring(param[1])
        denyPlayerDungeon(player, name)
    elseif opcode == 50 then
        local param = buffer:explode("@")
        local category = tostring(param[1])
        local numeration = tonumber(param[2])
        enterDungeon(player, category, numeration)
    elseif opcode == 47 then
        local param = buffer:explode("@")
        local targetPlayer = tostring(param[1])
        sendInviteToPlayer(player, targetPlayer)
    elseif opcode == 46 then
        local param = buffer:explode("@")
        local category = tostring(param[1])
        local numeration = tonumber(param[2])
        sendRecompenseToPlayer(player, category, numeration)
    end
    return true
end
