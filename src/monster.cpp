/**
 * The Forgotten Server - a free and open-source MMORPG server emulator
 * Copyright (C) 2019  Mark Samman <mark.samman@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include "otpch.h"

#include "configmanager.h"
#include "events.h"
#include "game.h"
#include "instance_utils.h"
#include "monster.h"
#include "spells.h"

extern Game g_game;
extern Monsters g_monsters;
extern Events *g_events;
extern ConfigManager g_config;

int32_t Monster::despawnRange;
int32_t Monster::despawnRadius;

uint32_t Monster::monsterAutoID = 0x40000000;

std::unordered_map<std::string, uint32_t> Monster::monsterLevelRequirements = {
    {"Shenlong", 300},
};

Monster *Monster::createMonster(const std::string &name) {
  MonsterType *mType = g_monsters.getMonsterType(name);
  if (!mType) {
    return nullptr;
  }
  return new Monster(mType);
}

Monster::Monster(MonsterType *mType)
    : Creature(), strDescription(mType->nameDescription), mType(mType) {
  defaultOutfit = mType->info.outfit;
  currentOutfit = mType->info.outfit;
  skull = mType->info.skull;
  level = uniform_random(mType->info.minLevel, mType->info.maxLevel);
  health = mType->info.health;
  healthMax = mType->info.healthMax;
  baseSpeed = mType->info.baseSpeed;
  internalLight = mType->info.light;
  hiddenHealth = mType->info.hiddenHealth;

  if (level > 0) {
    float bonusHp = g_config.getFloat(ConfigManager::MLVL_BONUSHP) * level;
    if (bonusHp != 0.0) {
      healthMax += healthMax * bonusHp;
      health += health * bonusHp;
    }
    float bonusSpeed =
        g_config.getFloat(ConfigManager::MLVL_BONUSSPEED) * level;
    if (bonusSpeed != 0.0) {
      baseSpeed += baseSpeed * bonusSpeed;
    }
  }

  // register creature events
  for (const std::string &scriptName : mType->info.scripts) {
    if (!registerCreatureEvent(scriptName)) {
      std::cout << "[Warning - Monster::Monster] Unknown event name: "
                << scriptName << std::endl;
    }
  }
}

Monster::~Monster() {
  clearTargetList();
  clearFriendList();
}

void Monster::setLevel(int32_t lvl) {
  level = lvl;
  // Re-apply HP and Speed bonuses based on new level
  health = mType->info.health;
  healthMax = mType->info.healthMax;
  baseSpeed = mType->info.baseSpeed;

  if (level > 0) {
    // Update displayed name to include level
    setName(mType->name + " Lv." + std::to_string(level));

    float bonusHp = g_config.getFloat(ConfigManager::MLVL_BONUSHP) * level;
    if (bonusHp != 0.0f) {
      healthMax += static_cast<int32_t>(healthMax * bonusHp);
      health += static_cast<int32_t>(health * bonusHp);
    }
    float bonusSpeed =
        g_config.getFloat(ConfigManager::MLVL_BONUSSPEED) * level;
    if (bonusSpeed != 0.0f) {
      baseSpeed += static_cast<uint32_t>(baseSpeed * bonusSpeed);
    }
    float bonusDmg = g_config.getFloat(ConfigManager::MLVL_BONUSDMG) * level;
    if (bonusDmg != 0.0f) {
      bonusDamageMultiplier = 1.0f + bonusDmg;
    }
  }
}

uint64_t Monster::getLostExperience() const {
  if (!skillLoss)
    return 0;
  uint64_t baseExp = mType->info.experience;
  if (level > 0) {
    float bonusExp = g_config.getFloat(ConfigManager::MLVL_BONUSEXP) * level;
    baseExp += static_cast<uint64_t>(baseExp * bonusExp);
  }
  return baseExp;
}

void Monster::addList() { g_game.addMonster(this); }

void Monster::removeList() { g_game.removeMonster(this); }

bool Monster::canSee(const Position &pos) const {
  return Creature::canSee(getPosition(), pos, 15, 8);
}

bool Monster::canWalkOnFieldType(CombatType_t combatType) const {
  switch (combatType) {
  case COMBAT_ENERGYDAMAGE:
    return mType->info.canWalkOnEnergy;
  case COMBAT_FIREDAMAGE:
    return mType->info.canWalkOnFire;
  case COMBAT_EARTHDAMAGE:
    return mType->info.canWalkOnPoison;
  default:
    return true;
  }
}

void Monster::onAttackedCreatureDisappear(bool) { attackTicks = 0; }

void Monster::onCreatureAppear(Creature *creature, bool isLogin) {
  Creature::onCreatureAppear(creature, isLogin);

  if (mType->info.creatureAppearEvent != -1) {
    // onCreatureAppear(self, creature)
    LuaScriptInterface *scriptInterface = mType->info.scriptInterface;
    if (!scriptInterface->reserveScriptEnv()) {
      std::cout << "[Error - Monster::onCreatureAppear] Call stack overflow"
                << std::endl;
      return;
    }

    ScriptEnvironment *env = scriptInterface->getScriptEnv();
    env->setScriptId(mType->info.creatureAppearEvent, scriptInterface);

    lua_State *L = scriptInterface->getLuaState();
    scriptInterface->pushFunction(mType->info.creatureAppearEvent);

    LuaScriptInterface::pushUserdata<Monster>(L, this);
    LuaScriptInterface::setMetatable(L, -1, "Monster");

    LuaScriptInterface::pushUserdata<Creature>(L, creature);
    LuaScriptInterface::setCreatureMetatable(L, -1, creature);

    if (scriptInterface->callFunction(2)) {
      return;
    }
  }

  if (creature == this) {
    // We just spawned, let's look around to see who is there.
    if (isSummon()) {
      isMasterInRange = canSee(getMaster()->getPosition());
    }

    updateTargetList();
    updateIdleStatus();
  } else {
    onCreatureEnter(creature);
  }
}

uint32_t Monster::getRequiredLevel(const std::string &monsterName) {
  auto it = monsterLevelRequirements.find(monsterName);
  if (it != monsterLevelRequirements.end()) {
    return it->second;
  }
  return 0;
}

void Monster::onRemoveCreature(Creature *creature, bool isLogout) {
  Creature::onRemoveCreature(creature, isLogout);

  if (mType->info.creatureDisappearEvent != -1) {
    // onCreatureDisappear(self, creature)
    LuaScriptInterface *scriptInterface = mType->info.scriptInterface;
    if (!scriptInterface->reserveScriptEnv()) {
      std::cout << "[Error - Monster::onCreatureDisappear] Call stack overflow"
                << std::endl;
      return;
    }

    ScriptEnvironment *env = scriptInterface->getScriptEnv();
    env->setScriptId(mType->info.creatureDisappearEvent, scriptInterface);

    lua_State *L = scriptInterface->getLuaState();
    scriptInterface->pushFunction(mType->info.creatureDisappearEvent);

    LuaScriptInterface::pushUserdata<Monster>(L, this);
    LuaScriptInterface::setMetatable(L, -1, "Monster");

    LuaScriptInterface::pushUserdata<Creature>(L, creature);
    LuaScriptInterface::setCreatureMetatable(L, -1, creature);

    if (scriptInterface->callFunction(2)) {
      return;
    }
  }

  if (creature == this) {
    if (spawn) {
      spawn->startSpawnCheck();
    }

    setIdle(true);
  } else {
    onCreatureLeave(creature);
  }
}

void Monster::onCreatureMove(Creature *creature, const Tile *newTile,
                             const Position &newPos, const Tile *oldTile,
                             const Position &oldPos, bool teleport) {
  Creature::onCreatureMove(creature, newTile, newPos, oldTile, oldPos,
                           teleport);

  if (mType->info.creatureMoveEvent != -1) {
    // onCreatureMove(self, creature, oldPosition, newPosition)
    LuaScriptInterface *scriptInterface = mType->info.scriptInterface;
    if (!scriptInterface->reserveScriptEnv()) {
      std::cout << "[Error - Monster::onCreatureMove] Call stack overflow"
                << std::endl;
      return;
    }

    ScriptEnvironment *env = scriptInterface->getScriptEnv();
    env->setScriptId(mType->info.creatureMoveEvent, scriptInterface);

    lua_State *L = scriptInterface->getLuaState();
    scriptInterface->pushFunction(mType->info.creatureMoveEvent);

    LuaScriptInterface::pushUserdata<Monster>(L, this);
    LuaScriptInterface::setMetatable(L, -1, "Monster");

    LuaScriptInterface::pushUserdata<Creature>(L, creature);
    LuaScriptInterface::setCreatureMetatable(L, -1, creature);

    LuaScriptInterface::pushPosition(L, oldPos);
    LuaScriptInterface::pushPosition(L, newPos);

    if (scriptInterface->callFunction(4)) {
      return;
    }
  }

  if (creature == this) {
    if (isSummon()) {
      isMasterInRange = canSee(getMaster()->getPosition());
    }
    updateTargetList();
    updateIdleStatus();
  } else {
    bool canSeeNewPos = canSee(newPos);
    bool canSeeOldPos = canSee(oldPos);

    if (canSeeNewPos && !canSeeOldPos) {
      onCreatureEnter(creature);
    } else if (!canSeeNewPos && canSeeOldPos) {
      onCreatureLeave(creature);
    }

    if (canSeeNewPos && isSummon() && getMaster() == creature) {
      isMasterInRange = true;
    }

    updateIdleStatus();

    if (!followCreature && !isSummon() && isOpponent(creature)) {
      selectTarget(creature);
    }
  }
}

void Monster::onCreatureSay(Creature *creature, SpeakClasses type,
                            const std::string &text) {
  Creature::onCreatureSay(creature, type, text);

  if (mType->info.creatureSayEvent != -1) {
    // onCreatureSay(self, creature, type, message)
    LuaScriptInterface *scriptInterface = mType->info.scriptInterface;
    if (!scriptInterface->reserveScriptEnv()) {
      std::cout << "[Error - Monster::onCreatureSay] Call stack overflow"
                << std::endl;
      return;
    }

    ScriptEnvironment *env = scriptInterface->getScriptEnv();
    env->setScriptId(mType->info.creatureSayEvent, scriptInterface);

    lua_State *L = scriptInterface->getLuaState();
    scriptInterface->pushFunction(mType->info.creatureSayEvent);

    LuaScriptInterface::pushUserdata<Monster>(L, this);
    LuaScriptInterface::setMetatable(L, -1, "Monster");

    LuaScriptInterface::pushUserdata<Creature>(L, creature);
    LuaScriptInterface::setCreatureMetatable(L, -1, creature);

    lua_pushnumber(L, type);
    LuaScriptInterface::pushString(L, text);

    scriptInterface->callVoidFunction(4);
  }
}

void Monster::addFriend(Creature *creature) {
  assert(creature != this);
  auto result = friendList.insert(creature);
  if (result.second) {
    creature->incrementReferenceCounter();
  }
}

void Monster::removeFriend(Creature *creature) {
  auto it = friendList.find(creature);
  if (it != friendList.end()) {
    creature->decrementReferenceCounter();
    friendList.erase(it);
  }
}

void Monster::addTarget(Creature *creature, bool pushFront /* = false*/) {
  assert(creature != this);
  if (std::find(targetList.begin(), targetList.end(), creature) ==
      targetList.end()) {
    creature->incrementReferenceCounter();
    if (pushFront) {
      targetList.push_front(creature);
    } else {
      targetList.push_back(creature);
    }
  }
}

