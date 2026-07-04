-- Configs server
motd = "Bem-vindo ao NDBO!"
serverName = "NDBO"
ip = "127.0.0.1"
loginProtocolPort = 7171
gameProtocolPort = 7172
statusProtocolPort = 7171
maxPlayers = 500
bindOnlyGlobalAddress = true
deathLosePercent = -1
kickIdlePlayerAfterMinutes = 15
timeBetweenActions = 1000
timeBetweenExActions = 1000
stairJumpExhaustion = 0 * 1000
teleportPlayerSummons = true
replaceKickOnLogin = true
maxPacketsPerSecond = 475
packetCompression = true
hotkeyAimbotEnabled = true
statusTimeout = 1
allowClones = false
allowWalkthrough = true
onePlayerOnlinePerAccount = false
protectionLevel = 250

-- Cast system
enableLiveCasting = true
liveCastPort = 7173

-- Market
marketOfferDuration = 30 * 24 * 60 * 60
premiumToCreateMarketOffer = false
checkExpiredMarketOffersEachMinutes = 60
maxMarketOffersAtATimePerPlayer = 100

-- Critical system
criticalHitChance = 7
criticalHitMultiplier = 1.05
displayCriticalHitNotify = true

-- PZ & Frags
killsToRedSkull = 15
killsToBlackSkull = 100000000
pzLocked = 10 * 1000
timeToDecreaseFrags = 24 * 60 * 60 * 1000
whiteSkullTime = 5 * 60 * 1000

-- monster level
monsterLevelEnabled = true
monsterLevelMaxLevel = 5
monsterLevelSpawnChance = 0     -- 15% chance
monsterBonusDamage = 0.05          -- +10% dano/level
monsterBonusSpeed = 0.08           -- +8% speed/level
monsterBonusHealth = 0.70          -- +15% HP/level
monsterBonusExp = 0.90             -- +20% exp/level
monsterBonusLoot = 15         -- +15% loot/level

-- Stack máximo de items stackáveis (max 65535)
maxItemStack = 10000

-- Anti-multicliente: max clients simultaneos por HWID e por IP
-- extras alem do limite logam mas NAO ganham exp/loot
maxClientsPerHwid = 2
maxClientsPerIp = 3

-- Houses
housePriceEachSQM = 30000
houseRentPeriod = "weekly"

-- Database
mysqlHost = "127.0.0.1"
mysqlUser = "tibia"
mysqlPass = "tibia123"
mysqlDatabase = "dbo"
mysqlPort = 3306
mysqlSock = ""
passwordType = "sha1"
sqlType = "mysql"
defaultPriority = "high"
startupDatabaseOptimization = true

-- Save
kickIdlePlayerAfterMinutes = 15
maxMessageBuffer = 10
emoteSpells = true
classicEquipmentSlots = true
classicAttackSpeed = true
showScriptsLogInConsole = false
showOnlineStatusInCharlist = false

-- Save
serverSaveNotifyMessage = false
serverSaveNotifyDuration = 5
serverSaveCleanMap = false
serverSaveClose = false
serverSaveShutdown = false

