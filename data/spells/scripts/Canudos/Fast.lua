local configSpell = {
storageCd = 685003, --- Storage do cooldown
timeCd = 7, -- Tempo de cooldown em segundos
----------------------------------------------------------------
hits = 10, --- Número de hits no cast
hitsNoOffset = 3, -- A cada 3 hits, o offset será 0
hitDelay = 175, -- Delay entre hits (ms)
----------------------------------------------------------------
distanceEffect = 26, -- Id do missile padrão
tileEffect = 10, -- Efeito visual que aparece no piso atingido
tileEffectOffset = {x = 0, y = 0}, -- Offset do efeito no piso
hitColor = 89 -- Hitcolor padrão
----------------------------------------------------------------
}

local combat = createCombatObject()
local combatDamage = createCombatObject()
setCombatParam(combatDamage, COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)

function onGetFormulaValues(player, level, magicLevel)
local minDmg = ((level * 0.25) + (magicLevel * 0.70) + 0)
local maxDmg = minDmg + 1
return -minDmg, -maxDmg
end
combatDamage:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

local arr1 = {
{0, 0, 0, 0, 0},
{0, 0, 3, 0, 0},
{0, 0, 0, 0, 0}
}
local area1 = createCombatArea(arr1)
setCombatArea(combat, area1)

local hitCounter = {}

local function getRandomOffset()
local x = math.random(-1,1)
local y = math.random(-1,1)
if x == 0 and y == 0 then
if math.random(0,1) == 0 then x = 1 else y = 1 end
end
return x, y
end

function onTargetTile(creature, pos)
local c = Creature(creature)
if not c then return end
local cid = c:getId()
hitCounter[cid] = (hitCounter[cid] or 0) + 1
local currentHit = hitCounter[cid]
local offsetX, offsetY
if configSpell.hitsNoOffset and currentHit % configSpell.hitsNoOffset == 0 then
offsetX, offsetY = 0, 0
else
offsetX, offsetY = getRandomOffset()
end
local finalPos = {x = pos.x + offsetX, y = pos.y + offsetY, z = pos.z}
local finalVariant = positionToVariant(finalPos)
doSendDistanceShoot(c:getPosition(), finalPos, configSpell.distanceEffect, nil, 125)
doSendMagicEffect({
x = finalPos.x + configSpell.tileEffectOffset.x,
y = finalPos.y + configSpell.tileEffectOffset.y,
z = finalPos.z
}, configSpell.tileEffect, c)
addEvent(function(cid, variant)
local caster = Creature(cid)
if caster then
setCombatParam(combatDamage, COMBAT_PARAM_HITCOLOR, configSpell.hitColor)
doCombat(caster, combatDamage, variant)
end
end, 200, cid, finalVariant)
end

setCombatCallback(combat, CALLBACK_PARAM_TARGETTILE, "onTargetTile")

local function faceTarget(caster, target)
if not caster or not target then return end
local cPos, tPos = caster:getPosition(), target:getPosition()
local dir = NORTH
if tPos.x > cPos.x then dir = EAST
elseif tPos.x < cPos.x then dir = WEST
elseif tPos.y > cPos.y then dir = SOUTH
elseif tPos.y < cPos.y then dir = NORTH
end
caster:setDirection(dir)
end

local function doHit(creatureId)
local caster = Creature(creatureId)
if not caster then return end
local target = caster:getTarget()
if not target then return end
faceTarget(caster, target)
doCombat(caster, combat, positionToVariant(target:getPosition()))
end

function onCastSpell(creature, var)
local c = Creature(creature)
if not c then return false end
local now = os.time() + os.clock() % 1
local remaining = getPlayerStorageValue(c, configSpell.storageCd) - now
if remaining > 0 then
doPlayerSendCancel(c, string.format("Espere [%.2f] segundos para usar esta habilidade novamente.", remaining))
return false
end

local creatureId = c:getId()
for i = 1, configSpell.hits do
addEvent(doHit, configSpell.hitDelay * i, creatureId)
end

addEvent(function(cid)
hitCounter[cid] = nil
end, configSpell.hitDelay * configSpell.hits, creatureId)

setPlayerStorageValue(c, configSpell.storageCd, os.time() + configSpell.timeCd)
return true
end