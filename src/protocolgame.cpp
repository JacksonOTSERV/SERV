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

#include <boost/range/adaptor/reversed.hpp>

#include "protocolgame.h"
#include "protocolspectator.h"

#include "outputmessage.h"

#include "player.h"

#include "actions.h"
#include "ban.h"
#include "configmanager.h"
#include "databasetasks.h"
#include "game.h"
#include "instance_utils.h"
#include "iologindata.h"
#include "iomarket.h"
#include "monster.h"
#include "scheduler.h"
#include "waitlist.h"

#define FMT_HEADER_ONLY
#define FMT_UNICODE 0
#include <fmt/format.h>

static std::map<ProtocolGame *, uint32_t> spectatorCounter;
static std::map<ProtocolSpectator_ptr, std::string> spectatorNames;

extern Game g_game;
extern ConfigManager g_config;
extern Actions actions;
extern CreatureEvents *g_creatureEvents;
extern Chat *g_chat;

ProtocolGame::LiveCastsMap ProtocolGame::liveCasts;

void ProtocolGame::spectatorRelease() {
  if (spect && player) {
    spect->removeSpectator(
        std::static_pointer_cast<ProtocolSpectator>(shared_from_this()));
    player->decrementReferenceCounter();
    player = nullptr;
  }
  Protocol::release();
  OutputMessagePool::getInstance().removeProtocolFromAutosend(
      shared_from_this());
}

void ProtocolGame::release() {
  // dispatcher thread
  stopLiveCast();
  if (player && player->client == shared_from_this()) {
    player->client.reset();
    player->decrementReferenceCounter();
    player = nullptr;
  }

  OutputMessagePool::getInstance().removeProtocolFromAutosend(
      shared_from_this());
  Protocol::release();
}

void ProtocolGame::forceRemoveFromSpectatorList() {
  if (m_spectator && spect && player) {
    spect->removeSpectator(
        std::static_pointer_cast<ProtocolSpectator>(shared_from_this()));
    player->decrementReferenceCounter();
    player = nullptr;
  }
}

bool ProtocolGame::isSpectatorConnection() const { return m_spectator; }

void ProtocolGame::login(const std::string &name, uint32_t accountId,
                         OperatingSystem_t operatingSystem) {

  if (otclientV8 || operatingSystem >= CLIENTOS_OTCLIENT_LINUX) {
    if (otclientV8)
      sendFeatures();
    NetworkMessage opcodeMessage;
    opcodeMessage.addByte(0x32);
    opcodeMessage.addByte(0x00);
    opcodeMessage.add<uint16_t>(0x00);
    writeToOutputBuffer(opcodeMessage);
  }

  Player *foundPlayer = g_game.getPlayerByName(name);
  if (!foundPlayer || g_config.getBoolean(ConfigManager::ALLOW_CLONES)) {
    player = new Player(getThis());
    player->setName(name);

    player->incrementReferenceCounter();

    if (!IOLoginData::preloadPlayer(player, name)) {
      disconnectClient("Não foi possível carregar seu personagem.");
      return;
    }

    player->setID();
    if (IOBan::isPlayerNamelocked(player->getGUID())) {
      disconnectClient("Seu personagem foi bloqueado pelo nome.");
      return;
    }

    if (g_game.getGameState() == GAME_STATE_CLOSING &&
        !player->hasFlag(PlayerFlag_CanAlwaysLogin)) {
      disconnectClient(
          "O jogo está desligando.\nPor favor, tente novamente mais tarde.");
      return;
    }

    if (g_game.getGameState() == GAME_STATE_CLOSED &&
        !player->hasFlag(PlayerFlag_CanAlwaysLogin)) {
      disconnectClient("O servidor está fechado no momento.\nPor favor, tente "
                       "novamente mais tarde.");
      return;
    }

    if (g_config.getBoolean(ConfigManager::ONE_PLAYER_ON_ACCOUNT) &&
        player->getAccountType() < ACCOUNT_TYPE_GAMEMASTER &&
        g_game.getPlayerByAccount(player->getAccount())) {
      disconnectClient("Você pode fazer login apenas com um jogador\n na sua "
                       "conta ao mesmo tempo.");
      return;
    }

    if (!player->hasFlag(PlayerFlag_CannotBeBanned)) {
      BanInfo banInfo;
      if (IOBan::isAccountBanned(accountId, banInfo)) {
        if (banInfo.reason.empty()) {
          banInfo.reason = "(none)";
        }

        std::ostringstream ss;
        if (banInfo.expiresAt > 0) {
          ss << "Sua conta foi banida até "
             << formatDateShort(banInfo.expiresAt) << ".\n\nRazão:\n"
             << banInfo.reason;
        } else {
          ss << "Sua conta foi permanentemente banida.\n\nRazão:\n"
             << banInfo.reason;
        }
        disconnectClient(ss.str());
        return;
      }
    }

    std::size_t currentSlot;
    if (!WaitingList::getInstance().clientLogin(player, currentSlot)) {
      int64_t retryTime = WaitingList::getTime(currentSlot);
      std::ostringstream ss;

      ss << "Muitos jogadores online.\nVocê está no lugar " << currentSlot
         << " na lista de espera.";

      auto output = OutputMessagePool::getOutputMessage();
      output->addByte(0x16);
      output->addString(ss.str());
      output->addByte(static_cast<uint8_t>(retryTime));
      send(output);
      disconnect();
      return;
    }

    if (!IOLoginData::loadPlayerById(player, player->getGUID())) {
      disconnectClient("Não foi possível carregar seu personagem.");
      return;
    }

    player->setOperatingSystem(operatingSystem);

    // Always reset to instance 0 on login/respawn — instances are session-only
    player->setInstanceID(0);

    if (!g_game.placeCreature(player, player->getLoginPosition())) {
      if (!g_game.placeCreature(player, player->getTemplePosition(), false,
                                true)) {
        disconnectClient("A posição do templo esta errada.");
        return;
      }
    }
    player->autoOpenContainers();

    player->registerCreatureEvent("ExtendedOpcode");

    player->lastIP = player->getIP();
    player->lastLoginSaved =
        std::max<time_t>(time(nullptr), player->lastLoginSaved + 1);
    acceptPackets = true;
  } else {
    if (eventConnect != 0 ||
        !g_config.getBoolean(ConfigManager::REPLACE_KICK_ON_LOGIN)) {
      disconnectClient("Você já está logado.");
      return;
    }

    if (foundPlayer->client) {
      foundPlayer->disconnect();
      foundPlayer->isConnecting = true;

      eventConnect = g_scheduler.addEvent(createSchedulerTask(
          1000, std::bind(&ProtocolGame::connect, getThis(),
                          foundPlayer->getID(), operatingSystem)));
    } else {
      connect(foundPlayer->getID(), operatingSystem);
    }
  }
  OutputMessagePool::getInstance().addProtocolToAutosend(shared_from_this());
}

void ProtocolGame::connect(uint32_t playerId,
                           OperatingSystem_t operatingSystem) {
  eventConnect = 0;

  Player *foundPlayer = g_game.getPlayerByID(playerId);
  if (!foundPlayer || foundPlayer->client) {
    disconnectClient("Você já está logado.");
    return;
  }

  if (isConnectionExpired()) {
    return;
  }

  player = foundPlayer;
  player->incrementReferenceCounter();

  g_chat->removeUserFromAllChannels(*player);
  player->setOperatingSystem(operatingSystem);
  player->isConnecting = false;

  player->client = getThis();
  sendAddCreature(player, player->getPosition(), 0, false);
  player->autoOpenContainers();
  player->lastIP = player->getIP();
  player->lastLoginSaved =
      std::max<time_t>(time(nullptr), player->lastLoginSaved + 1);
  acceptPackets = true;
}

void ProtocolGame::logout(bool displayEffect, bool forced) {
  if (!player) {
    return;
  }

  if (!player->isRemoved()) {
    if (!forced) {
      if (!player->isAccessPlayer()) {
        if (player->getTile()->hasFlag(TILESTATE_NOLOGOUT)) {
          player->sendCancelMessage(RETURNVALUE_YOUCANNOTLOGOUTHERE);
          return;
        }

        if (!player->getTile()->hasFlag(TILESTATE_PROTECTIONZONE) &&
            player->hasCondition(CONDITION_INFIGHT)) {
          player->sendCancelMessage(RETURNVALUE_YOUMAYNOTLOGOUTDURINGAFIGHT);
          return;
        }
      }

      if (!g_creatureEvents->playerLogout(player)) {
        return;
      }
    }

    if (displayEffect && player->getHealth() > 0) {
      g_game.addMagicEffect(player->getPosition(), CONST_ME_POFF, player->getInstanceID());
    }
  }

  stopLiveCast();
  disconnect();

  g_game.removeCreature(player);
}

bool ProtocolGame::startLiveCast(const std::string &password /*= ""*/) {
  auto connection = getConnection();
  if (!g_config.getBoolean(ConfigManager::ENABLE_LIVE_CASTING) ||
      isLiveCaster() || !player || player->isRemoved() || !connection ||
      liveCasts.size() >= getMaxLiveCastCount()) {
    return false;
  }

  {
    std::lock_guard<decltype(liveCastLock)> lock{liveCastLock};
    liveCastName = player->getName();
    liveCastPassword = password;
    isCaster.store(true, std::memory_order_relaxed);
    spectatorCounter[this] = 0;
  }

  liveCasts.insert(std::make_pair(player, getThis()));

  registerLiveCast();
  sendChannel(CHANNEL_CAST, LIVE_CAST_CHAT_NAME);
  return true;
}

bool ProtocolGame::stopLiveCast() {
  if (!isLiveCaster()) {
    return false;
  }

  CastSpectatorVec spectators;

  {
    std::lock_guard<decltype(liveCastLock)> lock{liveCastLock};
    std::swap(this->spectators, spectators);
    isCaster.store(false, std::memory_order_relaxed);
    spectatorCounter.erase(this);
  }

  liveCasts.erase(player);
  for (auto &spectator : spectators) {
    spectator->onLiveCastStop(player);
    spectatorNames.erase(spectator);
  }
  unregisterLiveCast();

  return true;
}

void ProtocolGame::clearLiveCastInfo() {
  static std::once_flag flag;
  std::call_once(flag, []() {
    assert(g_game.getGameState() == GAME_STATE_INIT);
    std::ostringstream query;
    query << "TRUNCATE TABLE `live_casts`;";
    g_databaseTasks.addTask(query.str());
  });
}

void ProtocolGame::registerLiveCast() {
  std::ostringstream query;
  query << "INSERT into `live_casts` (`player_id`, `cast_name`, `password`) "
           "VALUES ("
        << player->getGUID() << ", '" << getLiveCastName() << "', "
        << isPasswordProtected() << ");";
  g_databaseTasks.addTask(query.str());
}

void ProtocolGame::unregisterLiveCast() {
  std::ostringstream query;
  query << "DELETE FROM `live_casts` WHERE `player_id`=" << player->getGUID()
        << ";";
  g_databaseTasks.addTask(query.str());
}

void ProtocolGame::updateLiveCastInfo() {
  std::ostringstream query;
  query << "UPDATE `live_casts` SET `cast_name`='" << getLiveCastName()
        << "', `password`=" << isPasswordProtected()
        << ", `spectators`=" << getSpectatorCount()
        << " WHERE `player_id`=" << player->getGUID() << ";";
  g_databaseTasks.addTask(query.str());
}

void ProtocolGame::addSpectator(ProtocolSpectator_ptr spectatorClient) {
  std::lock_guard<decltype(liveCastLock)> lock(liveCastLock);

  auto it = std::find(spectators.begin(), spectators.end(), spectatorClient);
  if (it != spectators.end()) {
    return;
  }

  spectators.emplace_back(spectatorClient);
  updateLiveCastInfo();

  if (spectators.size() > spectatorRecord) {
    spectatorRecord = spectators.size();
  }

  uint32_t count = ++spectatorCounter[this];
  std::string generatedName = "Spectator " + std::to_string(count);
  spectatorNames[spectatorClient] = generatedName;

  if (player) {
    player->sendTextMessage(MESSAGE_EVENT_ORANGE,
                            generatedName + " entrou na transmissão.");
  }
}

void ProtocolGame::removeSpectator(ProtocolSpectator_ptr spectatorClient) {
  std::lock_guard<decltype(liveCastLock)> lock(liveCastLock);
  auto it = std::find(spectators.begin(), spectators.end(), spectatorClient);
  if (it != spectators.end()) {
    std::string name = spectatorNames[spectatorClient];
    spectators.erase(it);
    spectatorNames.erase(spectatorClient);
    updateLiveCastInfo();

    if (player) {
      std::string msg = name + " saiu da transmissão.";
      player->sendTextMessage(MESSAGE_EVENT_ORANGE, msg);
    }
  }
}

void ProtocolGame::spectatelogout() {
  m_spectator = false;
  acceptPackets = false;

  if (spect && player) {
    spect->removeSpectator(
        std::static_pointer_cast<ProtocolSpectator>(shared_from_this()));
    player->decrementReferenceCounter();
    player = nullptr;
  }
  disconnect();
  release();
}

void ProtocolGame::spectate(const std::string &liveCastName,
                            const std::string &password) {
  auto foundPlayer = g_game.getPlayerByName(liveCastName);
  if (!foundPlayer || foundPlayer->isRemoved()) {
    disconnectSpectator("Essa transmissão já foi encerrada.");
    return;
  }

  const auto liveCasterProtocol = ProtocolGame::getLiveCast(foundPlayer);
  if (!liveCasterProtocol) {
    disconnectSpectator("Essa transmissão já foi encerrada.");
    return;
  }

  const auto &liveCastPassword = liveCasterProtocol->getLiveCastPassword();
  if (liveCasterProtocol->isLiveCaster()) {
    if (!liveCastPassword.empty() && password != liveCastPassword) {
      disconnectSpectator("Transmissão protegida com senha.");
      return;
    }

    m_spectator = true;
    player = foundPlayer;
    player->incrementReferenceCounter();
    eventConnect = 0;
    spect = liveCasterProtocol;
    acceptPackets = true;
    OutputMessagePool::getInstance().addProtocolToAutosend(shared_from_this());
    sendAddCreature(player, player->getPosition(), 0, false);
    syncKnownCreatureSets();
    syncOpenContainers();
    sendChannel(CHANNEL_CAST, LIVE_CAST_CHAT_NAME);

    liveCasterProtocol->addSpectator(
        std::static_pointer_cast<ProtocolSpectator>(shared_from_this()));
  } else {
    disconnectSpectator("Essa transmissão já foi encerrada.");
  }
}

void ProtocolGame::syncOpenContainers() {
  const auto &openContainers = player->getOpenContainers();
  for (const auto &it : openContainers) {
    auto openContainer = it.second;
    auto container = openContainer.container;
    bool hasParent = container->getParent() != nullptr;
    sendContainer(it.first, container, hasParent, openContainer.index);
  }
}