-- Stages
experienceStages = {
    { minlevel = 1,   maxlevel = 10,  multiplier = 55 },
    { minlevel = 11,  maxlevel = 20,  multiplier = 50 },
    { minlevel = 21,  maxlevel = 30,  multiplier = 45 },
    { minlevel = 31,  maxlevel = 40,  multiplier = 40 },
    { minlevel = 41,  maxlevel = 50,  multiplier = 35 },
    { minlevel = 51,  maxlevel = 60,  multiplier = 30 },
    { minlevel = 61,  maxlevel = 70,  multiplier = 26 },
    { minlevel = 71,  maxlevel = 80,  multiplier = 22 },
    { minlevel = 81,  maxlevel = 90,  multiplier = 19 },
    { minlevel = 91,  maxlevel = 100, multiplier = 17 },
    { minlevel = 101, maxlevel = 120, multiplier = 15 },
    { minlevel = 121, maxlevel = 140, multiplier = 13 },
    { minlevel = 141, maxlevel = 160, multiplier = 11 },
    { minlevel = 161, maxlevel = 180, multiplier = 9 },
    { minlevel = 181, maxlevel = 200, multiplier = 7 },
    { minlevel = 201, maxlevel = 220, multiplier = 6 },
    { minlevel = 221, maxlevel = 240, multiplier = 5 },
    { minlevel = 241, maxlevel = 260, multiplier = 4 },
    { minlevel = 261, maxlevel = 280, multiplier = 3 },
    { minlevel = 281, maxlevel = 300, multiplier = 2.5 },
    { minlevel = 301, maxlevel = 320, multiplier = 2.2 },
    { minlevel = 321, maxlevel = 340, multiplier = 2.0 },
    { minlevel = 341, maxlevel = 360, multiplier = 1.8 },
    { minlevel = 361, maxlevel = 380, multiplier = 1.6 },
    { minlevel = 381, maxlevel = 400, multiplier = 1.4 },
    { minlevel = 401, maxlevel = 420, multiplier = 1.2 },
    { minlevel = 421, maxlevel = 440, multiplier = 1.0 },
    { minlevel = 441, maxlevel = 460, multiplier = 0.8 },
    { minlevel = 461, maxlevel = 480, multiplier = 0.6 },
    { minlevel = 481, maxlevel = 500, multiplier = 0.5 },
    { minlevel = 501, maxlevel = 520, multiplier = 0.4 },
    { minlevel = 521, maxlevel = 540, multiplier = 0.3 },
    { minlevel = 541, maxlevel = 560, multiplier = 0.25 },
    { minlevel = 561, maxlevel = 580, multiplier = 0.2 },
    { minlevel = 581, maxlevel = 600, multiplier = 0.15 },
    { minlevel = 601, maxlevel = 620, multiplier = 0.12 },
    { minlevel = 621, maxlevel = 640, multiplier = 0.1 },
    { minlevel = 641, maxlevel = 660, multiplier = 0.08 },
    { minlevel = 661, maxlevel = 680, multiplier = 0.06 },
    { minlevel = 681, maxlevel = 700, multiplier = 0.05 },
    { minlevel = 701, maxlevel = 749, multiplier = 0.04 },
    { minlevel = 750, maxlevel = 799, multiplier = 0.03 },
    { minlevel = 800, maxlevel = 800, multiplier = 0 }
}
rateExperience = 50
rateExperienceFromPlayers = 0
rateSkill = 3
rateMagic = 3
rateLoot = 3
rateSpawn = 7
spawnMultiplier = 1
deSpawnRange = 2
deSpawnRadius = 50
removeOnDespawn = false

-- stamina
staminaSystem = true

-- INFOS & MAP
mapName = "MAP"
mapAuthor = "Jackson"
ownerName = "theforgottenserver"
ownerEmail = ""
url = ""
location = "Brazil"
worldType = "pvp"

-- outros
allowChangeOutfit = true
freePremium = false
warnUnsafeScripts = true
convertUnsafeScripts = true

-- não utilizaveis
spoofEnabled = false
spoofDailyMinPlayers = 1
spoofDailyMaxPlayers = 2050
spoofNoiseInterval = 1000
spoofNoise = 0
spoofTimezone = -1
spoofInterval = 1
spoofChangeChance = 70
spoofIncrementChange = 100
removeChargesFromRunes = false
removeChargesFromPotions = false
removeWeaponAmmunition = false
removeWeaponCharges = false
experienceByKillingPlayers = false
expFromPlayersLevelRange = 0
GMFullLightOnEquipItem = false
closedWorld = false
showMonsterExiva = false
antiBot = false
guildLeaderSquare = false
pvpBalance = false
pushCruzado = false