void Monster::removeTarget(Creature *creature) {
  auto it = std::find(targetList.begin(), targetList.end(), creature);
  if (it != targetList.end()) {
    creature->decrementReferenceCounter();
    targetList.erase(it);
  }
}

void Monster::updateTargetList() {
  for (auto it = friendList.begin(); it != friendList.end();) {
    Creature *creature = *it;
    if (creature->getHealth() <= 0 || !canSee(creature->getPosition())) {
      creature->decrementReferenceCounter(); // Equivalente ao unRef() da 0.4
      it = friendList.erase(it);
    } else {
      ++it;
    }
  }

  for (auto it = targetList.begin(); it != targetList.end();) {
    Creature *creature = *it;
    if (creature->getHealth() <= 0 || !canSee(creature->getPosition())) {
      creature->decrementReferenceCounter(); // Equivalente ao unRef() da 0.4
      it = targetList.erase(it);
    } else {
      ++it;
    }
  }

  SpectatorVector spectators;
  g_game.map.getSpectators(spectators, getPosition(), true);

  const uint32_t myInstance = getInstanceID();
  for (Creature *spectator : spectators) {
    if (spectator != this && spectator->getInstanceID() == myInstance && canSee(spectator->getPosition())) {
      onCreatureFound(spectator);
    }
  }
}

void Monster::clearTargetList() {
  for (auto it = targetList.begin(); it != targetList.end(); ++it) {
    (*it)->decrementReferenceCounter();
  }
  targetList.clear();
}

void Monster::clearFriendList() {
  for (auto it = friendList.begin(); it != friendList.end(); ++it) {
    (*it)->decrementReferenceCounter();
  }
  friendList.clear();
}

void Monster::onCreatureFound(Creature *creature, bool pushFront /* = false*/) {

  if (!creature) {
    return;
  }

  if (!canSee(creature->getPosition())) {
    return;
  }

  if (isFriend(creature)) {
    addFriend(creature);
  }

  if (isOpponent(creature)) {
    addTarget(creature, pushFront);
  }

  updateIdleStatus();
}

void Monster::onCreatureEnter(Creature *creature) {
  // std::cout << "onCreatureEnter - " << creature->getName() << std::endl;

  if (getMaster() == creature) {
    // Follow master again
    isMasterInRange = true;
  }

  onCreatureFound(creature, true);
}

bool Monster::isFriend(const Creature *creature) const {
  if (isSummon() && getMaster()->getPlayer()) {
    const Player *masterPlayer = getMaster()->getPlayer();
    const Player *tmpPlayer = nullptr;

    if (creature->getPlayer()) {
      tmpPlayer = creature->getPlayer();
    } else {
      const Creature *creatureMaster = creature->getMaster();

      if (creatureMaster && creatureMaster->getPlayer()) {
        tmpPlayer = creatureMaster->getPlayer();
      }
    }

    if (tmpPlayer &&
        (tmpPlayer == getMaster() || masterPlayer->isPartner(tmpPlayer))) {
      return true;
    }
  } else if (creature->getMonster() && !creature->isSummon()) {
    return true;
  }

  return false;
}

bool Monster::isOpponent(const Creature *creature) const {
  if (isSummon() && getMaster()->getPlayer()) {
    if (creature != getMaster()) {
      return true;
    }
  } else {
    if ((creature->getPlayer() &&
         !creature->getPlayer()->hasFlag(PlayerFlag_IgnoredByMonsters)) ||
        (creature->getMaster() && creature->getMaster()->getPlayer())) {
      return true;
    }
  }

  return false;
}

void Monster::onCreatureLeave(Creature *creature) {

  if (getMaster() == creature) {
    isMasterInRange = false;
    updateIdleStatus();
  }

  if (isFriend(creature)) {
    auto it = std::find(friendList.begin(), friendList.end(), creature);
    if (it != friendList.end()) {
      (*it)->decrementReferenceCounter();
      friendList.erase(it);
    }
  }

  if (isOpponent(creature)) {
    auto it = std::find(targetList.begin(), targetList.end(), creature);
    if (it != targetList.end()) {
      (*it)->decrementReferenceCounter();
      targetList.erase(it);
      if (targetList.empty()) {
        updateIdleStatus();
      }
    }
  }
}

bool Monster::searchTarget(
    TargetSearchType_t searchType /*= TARGETSEARCH_DEFAULT*/) {
  std::list<Creature *> resultList;
  const Position &myPos = getPosition();

  for (Creature *creature : targetList) {
    if (followCreature != creature && isTarget(creature)) {
      if (searchType == TARGETSEARCH_RANDOM || canUseAttack(myPos, creature)) {
        resultList.push_back(creature);
      }
    }
  }

  switch (searchType) {
  case TARGETSEARCH_NEAREST: {
    Creature *target = nullptr;
    int32_t minRange = std::numeric_limits<int32_t>::max();

    for (Creature *creature : resultList) {
      const Position &pos = creature->getPosition();
      int32_t distance =
          std::max(std::abs(myPos.x - pos.x), std::abs(myPos.y - pos.y));

      if (distance < minRange) {
        target = creature;
        minRange = distance;
      }
    }

    if (target && selectTarget(target)) {
      return true;
    }
    break;
  }

  default: {
    if (!resultList.empty()) {
      auto it = resultList.begin();
      std::advance(it, uniform_random(0, resultList.size() - 1));
      return selectTarget(*it);
    }

    if (searchType == TARGETSEARCH_ATTACKRANGE) {
      return false;
    }

    break;
  }
  }

  for (Creature *target : targetList) {
    if (followCreature != target && selectTarget(target)) {
      return true;
    }
  }

  return false;
}

