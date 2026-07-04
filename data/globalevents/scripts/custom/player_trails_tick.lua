-- Player Trails Tick — polla todos players, detecta movimento, spawna effect

local STORAGE_TRAIL_KEY = 87651
local TRAILS = {
    [1] = { effect = 1978                  }, -- Default custom
    [2] = { effect = CONST_ME_HITBYFIRE    },
    [3] = { effect = CONST_ME_MAGIC_BLUE   },
    [4] = { effect = CONST_ME_MAGIC_GREEN  },
}

-- RASTRO: spawna o effect a cada N tiles andados (maior = rastro MENOR/mais
-- espacado). 1 = todo tile (rastro denso); 2 = a cada 2 tiles; 3 = a cada 3...
local TRAIL_STEP = 2

local lastPositions = {} -- [playerId] = {x, y, z}
local stepCount = {}     -- [playerId] = contador de tiles andados

function onThink(interval, lastExecution)
    for _, player in ipairs(Game.getPlayers()) do
        local pid = player:getId()
        local trailId = player:getStorageValue(STORAGE_TRAIL_KEY)
        if trailId > 0 and TRAILS[trailId] then
            local pos = player:getPosition()
            local last = lastPositions[pid]
            if last and (last.x ~= pos.x or last.y ~= pos.y or last.z ~= pos.z) then
                stepCount[pid] = (stepCount[pid] or 0) + 1
                if stepCount[pid] >= TRAIL_STEP then
                    stepCount[pid] = 0
                    Position(last.x, last.y, last.z):sendMagicEffect(TRAILS[trailId].effect)
                end
            end
            lastPositions[pid] = { x = pos.x, y = pos.y, z = pos.z }
        else
            lastPositions[pid] = nil
            stepCount[pid] = nil
        end
    end
    return true
end
