-- /testinstance setup   -- cria 10 instancias com mobs ao redor de voce
-- /testinstance clear   -- remove todos os mobs de teste
-- /testinstance info    -- mostra sua instancia atual e mobs proximos

local TEST_MONSTER = "Li Shenron"
local spawnedCreatures = {}

function onSay(player, words, param)
    if not player:getGroup():getAccess() then
        return false
    end

    local cmd = param:lower():match("^%s*(%S+)")

    if cmd == "setup" then
        local pos = player:getPosition()
        local guid = player:getGuid()
        spawnedCreatures[guid] = spawnedCreatures[guid] or {}

        -- offsets ao redor do player para spawnar 5 mobs por instancia
        local offsets = {
            {x=2, y=0, z=0}, {x=-2, y=0, z=0}, {x=0, y=2, z=0},
            {x=2, y=2, z=0}, {x=-2, y=-2, z=0}
        }

        local total = 0
        for instanceId = 1, 10 do
            for _, off in ipairs(offsets) do
                local spawnPos = {x=pos.x+off.x, y=pos.y+off.y, z=pos.z+off.z}
                local m = Game.createMonster(TEST_MONSTER, spawnPos, false, false, instanceId)
                if m then
                    table.insert(spawnedCreatures[guid], m:getId())
                    total = total + 1
                end
            end
        end

        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
            string.format("[TestInstance] Criados %d mobs em 10 instancias.", total))
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
            "Use: /instancia 1 ate /instancia 10 para entrar em cada instancia.")
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
            "Use: /instancia 0 para voltar ao mundo normal.")

    elseif cmd == "clear" then
        local guid = player:getGuid()
        local count = 0
        if spawnedCreatures[guid] then
            for _, cid in ipairs(spawnedCreatures[guid]) do
                local c = Creature(cid)
                if c then
                    c:remove()
                    count = count + 1
                end
            end
            spawnedCreatures[guid] = nil
        end
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
            string.format("[TestInstance] Removidos %d mobs.", count))

    elseif cmd == "info" then
        local myInstance = player:getInstanceId()
        local pos = player:getPosition()
        local spectators = Game.getSpectators(pos, false, false, 14, 14, 10, 10)

        local monstersHere = {}
        for _, spec in ipairs(spectators) do
            if spec:isMonster() then
                table.insert(monstersHere, string.format("%s (inst=%d)", spec:getName(), spec:getInstanceId()))
            end
        end

        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
            string.format("[TestInstance] Sua instancia: %d", myInstance))

        if #monstersHere > 0 then
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
                "Mobs visiveis na area: " .. table.concat(monstersHere, ", "))
        else
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Nenhum mob visivel na area.")
        end

    else
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
            "Uso: /testinstance setup | clear | info")
    end

    return false
end