void Monster::onFollowCreatureComplete(const Creature *creature) {
  if (creature) {
    auto it = std::find(targetList.begin(), targetList.end(), creature);
    if (it != targetList.end()) {
      Creature *target = (*it);
      targetList.erase(it);

      if (hasFollowPath) {
        targetList.push_front(target);
      } else if (!isSummon()) {
        targetList.push_back(target);
      } else {
        target->decrementReferenceCounter();
      }
    }
  }
}

BlockType_t Monster::blockHit(Creature *attacker, CombatType_t combatType,
                              int32_t &damage, bool checkDefense /* = false*/,
                              bool checkArmor /* = false*/,
                              bool /* field = false */,
                              bool /* ignoreResistances = false */) {
  BlockType_t blockType = Creature::blockHit(attacker, combatType, damage,
                                             checkDefense, checkArmor);

  if (damage != 0) {
    int32_t elementMod = 0;
    auto it = mType->info.elementMap.find(combatType);
    if (it != mType->info.elementMap.end()) {
      elementMod = it->second;
    }

    if (elementMod != 0) {
      damage = static_cast<int32_t>(
          std::round(damage * ((100 - elementMod) / 100.)));
      if (damage <= 0) {
        damage = 0;
        blockType = BLOCK_ARMOR;
      }
    }
  }

  return blockType;
}

bool Monster::isTarget(const Creature *creature) const {
  if (creature->isRemoved() || !creature->isAttackable() ||
      creature->getZone() == ZONE_PROTECTION || !canSeeCreature(creature)) {
    return false;
  }

  if (creature->getPosition().z != getPosition().z) {
    return false;
  }
  return true;
}

bool Monster::selectTarget(Creature *creature) {
  if (!creature) {
    return false;
  }

  Player *targetPlayer = creature->getPlayer();
  if (!targetPlayer) {
    targetPlayer = creature->getPlayerMaster();
  }

  if (targetPlayer) {
    auto levelIt = monsterLevelRequirements.find(getName());
    if (levelIt != monsterLevelRequirements.end()) {
      uint32_t requiredLevel = levelIt->second;

      if (targetPlayer->getLevel() < requiredLevel) {
        return false;
      }
    }
  }

  if (!isTarget(creature)) {
    return false;
  }

  if (targetList.empty() || std::find(targetList.begin(), targetList.end(),
                                      creature) == targetList.end()) {
    return false;
  }

  if ((isHostile() || isSummon()) && setAttackedCreature(creature) &&
      !isSummon()) {
    g_dispatcher.addTask(
        createTask(std::bind(&Game::checkCreatureAttack, &g_game, getID())));
  }

  return setFollowCreature(creature);
}

void Monster::setIdle(bool idle) {
  if (isRemoved() || getHealth() <= 0) {
    return;
  }

  isIdle = idle;

  if (!isIdle) {
    g_game.addCreatureCheck(this);
  } else {
    onIdleStatus();
    clearTargetList();
    clearFriendList();
    Game::removeCreatureCheck(this);
  }
}

void Monster::updateIdleStatus() {
  bool idle = false;

  if (conditions.empty()) {
    if (!isSummon() && targetList.empty()) {
      idle = true;
    }
  }

  setIdle(idle);
}

void Monster::onAddCondition(ConditionType_t type) {
  if (type == CONDITION_FIRE || type == CONDITION_ENERGY ||
      type == CONDITION_POISON) {
    updateMapCache();
  }

  updateIdleStatus();
}

void Monster::onEndCondition(ConditionType_t type) {
  if (type == CONDITION_FIRE || type == CONDITION_ENERGY ||
      type == CONDITION_POISON) {
    ignoreFieldDamage = false;
    updateMapCache();
  }

  updateIdleStatus();
}

void Monster::onThink(uint32_t interval) {
  Creature::onThink(interval);

  const std::string &monsterName = getName();

  auto levelIt = monsterLevelRequirements.find(monsterName);
  if (levelIt != monsterLevelRequirements.end()) {
    bool canMove = false;
    const Position &monsterPos = getPosition();
    SpectatorVector spectators;

    g_game.map.getSpectators(spectators, monsterPos, false, true);

    uint32_t requiredLevel = levelIt->second;

    const uint32_t monsterInstanceId = getInstanceID();
    for (Creature *creature : spectators) {
      if (creature->getInstanceID() != monsterInstanceId) {
        continue;
      }
      Player *player = creature->getPlayer();
      if (!player) {
        player = creature->getPlayerMaster();
      }

      if (player && player->getLevel() >= requiredLevel) {
        canMove = true;
        break;
      }
    }

    if (!canMove)
      return;
  }

  if (!isInSpawnRange(position)) {
    if (g_config.getBoolean(ConfigManager::REMOVE_ON_DESPAWN)) {
      g_game.removeCreature(this, false);
    } else {
      g_game.internalTeleport(this, masterPos);
      setIdle(true);
    }
    g_game.addMagicEffect(this->getPosition(), CONST_ME_POFF, getInstanceID());
    return;
  }

  if (attackedCreature &&
      (attackedCreature->hasCondition(CONDITION_OUTFIT, 125) ||
       attackedCreature->hasCondition(CONDITION_OUTFIT, 427) ||
       attackedCreature->isInGhostMode() ||
       attackedCreature->getPosition().z != getPosition().z)) {
    searchTarget();
    setFollowCreature(nullptr);
  }

  if (!isIdle) {
    addEventWalk();

    if (isSummon()) {
      if (getName() == "Katsuyu") {
        setFollowCreature(getMaster());
        return;
      }
      if (getCurrentOutfit().lookAura == 157) {
        return;
      }
      if (getMaster() && !attackedCreature) {
        selectTarget(getMaster()->getAttackedCreature());
        setFollowCreature(getMaster());
      } else if (attackedCreature != this) {
        setFollowCreature(attackedCreature);
      }
    } else if (!targetList.empty()) {
      if (!followCreature || !hasFollowPath) {
        searchTarget();
      } else if (isFleeing()) {
        if (attackedCreature &&
            !canUseAttack(getPosition(), attackedCreature)) {
          searchTarget(TARGETSEARCH_ATTACKRANGE);
        }
      }
    }

    onThinkTarget(interval);
    onThinkYell(interval);
    onThinkDefense(interval);
  }
}

void Monster::doAttacking(uint32_t interval) {
  if (!attackedCreature || (isSummon() && attackedCreature == this)) {
    return;
  }

  if (getName() == "Katsuyu") {
    return;
  }

  if (getCurrentOutfit().lookAura == 157) {
    return;
  }

  if (attackedCreature &&
      (attackedCreature->hasCondition(CONDITION_OUTFIT, 125) ||
       attackedCreature->hasCondition(CONDITION_OUTFIT, 427) ||
       attackedCreature->isInGhostMode() ||
       attackedCreature->getPosition().z != getPosition().z)) {
    selectTarget(nullptr);
    setFollowCreature(nullptr);
    attackTicks = 0;
    return;
  }

  if (extraSpellsInterval == 0) {
    extraSpellsInterval = uniform_random(300, 600);
  }

  if (attackedCreature->isRemoved()) {
    attackedCreature = nullptr;
    return;
  }

  bool updateLook = true;
  bool resetTicks = interval != 0;
  attackTicks += interval;

  const Position &myPos = getPosition();
  const Position &targetPos = attackedCreature->getPosition();

  for (const spellBlock_t &spellBlock : mType->info.attackSpells) {
    bool inRange = false;

    if (attackedCreature == nullptr) {
      break;
    }

    if (canUseSpell(myPos, targetPos, spellBlock, interval, inRange,
                    resetTicks)) {
      if (spellBlock.chance >= static_cast<uint32_t>(uniform_random(1, 100))) {
        if (updateLook) {
          updateLookDirection();
          updateLook = false;
        }

        minCombatValue = spellBlock.minCombatValue;
        maxCombatValue = spellBlock.maxCombatValue;

        if (hasCondition(CONDITION_OUTFIT)) {
          minCombatValue = 100000;
          maxCombatValue = 100000;
        }

        spellBlock.spell->castSpell(this, attackedCreature);
        lastAttackTime = OTSYS_TIME();

        if (spellBlock.isMelee) {
          lastMeleeAttack = OTSYS_TIME();
        }
      }
    }

    if (!inRange && spellBlock.isMelee) {
      lastMeleeAttack = 0;
    }
  }

  if (updateLook) {
    updateLookDirection();
  }

  if (resetTicks) {
    attackTicks = 0;
  }
}