void ProtocolGame::parseSpectatorSay(NetworkMessage &msg) {
  SpeakClasses type = (SpeakClasses)msg.getByte();
  uint16_t channelId = 0;

  if (type == TALKTYPE_CHANNEL_Y) {
    channelId = msg.get<uint16_t>();
  } else {
    return;
  }

  const std::string text = msg.getString();

  if (m_spectator) {
    if (text.length() > 255 || channelId != CHANNEL_CAST || !spect) {
      return;
    }

    if (text.substr(0, 5) == "/name" && text.length() > 6) {
      std::string newName = text.substr(6);
      int iSpaces = 0;
      unsigned int strSize = strlen(newName.c_str());
      for (unsigned int iLoop = 0; iLoop < strSize; iLoop++) {
        if (newName[iLoop] == ' ') {
          iSpaces++;
        }
      }
      if (newName.length() > 20) {
        sendChannelMessage("", "Este nome tem mais de 20 letras.",
                           TALKTYPE_CHANNEL_R1, CHANNEL_CAST);
        return;
      }

      if (iSpaces > 1) {
        sendChannelMessage("", "Este nome tem mais de um espaço.",
                           TALKTYPE_CHANNEL_R1, CHANNEL_CAST);
        return;
      }

      if (spect) {
        sendChannelMessage("", "Muito bem, seu novo nome é: " + newName,
                           TALKTYPE_CHANNEL_W, CHANNEL_CAST);
      }
      name = newName;
      return;
    }

    if (text == "/spectators") {
      if (spect) {
        std::ostringstream entry;
        entry << "Essa transmissão ao vivo tem " << spect->getSpectatorCount()
              << " espectador(es) agora.";
        sendChannelMessage("", entry.str(), TALKTYPE_CHANNEL_O, CHANNEL_CAST);
      }
      return;
    }

    if (name.empty()) {
      auto it = spectatorNames.find(
          std::static_pointer_cast<ProtocolSpectator>(shared_from_this()));
      name = (it != spectatorNames.end()) ? it->second : "Spectator";
    }

    if (OTSYS_TIME() < (lastTalkTime + 2000)) {
      return;
    }

    if (spect) {
      player->sendChannelMessage(name, text, TALKTYPE_CHANNEL_Y, CHANNEL_CAST);
    }

    lastTalkTime = OTSYS_TIME();
  }
}

void ProtocolGame::onRecvFirstMessage(NetworkMessage &msg) {
  if (g_game.getGameState() == GAME_STATE_SHUTDOWN) {
    disconnect();
    return;
  }

  OperatingSystem_t operatingSystem =
      static_cast<OperatingSystem_t>(msg.get<uint16_t>());
  version = msg.get<uint16_t>();

  if (!Protocol::RSA_decrypt(msg)) {
    disconnect();
    return;
  }

  xtea::key key;
  key[0] = msg.get<uint32_t>();
  key[1] = msg.get<uint32_t>();
  key[2] = msg.get<uint32_t>();
  key[3] = msg.get<uint32_t>();
  enableXTEAEncryption();
  setXTEAKey(std::move(key));

  if (operatingSystem >= CLIENTOS_OTCLIENT_LINUX) {
    NetworkMessage opcodeMessage;
    opcodeMessage.addByte(0x32);
    opcodeMessage.addByte(0x00);
    opcodeMessage.add<uint16_t>(0x00);
    writeToOutputBuffer(opcodeMessage);
  }

  msg.skipBytes(1); // gamemaster flag

  std::string accountName = msg.getString();
  std::string characterName = msg.getString();
  std::string password = msg.getString();

  uint32_t timeStamp = msg.get<uint32_t>();
  uint8_t randNumber = msg.getByte();
  if (challengeTimestamp != timeStamp || challengeRandom != randNumber) {
    disconnect();
    return;
  }

  // OTCv8 version detection
  uint16_t otcV8StringLength = msg.get<uint16_t>();
  if (otcV8StringLength == 5 && msg.getString(5) == "OTCv8") {
    otclientV8 = msg.get<uint16_t>(); // 253, 260, 261, ...
  }
  // HWID recebido via extended opcode pos-login (anti-multicliente)

  if (version < CLIENT_VERSION_MIN || version > CLIENT_VERSION_MAX) {
    std::ostringstream ss;
    ss << "Somente clients com protocolo " << CLIENT_VERSION_STR
       << " são permitidos!";
    disconnectClient(ss.str());
    return;
  }

  if (g_game.getGameState() == GAME_STATE_STARTUP) {
    disconnectClient("Gameworld is starting up. Please wait.");
    return;
  }

  if (g_game.getGameState() == GAME_STATE_MAINTAIN) {
    disconnectClient(
        "Gameworld is under maintenance. Please re-connect in a while.");
    return;
  }

  BanInfo banInfo;
  if (IOBan::isIpBanned(getIP(), banInfo)) {
    if (banInfo.reason.empty()) {
      banInfo.reason = "(none)";
    }

    std::ostringstream ss;
    ss << "Your IP has been banned until " << formatDateShort(banInfo.expiresAt)
       << " by " << banInfo.bannedBy << ".\n\nReason specified:\n"
       << banInfo.reason;
    disconnectClient(ss.str());
    return;
  }

  if (accountName.empty()) {
    std::size_t pos = characterName.find("[");
    if (pos != std::string::npos) {
      pos -= 1;
    }
    g_dispatcher.addTask(
        createTask(std::bind(&ProtocolGame::spectate, getThis(),
                             characterName.substr(0, pos), password)));
  } else {
    uint32_t accountId = IOLoginData::gameworldAuthentication(
        accountName, password, characterName);
    if (accountId == 0) {
      disconnectClient("Account name or password is not correct.");
      return;
    }
    g_dispatcher.addTask(
        createTask(std::bind(&ProtocolGame::login, getThis(), characterName,
                             accountId, operatingSystem)));
  }
}

void ProtocolGame::sendEmptyTileOnPlayerPos(const Tile *tile,
                                            const Position &playerPos) {
  NetworkMessage msg;

  msg.addByte(0x69);
  msg.addPosition(playerPos);

  Item *ground = tile->getGround();
  if (ground) {
    msg.addItem(ground);
  }

  msg.addByte(0x00);
  msg.addByte(0xFF);
  writeToOutputBuffer(msg);
}

void ProtocolGame::syncKnownCreatureSets() {
  const auto &casterKnownCreatures = spect->getKnownCreatures();
  const auto playerPos = player->getPosition();
  const auto tile = player->getTile();

  if (!tile || !tile->getGround()) {
    disconnectClient("A sync error has occured.");
    return;
  }
  sendEmptyTileOnPlayerPos(tile, playerPos);

  bool known;
  uint32_t removedKnown;
  for (const auto creatureID : casterKnownCreatures) {
    if (knownCreatureSet.find(creatureID) != knownCreatureSet.end()) {
      continue;
    }

    NetworkMessage msg;
    const auto creature = g_game.getCreatureByID(creatureID);
    if (creature && !creature->isRemoved()) {
      msg.addByte(0x6A);
      msg.addPosition(playerPos);
      msg.addByte(1);
      checkCreatureAsKnown(creature->getID(), known, removedKnown);
      AddCreature(msg, creature, known, removedKnown);
      RemoveTileThing(msg, playerPos, 1);
    }
    writeToOutputBuffer(msg, false);
  }
  sendUpdateTile(tile, playerPos);
}

void ProtocolGame::onConnect() {
  auto output = OutputMessagePool::getOutputMessage();
  static std::random_device rd;
  static std::ranlux24 generator(rd());
  static std::uniform_int_distribution<uint16_t> randNumber(0x00, 0xFF);

  // Skip checksum
  output->skipBytes(sizeof(uint32_t));

  // Packet length & type
  output->add<uint16_t>(0x0006);
  output->addByte(0x1F);

  // Add timestamp & random number
  challengeTimestamp = static_cast<uint32_t>(time(nullptr));
  output->add<uint32_t>(challengeTimestamp);

  challengeRandom = randNumber(generator);
  output->addByte(challengeRandom);

  // Go back and write checksum
  output->skipBytes(-12);
  output->add<uint32_t>(
      adlerChecksum(output->getOutputBuffer() + sizeof(uint32_t), 8));

  send(std::move(output));
}

void ProtocolGame::disconnectSpectator(const std::string &message) const {
  auto output = OutputMessagePool::getOutputMessage();
  output->addByte(0x14);
  output->addString(message);
  send(std::move(output));
  disconnect();
}

void ProtocolGame::disconnectClient(const std::string &message) const {
  auto output = OutputMessagePool::getOutputMessage();
  output->addByte(0x14);
  output->addString(message);
  send(output);
  disconnect();
}

void ProtocolGame::writeToOutputBuffer(const NetworkMessage &msg,
                                       bool broadcast /*= true*/) {
  if (!broadcast && isLiveCaster()) {
    auto out = OutputMessagePool::getOutputMessage();
    out->append(msg);
    send(std::move(out));
  } else {
    auto out = getOutputBuffer(msg.getLength());
    if (isLiveCaster()) {
      out->setBroadcastMsg(true);
    }
    out->append(msg);
  }

  // PokeMonster: forward host packets to in-game spectators
  if (broadcast && player && !player->getSpectators().empty()) {
    auto specsCopy = player->getSpectators();
    for (Player* spectator : specsCopy) {
      if (spectator && spectator->getProtocolGame()) {
        spectator->sendNetworkMessage(msg, false);
      }
    }
  }
}

void ProtocolGame::parseSpectatorPacket(NetworkMessage &msg) {
  if (!acceptPackets || g_game.getGameState() == GAME_STATE_SHUTDOWN ||
      msg.getLength() <= 0) {
    return;
  }

  if (getThis() == nullptr) {
    return;
  }

  uint8_t recvbyte = msg.getByte();

  if (!player) {
    if (recvbyte == 0x0F) {
      disconnect();
    }

    return;
  }

  if (player->isRemoved() || player->getHealth() <= 0) {
    disconnect();
    return;
  }

  switch (recvbyte) {
  case 0x14:
    g_dispatcher.addTask(
        createTask(std::bind(&ProtocolGame::spectatelogout, getThis())));
    break;
  case 0x1E:
    g_dispatcher.addTask(
        createTask(std::bind(&ProtocolGame::sendPing, getThis())));
    break;
  case 0x64:
  case 0x65:
  case 0x66:
  case 0x67:
  case 0x68:
  case 0x6A:
  case 0x6B:
  case 0x6C:
  case 0x6D:
    g_dispatcher.addTask(
        createTask(std::bind(&ProtocolGame::sendCancelWalk, getThis())));
    break;
  case 0x96:
    parseSpectatorSay(msg);
    break;
  default:
    break;
  }

  if (msg.isOverrun()) {
    disconnect();
  }
}

void ProtocolGame::parsePacket(NetworkMessage &msg) {
  if (m_spectator) {
    parseSpectatorPacket(msg);
    return;
  }

  if (!acceptPackets || g_game.getGameState() == GAME_STATE_SHUTDOWN ||
      msg.getLength() <= 0) {
    return;
  }

  uint8_t recvbyte = msg.getByte();

  if (!player || player->isRemoved() || player->getHealth() <= 0) {
    if (recvbyte == 0x0F) {
      disconnect();
      return;
    }

    if (recvbyte != 0x14) {
      return;
    }
  }

  switch (recvbyte) {
  case 0x14:
    addDispatcherTask(std::bind(&ProtocolGame::logout, getThis(), true, false));
    break;
  case 0x1E:
    addDispatcherTask(
        [playerID = player->getID()]() { g_game.playerReceivePing(playerID); });
    break;
  case 0x32:
    parseExtendedOpcode(msg);
    break; // otclient extended opcode
  case 0x40:
    parseNewPing(msg);
    break;
  case 0x64:
    parseAutoWalk(msg);
    break;
  case 0x65:
    addDispatcherTask([playerID = player->getID()]() {
      g_game.playerMove(playerID, DIRECTION_NORTH);
    });
    break;
  case 0x66:
    addDispatcherTask([playerID = player->getID()]() {
      g_game.playerMove(playerID, DIRECTION_EAST);
    });
    break;
  case 0x67:
    addDispatcherTask([playerID = player->getID()]() {
      g_game.playerMove(playerID, DIRECTION_SOUTH);
    });
    break;
  case 0x68:
    addDispatcherTask([playerID = player->getID()]() {
      g_game.playerMove(playerID, DIRECTION_WEST);
    });
    break;
  case 0x69:
    addDispatcherTask([playerID = player->getID()]() {
      g_game.playerStopAutoWalk(playerID);
    });
    break;
  case 0x6A:
    addDispatcherTask([playerID = player->getID()]() {
      g_game.playerMove(playerID, DIRECTION_NORTHEAST);
    });
    break;
  case 0x6B:
    addDispatcherTask([playerID = player->getID()]() {
      g_game.playerMove(playerID, DIRECTION_SOUTHEAST);
    });
    break;
  case 0x6C:
    addDispatcherTask([playerID = player->getID()]() {
      g_game.playerMove(playerID, DIRECTION_SOUTHWEST);
    });
    break;
  case 0x6D:
    addDispatcherTask([playerID = player->getID()]() {
      g_game.playerMove(playerID, DIRECTION_NORTHWEST);
    });
    break;
  case 0x6F:
    addTimedDispatcherTask(DISPATCHER_TASK_EXPIRATION,
                           [playerID = player->getID()]() {
                             g_game.playerTurn(playerID, DIRECTION_NORTH);
                           });
    break;
  case 0x70:
    addTimedDispatcherTask(DISPATCHER_TASK_EXPIRATION,
                           [playerID = player->getID()]() {
                             g_game.playerTurn(playerID, DIRECTION_EAST);
                           });
    break;
  case 0x71:
    addTimedDispatcherTask(DISPATCHER_TASK_EXPIRATION,
                           [playerID = player->getID()]() {
                             g_game.playerTurn(playerID, DIRECTION_SOUTH);
                           });
    break;
  case 0x72:
    addTimedDispatcherTask(DISPATCHER_TASK_EXPIRATION,
                           [playerID = player->getID()]() {
                             g_game.playerTurn(playerID, DIRECTION_WEST);
                           });
    break;
  case 0x78:
    parseThrow(msg);
    break;
  case 0x79:
    parseLookInShop(msg);
    break;
  case 0x7A:
    parsePlayerPurchase(msg);
    break;
  case 0x7B:
    parsePlayerSale(msg);
    break;
  case 0x7C:
    addDispatcherTask(
        [playerID = player->getID()]() { g_game.playerCloseShop(playerID); });
    break;
  case 0x7D:
    parseRequestTrade(msg);
    break;
  case 0x7E:
    parseLookInTrade(msg);
    break;
  case 0x7F:
    addDispatcherTask(
        [playerID = player->getID()]() { g_game.playerAcceptTrade(playerID); });
    break;
  case 0x80:
    addDispatcherTask(
        [playerID = player->getID()]() { g_game.playerCloseTrade(playerID); });
    break;
  case 0x82:
    parseUseItem(msg);
    break;
  case 0x83:
    parseUseItemEx(msg);
    break;
  case 0x84:
    parseUseWithCreature(msg);
    break;
  case 0x85:
    parseRotateItem(msg);
    break;
  case 0x87:
    parseCloseContainer(msg);
    break;
  case 0x88:
    parseUpArrowContainer(msg);
    break;
  case 0x89:
    parseTextWindow(msg);
    break;
  case 0x8A:
    parseHouseWindow(msg);
    break;
  case 0x8C:
    parseLookAt(msg);
    break;
  case 0x8D:
    parseLookInBattleList(msg);
    break;
  case 0x8E: /* join aggression */
    break;
  case 0x96:
    parseSay(msg);
    break;
  case 0x97:
    addDispatcherTask([playerID = player->getID()]() {
      g_game.playerRequestChannels(playerID);
    });
    break;
  case 0x98:
    parseOpenChannel(msg);
    break;
  case 0x99:
    parseCloseChannel(msg);
    break;
  case 0x9A:
    parseOpenPrivateChannel(msg);
    break;
  case 0x9E:
    addDispatcherTask([playerID = player->getID()]() {
      g_game.playerCloseNpcChannel(playerID);
    });
    break;
  case 0xA0:
    parseFightModes(msg);
    break;
  case 0xA1:
    parseAttack(msg);
    break;
  case 0xA2:
    parseFollow(msg);
    break;
  case 0xA3:
    parseInviteToParty(msg);
    break;
  case 0xA4:
    parseJoinParty(msg);
    break;
  case 0xA5:
    parseRevokePartyInvite(msg);
    break;
  case 0xA6:
    parsePassPartyLeadership(msg);
    break;
  case 0xA7:
    addDispatcherTask(
        [playerID = player->getID()]() { g_game.playerLeaveParty(playerID); });
    break;
  case 0xA8:
    parseEnableSharedPartyExperience(msg);
    break;
  case 0xAA:
    addDispatcherTask([playerID = player->getID()]() {
      g_game.playerCreatePrivateChannel(playerID);
    });
    break;
  case 0xAB:
    parseChannelInvite(msg);
    break;
  case 0xAC:
    parseChannelExclude(msg);
    break;
  case 0xBE:
    addDispatcherTask([playerID = player->getID()]() {
      g_game.playerCancelAttackAndFollow(playerID);
    });
    break;
  case 0xC9: /* update tile */
    break;
  case 0xCA:
    parseUpdateContainer(msg);
    break;
  case 0xD2:
    addDispatcherTask([playerID = player->getID()]() {
      g_game.playerRequestOutfit(playerID);
    });
    break;
  case 0xD3:
    parseSetOutfit(msg);
    break;
  case 0xDC:
    parseAddVip(msg);
    break;
  case 0xDD:
    parseRemoveVip(msg);
    break;
  case 0xE6:
    parseBugReport(msg);
    break;
  case 0xE7: /* thank you */
    break;
  case 0xE8:
    parseDebugAssert(msg);
    break;
  case 0xF0:
    addTimedDispatcherTask(DISPATCHER_TASK_EXPIRATION,
                           [playerID = player->getID()]() {
                             g_game.playerShowQuestLog(playerID);
                           });
    break;
  case 0xF1:
    parseQuestLine(msg);
    break;
  case 0xF2:
    parseRuleViolationReport(msg);
    break;
  case 0xF3: /* get object info */
    break;
  case 0xF4:
    parseMarketLeave();
    break;
  case 0xF5:
    parseMarketBrowse(msg);
    break;
  case 0xF6:
    parseMarketCreateOffer(msg);
    break;
  case 0xF7:
    parseMarketCancelOffer(msg);
    break;
  case 0xF8:
    parseMarketAcceptOffer(msg);
    break;
  case 0xF9:
    parseModalWindowAnswer(msg);
    break;

  default:
    // std::cout << "Player: " << player->getName() << " sent an unknown packet
    // header: 0x" << std::hex << static_cast<uint16_t>(recvbyte) << std::dec <<
    // "!" << std::endl;
    break;
  }

  if (msg.isOverrun()) {
    disconnect();
  }
}

