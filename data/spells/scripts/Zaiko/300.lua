local exhaustion_time = 5
local exhaustion_storage = 1000300

local arr = {
    {0, 0, 0, 1, 0, 0, 0},
    {0, 0, 0, 1, 0, 0, 0},
    {0, 0, 0, 1, 0, 0, 0},
    {0, 0, 0, 1, 0, 0, 0},
    {0, 0, 0, 1, 0, 0, 0},
    {0, 0, 0, 1, 0, 0, 0},
    {0, 0, 0, 3, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0}
}

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setArea(createCombatArea(arr))

function onGetFormulaValues(player, level, magicLevel)
    local min = - (DAMAGE_FACTOR_LEVEL300 * level + DAMAGE_FACTOR_SKILL300 * magicLevel) / 1 * 0.98
    local max = - (DAMAGE_FACTOR_LEVEL300 * level + DAMAGE_FACTOR_SKILL300 * magicLevel) / 1 * 1.02
    return min, max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

function onCastSpell(player, var)
    if not player or not player:isCreature() then
        return false
    end

    if player:isRemoved() then
        return false
    end
	
    if exhaustion.check(player, exhaustion_storage) then
        player:sendCancelMessage("Aguarde " .. tostring(exhaustion.get(player, exhaustion_storage)) .. " segundos para usar essa tecnica novamente.")
        return false
    end
	
    if player:hasSecureMode() then
        player:sendCancelMessage("Você precisa ativar seu PVP para utilizar essa tecnica.")
        return false
    end
	
	local tile = Tile(player:getPosition())
	if tile and tile:hasFlag(TILESTATE_NOPVPZONE) then
		player:sendCancelMessage("Você não pode utilizar essa tecnica aqui.")
		return false
	end

	local playerId = player:getId()
	local playerCreature = Creature(playerId)

	if playerCreature and playerCreature:isCreature() and not playerCreature:isRemoved() and playerCreature:getLevel() >= 200 and not playerCreature:isInGhostMode() and not getCreatureCondition(playerCreature, CONDITION_OUTFIT, 127) then
	local position = playerCreature:getPosition()
		local effects = {
			[0] = {id = 230, position = {x = position.x + 1, y = position.y, z = position.z}},
			[1] = {id = 231, position = {x = position.x + 7, y = position.y + 1, z = position.z}},
			[2] = {id = 229, position = {x = position.x + 1, y = position.y + 7, z = position.z}},
			[3] = {id = 232, position = {x = position.x, y = position.y + 1, z = position.z}}
		}
		
		local dir = playerCreature:getDirection()
		local currentEffect = effects[dir]
		local effectPosition = Position(currentEffect.position.x, currentEffect.position.y, currentEffect.position.z)
		effectPosition:sendMagicEffect(currentEffect.id)
        for i = 0, 4 do
            addEvent(function()
				local Repeat = Creature(playerId)
				
				if not Repeat then
					return
				end
				
				combat:execute(Repeat, var)
            end, i * 100)
        end
	end
	exhaustion.set(player, 1000400, 4)
	exhaustion.set(player, 1000150, 4)
    exhaustion.set(player, exhaustion_storage, exhaustion_time)
        -- Send cooldown to spellbar
    if sendSpellbarCooldownAuto then
        sendSpellbarCooldownAuto(player, "Saiko chou")
    end
    return true
end