bool Monster::canUseAttack(const Position &pos, const Creature *target) const {
  if (!target) {
    return false;
  }

  if (target->hasCondition(CONDITION_OUTFIT, 125)) {
    return false;
  }

  if (target->hasCondition(CONDITION_OUTFIT, 427)) {
    return false;
  }

  if (target->isInGhostMode()) {
    return false;
  }

  if (target->getPosition().z != getPosition().z) {
    return false;
  }

  if (isHostile()) {
    const Position &targetPos = target->getPosition();
    uint32_t distance =
        std::max<uint32_t>(Position::getDistanceX(pos, targetPos),
                           Position::getDistanceY(pos, targetPos));
    for (const spellBlock_t &spellBlock : mType->info.attackSpells) {
      if (spellBlock.range != 0 && distance <= spellBlock.range) {
        return g_game.isSightClear(pos, targetPos, true);
      }
    }
    return false;
  }
  return true;
}

bool Monster::canUseSpell(const Position &pos, const Position &targetPos,
                          const spellBlock_t &sb, uint32_t interval,
                          bool &inRange, bool &resetTicks) {
  inRange = true;

  if (sb.isMelee) {
    if (isFleeing() ||
        (OTSYS_TIME() - lastMeleeAttack) < (sb.speed + extraSpellsInterval)) {
      return false;
    }
  } else {
    // vou compilar e testar no windows antes de enviar pra vps
    if ((sb.speed + extraSpellsInterval) > attackTicks) {
      resetTicks = false;
      return false;
    }

    if ((attackTicks % (sb.speed + extraSpellsInterval)) >= interval) {
      // already used this spell for this round
      return false;
    }
  }

  if (sb.range != 0 &&
      std::max<uint32_t>(Position::getDistanceX(pos, targetPos),
                         Position::getDistanceY(pos, targetPos)) > sb.range) {
    inRange = false;
    return false;
  }
  return true;
}

void Monster::onThinkTarget(uint32_t interval) {
  if (isSummon() || mType->info.changeTargetSpeed <= 0) {
    return;
  }

  bool canChangeTarget = true;

  if (targetChangeCooldown > 0) {
    targetChangeCooldown -= interval;
    if (targetChangeCooldown <= 0) {
      targetChangeCooldown = 0;
      targetChangeTicks = mType->info.changeTargetSpeed;
    } else
      canChangeTarget = false;
  }

  if (!canChangeTarget) {
    return;
  }

  targetChangeTicks += interval;
  if (targetChangeTicks < mType->info.changeTargetSpeed) {
    return;
  }

  targetChangeTicks = 0;
  targetChangeCooldown = mType->info.changeTargetSpeed;

  if (mType->info.changeTargetChance < uniform_random(1, 100)) {
    return;
  }

  if (attackedCreature &&
      (attackedCreature->hasCondition(CONDITION_OUTFIT, 125) ||
       attackedCreature->hasCondition(CONDITION_OUTFIT, 427) ||
       attackedCreature->isInGhostMode() ||
       attackedCreature->getPosition().z != getPosition().z)) {
    selectTarget(nullptr);
    setFollowCreature(nullptr);
  }

  if (mType->info.targetDistance <= 1) {
    searchTarget(TARGETSEARCH_RANDOM);
  } else {
    searchTarget(TARGETSEARCH_NEAREST);
  }
}

void Monster::onThinkDefense(uint32_t interval) {
  bool resetTicks = true;
  defenseTicks += interval;

  for (const spellBlock_t &spellBlock : mType->info.defenseSpells) {
    if (spellBlock.speed > defenseTicks) {
      resetTicks = false;
      continue;
    }

    if (defenseTicks % spellBlock.speed >= interval) {
      // already used this spell for this round
      continue;
    }

    if ((spellBlock.chance >= static_cast<uint32_t>(uniform_random(1, 100)))) {
      minCombatValue = spellBlock.minCombatValue;
      maxCombatValue = spellBlock.maxCombatValue;
      spellBlock.spell->castSpell(this, this);
    }
  }

  if (!isSummon() && summons.size() < mType->info.maxSummons && hasFollowPath) {
    for (const summonBlock_t &summonBlock : mType->info.summons) {
      if (summonBlock.speed > defenseTicks) {
        resetTicks = false;
        continue;
      }

      if (summons.size() >= mType->info.maxSummons) {
        continue;
      }

      if (defenseTicks % summonBlock.speed >= interval) {
        // already used this spell for this round
        continue;
      }

      uint32_t summonCount = 0;
      for (Creature *summon : summons) {
        if (summon->getName() == summonBlock.name) {
          ++summonCount;
        }
      }

      if (summonCount >= summonBlock.max) {
        continue;
      }

      if (summonBlock.chance < static_cast<uint32_t>(uniform_random(1, 100))) {
        continue;
      }

      Monster *summon = Monster::createMonster(summonBlock.name);
      if (summon) {
        if (g_game.placeCreature(summon, getPosition(), false,
                                 summonBlock.force)) {
          summon->setDropLoot(false);
          summon->setSkillLoss(false);
          summon->setMaster(this);
          summon->setInstanceID(getInstanceID());
          g_game.addMagicEffect(getPosition(), CONST_ME_MAGIC_BLUE, getInstanceID());
          g_game.addMagicEffect(summon->getPosition(), CONST_ME_TELEPORT, getInstanceID());
        } else {
          delete summon;
        }
      }
    }
  }

  if (resetTicks) {
    defenseTicks = 0;
  }
}

void Monster::onThinkYell(uint32_t interval) {
  if (mType->info.yellSpeedTicks == 0) {
    return;
  }

  yellTicks += interval;
  if (yellTicks >= mType->info.yellSpeedTicks) {
    yellTicks = 0;

    if (!mType->info.voiceVector.empty() &&
        (mType->info.yellChance >=
         static_cast<uint32_t>(uniform_random(1, 100)))) {
      uint32_t index = uniform_random(0, mType->info.voiceVector.size() - 1);
      const voiceBlock_t &vb = mType->info.voiceVector[index];

      if (vb.yellText) {
        g_game.internalCreatureSay(this, TALKTYPE_MONSTER_YELL, vb.text, false);
      } else {
        g_game.internalCreatureSay(this, TALKTYPE_MONSTER_SAY, vb.text, false);
      }
    }
  }
}

void Monster::onWalk() { Creature::onWalk(); }

bool Monster::pushItem(Item *item, uint32_t instanceId) {
  const Position &centerPos = item->getPosition();

  static std::vector<std::pair<int32_t, int32_t>> relList{
      {-1, -1}, {0, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}};

  std::shuffle(relList.begin(), relList.end(), getRandomGenerator());

  for (const auto &it : relList) {
    Position tryPos(centerPos.x + it.first, centerPos.y + it.second,
                    centerPos.z);
    Tile *tile = g_game.map.getTile(tryPos);
    if (tile && g_game.canThrowObjectTo(centerPos, tryPos)) {
      if (g_game.internalMoveItem(item->getParent(), tile, INDEX_WHEREEVER,
                                  item, item->getItemCount(),
                                  nullptr) == RETURNVALUE_NOERROR) {
        return true;
      }
    }
  }
  return false;
}

