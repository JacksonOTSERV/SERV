local BEAM_OPCODE   = 103
local BEAM_DURATION = 10000  -- total ms
local TICK_INTERVAL = 500    -- damage tick ms
local BEAM_RANGE    = 8       -- max distance
local BEAM_COLOR    = "#a8ffc8ff"
local BEAM_WIDTH    = 1

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_ENERGYDAMAGE)
combat:setParameter(COMBAT_PARAM_HITCOLOR, COLOR_LIGHTGREEN)
-- effect removido: ENERGYHIT emite big light no target a cada tick, parecia que player light migrava
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_NONE)
combat:setFormula(COMBAT_FORMULA_DAMAGE, -200, 0, -400, 0)

local function getBeamTargets(caster, primary)
    local list = { primary }
    -- party members near primary
    if primary:isPlayer() then
        local party = primary:getParty()
        if party then
            for _, m in ipairs(party:getMembers()) do
                if m:getId() ~= primary:getId() and m:getPosition():getDistance(caster:getPosition()) <= BEAM_RANGE then
                    list[#list+1] = m
                end
            end
            local leader = party:getLeader()
            if leader and leader:getId() ~= primary:getId() and leader:getPosition():getDistance(caster:getPosition()) <= BEAM_RANGE then
                list[#list+1] = leader
            end
        end
        -- guild members nearby
        local guild = primary:getGuild()
        if guild then
            local spectators = Game.getSpectators(caster:getPosition(), false, true, BEAM_RANGE, BEAM_RANGE, BEAM_RANGE, BEAM_RANGE)
            for _, sp in ipairs(spectators) do
                if sp:isPlayer() and sp:getId() ~= primary:getId() then
                    local g = sp:getGuild()
                    if g and g:getId() == guild:getId() then
                        local dup = false
                        for _, t in ipairs(list) do if t:getId() == sp:getId() then dup = true; break end end
                        if not dup then list[#list+1] = sp end
                    end
                end
            end
        end
    end
    return list
end

local function pickPrimary(caster)
    local target = caster:getTarget()
    if target and target:getPosition():getDistance(caster:getPosition()) <= BEAM_RANGE then
        return target
    end
    -- fallback: nearest player
    local spectators = Game.getSpectators(caster:getPosition(), false, true, BEAM_RANGE, BEAM_RANGE, BEAM_RANGE, BEAM_RANGE)
    local best, bestDist
    for _, sp in ipairs(spectators) do
        if sp:isPlayer() then
            local d = sp:getPosition():getDistance(caster:getPosition())
            if not bestDist or d < bestDist then best = sp; bestDist = d end
        end
    end
    return best
end

local function sendBeams(caster, targets)
    local casterId = caster:getId()
    local spectators = Game.getSpectators(caster:getPosition(), false, true, 9, 9, 7, 7)
    for _, t in ipairs(targets) do
        local payload = casterId .. ';' .. t:getId() .. ';' .. BEAM_DURATION .. ';' .. BEAM_COLOR .. ';' .. BEAM_WIDTH
        for _, p in ipairs(spectators) do
            if p:isPlayer() then p:sendExtendedOpcode(BEAM_OPCODE, payload) end
        end
    end
end

local function tickDamage(casterId, targetIds, ticksLeft)
    if ticksLeft <= 0 then return end
    local caster = Creature(casterId)
    if not caster then return end
    for _, tid in ipairs(targetIds) do
        local t = Creature(tid)
        if t and t:getPosition():getDistance(caster:getPosition()) <= BEAM_RANGE then
            combat:execute(caster, Variant(tid))
        end
    end
    addEvent(tickDamage, TICK_INTERVAL, casterId, targetIds, ticksLeft - 1)
end

function onCastSpell(creature, variant)
    if not creature then return false end
    local primary = pickPrimary(creature)
    if not primary then return false end
    local targets = getBeamTargets(creature, primary)
    sendBeams(creature, targets)
    local targetIds = {}
    for _, t in ipairs(targets) do targetIds[#targetIds+1] = t:getId() end
    local ticks = math.floor(BEAM_DURATION / TICK_INTERVAL)
    tickDamage(creature:getId(), targetIds, ticks)
    creature:say("Lightning chain!", TALKTYPE_ORANGE_1)
    return true
end
