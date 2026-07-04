local conf = {
  maxLevel = 8,
  level = {
    [1] = { successPercent = 90, attack = 3, defense = 3 },
    [2] = { successPercent = 55, attack = 6, defense = 6 },
    [3] = { successPercent = 35, attack = 9, defense = 9 },
    [4] = { successPercent = 15, attack = 12, defense = 12 },
    [5] = { successPercent = 5, attack = 15, defense = 15 },
    [6] = { successPercent = 3, attack = 18, defense = 18 },
    [7] = { successPercent = 2, attack = 21, defense = 21 },
    [8] = { successPercent = 1, attack = 24, defense = 24 },
  },
}

local upgrading = {
  getLevel = function(item)
    local name = Item(item):getName():split('+')
    if #name == 1 then
      return 0
    end
    local lvl = tonumber(name[2])
    return lvl and math.abs(lvl) or 0
  end,
}

function onUse(cid, item, fromPosition, itemEx, toPosition)
  local player = cid
  local cid = cid:getId()

  local it = ItemType(itemEx.itemid)
  local itemName = it:getName():lower()

  if not (itemName:find("sword") or itemName:find("glove") or itemName:find("bracelets")) then
	player:sendCancelMessage("Este tipo de item não pode ser aprimorado.")
    return true
  end

  if ((it:getWeaponType() > 0 and it:getWeaponType() ~= WEAPON_WAND) or getItemAttribute(itemEx.uid, ITEM_ATTRIBUTE_ARMOR) > 0) and not isItemStackable(itemEx.itemid) then
    local level = upgrading.getLevel(itemEx.uid)

    if level >= conf.maxLevel then
	  player:sendCancelMessage("Seu item " .. it:getName() .. " já está no nível máximo de aprimoramento.")
      return true
    end

    if not player:removeMoney(10000000) then
      player:sendCancelMessage("Você precisa de 10.000.000 de money para tentar o upgrade.")
      return true
    end

    local nextLevel = level + 1
    local levelConf = conf.level[nextLevel]
    if not levelConf then
      return true
    end

    local roll = math.random(1, 100)
    local success = roll <= levelConf.successPercent
    local newLevel

    if success then
      newLevel = nextLevel
      doSendMagicEffect(toPosition, CONST_ME_MAGIC_GREEN)
      doPlayerSendTextMessage(cid, MESSAGE_EVENT_ADVANCE, "Upgrade para o nível " .. newLevel .. " realizado com sucesso!")
    else
      if level >= 2 then
        newLevel = math.max(level - 1, 0)
      else
        newLevel = level
      end

      doSendMagicEffect(toPosition, CONST_ME_BLOCKHIT)
      if newLevel < level then
        doPlayerSendTextMessage(cid, MESSAGE_EVENT_ADVANCE, "O upgrade falhou. Seu item " .. it:getName() .. " foi rebaixado para o nível " .. newLevel .. ".")
      else
        doPlayerSendTextMessage(cid, MESSAGE_EVENT_ADVANCE, "O upgrade falhou. Seu item " .. it:getName() .. " permaneceu no nível " .. newLevel .. ".")
      end
    end

    local baseName = it:getName():split('+')[1]
    local newName = baseName .. (newLevel > 0 and " +" .. newLevel or "")
    doItemSetAttribute(itemEx.uid, ITEM_ATTRIBUTE_NAME, newName)

    local baseAttack = it:getAttack()
    local baseDefense = it:getDefense()

    local upgradeConf = conf.level[newLevel] or {attack = 0, defense = 0}

    local totalAttack = baseAttack + upgradeConf.attack
    local totalDefense = baseDefense + upgradeConf.defense

    doItemSetAttribute(itemEx.uid, ITEM_ATTRIBUTE_ATTACK, totalAttack)
    doItemSetAttribute(itemEx.uid, ITEM_ATTRIBUTE_DEFENSE, totalDefense)

    doRemoveItem(item.uid, 1)
  else
    player:sendCancelMessage("Você não pode aprimorar este item.")
  end
  return true
end