void Monster::pushItems(Tile *tile, uint32_t instanceId) {
  // We can not use iterators here since we can push the item to another tile
  // which will invalidate the iterator.
  // start from the end to minimize the amount of traffic
  if (TileItemVector *items = tile->getItemList()) {
    uint32_t moveCount = 0;
    uint32_t removeCount = 0;

    int32_t downItemSize = tile->getDownItemCount();
    for (int32_t i = downItemSize; --i >= 0;) {
      Item *item = items->at(i);
      if (item && item->hasProperty(CONST_PROP_MOVEABLE) &&
          (item->hasProperty(CONST_PROP_BLOCKPATH) ||
           item->hasProperty(CONST_PROP_BLOCKSOLID))) {
        if (moveCount < 20 && Monster::pushItem(item, instanceId)) {
          ++moveCount;
        } else if (g_game.internalRemoveItem(item) == RETURNVALUE_NOERROR) {
          ++removeCount;
        }
      }
    }

    if (removeCount > 0) {
      g_game.addMagicEffect(tile->getPosition(), CONST_ME_POFF, instanceId);
    }
  }
}

bool Monster::pushCreature(Creature *creature, uint32_t instanceId) {
  static std::vector<Direction> dirList{DIRECTION_NORTH, DIRECTION_WEST,
                                        DIRECTION_EAST, DIRECTION_SOUTH};
  std::shuffle(dirList.begin(), dirList.end(), getRandomGenerator());

  for (Direction dir : dirList) {
    const Position &tryPos = Spells::getCasterPosition(creature, dir);
    Tile *toTile = g_game.map.getTile(tryPos);
    if (toTile && !toTile->hasFlag(TILESTATE_BLOCKPATH)) {
      if (g_game.internalMoveCreature(creature, dir) == RETURNVALUE_NOERROR) {
        return true;
      }
    }
  }
  return false;
}

void Monster::pushCreatures(Tile *tile, uint32_t instanceId) {
  // We can not use iterators here since we can push a creature to another tile
  // which will invalidate the iterator.
  if (CreatureVector *creatures = tile->getCreatures()) {
    uint32_t removeCount = 0;
    Monster *lastPushedMonster = nullptr;

    for (size_t i = 0; i < creatures->size();) {
      Monster *monster = creatures->at(i)->getMonster();
      if (monster && monster->isPushable()) {
        if (monster != lastPushedMonster && Monster::pushCreature(monster, instanceId)) {
          lastPushedMonster = monster;
          continue;
        }

        monster->changeHealth(-monster->getHealth());
        removeCount++;
      }

      ++i;
    }

    if (removeCount > 0) {
      g_game.addMagicEffect(tile->getPosition(), CONST_ME_BLOCKHIT, instanceId);
    }
  }
}

bool Monster::getNextStep(Direction &dir, uint32_t &flags) {
  if (isIdle || getHealth() <= 0) {
    // we dont have anyone watching might aswell stop walking
    eventWalk = 0;
    return false;
  }

  bool result = false;
  if ((!followCreature || !hasFollowPath) &&
      (!isSummon() || !isMasterInRange)) {
    if (getTimeSinceLastMove() >= 1000) {
      randomStepping = true;
      result = getRandomStep(getPosition(), dir);
    }
  } else if ((isSummon() && isMasterInRange) || followCreature) {
    randomStepping = false;
    result = Creature::getNextStep(dir, flags);
    if (!result) {
      if (ignoreFieldDamage) {
        ignoreFieldDamage = false;
        updateMapCache();
      }
      // target dancing
      if (attackedCreature && attackedCreature == followCreature) {
        if (isFleeing())
          result = getDanceStep(getPosition(), dir, false, false);
        else if (mType->info.staticAttackChance <
                 static_cast<uint32_t>(uniform_random(1, 100)))
          result = getDanceStep(getPosition(), dir);
      }
    } else
      flags |= FLAG_PATHFINDING;
  }

  if (result && (canPushItems() || canPushCreatures())) {
    const Position &pos = Spells::getCasterPosition(this, dir);
    Tile *tile = g_game.map.getTile(pos);
    if (tile) {
      if (canPushItems())
        pushItems(tile, getInstanceID());

      if (canPushCreatures())
        pushCreatures(tile, getInstanceID());
    }
#ifdef __DEBUG__
    else
      std::clog << "[Warning - Monster::getNextStep] no tile found."
                << std::endl;
#endif
  }

  return result;
}

bool Monster::getRandomStep(const Position &creaturePos,
                            Direction &direction) const {
  static std::vector<Direction> dirList{DIRECTION_NORTH, DIRECTION_WEST,
                                        DIRECTION_EAST, DIRECTION_SOUTH};
  std::shuffle(dirList.begin(), dirList.end(), getRandomGenerator());

  for (Direction dir : dirList) {
    if (canWalkTo(creaturePos, dir)) {
      direction = dir;
      return true;
    }
  }
  return false;
}

bool Monster::getDanceStep(const Position &creaturePos, Direction &direction,
                           bool keepAttack /*= true*/,
                           bool keepDistance /*= true*/) {
  bool canDoAttackNow = canUseAttack(creaturePos, attackedCreature);

  assert(attackedCreature != nullptr);
  const Position &centerPos = attackedCreature->getPosition();

  int_fast32_t offset_x = Position::getOffsetX(creaturePos, centerPos);
  int_fast32_t offset_y = Position::getOffsetY(creaturePos, centerPos);

  int_fast32_t distance_x = std::abs(offset_x);
  int_fast32_t distance_y = std::abs(offset_y);

  uint32_t centerToDist = std::max<uint32_t>(distance_x, distance_y);

  std::vector<Direction> dirList;

  if (!keepDistance || offset_y >= 0) {
    uint32_t tmpDist = std::max<uint32_t>(
        distance_x, std::abs((creaturePos.getY() - 1) - centerPos.getY()));
    if (tmpDist == centerToDist && canWalkTo(creaturePos, DIRECTION_NORTH)) {
      bool result = true;

      if (keepAttack) {
        result = (!canDoAttackNow ||
                  canUseAttack(
                      Position(creaturePos.x, creaturePos.y - 1, creaturePos.z),
                      attackedCreature));
      }

      if (result) {
        dirList.push_back(DIRECTION_NORTH);
      }
    }
  }

  if (!keepDistance || offset_y <= 0) {
    uint32_t tmpDist = std::max<uint32_t>(
        distance_x, std::abs((creaturePos.getY() + 1) - centerPos.getY()));
    if (tmpDist == centerToDist && canWalkTo(creaturePos, DIRECTION_SOUTH)) {
      bool result = true;

      if (keepAttack) {
        result = (!canDoAttackNow ||
                  canUseAttack(
                      Position(creaturePos.x, creaturePos.y + 1, creaturePos.z),
                      attackedCreature));
      }

      if (result) {
        dirList.push_back(DIRECTION_SOUTH);
      }
    }
  }

  if (!keepDistance || offset_x <= 0) {
    uint32_t tmpDist = std::max<uint32_t>(
        std::abs((creaturePos.getX() + 1) - centerPos.getX()), distance_y);
    if (tmpDist == centerToDist && canWalkTo(creaturePos, DIRECTION_EAST)) {
      bool result = true;

      if (keepAttack) {
        result = (!canDoAttackNow ||
                  canUseAttack(
                      Position(creaturePos.x + 1, creaturePos.y, creaturePos.z),
                      attackedCreature));
      }

      if (result) {
        dirList.push_back(DIRECTION_EAST);
      }
    }
  }

  if (!keepDistance || offset_x >= 0) {
    uint32_t tmpDist = std::max<uint32_t>(
        std::abs((creaturePos.getX() - 1) - centerPos.getX()), distance_y);
    if (tmpDist == centerToDist && canWalkTo(creaturePos, DIRECTION_WEST)) {
      bool result = true;

      if (keepAttack) {
        result = (!canDoAttackNow ||
                  canUseAttack(
                      Position(creaturePos.x - 1, creaturePos.y, creaturePos.z),
                      attackedCreature));
      }

      if (result) {
        dirList.push_back(DIRECTION_WEST);
      }
    }
  }

  if (!dirList.empty()) {
    std::shuffle(dirList.begin(), dirList.end(), getRandomGenerator());
    direction = dirList[uniform_random(0, dirList.size() - 1)];
    return true;
  }
  return false;
}