void ProtocolGame::GetTileDescription(const Tile *tile, NetworkMessage &msg) {
  int32_t count;
  Item *ground = tile->getGround();
  if (ground) {
    msg.addItem(ground);
    count = 1;
  } else {
    count = 0;
  }

  const uint32_t viewerInstanceId = player->getInstanceID();

  const TileItemVector *items = tile->getItemList();
  if (items) {
    for (auto it = items->getBeginTopItem(), end = items->getEndTopItem();
         it != end; ++it) {
      Item *item = *it;
      if (!InstanceUtils::canSeeItemInInstance(viewerInstanceId, item)) {
        continue;
      }

      msg.addItem(item);

      count++;
      if (count == 9 && tile->getPosition() == player->getPosition()) {
        break;
      } else if (count == 10) {
        return;
      }
    }
  }

  const CreatureVector *creatures = tile->getCreatures();
  if (creatures) {
    bool playerAdded = false;
    for (const Creature *creature : boost::adaptors::reverse(*creatures)) {
      if (!player->canSeeCreature(creature)) {
        continue;
      }

      if (tile->getPosition() == player->getPosition() && count == 9 &&
          !playerAdded) {
        creature = player;
      }

      if (creature->getID() == player->getID()) {
        playerAdded = true;
      }

      bool known;
      uint32_t removedKnown;
      checkCreatureAsKnown(creature->getID(), known, removedKnown);
      AddCreature(msg, creature, known, removedKnown);

      if (++count == 10) {
        return;
      }
    }
  }

  if (items) {
    for (auto it = items->getBeginDownItem(), end = items->getEndDownItem();
         it != end; ++it) {
      Item *item = *it;
      if (!InstanceUtils::canSeeItemInInstance(viewerInstanceId, item)) {
        continue;
      }

      msg.addItem(item);

      if (++count == 10) {
        return;
      }
    }
  }
}

void ProtocolGame::GetMapDescription(int32_t x, int32_t y, int32_t z,
                                     int32_t width, int32_t height,
                                     NetworkMessage &msg) {
  int32_t skip = -1;
  int32_t startz, endz, zstep;

  if (z > 7) {
    startz = z - 2;
    endz = std::min<int32_t>(MAP_MAX_LAYERS - 1, z + 2);
    zstep = 1;
  } else {
    startz = 7;
    endz = 0;
    zstep = -1;
  }

  for (int32_t nz = startz; nz != endz + zstep; nz += zstep) {
    GetFloorDescription(msg, x, y, nz, width, height, z - nz, skip);
  }

  if (skip >= 0) {
    msg.addByte(skip);
    msg.addByte(0xFF);
  }
}

void ProtocolGame::GetFloorDescription(NetworkMessage &msg, int32_t x,
                                       int32_t y, int32_t z, int32_t width,
                                       int32_t height, int32_t offset,
                                       int32_t &skip) {
  for (int32_t nx = 0; nx < width; nx++) {
    for (int32_t ny = 0; ny < height; ny++) {
      Tile *tile = g_game.map.getTile(x + nx + offset, y + ny + offset, z);
      if (tile) {
        if (skip >= 0) {
          msg.addByte(skip);
          msg.addByte(0xFF);
        }

        skip = 0;
        GetTileDescription(tile, msg);
      } else if (skip == 0xFE) {
        msg.addByte(0xFF);
        msg.addByte(0xFF);
        skip = -1;
      } else {
        ++skip;
      }
    }
  }
}

void ProtocolGame::checkCreatureAsKnown(uint32_t id, bool &known,
                                        uint32_t &removedKnown) {
  auto result = knownCreatureSet.insert(id);
  if (!result.second) {
    known = true;
    return;
  }

  known = false;

  if (knownCreatureSet.size() > 250) {
    // Look for a creature to remove
    for (auto it = knownCreatureSet.begin(), end = knownCreatureSet.end();
         it != end; ++it) {
      Creature *creature = g_game.getCreatureByID(*it);
      if (!canSee(creature)) {
        removedKnown = *it;
        knownCreatureSet.erase(it);
        return;
      }
    }

    // Bad situation. Let's just remove anyone.
    auto it = knownCreatureSet.begin();
    if (*it == id) {
      ++it;
    }

    removedKnown = *it;
    knownCreatureSet.erase(it);
  } else {
    removedKnown = 0;
  }
}

bool ProtocolGame::canSee(const Creature *c) const {
  if (!c || !player || c->isRemoved()) {
    return false;
  }

  if (!player->canSeeCreature(c)) {
    return false;
  }

  return canSee(c->getPosition());
}

bool ProtocolGame::canSee(const Position &pos) const {
  return canSee(pos.x, pos.y, pos.z);
}

bool ProtocolGame::canSee(int32_t x, int32_t y, int32_t z) const {
  if (!player) {
    return false;
  }

  const Position &myPos = player->getPosition();
  if (myPos.z <= 7) {
    // we are on ground level or above (7 -> 0)
    // view is from 7 -> 0
    if (z > 7) {
      return false;
    }
  } else if (myPos.z >= 8) {
    // we are underground (8 -> 15)
    // view is +/- 2 from the floor we stand on
    if (std::abs(myPos.getZ() - z) > 2) {
      return false;
    }
  }

  // negative offset means that the action taken place is on a lower floor than
  // ourself
  int32_t offsetz = myPos.getZ() - z;
  if ((x >= myPos.getX() - Map::maxClientViewportX + offsetz) &&
      (x <= myPos.getX() + (Map::maxClientViewportX + 1) + offsetz) &&
      (y >= myPos.getY() - Map::maxClientViewportY + offsetz) &&
      (y <= myPos.getY() + (Map::maxClientViewportY + 1) + offsetz)) {
    return true;
  }
  return false;
}

// Parse methods
void ProtocolGame::parseChannelInvite(NetworkMessage &msg) {
  std::string name = msg.getString();
  addDispatcherTask(([playerID = player->getID(), name = std::move(name)]() {
    g_game.playerChannelInvite(playerID, name);
  }));
}

void ProtocolGame::parseChannelExclude(NetworkMessage &msg) {
  std::string name = msg.getString();
  addDispatcherTask(([playerID = player->getID(), name = std::move(name)]() {
    g_game.playerChannelExclude(playerID, name);
  }));
}

void ProtocolGame::parseOpenChannel(NetworkMessage &msg) {
  uint16_t channelId = msg.get<uint16_t>();
  addDispatcherTask(([playerID = player->getID(), channelId]() {
    g_game.playerOpenChannel(playerID, channelId);
  }));
}

void ProtocolGame::parseCloseChannel(NetworkMessage &msg) {
  uint16_t channelId = msg.get<uint16_t>();
  addDispatcherTask(([playerID = player->getID(), channelId]() {
    g_game.playerCloseChannel(playerID, channelId);
  }));
}

void ProtocolGame::parseOpenPrivateChannel(NetworkMessage &msg) {
  std::string receiver = msg.getString();
  addDispatcherTask(
      ([playerID = player->getID(), receiver = std::move(receiver)]() mutable {
        g_game.playerOpenPrivateChannel(playerID, receiver);
      }));
}

void ProtocolGame::parseAutoWalk(NetworkMessage &msg) {
  uint8_t numdirs = msg.getByte();
  if (numdirs == 0 ||
      (msg.getBufferPosition() + numdirs) != (msg.getLength() + 8)) {
    return;
  }

  msg.skipBytes(numdirs);

  std::vector<Direction> path;
  path.reserve(numdirs);
  for (uint8_t i = 0; i < numdirs; ++i) {
    uint8_t rawdir = msg.getPreviousByte();
    switch (rawdir) {
    case 1:
      path.emplace_back(DIRECTION_EAST);
      break;
    case 2:
      path.emplace_back(DIRECTION_NORTHEAST);
      break;
    case 3:
      path.emplace_back(DIRECTION_NORTH);
      break;
    case 4:
      path.emplace_back(DIRECTION_NORTHWEST);
      break;
    case 5:
      path.emplace_back(DIRECTION_WEST);
      break;
    case 6:
      path.emplace_back(DIRECTION_SOUTHWEST);
      break;
    case 7:
      path.emplace_back(DIRECTION_SOUTH);
      break;
    case 8:
      path.emplace_back(DIRECTION_SOUTHEAST);
      break;
    default:
      break;
    }
  }

  if (path.empty()) {
    return;
  }

  addDispatcherTask(([playerID = player->getID(), path = std::move(path)]() {
    g_game.playerAutoWalk(playerID, path);
  }));
}

void ProtocolGame::parseSetOutfit(NetworkMessage &msg) {
  if (!player || player->isRemoved()) {
    return;
  }

  Outfit_t newOutfit = player->defaultOutfit;

  uint16_t requestedLookType = msg.get<uint16_t>();

  std::vector<uint16_t> restrictedLookTypes = {729, 56};

  if (std::find(restrictedLookTypes.begin(), restrictedLookTypes.end(),
                requestedLookType) != restrictedLookTypes.end()) {
    player->sendTextMessage(MESSAGE_STATUS_SMALL,
                            "Você não pode mudar para essa transformação.");
    return;
  }

  std::unordered_map<uint16_t, std::vector<uint16_t>> allowedOutfits = {
      {1245, {1}},  // Goku Justice
      {1254, {2}},  // Vegeta Justice
      {1243, {3}},  // Piccolo Justice
      {1240, {4}},  // C17 Justice
      {1244, {5}},  // Gohan Justice
      {1253, {6}},  // Trunks Justice
      {1242, {7}},  // Cell Justice
      {1248, {8}},  // Freeza Justice
      {1238, {9}},  // Buu Justice
      {1241, {10}}, // Broly Justice
      {1246, {11}}, // Goten Justice
      {1250, {12}}, // Kuririn Justice
      {1247, {13}}, // Janemba Justice
      {1252, {14}}, // Tapion Justice
      {1258, {15}}, // Chilled Justice
      {1239, {16}}, // Kagome Justice
      {1256, {17}}, // Zaiko Justice
      {1249, {18}}, // King Vegeta Justice
      {1255, {19}}, // Vegetto Justice
      {1251, {20}}, // Kame Justice
      {1257, {21}}, // Shenron Justice
      {1280, {22}}, // Kaioh Justice
      {1267, {23}}, // Goku Black Justice
      {1268, {24}}, // Zamasu Justice
      {1269, {25}}, // Jiren Justice
  };

  if (allowedOutfits.find(requestedLookType) != allowedOutfits.end()) {
    const std::vector<uint16_t> &allowedVocations =
        allowedOutfits[requestedLookType];
    uint16_t playerVocationId = player->getVocationId();
    if (std::find(allowedVocations.begin(), allowedVocations.end(),
                  playerVocationId) == allowedVocations.end()) {
      player->sendTextMessage(MESSAGE_STATUS_SMALL,
                              "Seu personagem não pode utilizar essa skin.");
      return;
    }
  }

  const Outfit_t &currentOutfit = player->getCurrentOutfit();

  if (currentOutfit.lookAura > 0) {
    player->sendTextMessage(MESSAGE_STATUS_SMALL,
                            "Você não pode mudar de transformação enquanto "
                            "estiver com um BUFF ativo.");
    return;
  }

  if (std::find(restrictedLookTypes.begin(), restrictedLookTypes.end(),
                currentOutfit.lookType) != restrictedLookTypes.end()) {
    player->sendTextMessage(MESSAGE_STATUS_SMALL,
                            "Você não pode mudar de transformação.");
    return;
  }

  newOutfit.lookType = requestedLookType;
  newOutfit.lookHead = msg.get<char>();
  newOutfit.lookBody = msg.get<char>();
  newOutfit.lookLegs = msg.get<char>();
  newOutfit.lookFeet = msg.get<char>();

  newOutfit.lookAddons = currentOutfit.lookAddons;

  newOutfit.lookAura = currentOutfit.lookAura;
  newOutfit.lookWings = currentOutfit.lookWings;

  newOutfit.healthBackground = currentOutfit.healthBackground;
  newOutfit.manaBackground = currentOutfit.manaBackground;
  newOutfit.koteElemental = currentOutfit.koteElemental;

  addDispatcherTask(
      ([playerID = player->getID(), newOutfit = std::move(newOutfit)]() {
        g_game.playerChangeOutfit(playerID, newOutfit);
      }));
}

