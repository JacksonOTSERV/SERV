DAMAGE_FACTOR_LEVEL400 = 45
DAMAGE_FACTOR_SKILL400 = 240

DAMAGE_FACTOR_LEVEL300 = 30
DAMAGE_FACTOR_SKILL300 = 205

DAMAGE_FACTOR_LEVEL250 = 28
DAMAGE_FACTOR_SKILL250 = 205

DAMAGE_FACTOR_LEVEL200 = 25
DAMAGE_FACTOR_SKILL200 = 200

DAMAGE_FACTOR_LEVEL150 = 10
DAMAGE_FACTOR_SKILL150 = 85

DAMAGE_FACTOR_LEVEL100 = 65
DAMAGE_FACTOR_SKILL100 = 260

DAMAGE_FACTOR_LEVEL50 = 5
DAMAGE_FACTOR_SKILL50 = 35

DAMAGE_FACTOR_LEVEL1 = 5
DAMAGE_FACTOR_SKILL1 = 30

function Player.JumpCreature(self, creatureID, jumpHeight, jumpDuration, jumpStraight)
    local networkMessage = NetworkMessage()
    networkMessage:addByte(0x36)
    networkMessage:addU32(creatureID)
    networkMessage:addU32(jumpHeight)
    networkMessage:addU32(jumpDuration)
    networkMessage:addByte(jumpStraight)
    networkMessage:sendToPlayer(self)
    networkMessage:delete()
    return true
end

function Combat:getPositions(creature, variant)
	local positions = {}
	function onTargetTile(creature, position)
		positions[#positions + 1] = position
	end

	self:setCallback(CALLBACK_PARAM_TARGETTILE, "onTargetTile")
	self:execute(creature, variant)
	return positions
end

function Combat:getTargets(creature, variant)
	local targets = {}
	function onTargetCreature(creature, target)
		targets[#targets + 1] = target
	end

	self:setCallback(CALLBACK_PARAM_TARGETCREATURE, "onTargetCreature")
	self:execute(creature, variant)
	return targets
end