bool Monster::getDistanceStep(const Position &targetPos, Direction &direction,
                              bool flee /* = false */) {
  const Position &creaturePos = getPosition();

  int_fast32_t dx = Position::getDistanceX(creaturePos, targetPos);
  int_fast32_t dy = Position::getDistanceY(creaturePos, targetPos);

  int32_t distance = std::max<int32_t>(dx, dy);

  if (!flee && (distance > mType->info.targetDistance ||
                !g_game.isSightClear(creaturePos, targetPos, true))) {
    return false; // let the A* calculate it
  } else if (!flee && distance == mType->info.targetDistance) {
    return true; // we don't really care here, since it's what we wanted to
                 // reach (a dancestep will take of dancing in that position)
  }

  int_fast32_t offsetx = Position::getOffsetX(creaturePos, targetPos);
  int_fast32_t offsety = Position::getOffsetY(creaturePos, targetPos);

  if (dx <= 1 && dy <= 1) {
    // seems like a target is near, it this case we need to slow down our
    // movements (as a monster)
    if (stepDuration < 2) {
      stepDuration++;
    }
  } else if (stepDuration > 0) {
    stepDuration--;
  }

  if (offsetx == 0 && offsety == 0) {
    return getRandomStep(
        creaturePos,
        direction); // player is "on" the monster so let's get some random step
                    // and rest will be taken care later.
  }

  if (dx == dy) {
    // player is diagonal to the monster
    if (offsetx >= 1 && offsety >= 1) {
      // player is NW
      // escape to SE, S or E [and some extra]
      bool s = canWalkTo(creaturePos, DIRECTION_SOUTH);
      bool e = canWalkTo(creaturePos, DIRECTION_EAST);

      if (s && e) {
        direction = boolean_random() ? DIRECTION_SOUTH : DIRECTION_EAST;
        return true;
      } else if (s) {
        direction = DIRECTION_SOUTH;
        return true;
      } else if (e) {
        direction = DIRECTION_EAST;
        return true;
      } else if (canWalkTo(creaturePos, DIRECTION_SOUTHEAST)) {
        direction = DIRECTION_SOUTHEAST;
        return true;
      }

      /* fleeing */
      bool n = canWalkTo(creaturePos, DIRECTION_NORTH);
      bool w = canWalkTo(creaturePos, DIRECTION_WEST);

      if (flee) {
        if (n && w) {
          direction = boolean_random() ? DIRECTION_NORTH : DIRECTION_WEST;
          return true;
        } else if (n) {
          direction = DIRECTION_NORTH;
          return true;
        } else if (w) {
          direction = DIRECTION_WEST;
          return true;
        }
      }

      /* end of fleeing */

      if (w && canWalkTo(creaturePos, DIRECTION_SOUTHWEST)) {
        direction = DIRECTION_WEST;
      } else if (n && canWalkTo(creaturePos, DIRECTION_NORTHEAST)) {
        direction = DIRECTION_NORTH;
      }

      return true;
    } else if (offsetx <= -1 && offsety <= -1) {
      // player is SE
      // escape to NW , W or N [and some extra]
      bool w = canWalkTo(creaturePos, DIRECTION_WEST);
      bool n = canWalkTo(creaturePos, DIRECTION_NORTH);

      if (w && n) {
        direction = boolean_random() ? DIRECTION_WEST : DIRECTION_NORTH;
        return true;
      } else if (w) {
        direction = DIRECTION_WEST;
        return true;
      } else if (n) {
        direction = DIRECTION_NORTH;
        return true;
      }

      if (canWalkTo(creaturePos, DIRECTION_NORTHWEST)) {
        direction = DIRECTION_NORTHWEST;
        return true;
      }

      /* fleeing */
      bool s = canWalkTo(creaturePos, DIRECTION_SOUTH);
      bool e = canWalkTo(creaturePos, DIRECTION_EAST);

      if (flee) {
        if (s && e) {
          direction = boolean_random() ? DIRECTION_SOUTH : DIRECTION_EAST;
          return true;
        } else if (s) {
          direction = DIRECTION_SOUTH;
          return true;
        } else if (e) {
          direction = DIRECTION_EAST;
          return true;
        }
      }

      /* end of fleeing */

      if (s && canWalkTo(creaturePos, DIRECTION_SOUTHWEST)) {
        direction = DIRECTION_SOUTH;
      } else if (e && canWalkTo(creaturePos, DIRECTION_NORTHEAST)) {
        direction = DIRECTION_EAST;
      }

      return true;
    } else if (offsetx >= 1 && offsety <= -1) {
      // player is SW
      // escape to NE, N, E [and some extra]
      bool n = canWalkTo(creaturePos, DIRECTION_NORTH);
      bool e = canWalkTo(creaturePos, DIRECTION_EAST);
      if (n && e) {
        direction = boolean_random() ? DIRECTION_NORTH : DIRECTION_EAST;
        return true;
      } else if (n) {
        direction = DIRECTION_NORTH;
        return true;
      } else if (e) {
        direction = DIRECTION_EAST;
        return true;
      }

      if (canWalkTo(creaturePos, DIRECTION_NORTHEAST)) {
        direction = DIRECTION_NORTHEAST;
        return true;
      }

      /* fleeing */
      bool s = canWalkTo(creaturePos, DIRECTION_SOUTH);
      bool w = canWalkTo(creaturePos, DIRECTION_WEST);

      if (flee) {
        if (s && w) {
          direction = boolean_random() ? DIRECTION_SOUTH : DIRECTION_WEST;
          return true;
        } else if (s) {
          direction = DIRECTION_SOUTH;
          return true;
        } else if (w) {
          direction = DIRECTION_WEST;
          return true;
        }
      }

      /* end of fleeing */

      if (w && canWalkTo(creaturePos, DIRECTION_NORTHWEST)) {
        direction = DIRECTION_WEST;
      } else if (s && canWalkTo(creaturePos, DIRECTION_SOUTHEAST)) {
        direction = DIRECTION_SOUTH;
      }

      return true;
    } else if (offsetx <= -1 && offsety >= 1) {
      // player is NE
      // escape to SW, S, W [and some extra]
      bool w = canWalkTo(creaturePos, DIRECTION_WEST);
      bool s = canWalkTo(creaturePos, DIRECTION_SOUTH);
      if (w && s) {
        direction = boolean_random() ? DIRECTION_WEST : DIRECTION_SOUTH;
        return true;
      } else if (w) {
        direction = DIRECTION_WEST;
        return true;
      } else if (s) {
        direction = DIRECTION_SOUTH;
        return true;
      } else if (canWalkTo(creaturePos, DIRECTION_SOUTHWEST)) {
        direction = DIRECTION_SOUTHWEST;
        return true;
      }

      /* fleeing */
      bool n = canWalkTo(creaturePos, DIRECTION_NORTH);
      bool e = canWalkTo(creaturePos, DIRECTION_EAST);

      if (flee) {
        if (n && e) {
          direction = boolean_random() ? DIRECTION_NORTH : DIRECTION_EAST;
          return true;
        } else if (n) {
          direction = DIRECTION_NORTH;
          return true;
        } else if (e) {
          direction = DIRECTION_EAST;
          return true;
        }
      }

      /* end of fleeing */

      if (e && canWalkTo(creaturePos, DIRECTION_SOUTHEAST)) {
        direction = DIRECTION_EAST;
      } else if (n && canWalkTo(creaturePos, DIRECTION_NORTHWEST)) {
        direction = DIRECTION_NORTH;
      }

      return true;
    }
  }

  // Now let's decide where the player is located to the monster (what
  // direction) so we can decide where to escape.
  if (dy > dx) {
    Direction playerDir = offsety < 0 ? DIRECTION_SOUTH : DIRECTION_NORTH;
    switch (playerDir) {
    case DIRECTION_NORTH: {
      // Player is to the NORTH, so obviously we need to check if we can go
      // SOUTH, if not then let's choose WEST or EAST and again if we can't we
      // need to decide about some diagonal movements.
      if (canWalkTo(creaturePos, DIRECTION_SOUTH)) {
        direction = DIRECTION_SOUTH;
        return true;
      }

      bool w = canWalkTo(creaturePos, DIRECTION_WEST);
      bool e = canWalkTo(creaturePos, DIRECTION_EAST);
      if (w && e && offsetx == 0) {
        direction = boolean_random() ? DIRECTION_WEST : DIRECTION_EAST;
        return true;
      } else if (w && offsetx <= 0) {
        direction = DIRECTION_WEST;
        return true;
      } else if (e && offsetx >= 0) {
        direction = DIRECTION_EAST;
        return true;
      }

      /* fleeing */
      if (flee) {
        if (w && e) {
          direction = boolean_random() ? DIRECTION_WEST : DIRECTION_EAST;
          return true;
        } else if (w) {
          direction = DIRECTION_WEST;
          return true;
        } else if (e) {
          direction = DIRECTION_EAST;
          return true;
        }
      }

      /* end of fleeing */

      bool sw = canWalkTo(creaturePos, DIRECTION_SOUTHWEST);
      bool se = canWalkTo(creaturePos, DIRECTION_SOUTHEAST);
      if (sw || se) {
        // we can move both dirs
        if (sw && se) {
          direction =
              boolean_random() ? DIRECTION_SOUTHWEST : DIRECTION_SOUTHEAST;
        } else if (w) {
          direction = DIRECTION_WEST;
        } else if (sw) {
          direction = DIRECTION_SOUTHWEST;
        } else if (e) {
          direction = DIRECTION_EAST;
        } else if (se) {
          direction = DIRECTION_SOUTHEAST;
        }
        return true;
      }

      /* fleeing */
      if (flee && canWalkTo(creaturePos, DIRECTION_NORTH)) {
        // towards player, yea
        direction = DIRECTION_NORTH;
        return true;
      }

      /* end of fleeing */
      break;
    }

    case DIRECTION_SOUTH: {
      if (canWalkTo(creaturePos, DIRECTION_NORTH)) {
        direction = DIRECTION_NORTH;
        return true;
      }

      bool w = canWalkTo(creaturePos, DIRECTION_WEST);
      bool e = canWalkTo(creaturePos, DIRECTION_EAST);
      if (w && e && offsetx == 0) {
        direction = boolean_random() ? DIRECTION_WEST : DIRECTION_EAST;
        return true;
      } else if (w && offsetx <= 0) {
        direction = DIRECTION_WEST;
        return true;
      } else if (e && offsetx >= 0) {
        direction = DIRECTION_EAST;
        return true;
      }

      /* fleeing */
      if (flee) {
        if (w && e) {
          direction = boolean_random() ? DIRECTION_WEST : DIRECTION_EAST;
          return true;
        } else if (w) {
          direction = DIRECTION_WEST;
          return true;
        } else if (e) {
          direction = DIRECTION_EAST;
          return true;
        }
      }

      /* end of fleeing */

      bool nw = canWalkTo(creaturePos, DIRECTION_NORTHWEST);
      bool ne = canWalkTo(creaturePos, DIRECTION_NORTHEAST);
      if (nw || ne) {
        // we can move both dirs
        if (nw && ne) {
          direction =
              boolean_random() ? DIRECTION_NORTHWEST : DIRECTION_NORTHEAST;
        } else if (w) {
          direction = DIRECTION_WEST;
        } else if (nw) {
          direction = DIRECTION_NORTHWEST;
        } else if (e) {
          direction = DIRECTION_EAST;
        } else if (ne) {
          direction = DIRECTION_NORTHEAST;
        }
        return true;
      }

      /* fleeing */
      if (flee && canWalkTo(creaturePos, DIRECTION_SOUTH)) {
        // towards player, yea
        direction = DIRECTION_SOUTH;
        return true;
      }

      /* end of fleeing */
      break;
    }

    default:
      break;
    }
  } else {
    Direction playerDir = offsetx < 0 ? DIRECTION_EAST : DIRECTION_WEST;
    switch (playerDir) {
    case DIRECTION_WEST: {
      if (canWalkTo(creaturePos, DIRECTION_EAST)) {
        direction = DIRECTION_EAST;
        return true;
      }

      bool n = canWalkTo(creaturePos, DIRECTION_NORTH);
      bool s = canWalkTo(creaturePos, DIRECTION_SOUTH);
      if (n && s && offsety == 0) {
        direction = boolean_random() ? DIRECTION_NORTH : DIRECTION_SOUTH;
        return true;
      } else if (n && offsety <= 0) {
        direction = DIRECTION_NORTH;
        return true;
      } else if (s && offsety >= 0) {
        direction = DIRECTION_SOUTH;
        return true;
      }

      /* fleeing */
      if (flee) {
        if (n && s) {
          direction = boolean_random() ? DIRECTION_NORTH : DIRECTION_SOUTH;
          return true;
        } else if (n) {
          direction = DIRECTION_NORTH;
          return true;
        } else if (s) {
          direction = DIRECTION_SOUTH;
          return true;
        }
      }

      /* end of fleeing */

      bool se = canWalkTo(creaturePos, DIRECTION_SOUTHEAST);
      bool ne = canWalkTo(creaturePos, DIRECTION_NORTHEAST);
      if (se || ne) {
        if (se && ne) {
          direction =
              boolean_random() ? DIRECTION_SOUTHEAST : DIRECTION_NORTHEAST;
        } else if (s) {
          direction = DIRECTION_SOUTH;
        } else if (se) {
          direction = DIRECTION_SOUTHEAST;
        } else if (n) {
          direction = DIRECTION_NORTH;
        } else if (ne) {
          direction = DIRECTION_NORTHEAST;
        }
        return true;
      }

      /* fleeing */
      if (flee && canWalkTo(creaturePos, DIRECTION_WEST)) {
        // towards player, yea
        direction = DIRECTION_WEST;
        return true;
      }

      /* end of fleeing */
      break;
    }

    case DIRECTION_EAST: {
      if (canWalkTo(creaturePos, DIRECTION_WEST)) {
        direction = DIRECTION_WEST;
        return true;
      }

      bool n = canWalkTo(creaturePos, DIRECTION_NORTH);
      bool s = canWalkTo(creaturePos, DIRECTION_SOUTH);
      if (n && s && offsety == 0) {
        direction = boolean_random() ? DIRECTION_NORTH : DIRECTION_SOUTH;
        return true;
      } else if (n && offsety <= 0) {
        direction = DIRECTION_NORTH;
        return true;
      } else if (s && offsety >= 0) {
        direction = DIRECTION_SOUTH;
        return true;
      }

      /* fleeing */
      if (flee) {
        if (n && s) {
          direction = boolean_random() ? DIRECTION_NORTH : DIRECTION_SOUTH;
          return true;
        } else if (n) {
          direction = DIRECTION_NORTH;
          return true;
        } else if (s) {
          direction = DIRECTION_SOUTH;
          return true;
        }
      }

      /* end of fleeing */

      bool nw = canWalkTo(creaturePos, DIRECTION_NORTHWEST);
      bool sw = canWalkTo(creaturePos, DIRECTION_SOUTHWEST);
      if (nw || sw) {
        if (nw && sw) {
          direction =
              boolean_random() ? DIRECTION_NORTHWEST : DIRECTION_SOUTHWEST;
        } else if (n) {
          direction = DIRECTION_NORTH;
        } else if (nw) {
          direction = DIRECTION_NORTHWEST;
        } else if (s) {
          direction = DIRECTION_SOUTH;
        } else if (sw) {
          direction = DIRECTION_SOUTHWEST;
        }
        return true;
      }

      /* fleeing */
      if (flee && canWalkTo(creaturePos, DIRECTION_EAST)) {
        // towards player, yea
        direction = DIRECTION_EAST;
        return true;
      }

      /* end of fleeing */
      break;
    }

    default:
      break;
    }
  }

  return true;
}