void ProtocolGame::parseToggleMount(NetworkMessage &msg) {
  int wings = -1, aura = -1;
  if (otclientV8 >= 254) {
    wings = msg.get<int8_t>();
    aura = msg.get<int8_t>();
  }
  addDispatcherTask(([playerID = player->getID(), wings, aura]() {
    g_game.playerToggleOutfitExtension(playerID, wings, aura);
  }));
}

void ProtocolGame::parseUseItem(NetworkMessage &msg) {
  Position pos = msg.getPosition();
  uint16_t spriteId = msg.get<uint16_t>();
  uint8_t stackpos = msg.getByte();
  uint8_t index = msg.getByte();
  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerUseItem(playerID, pos, stackpos, index, spriteId);
  }));
}

void ProtocolGame::parseUseItemEx(NetworkMessage &msg) {
  Position fromPos = msg.getPosition();
  uint16_t fromSpriteId = msg.get<uint16_t>();
  uint8_t fromStackPos = msg.getByte();
  Position toPos = msg.getPosition();
  uint16_t toSpriteId = msg.get<uint16_t>();
  uint8_t toStackPos = msg.getByte();
  addTimedDispatcherTask(
      DISPATCHER_TASK_EXPIRATION, ([=, playerID = player->getID()]() {
        g_game.playerUseItemEx(playerID, fromPos, fromStackPos, fromSpriteId,
                               toPos, toStackPos, toSpriteId);
      }));
}

void ProtocolGame::parseUseWithCreature(NetworkMessage &msg) {
  Position fromPos = msg.getPosition();
  uint16_t spriteId = msg.get<uint16_t>();
  uint8_t fromStackPos = msg.getByte();
  uint32_t creatureId = msg.get<uint32_t>();
  addTimedDispatcherTask(
      DISPATCHER_TASK_EXPIRATION, ([=, playerID = player->getID()]() {
        g_game.playerUseWithCreature(playerID, fromPos, fromStackPos,
                                     creatureId, spriteId);
      }));
}

void ProtocolGame::parseCloseContainer(NetworkMessage &msg) {
  uint8_t cid = msg.getByte();
  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerCloseContainer(playerID, cid);
  }));
}

void ProtocolGame::parseUpArrowContainer(NetworkMessage &msg) {
  uint8_t cid = msg.getByte();
  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerMoveUpContainer(playerID, cid);
  }));
}

void ProtocolGame::parseUpdateContainer(NetworkMessage &msg) {
  uint8_t cid = msg.getByte();
  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerUpdateContainer(playerID, cid);
  }));
}

void ProtocolGame::parseThrow(NetworkMessage &msg) {
  Position fromPos = msg.getPosition();
  uint16_t spriteId = msg.get<uint16_t>();
  uint8_t fromStackpos = msg.getByte();
  Position toPos = msg.getPosition();
  uint16_t count = msg.get<uint16_t>();

  if (toPos != fromPos) {
    addTimedDispatcherTask(DISPATCHER_TASK_EXPIRATION,
                           ([=, playerID = player->getID()]() {
                             g_game.playerMoveThing(playerID, fromPos, spriteId,
                                                    fromStackpos, toPos, count);
                           }));
  }
}

void ProtocolGame::parseLookAt(NetworkMessage &msg) {
  Position pos = msg.getPosition();
  msg.skipBytes(2); // spriteId
  uint8_t stackpos = msg.getByte();
  addTimedDispatcherTask(DISPATCHER_TASK_EXPIRATION,
                         ([=, playerID = player->getID()]() {
                           g_game.playerLookAt(playerID, pos, stackpos);
                         }));
}

void ProtocolGame::parseLookInBattleList(NetworkMessage &msg) {
  uint32_t creatureId = msg.get<uint32_t>();
  addTimedDispatcherTask(DISPATCHER_TASK_EXPIRATION,
                         ([=, playerID = player->getID()]() {
                           g_game.playerLookInBattleList(playerID, creatureId);
                         }));
}

void ProtocolGame::parseSay(NetworkMessage &msg) {
  std::string receiver;
  uint16_t channelId;

  SpeakClasses type = static_cast<SpeakClasses>(msg.getByte());
  switch (type) {
  case TALKTYPE_PRIVATE:
  case TALKTYPE_PRIVATE_RED:
    receiver = msg.getString();
    channelId = 0;
    break;

  case TALKTYPE_CHANNEL_Y:
  case TALKTYPE_CHANNEL_R1:
  case TALKTYPE_CHANNEL_R2:
    channelId = msg.get<uint16_t>();
    break;

  default:
    channelId = 0;
    break;
  }

  const std::string text = msg.getString();
  if (text.length() > 255) {
    return;
  }

  if (channelId == CHANNEL_CAST) {
    if (text == "/spectators") {
      std::ostringstream entry;
      entry << "Your live stream haves " << getSpectatorCount()
            << " spectators now.";
      player->sendChannelMessage("", entry.str(), TALKTYPE_CHANNEL_O,
                                 CHANNEL_CAST);
      return;
    }
  }

  addGameTask(&Game::playerSay, player->getID(), channelId, type, receiver,
              text);
}

void ProtocolGame::parseFightModes(NetworkMessage &msg) {
  uint8_t rawFightMode =
      msg.getByte(); // 1 - offensive, 2 - balanced, 3 - defensive
  uint8_t rawChaseMode =
      msg.getByte(); // 0 - stand while fightning, 1 - chase opponent
  uint8_t rawSecureMode =
      msg.getByte(); // 0 - can't attack unmarked, 1 - can attack unmarked

  fightMode_t fightMode;
  if (rawFightMode == 1) {
    fightMode = FIGHTMODE_ATTACK;
  } else if (rawFightMode == 2) {
    fightMode = FIGHTMODE_BALANCED;
  } else {
    fightMode = FIGHTMODE_DEFENSE;
  }

  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerSetFightModes(playerID, fightMode, rawChaseMode != 0,
                               rawSecureMode != 0);
  }));
}

void ProtocolGame::parseAttack(NetworkMessage &msg) {
  uint32_t creatureId = msg.get<uint32_t>();
  // msg.get<uint32_t>(); creatureId (same as above)
  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerSetAttackedCreature(playerID, creatureId);
  }));
}

void ProtocolGame::parseFollow(NetworkMessage &msg) {
  uint32_t creatureId = msg.get<uint32_t>();
  // msg.get<uint32_t>(); creatureId (same as above)
  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerFollowCreature(playerID, creatureId);
  }));
}

void ProtocolGame::parseTextWindow(NetworkMessage &msg) {
  uint32_t windowTextId = msg.get<uint32_t>();
  std::string newText = msg.getString();
  addDispatcherTask(
      ([=, playerID = player->getID(), newText = std::move(newText)]() {
        g_game.playerWriteItem(playerID, windowTextId, newText);
      }));
}

void ProtocolGame::parseHouseWindow(NetworkMessage &msg) {
  uint8_t doorId = msg.getByte();
  uint32_t id = msg.get<uint32_t>();
  std::string text = msg.getString();
  addDispatcherTask(([=, playerID = player->getID(), text = std::move(text)]() {
    g_game.playerUpdateHouseWindow(playerID, doorId, id, text);
  }));
}

void ProtocolGame::parseLookInShop(NetworkMessage &msg) {
  uint16_t id = msg.get<uint16_t>();
  uint16_t count = msg.get<uint16_t>();
  addTimedDispatcherTask(DISPATCHER_TASK_EXPIRATION,
                         ([=, playerID = player->getID()]() {
                           g_game.playerLookInShop(playerID, id, count);
                         }));
}

void ProtocolGame::parsePlayerPurchase(NetworkMessage &msg) {
  uint16_t id = msg.get<uint16_t>();
  uint8_t count = msg.getByte();
  uint16_t amount = msg.get<uint16_t>();
  bool ignoreCap = msg.getByte() != 0;
  bool inBackpacks = msg.getByte() != 0;
  addTimedDispatcherTask(
      DISPATCHER_TASK_EXPIRATION, ([=, playerID = player->getID()]() {
        g_game.playerPurchaseItem(playerID, id, count, amount, ignoreCap,
                                  inBackpacks);
      }));
}

void ProtocolGame::parsePlayerSale(NetworkMessage &msg) {
  uint16_t id = msg.get<uint16_t>();
  uint8_t count = msg.getByte();
  uint16_t amount = msg.get<uint16_t>();
  bool ignoreEquipped = msg.getByte() != 0;
  addTimedDispatcherTask(
      DISPATCHER_TASK_EXPIRATION, ([=, playerID = player->getID()]() {
        g_game.playerSellItem(playerID, id, count, amount, ignoreEquipped);
      }));
}

void ProtocolGame::parseRequestTrade(NetworkMessage &msg) {
  Position pos = msg.getPosition();
  uint16_t spriteId = msg.get<uint16_t>();
  uint8_t stackpos = msg.getByte();
  uint32_t playerId = msg.get<uint32_t>();
  addTimedDispatcherTask(
      DISPATCHER_TASK_EXPIRATION, ([=, playerID = player->getID()]() {
        g_game.playerRequestTrade(playerID, pos, stackpos, playerId, spriteId);
      }));
}

void ProtocolGame::parseLookInTrade(NetworkMessage &msg) {
  bool counterOffer = (msg.getByte() == 0x01);
  uint8_t index = msg.getByte();
  addTimedDispatcherTask(
      DISPATCHER_TASK_EXPIRATION, ([=, playerID = player->getID()]() {
        g_game.playerLookInTrade(playerID, counterOffer, index);
      }));
}

void ProtocolGame::parseAddVip(NetworkMessage &msg) {
  std::string name = msg.getString();
  addDispatcherTask(([playerID = player->getID(), name = std::move(name)]() {
    g_game.playerRequestAddVip(playerID, name);
  }));
}

void ProtocolGame::parseRemoveVip(NetworkMessage &msg) {
  uint32_t guid = msg.get<uint32_t>();
  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerRequestRemoveVip(playerID, guid);
  }));
}

void ProtocolGame::parseRotateItem(NetworkMessage &msg) {
  Position pos = msg.getPosition();
  uint16_t spriteId = msg.get<uint16_t>();
  uint8_t stackpos = msg.getByte();
  addTimedDispatcherTask(
      DISPATCHER_TASK_EXPIRATION, ([=, playerID = player->getID()]() {
        g_game.playerRotateItem(playerID, pos, stackpos, spriteId);
      }));
}

void ProtocolGame::parseRuleViolationReport(NetworkMessage &msg) {
  uint8_t reportType = msg.getByte();
  uint8_t reportReason = msg.getByte();
  std::string targetName = msg.getString();
  std::string comment = msg.getString();
  std::string translation;
  if (reportType == REPORT_TYPE_NAME) {
    translation = msg.getString();
  } else if (reportType == REPORT_TYPE_STATEMENT) {
    translation = msg.getString();
    msg.get<uint32_t>(); // statement id, used to get whatever player have said,
                         // we don't log that.
  }

  addDispatcherTask(
      ([=, playerID = player->getID(), targetName = std::move(targetName),
        comment = std::move(comment), translation = std::move(translation)]() {
        g_game.playerReportRuleViolation(playerID, targetName, reportType,
                                         reportReason, comment, translation);
      }));
}

void ProtocolGame::parseBugReport(NetworkMessage &msg) {
  std::string message = msg.getString();
  addDispatcherTask(
      ([playerID = player->getID(), message = std::move(message)]() {
        g_game.playerReportBug(playerID, message);
      }));
}

void ProtocolGame::parseDebugAssert(NetworkMessage &msg) {
  if (debugAssertSent) {
    return;
  }

  debugAssertSent = true;

  std::string assertLine = msg.getString();
  std::string date = msg.getString();
  std::string description = msg.getString();
  std::string comment = msg.getString();
  addDispatcherTask(
      ([playerID = player->getID(), assertLine = std::move(assertLine),
        date = std::move(date), description = std::move(description),
        comment = std::move(comment)]() {
        g_game.playerDebugAssert(playerID, assertLine, date, description,
                                 comment);
      }));
}

void ProtocolGame::parseInviteToParty(NetworkMessage &msg) {
  uint32_t targetId = msg.get<uint32_t>();
  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerInviteToParty(playerID, targetId);
  }));
}

void ProtocolGame::parseJoinParty(NetworkMessage &msg) {
  uint32_t targetId = msg.get<uint32_t>();
  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerJoinParty(playerID, targetId);
  }));
}

void ProtocolGame::parseRevokePartyInvite(NetworkMessage &msg) {
  uint32_t targetId = msg.get<uint32_t>();
  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerRevokePartyInvitation(playerID, targetId);
  }));
}

void ProtocolGame::parsePassPartyLeadership(NetworkMessage &msg) {
  uint32_t targetId = msg.get<uint32_t>();
  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerPassPartyLeadership(playerID, targetId);
  }));
}

void ProtocolGame::parseEnableSharedPartyExperience(NetworkMessage &msg) {
  bool sharedExpActive = msg.getByte() == 1;
  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerEnableSharedPartyExperience(playerID, sharedExpActive);
  }));
}

void ProtocolGame::parseQuestLine(NetworkMessage &msg) {
  uint16_t questId = msg.get<uint16_t>();
  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerShowQuestLine(playerID, questId);
  }));
}

void ProtocolGame::parseModalWindowAnswer(NetworkMessage &msg) {
  uint32_t id = msg.get<uint32_t>();
  uint8_t button = msg.getByte();
  uint8_t choice = msg.getByte();
  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerAnswerModalWindow(playerID, id, button, choice);
  }));
}

void ProtocolGame::parseMarketLeave() {
  addDispatcherTask(
      ([playerID = player->getID()]() { g_game.playerLeaveMarket(playerID); }));
}

void ProtocolGame::parseMarketBrowse(NetworkMessage &msg) {
  uint16_t browseId = msg.get<uint16_t>();

  if (browseId == MARKETREQUEST_OWN_OFFERS) {
    addDispatcherTask(([playerID = player->getID()]() {
      g_game.playerBrowseMarketOwnOffers(playerID);
    }));
  } else if (browseId == MARKETREQUEST_OWN_HISTORY) {
    addDispatcherTask(([playerID = player->getID()]() {
      g_game.playerBrowseMarketOwnHistory(playerID);
    }));
  } else {
    addDispatcherTask(([=, playerID = player->getID()]() {
      g_game.playerBrowseMarket(playerID, browseId);
    }));
  }
}

