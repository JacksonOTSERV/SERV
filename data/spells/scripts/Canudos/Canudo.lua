local configSpell = {
storageCd = 685004, --- Storage do cooldown
timeCd = 1, -- Tempo de cooldown em segundos
--------------------------------------------------------------------
hits = 1, -- Quantidade de hits
hitDelay = 50, -- Delay entre cada hit em ms
initialDelay = 10, -- Delay inicial antes do primeiro hit em ms
--------------------------------------------------------------------
areas = { --- Áreas por direção
[DIRECTION_NORTH] = {
{0, 2, 0},
{0, 1, 0},
{0, 1, 0},
{0, 1, 0},
{0, 1, 0},
{0, 1, 0},
{0, 1, 0},
{0, 1, 0},
},
[DIRECTION_EAST] = {
{0, 0, 0, 0, 0, 0, 0, 0},
{0, 1, 1, 1, 1, 1, 1, 2},
{0, 0, 0, 0, 0, 0, 0, 0},
},
[DIRECTION_SOUTH] = {
{0, 0, 0},
{0, 1, 0},
{0, 1, 0},
{0, 1, 0},
{0, 1, 0},
{0, 1, 0},
{0, 1, 0},
{0, 2, 0},
},
[DIRECTION_WEST] = {
{0, 0, 0, 0, 0, 0, 0, 0},
{2, 1, 1, 1, 1, 1, 1, 1},
{0, 0, 0, 0, 0, 0, 0, 0},
}
},
--------------------------------------------------------------------
effectCreature = { --- Efeito ao acertar algum alvo
effectHit = 107, -- Efeito visual ao acertar alguém
offsetHit = {x = 0, y = 0} -- Offset do efeito
},

effects = { --- Efeitos visuais por direção
[DIRECTION_NORTH] = {xOffset = 1, yOffset = 0, effect = 325},
[DIRECTION_EAST] = {xOffset = 8, yOffset = 1, effect = 324},
[DIRECTION_SOUTH] = {xOffset = 1, yOffset = 9, effect = 323},
[DIRECTION_WEST] = {xOffset = 0, yOffset = 1, effect = 326}
},
    
hitColor = 89, -- Hitcolor padrão
textColor = 89 -- Cor do texto padrão
}

local configMessages = {
{text = "Kame!", delay = 0, offset = {x = 0, y = -1}},
{text = "Hame!", delay = 500, offset = {x = 0, y = -1}},
{text = "Haaaaa!", delay = 1000, offset = {x = 0, y = -1}}
}

local function doEffectCreature(targetId, casterId)
local target = Creature(targetId)
local caster = Creature(casterId)
if not target or not caster then return end
local effectConfig = configSpell.effectCreature
local pos = target:getPosition()
pos.x = pos.x + effectConfig.offsetHit.x
pos.y = pos.y + effectConfig.offsetHit.y
pos:sendMagicEffect(effectConfig.effectHit)
end

local combats = {}
for dir, area in pairs(configSpell.areas) do
local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_HITCOLOR, configSpell.hitColor)
combat:setArea(createCombatArea(area))
function onGetFormulaValues(player, level, magicLevel)
local minDmg = ((level * 0.30) + (magicLevel * 5)) / 2
local maxDmg = minDmg
return -minDmg, -maxDmg
end
combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")
function onTargetCreature(caster, target)
doEffectCreature(target:getId(), caster:getId())
end
combat:setCallback(CALLBACK_PARAM_TARGETCREATURE, "onTargetCreature")
combats[dir] = combat
end

local function doAnimatedTexts(creatureId)
for _, msg in ipairs(configMessages) do
addEvent(function()
local c = Creature(creatureId)
if not c then return end
local pos = c:getPosition()
pos.x = pos.x + (msg.offset and msg.offset.x or 0)
pos.y = pos.y + (msg.offset and msg.offset.y or 0)
Game.sendAnimatedText(msg.text, pos, configSpell.textColor)
end, msg.delay)
end
end

local function showEffectAtPosition(pos, dir)
local info = configSpell.effects[dir]
if info then
local effectPos = Position(pos.x + info.xOffset, pos.y + info.yOffset, pos.z)
effectPos:sendMagicEffect(info.effect)
end
end

local function doHitAtPosition(creatureId, pos, dir, hitNumber)
local player = Creature(creatureId)
if player and player:isPlayer() then
local combat = combats[dir]
if combat then
local posVariant = positionToVariant(pos)
combat:execute(player, posVariant)
end
if hitNumber < configSpell.hits then
addEvent(doHitAtPosition, configSpell.hitDelay, creatureId, pos, dir, hitNumber + 1)
end
end
end

function onCastSpell(creature, variant)
local now = os.time() + os.clock() % 1
local remaining = getPlayerStorageValue(creature, configSpell.storageCd) - now
if remaining > 0 then
doPlayerSendCancel(creature, string.format("Espere [%.2f] segundos para usar esta habilidade novamente.", remaining))
return false
end

local casterId = creature:getId()
doAnimatedTexts(casterId)
local noMoveDelay = math.max(0, configSpell.initialDelay - 100)

addEvent(function(cid)
local player = Creature(cid)
if not player or not player:isPlayer() then return end
doCreatureSetNoMove(player, true)
end, noMoveDelay, casterId)

addEvent(function(cid)
local p = Creature(cid)
if not p or not p:isPlayer() then return end
local pos = p:getPosition()
local dir = p:getDirection()
showEffectAtPosition(pos, dir)
doHitAtPosition(cid, pos, dir, 1)

local totalTime = (configSpell.hits * configSpell.hitDelay) + 100

addEvent(function(pid)
local player = Creature(pid)
if not player or not player:isPlayer() then return end
doCreatureSetNoMove(player, false)
end, totalTime, cid)

end, configSpell.initialDelay, casterId)

setPlayerStorageValue(creature, configSpell.storageCd, os.time() + configSpell.timeCd)
return true
end