bool Monster::canWalkTo(Position pos, Direction direction) const {
  pos = getNextPosition(direction, pos);
  if (isInSpawnRange(pos)) {
    if (getWalkCache(pos) == 0) {
      return false;
    }

    Tile *tile = g_game.map.getTile(pos);
    if (tile && tile->getTopVisibleCreature(this) == nullptr &&
        tile->queryAdd(0, *this, 1, FLAG_PATHFINDING) == RETURNVALUE_NOERROR) {
      return true;
    }
  }
  return false;
}

void Monster::death(Creature *lastHitCreature) {
  setAttackedCreature(nullptr);

  for (Creature *summon : summons) {
    summon->changeHealth(-summon->getHealth());
    summon->removeMaster();
  }
  summons.clear();

  clearTargetList();
  clearFriendList();
  onIdleStatus();

  // Monster Level System: spawn leveled monster on death
  if (g_config.getBoolean(ConfigManager::MLVL_ENABLED) && !isSummon() &&
      getLevel() == 0) {
    int32_t spawnChance = g_config.getNumber(ConfigManager::MLVL_SPAWNCHANCE);
    if (spawnChance > 0 && uniform_random(1, 100) <= spawnChance) {
      int32_t maxLevel = g_config.getNumber(ConfigManager::MLVL_MAXLEVEL);
      if (maxLevel > 0) {
        Position deathPos = getPosition();
        std::string monsterName = mType->name;

        uint32_t instanceId = getInstanceID();
        std::function<void(void)> spawnTask = [deathPos, monsterName,
                                               maxLevel, instanceId]() {
          Monster *newMonster = Monster::createMonster(monsterName);
          if (newMonster) {
            int32_t newLevel = uniform_random(1, maxLevel);
            newMonster->setLevel(newLevel);
            newMonster->setInstanceID(instanceId);

            if (g_game.placeCreature(newMonster, deathPos, true, true)) {
              g_game.addMagicEffect(deathPos, CONST_ME_TELEPORT, instanceId);
            } else {
              delete newMonster;
            }
          }
        };
        g_scheduler.addEvent(createSchedulerTask(500, std::move(spawnTask)));
      }
    }
  }
}