void ProtocolGame::parseMarketCreateOffer(NetworkMessage &msg) {
  uint8_t type = msg.getByte();
  uint16_t spriteId = msg.get<uint16_t>();
  uint16_t amount = msg.get<uint16_t>();
  uint32_t price = msg.get<uint32_t>();
  bool anonymous = (msg.getByte() != 0);
  uint16_t optionId = msg.get<uint16_t>();
  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerCreateMarketOffer(playerID, type, spriteId, amount, price,
                                   anonymous, optionId);
  }));
}

void ProtocolGame::parseMarketCancelOffer(NetworkMessage &msg) {
  uint32_t timestamp = msg.get<uint32_t>();
  uint16_t counter = msg.get<uint16_t>();
  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerCancelMarketOffer(playerID, timestamp, counter);
  }));
}

void ProtocolGame::parseMarketAcceptOffer(NetworkMessage &msg) {
  uint32_t timestamp = msg.get<uint32_t>();
  uint16_t counter = msg.get<uint16_t>();
  uint16_t amount = msg.get<uint16_t>();

  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerAcceptMarketOffer(playerID, timestamp, counter, amount);
  }));
}

// Send methods
void ProtocolGame::sendOpenPrivateChannel(const std::string &receiver) {
  NetworkMessage msg;
  msg.addByte(0xAD);
  msg.addString(receiver);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendCreatureOutfit(const Creature *creature,
                                      const Outfit_t &outfit) {
  if (!canSee(creature)) {
    return;
  }

  NetworkMessage msg;
  msg.addByte(0x8E);
  msg.add<uint32_t>(creature->getID());
  AddOutfit(msg, outfit);

  // Add attached effects for real-time sync
  const AttachedEffMap &attachedEffects = creature->getAttachedEffects();
  msg.addByte(attachedEffects.size());
  for (const auto &it : attachedEffects) {
    msg.add<uint16_t>(it.second.id);
  }

  writeToOutputBuffer(msg);
}

void ProtocolGame::sendCreatureLight(const Creature *creature) {
  if (!canSee(creature)) {
    return;
  }

  NetworkMessage msg;
  AddCreatureLight(msg, creature);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendWorldLight(LightInfo lightInfo) {
  NetworkMessage msg;
  AddWorldLight(msg, lightInfo);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendCreatureWalkthrough(const Creature *creature,
                                           bool walkthrough) {
  if (!canSee(creature)) {
    return;
  }

  NetworkMessage msg;
  msg.addByte(0x92);
  msg.add<uint32_t>(creature->getID());
  msg.addByte(walkthrough ? 0x00 : 0x01);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendCreatureShield(const Creature *creature) {
  if (!canSee(creature)) {
    return;
  }

  NetworkMessage msg;
  msg.addByte(0x91);
  msg.add<uint32_t>(creature->getID());
  msg.addByte(player->getPartyShield(creature->getPlayer()));
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendCreatureSkull(const Creature *creature) {
  if (g_game.getWorldType() != WORLD_TYPE_PVP) {
    return;
  }

  if (!canSee(creature)) {
    return;
  }

  NetworkMessage msg;
  msg.addByte(0x90);
  msg.add<uint32_t>(creature->getID());
  msg.addByte(player->getSkullClient(creature));
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendCreatureEmblem(const Creature *creature) {
  if (!canSee(creature)) {
    return;
  }
  // Remove creature from client and re-add to update
  Position pos = creature->getPosition();
  int32_t stackpos =
      creature->getTile()->getClientIndexOfCreature(player, creature);
  sendRemoveTileThing(pos, stackpos);
  NetworkMessage msg;
  msg.addByte(0x6A);
  msg.addPosition(pos);
  msg.addByte(stackpos);
  AddCreature(msg, creature, false, creature->getID());
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendCreatureSquare(const Creature *creature,
                                      SquareColor_t color) {
  if (!canSee(creature)) {
    return;
  }

  NetworkMessage msg;
  msg.addByte(0x86);
  msg.add<uint32_t>(creature->getID());
  msg.addByte(color);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendTutorial(uint8_t tutorialId) {
  NetworkMessage msg;
  msg.addByte(0xDC);
  msg.addByte(tutorialId);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendAddMarker(const Position &pos, uint8_t markType,
                                 const std::string &desc) {
  NetworkMessage msg;
  msg.addByte(0xDD);
  msg.addPosition(pos);
  msg.addByte(markType);
  msg.addString(desc);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendReLoginWindow() {
  NetworkMessage msg;
  msg.addByte(0x28);
  writeToOutputBuffer(msg);

  stopLiveCast();
}

void ProtocolGame::sendStats() {
  NetworkMessage msg;
  AddPlayerStats(msg);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendTextMessage(const TextMessage &message) {
  NetworkMessage msg;
  msg.addByte(0xB4);
  msg.addByte(message.type);
  msg.addString(message.text);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendClosePrivate(uint16_t channelId) {
  NetworkMessage msg;
  msg.addByte(0xB3);
  msg.add<uint16_t>(channelId);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendCreatePrivateChannel(uint16_t channelId,
                                            const std::string &channelName) {
  NetworkMessage msg;
  msg.addByte(0xB2);
  msg.add<uint16_t>(channelId);
  msg.addString(channelName);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendChannelsDialog() {
  NetworkMessage msg;
  msg.addByte(0xAB);

  const ChannelList &list = g_chat->getChannelList(*player);
  msg.addByte(list.size());
  for (ChatChannel *channel : list) {
    msg.add<uint16_t>(channel->getId());
    msg.addString(channel->getName());
  }

  writeToOutputBuffer(msg, false);
}

void ProtocolGame::sendChannel(uint16_t channelId,
                               const std::string &channelName) {
  NetworkMessage msg;
  msg.addByte(0xAC);
  msg.add<uint16_t>(channelId);
  msg.addString(channelName);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendExtendedOpcode(uint8_t opcode,
                                      const std::string &buffer) {
  NetworkMessage msg;
  msg.addByte(0x32);
  msg.addByte(opcode);
  msg.addString(buffer);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendChannelMessage(const std::string &author,
                                      const std::string &text,
                                      SpeakClasses type, uint16_t channel) {
  NetworkMessage msg;
  msg.addByte(0xAA);
  msg.add<uint32_t>(0x00);
  msg.addString(author);
  msg.add<uint16_t>(0x00);
  msg.addByte(type);
  msg.add<uint16_t>(channel);
  msg.addString(text);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendIcons(uint16_t icons) {
  NetworkMessage msg;
  msg.addByte(0xA2);
  msg.add<uint16_t>(icons);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendContainer(uint8_t cid, const Container *container,
                                 bool hasParent, uint16_t firstIndex) {
  NetworkMessage msg;
  msg.addByte(0x6E);

  msg.addByte(cid);

  msg.addItem(container, otclientV8);
  msg.addString(container->getName());

  msg.addByte(container->capacity());

  msg.addByte(hasParent ? 0x01 : 0x00);

  msg.addByte(std::min<uint32_t>(0xFF, container->size()));

  uint32_t i = 0;
  const ItemDeque &itemList = container->getItemList();
  for (ItemDeque::const_iterator cit = itemList.begin() + firstIndex,
                                 end = itemList.end();
       i < 0xFF && cit != end; ++cit, ++i) {
    msg.addItem(*cit, otclientV8);
  }
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendShop(const ShopInfoList &itemList) {
  NetworkMessage msg;
  msg.addByte(0x7A);

  uint16_t itemsToSend =
      std::min<size_t>(itemList.size(), std::numeric_limits<uint16_t>::max());
  msg.addByte(itemsToSend);

  uint16_t i = 0;
  for (auto it = itemList.begin(); i < itemsToSend; ++it, ++i) {
    AddShopItem(msg, *it);
  }

  writeToOutputBuffer(msg);
}

void ProtocolGame::sendCloseShop() {
  NetworkMessage msg;
  msg.addByte(0x7C);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendSaleItemList(const std::list<ShopInfo> &shop) {
  NetworkMessage msg;
  msg.addByte(0x7B);

  uint16_t moneyType =
      player->shopOwner ? player->shopOwner->getMoneyType() : 0;
  if (moneyType == 0) {
    msg.add<uint32_t>(player->getMoney() + player->getBankBalance());
  } else {
    msg.add<uint32_t>(player->getItemTypeCount(moneyType));
  }
  std::map<uint16_t, uint32_t> saleMap;

  if (shop.size() <= 5) {
    // For very small shops it's not worth it to create the complete map
    for (const ShopInfo &shopInfo : shop) {
      if (shopInfo.sellPrice == 0) {
        continue;
      }

      int8_t subtype = -1;

      const ItemType &itemType = Item::items[shopInfo.itemId];
      if (itemType.hasSubType() && !itemType.stackable) {
        subtype = (shopInfo.subType == 0 ? -1 : shopInfo.subType);
      }

      uint32_t count = player->getItemTypeCount(shopInfo.itemId, subtype);
      if (count > 0) {
        saleMap[shopInfo.itemId] = count;
      }
    }
  } else {
    // Large shop, it's better to get a cached map of all item counts and use it
    // We need a temporary map since the finished map should only contain items
    // available in the shop
    std::map<uint32_t, uint32_t> tempSaleMap;
    player->getAllItemTypeCount(tempSaleMap);

    // We must still check manually for the special items that require subtype
    // matches (That is, fluids such as potions etc., actually these items are
    // very few since health potions now use their own ID)
    for (const ShopInfo &shopInfo : shop) {
      if (shopInfo.sellPrice == 0) {
        continue;
      }

      int8_t subtype = -1;

      const ItemType &itemType = Item::items[shopInfo.itemId];
      if (itemType.hasSubType() && !itemType.stackable) {
        subtype = (shopInfo.subType == 0 ? -1 : shopInfo.subType);
      }

      if (subtype != -1) {
        uint32_t count;
        if (!itemType.isFluidContainer() && !itemType.isSplash()) {
          count = player->getItemTypeCount(
              shopInfo.itemId, subtype); // This shop item requires extra checks
        } else {
          count = subtype;
        }

        if (count > 0) {
          saleMap[shopInfo.itemId] = count;
        }
      } else {
        std::map<uint32_t, uint32_t>::const_iterator findIt =
            tempSaleMap.find(shopInfo.itemId);
        if (findIt != tempSaleMap.end() && findIt->second > 0) {
          saleMap[shopInfo.itemId] = findIt->second;
        }
      }
    }
  }

  uint8_t itemsToSend =
      std::min<size_t>(saleMap.size(), std::numeric_limits<uint8_t>::max());
  msg.addByte(itemsToSend);

  uint8_t i = 0;
  for (std::map<uint16_t, uint32_t>::const_iterator it = saleMap.begin();
       i < itemsToSend; ++it, ++i) {
    msg.addItemId(it->first);
    msg.add<uint16_t>(
        std::min<uint32_t>(it->second, std::numeric_limits<uint16_t>::max()));
  }

  writeToOutputBuffer(msg);
}

void ProtocolGame::sendMarketEnter(uint32_t depotId) {
  ;
  NetworkMessage msg;
  msg.addByte(0xF6);

  msg.add<uint64_t>(IOLoginData::getPremiumPoints(player->getAccount()));
  msg.addByte(
      std::min<uint32_t>(IOMarket::getPlayerOfferCount(player->getGUID()),
                         std::numeric_limits<uint8_t>::max()));

  player->setInMarket(true);

  std::list<Item *> items;
  std::forward_list<Container *> containerList{};

  DepotChest *depotChest = player->getDepotChest(depotId, true);
  if (depotChest) {
    containerList.push_front(depotChest);
  }

  // OK
  Container *container = containerList.front();
  if (container) {
    for (Item *item : container->getItemList()) {
      items.push_back(item);
    }
  }

  msg.add<uint16_t>(items.size());
  for (std::list<Item *>::iterator it = items.begin(); it != items.end();
       ++it) {
    const ItemType &itemType = Item::items[(*it)->getID()];
    std::string name = (*it)->getName();
    std::string description = (*it)->getDescription(1);

    msg.add<uint16_t>(itemType.clientId);
    msg.add<uint16_t>(std::min<uint32_t>(0xFFFF, (*it)->getItemCount()));
    msg.addString(name);
    msg.addString(description);
  }

  writeToOutputBuffer(msg);
}

void ProtocolGame::sendMarketLeave() {
  NetworkMessage msg;
  msg.addByte(0xF7);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendMarketBrowseItem(uint16_t itemId,
                                        const MarketOfferList &buyOffers,
                                        const MarketOfferList &sellOffers) {
  NetworkMessage msg;

  msg.addByte(0xF9);
  msg.addItemId(itemId);

  msg.add<uint32_t>(buyOffers.size());
  for (const MarketOffer &offer : buyOffers) {
    msg.add<uint32_t>(offer.timestamp);
    msg.add<uint16_t>(offer.counter);
    msg.add<uint16_t>(offer.amount);
    msg.add<uint32_t>(offer.price);
    msg.addString(offer.playerName);
    msg.addString(offer.description);
    msg.addString(offer.name);

    const ItemType &itemType = Item::items[offer.itemId];
    msg.add<uint32_t>(itemType.clientId);
    msg.add<uint16_t>(offer.category);
  }

  msg.add<uint32_t>(sellOffers.size());
  for (const MarketOffer &offer : sellOffers) {
    msg.add<uint32_t>(offer.timestamp);
    msg.add<uint16_t>(offer.counter);
    msg.add<uint16_t>(offer.amount);
    msg.add<uint32_t>(offer.price);
    msg.addString(offer.playerName);
    msg.addString(offer.description);
    msg.addString(offer.name);

    const ItemType &itemType = Item::items[offer.itemId];
    msg.add<uint32_t>(itemType.clientId);
    msg.add<uint16_t>(offer.category);
  }

  writeToOutputBuffer(msg);
}

void ProtocolGame::sendMarketAcceptOffer(const MarketOfferEx &offer) {
  NetworkMessage msg;
  msg.addByte(0xF9);
  msg.addItemId(offer.itemId);

  if (offer.type == MARKETACTION_BUY) {
    msg.add<uint32_t>(0x01);
    msg.add<uint32_t>(offer.timestamp);
    msg.add<uint16_t>(offer.counter);
    msg.add<uint16_t>(offer.amount);
    msg.add<uint32_t>(offer.price);
    msg.addString(offer.playerName);
    msg.add<uint32_t>(0x00);
    msg.addString("");
    msg.addString(offer.name);

    const ItemType &itemType = Item::items[offer.itemId];
    msg.add<uint32_t>(itemType.clientId);
    msg.add<uint16_t>(offer.category);
  } else {
    msg.add<uint32_t>(0x00);
    msg.add<uint32_t>(0x01);
    msg.add<uint32_t>(offer.timestamp);
    msg.add<uint16_t>(offer.counter);
    msg.add<uint16_t>(offer.amount);
    msg.add<uint32_t>(offer.price);
    msg.addString(offer.playerName);
    msg.addString("");
    msg.addString(offer.name);

    const ItemType &itemType = Item::items[offer.itemId];
    msg.add<uint32_t>(itemType.clientId);
    msg.add<uint16_t>(offer.category);
  }

  writeToOutputBuffer(msg);
}

void ProtocolGame::sendMarketBrowseOwnOffers(
    const MarketOfferList &buyOffers, const MarketOfferList &sellOffers) {
  NetworkMessage msg;
  msg.addByte(0xF9);
  msg.add<uint16_t>(MARKETREQUEST_OWN_OFFERS);

  msg.add<uint32_t>(buyOffers.size());
  for (const MarketOffer &offer : buyOffers) {
    msg.add<uint32_t>(offer.timestamp);
    msg.add<uint16_t>(offer.counter);
    msg.addItemId(offer.itemId);
    msg.add<uint16_t>(offer.amount);
    msg.add<uint32_t>(offer.price);
    msg.addString(offer.description);
    msg.addString(offer.name);

    const ItemType &itemType = Item::items[offer.itemId];
    msg.add<uint32_t>(itemType.clientId);
    msg.add<uint16_t>(offer.category);
  }

  msg.add<uint32_t>(sellOffers.size());
  for (const MarketOffer &offer : sellOffers) {
    msg.add<uint32_t>(offer.timestamp);
    msg.add<uint16_t>(offer.counter);
    msg.addItemId(offer.itemId);
    msg.add<uint16_t>(offer.amount);
    msg.add<uint32_t>(offer.price);
    msg.addString(offer.description);
    msg.addString(offer.name);

    const ItemType &itemType = Item::items[offer.itemId];
    msg.add<uint32_t>(itemType.clientId);
    msg.add<uint16_t>(offer.category);
  }

  writeToOutputBuffer(msg);
}

void ProtocolGame::sendMarketCancelOffer(const MarketOfferEx &offer) {
  NetworkMessage msg;
  msg.addByte(0xF9);
  msg.add<uint16_t>(MARKETREQUEST_OWN_OFFERS);

  if (offer.type == MARKETACTION_BUY) {
    msg.add<uint32_t>(0x01);
    msg.add<uint32_t>(offer.timestamp);
    msg.add<uint16_t>(offer.counter);
    msg.addItemId(offer.itemId);
    msg.add<uint16_t>(offer.amount);
    msg.add<uint32_t>(offer.price);
    msg.add<uint32_t>(0x00);
    msg.addString("");
    msg.addString(offer.name);

    const ItemType &itemType = Item::items[offer.itemId];
    msg.add<uint32_t>(itemType.clientId);
    msg.add<uint16_t>(offer.category);
  } else {
    msg.add<uint32_t>(0x00);
    msg.add<uint32_t>(0x01);
    msg.add<uint32_t>(offer.timestamp);
    msg.add<uint16_t>(offer.counter);
    msg.addItemId(offer.itemId);
    msg.add<uint16_t>(offer.amount);
    msg.add<uint32_t>(offer.price);
    msg.addString("");
    msg.addString(offer.name);

    const ItemType &itemType = Item::items[offer.itemId];
    msg.add<uint32_t>(itemType.clientId);
    msg.add<uint16_t>(offer.category);
  }

  writeToOutputBuffer(msg);
}

void ProtocolGame::sendMarketBrowseOwnHistory(
    const HistoryMarketOfferList &buyOffers,
    const HistoryMarketOfferList &sellOffers) {
  uint32_t i = 0;
  std::map<uint32_t, uint16_t> counterMap;
  uint32_t buyOffersToSend = std::min<uint32_t>(
      buyOffers.size(), 810 + std::max<int32_t>(0, 810 - sellOffers.size()));
  uint32_t sellOffersToSend = std::min<uint32_t>(
      sellOffers.size(), 810 + std::max<int32_t>(0, 810 - buyOffers.size()));

  NetworkMessage msg;
  msg.addByte(0xF9);
  msg.add<uint16_t>(MARKETREQUEST_OWN_HISTORY);

  msg.add<uint32_t>(buyOffersToSend);
  for (auto it = buyOffers.begin(); i < buyOffersToSend; ++it, ++i) {
    msg.add<uint32_t>(it->timestamp);
    msg.add<uint16_t>(counterMap[it->timestamp]++);
    msg.addItemId(it->itemId);
    msg.add<uint16_t>(it->amount);
    msg.add<uint32_t>(it->price);
    msg.addByte(it->state);
    msg.addString("");
    msg.addString("");
    msg.add<uint32_t>(it->itemId);
    msg.add<uint16_t>(0);
  }

  counterMap.clear();
  i = 0;

  msg.add<uint32_t>(sellOffersToSend);
  for (auto it = sellOffers.begin(); i < sellOffersToSend; ++it, ++i) {
    msg.add<uint32_t>(it->timestamp);
    msg.add<uint16_t>(counterMap[it->timestamp]++);
    msg.addItemId(it->itemId);
    msg.add<uint16_t>(it->amount);
    msg.add<uint32_t>(it->price);
    msg.addByte(it->state);
    msg.addString("");
    msg.addString("");
    msg.add<uint32_t>(it->itemId);
    msg.add<uint16_t>(0);
  }

  writeToOutputBuffer(msg);
}

void ProtocolGame::sendMarketDetail(uint16_t itemId) {
  NetworkMessage msg;
  msg.addByte(0xF8);
  msg.addItemId(itemId);

  const ItemType &it = Item::items[itemId];
  if (it.armor != 0) {
    msg.addString(std::to_string(it.armor));
  } else {
    msg.add<uint16_t>(0x00);
  }

  if (it.attack != 0) {
    // TODO: chance to hit, range
    // example:
    // "attack +x, chance to hit +y%, z fields"
    if (it.abilities && it.abilities->elementType != COMBAT_NONE &&
        it.abilities->elementDamage != 0) {
      msg.addString(fmt::format("{:d} physical +{:d} {:s}", it.attack,
                                it.abilities->elementDamage,
                                getCombatName(it.abilities->elementType)));
    } else {
      msg.addString(std::to_string(it.attack));
    }
  } else {
    msg.add<uint16_t>(0x00);
  }

  if (it.isContainer()) {
    msg.addString(std::to_string(it.maxItems));
  } else {
    msg.add<uint16_t>(0x00);
  }

  if (it.defense != 0) {
    if (it.extraDefense != 0) {
      msg.addString(fmt::format("{:d} {:+d}", it.defense, it.extraDefense));
    } else {
      msg.addString(std::to_string(it.defense));
    }
  } else {
    msg.add<uint16_t>(0x00);
  }

  if (!it.description.empty()) {
    const std::string &descr = it.description;
    if (descr.back() == '.') {
      msg.addString(std::string(descr, 0, descr.length() - 1));
    } else {
      msg.addString(descr);
    }
  } else {
    msg.add<uint16_t>(0x00);
  }

  if (it.decayTime != 0) {
    msg.addString(fmt::format("{:d} seconds", it.decayTime));
  } else {
    msg.add<uint16_t>(0x00);
  }

  if (it.abilities) {
    std::ostringstream ss;
    bool separator = false;

    for (size_t i = 0; i < COMBAT_COUNT; ++i) {
      if (it.abilities->absorbPercent[i] == 0) {
        continue;
      }

      if (separator) {
        ss << ", ";
      } else {
        separator = true;
      }

      ss << getCombatName(indexToCombatType(i)) << ' ' << std::showpos
         << it.abilities->absorbPercent[i] << std::noshowpos << '%';
    }

    msg.addString(ss.str());
  } else {
    msg.add<uint16_t>(0x00);
  }

  if (it.minReqLevel != 0) {
    msg.addString(std::to_string(it.minReqLevel));
  } else {
    msg.add<uint16_t>(0x00);
  }

  if (it.minReqMagicLevel != 0) {
    msg.addString(std::to_string(it.minReqMagicLevel));
  } else {
    msg.add<uint16_t>(0x00);
  }

  msg.addString(it.vocationString);

  msg.addString(it.runeSpellName);

  if (it.abilities) {
    std::ostringstream ss;
    bool separator = false;

    for (uint8_t i = SKILL_FIRST; i <= SKILL_LAST; i++) {
      if (!it.abilities->skills[i]) {
        continue;
      }

      if (separator) {
        ss << ", ";
      } else {
        separator = true;
      }

      ss << getSkillName(i) << ' ' << std::showpos << it.abilities->skills[i]
         << std::noshowpos;
    }

    if (it.abilities->stats[STAT_MAGICPOINTS] != 0) {
      if (separator) {
        ss << ", ";
      } else {
        separator = true;
      }

      ss << "magic level " << std::showpos
         << it.abilities->stats[STAT_MAGICPOINTS] << std::noshowpos;
    }

    if (it.abilities->speed != 0) {
      if (separator) {
        ss << ", ";
      }

      ss << "speed " << std::showpos << (it.abilities->speed >> 1)
         << std::noshowpos;
    }

    msg.addString(ss.str());
  } else {
    msg.add<uint16_t>(0x00);
  }

  if (it.charges != 0) {
    msg.addString(std::to_string(it.charges));
  } else {
    msg.add<uint16_t>(0x00);
  }

  std::string weaponName = getWeaponName(it.weaponType);

  if (it.slotPosition & SLOTP_TWO_HAND) {
    if (!weaponName.empty()) {
      weaponName += ", two-handed";
    } else {
      weaponName = "two-handed";
    }
  }

  msg.addString(weaponName);

  if (it.weight != 0) {
    std::ostringstream ss;
    if (it.weight < 10) {
      ss << "0.0" << it.weight;
    } else if (it.weight < 100) {
      ss << "0." << it.weight;
    } else {
      std::string weightString = std::to_string(it.weight);
      weightString.insert(weightString.end() - 2, '.');
      ss << weightString;
    }
    ss << " oz";
    msg.addString(ss.str());
  } else {
    msg.add<uint16_t>(0x00);
  }

  MarketStatistics *statistics =
      IOMarket::getInstance().getPurchaseStatistics(itemId);
  if (statistics) {
    msg.addByte(0x01);
    msg.add<uint32_t>(statistics->numTransactions);
    msg.add<uint32_t>(std::min<uint64_t>(std::numeric_limits<uint32_t>::max(),
                                         statistics->totalPrice));
    msg.add<uint32_t>(statistics->highestPrice);
    msg.add<uint32_t>(statistics->lowestPrice);
  } else {
    msg.addByte(0x00);
  }

  statistics = IOMarket::getInstance().getSaleStatistics(itemId);
  if (statistics) {
    msg.addByte(0x01);
    msg.add<uint32_t>(statistics->numTransactions);
    msg.add<uint32_t>(std::min<uint64_t>(std::numeric_limits<uint32_t>::max(),
                                         statistics->totalPrice));
    msg.add<uint32_t>(statistics->highestPrice);
    msg.add<uint32_t>(statistics->lowestPrice);
  } else {
    msg.addByte(0x00);
  }

  writeToOutputBuffer(msg);
}

void ProtocolGame::sendQuestLog() {
  NetworkMessage msg;
  msg.addByte(0xF0);
  msg.add<uint16_t>(g_game.quests.getQuestsCount(player));

  for (const Quest &quest : g_game.quests.getQuests()) {
    if (quest.isStarted(player)) {
      msg.add<uint16_t>(quest.getID());
      msg.addString(quest.getName());
      msg.addByte(quest.isCompleted(player));
    }
  }

  writeToOutputBuffer(msg);
}

void ProtocolGame::sendQuestLine(const Quest *quest) {
  NetworkMessage msg;
  msg.addByte(0xF1);
  msg.add<uint16_t>(quest->getID());
  msg.addByte(quest->getMissionsCount(player));

  for (const Mission &mission : quest->getMissions()) {
    if (mission.isStarted(player)) {
      msg.addString(mission.getName(player));
      msg.addString(mission.getDescription(player));
    }
  }

  writeToOutputBuffer(msg);
}

void ProtocolGame::sendTradeItemRequest(const std::string &traderName,
                                        const Item *item, bool ack) {
  NetworkMessage msg;

  if (ack) {
    msg.addByte(0x7D);
  } else {
    msg.addByte(0x7E);
  }

  msg.addString(traderName);

  if (const Container *tradeContainer = item->getContainer()) {
    std::list<const Container *> listContainer{tradeContainer};
    std::list<const Item *> itemList{tradeContainer};
    while (!listContainer.empty()) {
      const Container *container = listContainer.front();
      listContainer.pop_front();

      for (Item *containerItem : container->getItemList()) {
        Container *tmpContainer = containerItem->getContainer();
        if (tmpContainer) {
          listContainer.push_back(tmpContainer);
        }
        itemList.push_back(containerItem);
      }
    }

    msg.addByte(itemList.size());
    for (const Item *listItem : itemList) {
      msg.addItem(listItem, otclientV8);
    }
  } else {
    msg.addByte(0x01);
    msg.addItem(item, otclientV8);
  }
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendCloseTrade() {
  NetworkMessage msg;
  msg.addByte(0x7F);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendCloseContainer(uint8_t cid) {
  NetworkMessage msg;
  msg.addByte(0x6F);
  msg.addByte(cid);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendCreatureTurn(const Creature *creature,
                                    uint32_t stackPos) {
  if (!canSee(creature)) {
    return;
  }

  NetworkMessage msg;
  msg.addByte(0x6B);
  msg.addPosition(creature->getPosition());
  msg.addByte(stackPos);
  msg.add<uint16_t>(0x63);
  msg.add<uint32_t>(creature->getID());
  msg.addByte(creature->getDirection());
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendCreatureSay(const Creature *creature, SpeakClasses type,
                                   const std::string &text,
                                   const Position *pos /* = nullptr*/) {
  if (!creature) {
    return;
  }

  NetworkMessage msg;
  msg.addByte(0xAA);
  msg.add<uint32_t>(0x00);

  msg.addString(creature->getName());

  // Add level only for players
  if (const Player *speaker = creature->getPlayer()) {
    msg.add<uint16_t>(speaker->getLevel());
  } else {
    msg.add<uint16_t>(0x00);
  }

  msg.addByte(type);
  if (pos) {
    msg.addPosition(*pos);
  } else {
    msg.addPosition(creature->getPosition());
  }

  msg.addString(text);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendToChannel(const Creature *creature, SpeakClasses type,
                                 const std::string &text, uint16_t channelId) {
  if (!creature) {
    return;
  }

  NetworkMessage msg;
  msg.addByte(0xAA);
  msg.add<uint32_t>(0x00);

  if (type == TALKTYPE_CHANNEL_R2) {
    msg.addString("");
    type = TALKTYPE_CHANNEL_R1;
  } else {
    msg.addString(creature->getName());
    // Add level only for players
    if (const Player *speaker = creature->getPlayer()) {
      msg.add<uint16_t>(speaker->getLevel());
    } else {
      msg.add<uint16_t>(0x00);
    }
  }

  msg.addByte(type);
  msg.add<uint16_t>(channelId);
  msg.addString(text);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendPrivateMessage(const Player *speaker, SpeakClasses type,
                                      const std::string &text) {
  NetworkMessage msg;
  msg.addByte(0xAA);
  static uint32_t statementId = 0;
  msg.add<uint32_t>(++statementId);
  if (speaker) {
    msg.addString(speaker->getName());
    msg.add<uint16_t>(speaker->getLevel());
  } else {
    msg.add<uint32_t>(0x00);
  }
  msg.addByte(type);
  msg.addString(text);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendCancelTarget() {
  NetworkMessage msg;
  msg.addByte(0xA3);
  msg.add<uint32_t>(0x00);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendChangeSpeed(const Creature *creature, uint32_t speed) {
  NetworkMessage msg;
  msg.addByte(0x8F);
  msg.add<uint32_t>(creature->getID());
  msg.add<uint16_t>(speed);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendCancelWalk() {
  NetworkMessage msg;
  msg.addByte(0xB5);
  msg.addByte(player->getDirection());
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendSkills() {
  NetworkMessage msg;
  AddPlayerSkills(msg);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendPing() {
  NetworkMessage msg;
  msg.addByte(0x1E);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendDistanceShoot(const Position &from, const Position &to,
                                     uint16_t type) {
  NetworkMessage msg;
  msg.addByte(0x85);
  msg.addPosition(from);
  msg.addPosition(to);
  msg.add<uint16_t>(type);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendMagicEffect(const Position &pos, uint16_t type) {
  if (!canSee(pos)) {
    return;
  }

  NetworkMessage msg;
  msg.addByte(0x83);
  msg.addPosition(pos);
  msg.add<uint16_t>(type);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendCreatureHealth(const Creature *creature) {
  NetworkMessage msg;
  msg.addByte(0x8C);
  msg.add<uint32_t>(creature->getID());

  if (creature->isHealthHidden()) {
    msg.addByte(0x00);
  } else {
    msg.addByte(std::ceil((static_cast<double>(creature->getHealth()) /
                           std::max<int32_t>(creature->getMaxHealth(), 1)) *
                          100));
  }
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendFYIBox(const std::string &message) {
  NetworkMessage msg;
  msg.addByte(0x15);
  msg.addString(message);
  writeToOutputBuffer(msg, false);
}

// PokeMonster spectating (UI via Lua opcode 198, aqui so map+inv sync)
void ProtocolGame::sendStartSpectating(Player* target) {
  if (!target) return;
  sendMapDescription(target->getPosition());
  for (int i = CONST_SLOT_FIRST; i <= CONST_SLOT_LAST; ++i) {
    sendInventoryItem(static_cast<slots_t>(i),
                      target->getInventoryItem(static_cast<slots_t>(i)));
  }
  target->sendStats();
  target->sendSkills();
}

void ProtocolGame::sendStopSpectating() {
  if (!player) return;
  sendMapDescription(player->getPosition());
  for (int i = CONST_SLOT_FIRST; i <= CONST_SLOT_LAST; ++i) {
    sendInventoryItem(static_cast<slots_t>(i),
                      player->getInventoryItem(static_cast<slots_t>(i)));
  }
  player->sendStats();
  player->sendSkills();
}

// tile
void ProtocolGame::sendMapDescription(const Position &pos) {
  NetworkMessage msg;
  msg.addByte(0x64);
  msg.addPosition(pos);
  GetMapDescription(pos.x - Map::maxClientViewportX,
                    pos.y - Map::maxClientViewportY, pos.z,
                    (Map::maxClientViewportX + 1) * 2,
                    (Map::maxClientViewportY + 1) * 2, msg);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendAddTileItem(const Position &pos, uint32_t stackpos,
                                   const Item *item) {
  if (!canSee(pos)) {
    return;
  }

  NetworkMessage msg;
  msg.addByte(0x6A);
  msg.addPosition(pos);
  msg.addByte(stackpos);
  msg.addItem(item);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendUpdateTileItem(const Position &pos, uint32_t stackpos,
                                      const Item *item) {
  if (!canSee(pos)) {
    return;
  }

  NetworkMessage msg;
  msg.addByte(0x6B);
  msg.addPosition(pos);
  msg.addByte(stackpos);
  msg.addItem(item);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendRemoveTileThing(const Position &pos, uint32_t stackpos) {
  if (!canSee(pos)) {
    return;
  }

  NetworkMessage msg;
  RemoveTileThing(msg, pos, stackpos);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendUpdateTile(const Tile *tile, const Position &pos) {
  if (!canSee(pos)) {
    return;
  }

  NetworkMessage msg;
  msg.addByte(0x69);
  msg.addPosition(pos);

  if (tile) {
    GetTileDescription(tile, msg);
    msg.addByte(0x00);
    msg.addByte(0xFF);
  } else {
    msg.addByte(0x01);
    msg.addByte(0xFF);
  }

  writeToOutputBuffer(msg);
}

void ProtocolGame::sendFightModes() {
  NetworkMessage msg;
  msg.addByte(0xA7);
  msg.addByte(player->fightMode);
  msg.addByte(player->chaseMode);
  msg.addByte(player->secureMode);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendAddCreature(const Creature *creature,
                                   const Position &pos, int32_t stackpos,
                                   bool isLogin) {
  if (!canSee(pos)) {
    return;
  }

  if (creature != player) {
    if (stackpos != -1) {
      NetworkMessage msg;
      msg.addByte(0x6A);
      msg.addPosition(pos);
      msg.addByte(stackpos);

      bool known;
      uint32_t removedKnown;
      checkCreatureAsKnown(creature->getID(), known, removedKnown);
      AddCreature(msg, creature, known, removedKnown);
      writeToOutputBuffer(msg);
    }

    if (isLogin) {
      sendMagicEffect(pos, CONST_ME_TELEPORT);
    }
    return;
  }

  NetworkMessage msg;
  msg.addByte(0x0A);

  msg.add<uint32_t>(player->getID());
  msg.add<uint16_t>(0x32); // beat duration (50)

  // can report bugs?
  msg.addByte(0x01);

  writeToOutputBuffer(msg);

  sendMapDescription(pos);

  if (isLogin) {
    sendMagicEffect(pos, CONST_ME_TELEPORT);
  }

  for (int i = CONST_SLOT_FIRST; i <= CONST_SLOT_LAST; ++i) {
    sendInventoryItem(static_cast<slots_t>(i),
                      player->getInventoryItem(static_cast<slots_t>(i)));
  }

  sendStats();
  sendSkills();

  // gameworld light-settings
  sendWorldLight(g_game.getWorldLightInfo());

  // player light level
  sendCreatureLight(creature);

  const std::forward_list<VIPEntry> &vipEntries =
      IOLoginData::getVIPEntries(player->getAccount());
  for (const VIPEntry &entry : vipEntries) {
    Player *vipPlayer = g_game.getPlayerByGUID(entry.guid);

    sendVIP(
        entry.guid, entry.name,
        static_cast<VipStatus_t>((vipPlayer && (!vipPlayer->isInGhostMode() ||
                                                player->isAccessPlayer()))));
  }

  player->sendIcons();
}

void ProtocolGame::sendMoveCreature(const Creature *creature,
                                    const Position &newPos, int32_t newStackPos,
                                    const Position &oldPos, int32_t oldStackPos,
                                    bool teleport) {
  if (creature == player) {
    if (oldStackPos >= 10) {
      sendMapDescription(newPos);
    } else if (teleport) {
      NetworkMessage msg;
      RemoveTileThing(msg, oldPos, oldStackPos);
      writeToOutputBuffer(msg);
      sendMapDescription(newPos);
    } else {
      NetworkMessage msg;
      if (oldPos.z == 7 && newPos.z >= 8) {
        RemoveTileThing(msg, oldPos, oldStackPos);
      } else {
        msg.addByte(0x6D);
        msg.addPosition(oldPos);
        msg.addByte(oldStackPos);
        msg.addPosition(newPos);
      }

      if (newPos.z > oldPos.z) {
        MoveDownCreature(msg, creature, newPos, oldPos);
      } else if (newPos.z < oldPos.z) {
        MoveUpCreature(msg, creature, newPos, oldPos);
      }

      if (oldPos.y > newPos.y) { // north, for old x
        msg.addByte(0x65);
        GetMapDescription(oldPos.x - Map::maxClientViewportX,
                          newPos.y - Map::maxClientViewportY, newPos.z,
                          (Map::maxClientViewportX + 1) * 2, 1, msg);
      } else if (oldPos.y < newPos.y) { // south, for old x
        msg.addByte(0x67);
        GetMapDescription(oldPos.x - Map::maxClientViewportX,
                          newPos.y + (Map::maxClientViewportY + 1), newPos.z,
                          (Map::maxClientViewportX + 1) * 2, 1, msg);
      }

      if (oldPos.x < newPos.x) { // east, [with new y]
        msg.addByte(0x66);
        GetMapDescription(newPos.x + (Map::maxClientViewportX + 1),
                          newPos.y - Map::maxClientViewportY, newPos.z, 1,
                          (Map::maxClientViewportY + 1) * 2, msg);
      } else if (oldPos.x > newPos.x) { // west, [with new y]
        msg.addByte(0x68);
        GetMapDescription(newPos.x - Map::maxClientViewportX,
                          newPos.y - Map::maxClientViewportY, newPos.z, 1,
                          (Map::maxClientViewportY + 1) * 2, msg);
      }
      writeToOutputBuffer(msg);
    }
  } else if (canSee(oldPos) && canSee(creature->getPosition())) {
    if (teleport || (oldPos.z == 7 && newPos.z >= 8) || oldStackPos >= 10) {
      sendRemoveTileThing(oldPos, oldStackPos);
      sendAddCreature(creature, newPos, newStackPos, false);
    } else {
      NetworkMessage msg;
      msg.addByte(0x6D);
      msg.addPosition(oldPos);
      msg.addByte(oldStackPos);
      msg.addPosition(creature->getPosition());
      writeToOutputBuffer(msg);
    }
  } else if (canSee(oldPos)) {
    sendRemoveTileThing(oldPos, oldStackPos);
  } else if (canSee(creature->getPosition())) {
    sendAddCreature(creature, newPos, newStackPos, false);
  }
}

void ProtocolGame::sendInventoryItem(slots_t slot, const Item *item) {
  NetworkMessage msg;
  if (item) {
    msg.addByte(0x78);
    msg.addByte(slot);
    msg.addItem(item, otclientV8);
  } else {
    msg.addByte(0x79);
    msg.addByte(slot);
  }
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendAddContainerItem(uint8_t cid, const Item *item) {
  NetworkMessage msg;
  msg.addByte(0x70);
  msg.addByte(cid);
  msg.addItem(item, otclientV8);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendUpdateContainerItem(uint8_t cid, uint16_t slot,
                                           const Item *item) {
  NetworkMessage msg;
  msg.addByte(0x71);
  msg.addByte(cid);
  msg.addByte(slot);
  msg.addItem(item, otclientV8);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendRemoveContainerItem(uint8_t cid, uint16_t slot) {
  NetworkMessage msg;
  msg.addByte(0x72);
  msg.addByte(cid);
  msg.addByte(slot);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendTextWindow(uint32_t windowTextId, Item *item,
                                  uint16_t maxlen, bool canWrite) {
  NetworkMessage msg;
  msg.addByte(0x96);
  msg.add<uint32_t>(windowTextId);
  msg.add<uint16_t>(item->getID());

  if (canWrite) {
    msg.add<uint16_t>(maxlen);
    msg.addString(item->getText());
  } else {
    const std::string &text = item->getText();
    msg.add<uint16_t>(text.size());
    msg.addString(text);
  }

  const std::string &writer = item->getWriter();
  if (!writer.empty()) {
    msg.addString(writer);
  } else {
    msg.add<uint16_t>(0x00);
  }

  time_t writtenDate = item->getDate();
  if (writtenDate != 0) {
    msg.addString(formatDateShort(writtenDate));
  } else {
    msg.add<uint16_t>(0x00);
  }

  writeToOutputBuffer(msg);
}

void ProtocolGame::sendTextWindow(uint32_t windowTextId, uint32_t itemId,
                                  const std::string &text) {
  NetworkMessage msg;
  msg.addByte(0x96);
  msg.add<uint32_t>(windowTextId);
  msg.addItem(itemId, 1, otclientV8);
  msg.add<uint16_t>(text.size());
  msg.addString(text);
  msg.add<uint16_t>(0x00);
  msg.add<uint16_t>(0x00);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendHouseWindow(uint32_t windowTextId,
                                   const std::string &text) {
  NetworkMessage msg;
  msg.addByte(0x97);
  msg.addByte(0x00);
  msg.add<uint32_t>(windowTextId);
  msg.addString(text);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendOutfitWindow() {
  NetworkMessage msg;
  msg.addByte(0xC8);

  Outfit_t currentOutfit = player->getDefaultOutfit();
  AddOutfit(msg, currentOutfit);

  std::vector<ProtocolOutfit> protocolOutfits;
  if (player->isAccessPlayer()) {
    static const std::string gamemasterOutfitName = "Gamemaster";
    protocolOutfits.emplace_back(gamemasterOutfitName, 75, 0);
  }

  const auto &outfits = Outfits::getInstance().getOutfits(player->getSex());
  protocolOutfits.reserve(outfits.size());
  for (const Outfit &outfit : outfits) {
    uint8_t addons;
    if (!player->getOutfitAddons(outfit, addons)) {
      continue;
    }

    protocolOutfits.emplace_back(outfit.name, outfit.lookType, addons);
    if (protocolOutfits.size() == 50) {
      break;
    }
  }

  msg.addByte(protocolOutfits.size());
  for (const ProtocolOutfit &outfit : protocolOutfits) {
    msg.add<uint16_t>(outfit.lookType);
    msg.addString(outfit.name);
    msg.addByte(outfit.addons);
  }

  if (otclientV8) {
    std::vector<const Wing *> wings;
    for (const Wing &wing : g_game.wings.getWings()) {
      if (player->hasWing(&wing)) {
        wings.push_back(&wing);
      }
    }

    msg.addByte(wings.size());
    for (const Wing *wing : wings) {
      msg.add<uint16_t>(wing->clientId);
      msg.addString(wing->name);
    }

    std::vector<const Aura *> auras;
    for (const Aura &aura : g_game.auras.getAuras()) {
      if (player->hasAura(&aura)) {
        auras.push_back(&aura);
      }
    }

    msg.addByte(auras.size());
    for (const Aura *aura : auras) {
      msg.add<uint16_t>(aura->clientId);
      msg.addString(aura->name);
    }
  }

  msg.addByte(0);
  msg.addByte(0);
  msg.addByte(0);

  writeToOutputBuffer(msg, false);
}

void ProtocolGame::sendUpdatedVIPStatus(uint32_t guid, VipStatus_t newStatus) {
  NetworkMessage msg;
  msg.addByte(newStatus == VIPSTATUS_ONLINE ? 0xD3 : 0xD4);
  msg.add<uint32_t>(guid);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendVIP(uint32_t guid, const std::string &name,
                           VipStatus_t status) {
  NetworkMessage msg;
  msg.addByte(0xD2);
  msg.add<uint32_t>(guid);
  msg.addString(name);
  msg.addByte(status);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendAnimatedText(const std::string &message,
                                    const Position &pos, TextColor_t color) {
  if (!canSee(pos)) {
    return;
  }

  NetworkMessage msg;
  msg.addByte(0x84);
  msg.addPosition(pos);
  msg.addByte(color);
  msg.addString(message);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendModalWindow(const ModalWindow &modalWindow) {
  NetworkMessage msg;
  msg.addByte(0xFA);

  msg.add<uint32_t>(modalWindow.id);
  msg.addString(modalWindow.title);
  msg.addString(modalWindow.message);

  msg.addByte(modalWindow.buttons.size());
  for (const auto &it : modalWindow.buttons) {
    msg.addString(it.first);
    msg.addByte(it.second);
  }

  msg.addByte(modalWindow.choices.size());
  for (const auto &it : modalWindow.choices) {
    msg.addString(it.first);
    msg.addByte(it.second);
  }

  msg.addByte(modalWindow.defaultEscapeButton);
  msg.addByte(modalWindow.defaultEnterButton);
  msg.addByte(modalWindow.priority ? 0x01 : 0x00);

  writeToOutputBuffer(msg);
}

////////////// Add common messages
void ProtocolGame::AddCreature(NetworkMessage &msg, const Creature *creature,
                               bool known, uint32_t remove) {
  const Player *otherPlayer = creature->getPlayer();
  if (known) {
    msg.add<uint16_t>(0x62);
    msg.add<uint32_t>(creature->getID());
  } else {
    msg.add<uint16_t>(0x61);
    msg.add<uint32_t>(remove);
    msg.add<uint32_t>(creature->getID());
    msg.addString(creature->getName());
  }

  if (creature->isHealthHidden()) {
    msg.addByte(0x00);
  } else {
    msg.addByte(std::ceil((static_cast<double>(creature->getHealth()) /
                           std::max<int32_t>(creature->getMaxHealth(), 1)) *
                          100));
  }

  msg.addByte(creature->getDirection());

  if (!creature->isInGhostMode() && !creature->isInvisible()) {
    AddOutfit(msg, creature->getCurrentOutfit());
  } else {
    AddOutfit(msg, creature->getCurrentOutfit());
  }

  LightInfo lightInfo = creature->getCreatureLight();
  msg.addByte(player->isAccessPlayer() ? 0xFF : lightInfo.level);
  msg.addByte(lightInfo.color);

  msg.add<uint16_t>(creature->getStepSpeed());

  msg.addByte(player->getSkullClient(otherPlayer));
  msg.addByte(player->getPartyShield(otherPlayer));

  if (!known) {
    msg.addByte(player->getGuildEmblem(otherPlayer));
  }

  msg.addByte(player->canWalkthroughEx(creature) ? 0x00 : 0x01);

  const AttachedEffMap &attachedEffects = creature->getAttachedEffects();
  msg.addByte(attachedEffects.size());
  for (const auto &it : attachedEffects) {
    msg.add<uint16_t>(it.second.id);
  }
}

void ProtocolGame::AddPlayerStats(NetworkMessage &msg) {
  msg.addByte(0xA0);

  if (player->getMaxHealth() > 0) {
    msg.add<uint16_t>(
        std::min<int32_t>(player->getHealth() * 100 / player->getMaxHealth(),
                          std::numeric_limits<uint16_t>::max()));
    msg.add<uint16_t>(100);
  } else {
    msg.add<uint16_t>(0);
    msg.add<uint16_t>(0);
  }

  msg.add<uint32_t>(player->hasFlag(PlayerFlag_HasInfiniteCapacity)
                        ? 1000000
                        : player->getFreeCapacity());

  msg.add<uint32_t>(std::min<uint32_t>(player->getExperience(), 0x7FFFFFFF));

  msg.add<uint16_t>(player->getLevel());
  msg.addByte(player->getLevelPercent());

  if (player->getMaxMana() > 0) {
    msg.add<uint16_t>(
        std::min<int32_t>(player->getMana() * 100 / player->getMaxMana(),
                          std::numeric_limits<uint16_t>::max()));
    msg.add<uint16_t>(100);
  } else {
    msg.add<uint16_t>(0);
    msg.add<uint16_t>(0);
  }

  msg.addByte(std::min<uint32_t>(player->getMagicLevel(),
                                 std::numeric_limits<uint8_t>::max()));
  msg.addByte(player->getMagicLevelPercent());

  msg.addByte(player->getSoul());

  msg.add<uint16_t>(player->getStaminaMinutes());
}

void ProtocolGame::AddPlayerSkills(NetworkMessage &msg) {
  msg.addByte(0xA1);

  for (uint8_t i = SKILL_FIRST; i <= SKILL_LAST; ++i) {
    msg.addByte(std::min<int32_t>(player->getSkillLevel(i),
                                  std::numeric_limits<uint16_t>::max()));
    msg.addByte(player->getSkillPercent(i));
  }
}

void ProtocolGame::AddOutfit(NetworkMessage &msg, const Outfit_t &outfit) {
  msg.add<uint16_t>(outfit.lookType);

  if (outfit.lookType != 0) {
    msg.addByte(outfit.lookHead);
    msg.addByte(outfit.lookBody);
    msg.addByte(outfit.lookLegs);
    msg.addByte(outfit.lookFeet);
    msg.addByte(outfit.lookAddons);
    msg.add<uint16_t>(outfit.lookWings);
    msg.add<uint16_t>(outfit.lookAura);
    msg.add<uint16_t>(outfit.healthBackground);
    msg.add<uint16_t>(outfit.manaBackground);
    msg.add<uint16_t>(outfit.koteElemental);
  } else {
    msg.addItemId(outfit.lookTypeEx);
  }
}

void ProtocolGame::AddWorldLight(NetworkMessage &msg, LightInfo lightInfo) {
  msg.addByte(0x82);
  if (g_config.getBoolean(ConfigManager::GM_FULL_LIGHT_ON_EQUIP_ITEM))
    msg.addByte(player->isAccessPlayer() ? 0xFF : lightInfo.level);
  else
    msg.addByte(lightInfo.level);
  msg.addByte(lightInfo.color);
}

void ProtocolGame::AddCreatureLight(NetworkMessage &msg,
                                    const Creature *creature) {
  LightInfo lightInfo = creature->getCreatureLight();

  msg.addByte(0x8D);
  msg.add<uint32_t>(creature->getID());
  if (g_config.getBoolean(ConfigManager::GM_FULL_LIGHT_ON_EQUIP_ITEM))
    msg.addByte(player->isAccessPlayer() ? 0xFF : lightInfo.level);
  else
    msg.addByte(lightInfo.level);
  msg.addByte(lightInfo.color);
}

// tile
void ProtocolGame::RemoveTileThing(NetworkMessage &msg, const Position &pos,
                                   uint32_t stackpos) {
  if (stackpos >= 10) {
    return;
  }

  msg.addByte(0x6C);
  msg.addPosition(pos);
  msg.addByte(stackpos);
}

void ProtocolGame::MoveUpCreature(NetworkMessage &msg, const Creature *creature,
                                  const Position &newPos,
                                  const Position &oldPos) {
  if (creature != player) {
    return;
  }

  // floor change up
  msg.addByte(0xBE);

  // going to surface
  if (newPos.z == 7) {
    int32_t skip = -1;
    GetFloorDescription(msg, oldPos.x - Map::maxClientViewportX,
                        oldPos.y - Map::maxClientViewportY, 5,
                        (Map::maxClientViewportX + 1) * 2,
                        (Map::maxClientViewportY + 1) * 2, 3,
                        skip); //(floor 7 and 6 already set)
    GetFloorDescription(msg, oldPos.x - Map::maxClientViewportX,
                        oldPos.y - Map::maxClientViewportY, 4,
                        (Map::maxClientViewportX + 1) * 2,
                        (Map::maxClientViewportY + 1) * 2, 4, skip);
    GetFloorDescription(msg, oldPos.x - Map::maxClientViewportX,
                        oldPos.y - Map::maxClientViewportY, 3,
                        (Map::maxClientViewportX + 1) * 2,
                        (Map::maxClientViewportY + 1) * 2, 5, skip);
    GetFloorDescription(msg, oldPos.x - Map::maxClientViewportX,
                        oldPos.y - Map::maxClientViewportY, 2,
                        (Map::maxClientViewportX + 1) * 2,
                        (Map::maxClientViewportY + 1) * 2, 6, skip);
    GetFloorDescription(msg, oldPos.x - Map::maxClientViewportX,
                        oldPos.y - Map::maxClientViewportY, 1,
                        (Map::maxClientViewportX + 1) * 2,
                        (Map::maxClientViewportY + 1) * 2, 7, skip);
    GetFloorDescription(msg, oldPos.x - Map::maxClientViewportX,
                        oldPos.y - Map::maxClientViewportY, 0,
                        (Map::maxClientViewportX + 1) * 2,
                        (Map::maxClientViewportY + 1) * 2, 8, skip);

    if (skip >= 0) {
      msg.addByte(skip);
      msg.addByte(0xFF);
    }
  }
  // underground, going one floor up (still underground)
  else if (newPos.z > 7) {
    int32_t skip = -1;
    GetFloorDescription(msg, oldPos.x - Map::maxClientViewportX,
                        oldPos.y - Map::maxClientViewportY, oldPos.getZ() - 3,
                        (Map::maxClientViewportX + 1) * 2,
                        (Map::maxClientViewportY + 1) * 2, 3, skip);

    if (skip >= 0) {
      msg.addByte(skip);
      msg.addByte(0xFF);
    }
  }

  // moving up a floor up makes us out of sync
  // west
  msg.addByte(0x68);
  GetMapDescription(oldPos.x - Map::maxClientViewportX,
                    oldPos.y - (Map::maxClientViewportY - 1), newPos.z, 1,
                    (Map::maxClientViewportY + 1) * 2, msg);
  // north
  msg.addByte(0x65);
  GetMapDescription(oldPos.x - Map::maxClientViewportX,
                    oldPos.y - Map::maxClientViewportY, newPos.z,
                    (Map::maxClientViewportX + 1) * 2, 1, msg);
}

void ProtocolGame::MoveDownCreature(NetworkMessage &msg,
                                    const Creature *creature,
                                    const Position &newPos,
                                    const Position &oldPos) {
  if (creature != player) {
    return;
  }

  // floor change down
  msg.addByte(0xBF);

  // going from surface to underground
  if (newPos.z == 8) {
    int32_t skip = -1;
    GetFloorDescription(msg, oldPos.x - Map::maxClientViewportX,
                        oldPos.y - Map::maxClientViewportY, newPos.z,
                        (Map::maxClientViewportX + 1) * 2,
                        (Map::maxClientViewportY + 1) * 2, -1, skip);
    GetFloorDescription(msg, oldPos.x - Map::maxClientViewportX,
                        oldPos.y - Map::maxClientViewportY, newPos.z + 1,
                        (Map::maxClientViewportX + 1) * 2,
                        (Map::maxClientViewportY + 1) * 2, -2, skip);
    GetFloorDescription(msg, oldPos.x - Map::maxClientViewportX,
                        oldPos.y - Map::maxClientViewportY, newPos.z + 2,
                        (Map::maxClientViewportX + 1) * 2,
                        (Map::maxClientViewportY + 1) * 2, -3, skip);

    if (skip >= 0) {
      msg.addByte(skip);
      msg.addByte(0xFF);
    }
  }
  // going further down
  else if (newPos.z > oldPos.z && newPos.z > 8 && newPos.z < 14) {
    int32_t skip = -1;
    GetFloorDescription(msg, oldPos.x - Map::maxClientViewportX,
                        oldPos.y - Map::maxClientViewportY, newPos.z + 2,
                        (Map::maxClientViewportX + 1) * 2,
                        (Map::maxClientViewportY + 1) * 2, -3, skip);

    if (skip >= 0) {
      msg.addByte(skip);
      msg.addByte(0xFF);
    }
  }

  // moving down a floor makes us out of sync
  // east
  msg.addByte(0x66);
  GetMapDescription(oldPos.x + Map::maxClientViewportX + 1,
                    oldPos.y - (Map::maxClientViewportY + 1), newPos.z, 1,
                    ((Map::maxClientViewportY + 1) * 2), msg);
  // south
  msg.addByte(0x67);
  GetMapDescription(oldPos.x - Map::maxClientViewportX,
                    oldPos.y + (Map::maxClientViewportY + 1), newPos.z,
                    ((Map::maxClientViewportX + 1) * 2), 1, msg);
}

void ProtocolGame::AddShopItem(NetworkMessage &msg, const ShopInfo &item) {
  const ItemType &it = Item::items[item.itemId];
  msg.add<uint16_t>(it.clientId);

  if (it.isSplash() || it.isFluidContainer()) {
    msg.addByte(serverFluidToClient(item.subType));
  } else {
    msg.addByte(0x00);
  }

  msg.addString(item.realName);
  msg.add<uint32_t>(it.weight);
  msg.add<uint32_t>(item.buyPrice);
  msg.add<uint32_t>(item.sellPrice);
}

void ProtocolGame::parseExtendedOpcode(NetworkMessage &msg) {
  uint8_t opcode = msg.getByte();
  std::string buffer = msg.getString();

  // addGameTask(&Game::parsePlayerExtendedOpcode, player->getID(), opcode,
  // buffer);
  addDispatcherTask(
      ([playerID = player->getID(), opcode, buffer = std::move(buffer)]() {
        g_game.parsePlayerExtendedOpcode(playerID, opcode, buffer);
      }));
}

// OTCv8
void ProtocolGame::sendFeatures() {
  if (!otclientV8)
    return;

  std::map<GameFeature, bool> features;
  // place for non-standard OTCv8 features
  features[GameExtendedOpcode] = true;
  features[GameEnvironmentEffect] =
      false; // disable it, useless 2 byte with every tile
  features[GameExtendedClientPing] = false;
  features[GameItemTooltip] = true; // fully available from version 2.6
  features[GameWingsAndAura] = true;

  if (features.empty())
    return;

  NetworkMessage msg;
  msg.addByte(0x43);
  msg.add<uint16_t>(features.size());
  for (auto &feature : features) {
    msg.addByte((uint8_t)feature.first);
    msg.addByte(feature.second ? 1 : 0);
  }
  writeToOutputBuffer(msg);
}

void ProtocolGame::parseNewPing(NetworkMessage &msg) {
  uint32_t pingId = msg.get<uint32_t>();
  uint16_t localPing = msg.get<uint16_t>();
  uint16_t fps = msg.get<uint16_t>();

  addDispatcherTask(([=, playerID = player->getID()]() {
    g_game.playerReceiveNewPing(playerID, localPing, fps);
  }));
  addDispatcherTask(([=, self = getThis()]() { self->sendNewPing(pingId); }));
}

void ProtocolGame::sendNewPing(uint32_t pingId) {
  if (!otclientV8)
    return;

  NetworkMessage msg;
  msg.addByte(0x40);
  msg.add<uint32_t>(pingId);
  writeToOutputBuffer(msg);
}

void ProtocolGame::sendProgressbar(uint32_t id, uint32_t duration, bool ltr) {
  if (!otclientV8 || otclientV8 < 260)
    return;

  NetworkMessage msg;
  msg.addByte(0x3b);
  msg.add<uint32_t>(id);
  msg.add<uint32_t>(duration);
  msg.addByte(ltr);
  writeToOutputBuffer(msg);
}