Item *Monster::getCorpse(Creature *lastHitCreature,
                         Creature *mostDamageCreature) {
  Item *corpse = Creature::getCorpse(lastHitCreature, mostDamageCreature);
  if (corpse) {
    if (mostDamageCreature) {
      if (mostDamageCreature->getPlayer()) {
        corpse->setCorpseOwner(mostDamageCreature->getID());
      } else {
        const Creature *mostDamageCreatureMaster =
            mostDamageCreature->getMaster();
        if (mostDamageCreatureMaster && mostDamageCreatureMaster->getPlayer()) {
          corpse->setCorpseOwner(mostDamageCreatureMaster->getID());
        }
      }
    }
  }
  return corpse;
}

bool Monster::isInSpawnRange(const Position &pos) const {
  if (!spawn) {
    return true;
  }

  if (Monster::despawnRadius == 0) {
    return true;
  }

  if (!Spawns::isInZone(masterPos, Monster::despawnRadius, pos)) {
    return false;
  }

  if (Monster::despawnRange == 0) {
    return true;
  }

  if (Position::getDistanceZ(pos, masterPos) > Monster::despawnRange) {
    return false;
  }

  return true;
}

bool Monster::getCombatValues(int32_t &min, int32_t &max) {
  if (minCombatValue == 0 && maxCombatValue == 0) {
    return false;
  }

  min = minCombatValue;
  max = maxCombatValue;
  return true;
}

void Monster::updateLookDirection() {
  Direction newDir = getDirection();

  if (attackedCreature) {
    const Position &pos = getPosition();
    const Position &attackedCreaturePos = attackedCreature->getPosition();
    int_fast32_t offsetx = Position::getOffsetX(attackedCreaturePos, pos);
    int_fast32_t offsety = Position::getOffsetY(attackedCreaturePos, pos);

    int32_t dx = std::abs(offsetx);
    int32_t dy = std::abs(offsety);
    if (dx > dy) {
      // look EAST/WEST
      if (offsetx < 0) {
        newDir = DIRECTION_WEST;
      } else {
        newDir = DIRECTION_EAST;
      }
    } else if (dx < dy) {
      // look NORTH/SOUTH
      if (offsety < 0) {
        newDir = DIRECTION_NORTH;
      } else {
        newDir = DIRECTION_SOUTH;
      }
    } else {
      Direction dir = getDirection();
      if (offsetx < 0 && offsety < 0) {
        if (dir == DIRECTION_SOUTH) {
          newDir = DIRECTION_WEST;
        } else if (dir == DIRECTION_NORTH) {
          newDir = DIRECTION_WEST;
        } else if (dir == DIRECTION_EAST) {
          newDir = DIRECTION_NORTH;
        }
      } else if (offsetx < 0 && offsety > 0) {
        if (dir == DIRECTION_NORTH) {
          newDir = DIRECTION_WEST;
        } else if (dir == DIRECTION_SOUTH) {
          newDir = DIRECTION_WEST;
        } else if (dir == DIRECTION_EAST) {
          newDir = DIRECTION_SOUTH;
        }
      } else if (offsetx > 0 && offsety < 0) {
        if (dir == DIRECTION_SOUTH) {
          newDir = DIRECTION_EAST;
        } else if (dir == DIRECTION_NORTH) {
          newDir = DIRECTION_EAST;
        } else if (dir == DIRECTION_WEST) {
          newDir = DIRECTION_NORTH;
        }
      } else {
        if (dir == DIRECTION_NORTH) {
          newDir = DIRECTION_EAST;
        } else if (dir == DIRECTION_SOUTH) {
          newDir = DIRECTION_EAST;
        } else if (dir == DIRECTION_WEST) {
          newDir = DIRECTION_SOUTH;
        }
      }
    }
  }

  g_game.internalCreatureTurn(this, newDir);
}

void Monster::dropLoot(Container *corpse, Creature *lastHitCreature) {
  if (corpse && lootDrop) {
    g_events->eventMonsterOnDropLoot(this, corpse);

    Player *player = g_game.getPlayerByID(corpse->getCorpseOwner());
    if (!player && lastHitCreature) {
      player = lastHitCreature->getPlayer();
    }

    if (player) {
      const int32_t AUTOLOOT_STORAGE_START = 10000;
      const int32_t AUTO_LOOT_MAX_ITEMS = 10;
      std::vector<uint16_t> autoLootItems;

      for (int32_t i = 0; i <= AUTO_LOOT_MAX_ITEMS; ++i) {
        int32_t itemId = 0;
        if (player->getStorageValue(AUTOLOOT_STORAGE_START + i, itemId) &&
            itemId > 0) {
          autoLootItems.push_back(static_cast<uint16_t>(itemId));
        }
      }

      if (!autoLootItems.empty()) {
        std::vector<Item *> itemsToMove;
        for (Item *item : corpse->getItemList()) {
          if (std::find(autoLootItems.begin(), autoLootItems.end(),
                        item->getID()) != autoLootItems.end()) {
            itemsToMove.push_back(item);
          }
        }

        for (Item *item : itemsToMove) {
          Item *moveItem = nullptr;
          g_game.internalMoveItem(corpse, player, INDEX_WHEREEVER, item,
                                  item->getItemCount(), &moveItem, 0, player,
                                  nullptr);
        }
      }
    }
  }
}

void Monster::setNormalCreatureLight() { internalLight = mType->info.light; }

void Monster::drainHealth(Creature *attacker, int32_t damage) {
  Creature::drainHealth(attacker, damage);

  if (damage > 0 && randomStepping) {
    ignoreFieldDamage = true;
    updateMapCache();
  }

  if (isInvisible()) {
    removeCondition(CONDITION_INVISIBLE);
  }
}

void Monster::changeHealth(int32_t healthChange,
                           bool sendHealthChange /* = true*/) {
  // In case a player with ignore flag set attacks the monster
  setIdle(false);
  Creature::changeHealth(healthChange, sendHealthChange);
}

bool Monster::challengeCreature(Creature *creature) {
  if (isSummon()) {
    return false;
  }

  bool result = selectTarget(creature);
  if (result) {
    targetChangeCooldown = 8000;
    targetChangeTicks = 0;
  }
  return result;
}

void Monster::getPathSearchParams(const Creature *creature,
                                  FindPathParams &fpp) const {
  Creature::getPathSearchParams(creature, fpp);

  fpp.minTargetDist = 1;
  fpp.maxTargetDist = mType->info.targetDistance;

  if (isSummon()) {
    if (getMaster() == creature) {
      fpp.maxTargetDist = 2;
      fpp.fullPathSearch = true;
    } else if (mType->info.targetDistance <= 1) {
      fpp.fullPathSearch = true;
    } else {
      fpp.fullPathSearch = !canUseAttack(getPosition(), creature);
    }
  } else if (isFleeing()) {
    // Distance should be higher than the client view range
    // (Map::maxClientViewportX/Map::maxClientViewportY)
    fpp.maxTargetDist = Map::maxViewportX;
    fpp.clearSight = fpp.fullPathSearch = false;
    fpp.keepDistance = true;
  } else if (mType->info.targetDistance <= 1) {
    fpp.fullPathSearch = true;
  } else {
    fpp.fullPathSearch = !canUseAttack(getPosition(), creature);
  }
}

bool Monster::canPushItems() const {
  Monster *master = this->master ? this->master->getMonster() : nullptr;
  if (master) {
    return master->mType->info.canPushItems;
  }

  return mType->info.canPushItems;
}