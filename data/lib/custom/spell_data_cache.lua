-- Spell Data Cache
-- This file contains manually extracted spell data from spells.xml
-- Used by spellbar_opcode.lua to get accurate level, magiclevel, and cooldown

SPELL_DATA_CACHE = {}

-- Helper function to add spell data
-- slot: default position in spellbar (1-12), nil = auto
local function addSpell(name, level, magiclevel, cooldown, slot)
    SPELL_DATA_CACHE[name:lower()] = {
        level = level or 0,
        magiclevel = magiclevel or 0,
        cooldown = cooldown or 2000,
        slot = slot
    }
end

-- ================================================
-- ALL CHARACTERS SPELLS (HEALING)
-- ================================================
addSpell("Regeneration", 1, 0, 1000, 1)
addSpell("Big regeneration", 250, 100, 1000)

-- ================================================
-- ALL CHARACTERS SPELLS (SUPPORT)
-- ================================================
addSpell("Powerdown", 25, 0, 1000)
addSpell("Skip", 1, 0, 2000, 2)
addSpell("Sense", 75, 0, 1000)
addSpell("Aura", 1, 0, 2000)
addSpell("Kai", 50, 0, 1000)
addSpell("Speed up", 10, 0, 1000)
addSpell("Super speed", 100, 100, 1000)
addSpell("Fly kubu", 125, 0, 2000)
addSpell("Fight kubu", 125, 0, 45000)

-- ================================================
-- ALL CHARACTERS SPELLS (ATTACK)
-- ================================================
addSpell("Generic ki blast", 1, 0, 2000)
addSpell("Ki blast", 30, 0, 2000)
addSpell("Big explosion", 50, 0, 2000, 3)
addSpell("Energy blast", 75, 0, 2000)

-- ================================================
-- ALL CHARACTERS SPELLS (BUFFS)
-- ================================================
addSpell("Big power up", 100, 50, 30000) -- 30 seconds
addSpell("Giga power up", 250, 80, 45000) -- 45 seconds
addSpell("Ultimate power up", 400, 110, 60000) -- 60 seconds

-- ================================================
-- GOKU SPELLS
-- ================================================
addSpell("Super explosion wave", 100, 60, 900, 4)
addSpell("Renzoku kienzan", 150, 70, 200, 5)
addSpell("Impact blast", 200, 100, 200, 6)
addSpell("Small genki blast", 250, 110, 200, 7)
addSpell("Super kamehameha", 300, 115, 200, 8)
addSpell("Migatte no gokui", 350, 125, 45000, 9)
addSpell("Dragon fist attack", 400, 130, 200, 10)

-- ================================================
-- VEGETA SPELLS
-- ================================================
addSpell("Furie blast", 150, 70, 200, 4)
addSpell("Final shine", 200, 100, 200, 5)
addSpell("Saiyajin blast", 250, 110, 200, 6)
addSpell("Super final flash", 300, 115, 200, 7)
addSpell("Ki sense", 350, 125, 40000, 8)
addSpell("Big bang attack", 400, 130, 200, 9)

-- ================================================
-- PICCOLO SPELLS
-- ================================================
addSpell("Namekjin wave", 100, 60, 900, 4)
addSpell("Makankosappo", 150, 70, 200, 5)
addSpell("Namekjin rage", 200, 100, 200, 6)
addSpell("Shishin no ken", 250, 110, 200, 7)
addSpell("Kochi kara kikou ha", 300, 115, 200, 8)
addSpell("Namekian clone", 350, 125, 40000, 9)
addSpell("Demon hand", 400, 130, 200, 10)

-- ================================================
-- C17 SPELLS
-- ================================================
addSpell("Self destruction", 100, 60, 900, 4)
addSpell("Hell ball", 150, 70, 200, 5)
addSpell("Black blitz", 200, 100, 200, 6)
addSpell("Deadly bomb", 250, 110, 200, 7)
addSpell("Energy sign", 300, 115, 200, 8)
addSpell("Android barrier", 350, 125, 60000, 9)
addSpell("Cyborg explosion", 400, 130, 200, 10)

-- ================================================
-- GOHAN SPELLS
-- ================================================
addSpell("Super saiyaman furie", 100, 60, 900, 4)
addSpell("Saiyaman ball", 150, 70, 200, 5)
addSpell("Saiyaman power", 200, 100, 200, 6)
addSpell("Saiyaman blast", 250, 110, 200, 7)
addSpell("Rage ozaru", 350, 125, 45000, 8)
addSpell("Mystic saiyaman", 400, 130, 200, 9)

-- ================================================
-- TRUNKS SPELLS
-- ================================================
addSpell("Sword furie", 100, 60, 900, 4)
addSpell("Massive sword", 150, 70, 200, 5)
addSpell("Massive blast", 250, 110, 200, 6)
addSpell("Massive chikeitu", 350, 125, 60000, 7)
addSpell("Massive sword attack", 400, 130, 200, 8)

-- ================================================
-- CELL SPELLS
-- ================================================
addSpell("Auto destruction", 100, 60, 900, 4)
addSpell("Hell granade", 150, 70, 200, 5)
addSpell("Kienzan", 200, 100, 200, 6)
addSpell("Super hell granade", 250, 110, 200, 7)
addSpell("Kyushu", 350, 125, 60000, 8)
addSpell("Taiyouken", 300, 115, 200, 9)

-- ================================================
-- FREEZA SPELLS
-- ================================================
addSpell("Psycho barrier", 100, 60, 900, 4)
addSpell("Infinity psycho", 150, 70, 200, 5)
addSpell("Psycho impact", 200, 100, 200, 6)
addSpell("Pressure dust", 250, 110, 200, 7)
addSpell("Death cannon", 300, 115, 200, 8)
addSpell("Death beam", 350, 125, 15000, 9)
addSpell("Evil kienzan", 400, 130, 200, 10)

-- ================================================
-- BUU SPELLS
-- ================================================
addSpell("Jinruizetsu", 100, 60, 900, 4)
addSpell("Lightning arrow", 150, 70, 200, 5)
addSpell("Chikyuu hou kai", 200, 100, 200, 6)
addSpell("Pink ball", 250, 110, 200, 7)
addSpell("Chikyuu kamehameha", 300, 115, 200, 8)
addSpell("Choco buster beam", 350, 125, 40000, 9)
addSpell("Rage pink beam", 400, 130, 200, 10)

-- ================================================
-- BROLY SPELLS
-- ================================================
addSpell("Barakuitsu furie", 100, 60, 900, 4)
addSpell("Barakuitsu", 150, 70, 200, 5)
addSpell("Barakuitsu rio", 200, 100, 200, 6)
addSpell("Barakuitsu blast", 250, 110, 200, 7)
addSpell("Shunkan barakuisu rio", 300, 115, 200, 8)
addSpell("Shunkan rio", 350, 125, 50000, 9)
addSpell("Omega blast", 400, 130, 200, 10)

-- ================================================
-- GOTEN SPELLS
-- ================================================
addSpell("Fusion explosion", 100, 60, 900, 4)
addSpell("Renzoku shine missile", 150, 70, 200, 5)
addSpell("Sayajin blast", 200, 100, 200, 6)
addSpell("Super kamikaze attack", 250, 110, 200, 7)
addSpell("Ultra final flash", 300, 115, 200, 8)
addSpell("Kai super kamikaze", 350, 125, 45000, 9)
addSpell("Galactic donut", 400, 130, 200, 10)

-- ================================================
-- KURIRIN SPELLS
-- ================================================
addSpell("Energy wave", 100, 60, 900, 4)
addSpell("Simple kienzan", 150, 70, 200, 5)
addSpell("Kaukusudan", 200, 100, 200, 6)
addSpell("Triple kienzan", 250, 110, 200, 7)
addSpell("Chou kamehameha", 300, 115, 200, 8)
addSpell("Flash kienzan", 350, 125, 60000, 9)
addSpell("Super kienzan", 400, 130, 200, 10)

-- ================================================
-- JANEMBA SPELLS
-- ================================================
addSpell("Demon furie", 100, 60, 900, 4)
addSpell("Sword throw", 150, 70, 200, 5)
addSpell("Demon rage", 200, 100, 200, 6)
addSpell("Demon blast", 250, 110, 200, 7)
addSpell("Jigoku beam", 300, 115, 200, 8)
addSpell("Demon hell rage", 350, 125, 75000, 9)
addSpell("Sword dance", 400, 130, 200, 10)

-- ================================================
-- TAPION SPELLS
-- ================================================
addSpell("Brave furie", 100, 60, 900, 4)
addSpell("Brave sword Attack", 150, 70, 200, 5)
addSpell("Brave slash", 200, 100, 200, 6)
addSpell("Brave shine", 250, 110, 200, 7)
addSpell("Final hell cannon", 300, 115, 200, 8)
addSpell("Heros flute", 350, 125, 40000, 9)
addSpell("Rapid sword stream", 400, 130, 200, 10)

-- ================================================
-- CHILLED SPELLS
-- ================================================
addSpell("Death nodo", 100, 60, 900, 4)
addSpell("Ruthless blow", 150, 70, 200, 5)
addSpell("Concentrate razor", 200, 100, 200, 6)
addSpell("Ruthless spikes", 250, 110, 200, 7)
addSpell("Death razor", 300, 115, 200, 8)
addSpell("Sobagashira mahi", 350, 125, 25000, 9)
addSpell("Toxic beam", 400, 130, 200, 10)

-- ================================================
-- KAGOME SPELLS
-- ================================================
addSpell("Dodon ray", 100, 60, 900, 4)
addSpell("Brave gatling", 150, 70, 200, 5)
addSpell("Dynamite kick", 200, 100, 200, 6)
addSpell("Heat dome attack", 250, 110, 200, 7)
addSpell("Ohayo kamehameha", 300, 115, 200, 8)
addSpell("Kinzoku no kawa", 350, 125, 45000, 9)
addSpell("Kinzoku no kawa kai", 350, 125, 0, 10)
addSpell("Dynamic punch", 400, 130, 200, 11)

-- ================================================
-- ZAIKO SPELLS
-- ================================================
addSpell("Saiko nodo", 100, 60, 900, 4)
addSpell("Saikosai jakai", 150, 70, 200, 5)
addSpell("Daburuboru", 200, 100, 200, 6)
addSpell("Saikosai boru", 250, 110, 200, 7)
addSpell("Saiko chou", 300, 115, 200, 8)
addSpell("Enraged defense", 350, 125, 60000, 9)
addSpell("Tengai saikosai", 400, 130, 200, 10)

-- ================================================
-- KING VEGETA SPELLS
-- ================================================
addSpell("Saiyan destruction", 100, 60, 900, 4)
addSpell("Saiyan throw", 150, 70, 200, 5)
addSpell("Saiyajin rage", 200, 100, 200, 6)
addSpell("King blast", 250, 110, 200, 7)
addSpell("Execution beam", 300, 115, 200, 8)
addSpell("Full unlock ability skill", 350, 125, 60000, 9)
addSpell("Galick gun", 400, 130, 200, 10)

-- ================================================
-- VEGETTO SPELLS
-- ================================================
addSpell("Fusion storm", 100, 60, 5000, 4)
addSpell("M1", 150, 70, 200, 5)
addSpell("Super ki blast", 200, 100, 200, 6)
addSpell("Final ryuken rage", 250, 110, 200, 7)
addSpell("Ultra mega flash", 300, 115, 200, 8)
addSpell("Savage counter", 350, 125, 25000, 9)
addSpell("Guided scatter shot", 400, 130, 200, 10)

-- ================================================
-- KAME SPELLS
-- ================================================
addSpell("Turtle devastation", 100, 60, 900)
addSpell("Rush attack", 150, 70, 200)
addSpell("Full spirit", 200, 100, 200)
addSpell("Rosh attack", 250, 110, 200)
addSpell("Mafuba effect", 350, 125, 35000) -- 35 second cooldown
addSpell("Zanzoken", 400, 130, 200)

-- ================================================
-- SHENRON SPELLS
-- ================================================
addSpell("Fire storm", 100, 60, 900, 4)
addSpell("Demon throw", 150, 70, 200, 5)
addSpell("Demon meteor", 200, 100, 200, 6)
addSpell("Negative karma ball", 250, 110, 200, 7)
addSpell("Omega extra life", 350, 125, 60000, 8)
addSpell("Destructive hell", 400, 130, 200, 9)

-- ================================================
-- KAIOH SPELLS
-- ================================================
addSpell("Celestic wave", 100, 60, 900, 4)
addSpell("Energy last", 150, 70, 200, 5)
addSpell("Shoge flash", 200, 100, 200, 6)
addSpell("Supreme blast", 250, 110, 200, 7)
addSpell("Ultra shoge fissure", 300, 115, 200, 8)
addSpell("Unlock ability regen", 350, 125, 50000, 9)
addSpell("Shin fissure", 400, 130, 200, 10)

-- ================================================
-- GOKU BLACK SPELLS
-- ================================================
addSpell("Shockwave", 100, 60, 900, 4)
addSpell("Continuous energy bullet", 150, 70, 200, 5)
addSpell("Holy light grenade", 200, 100, 200, 6)
addSpell("God slicer", 250, 110, 200, 7)
addSpell("Ultra pink flash", 300, 115, 200, 8)
addSpell("Kiai", 350, 125, 8000, 9)
addSpell("Sickle of sorrow", 400, 130, 200, 10)
addSpell("Create spirit blade", 500, 135, 2000, 11)

-- ================================================
-- ZAMASU SPELLS
-- ================================================
addSpell("Exploding wave", 100, 60, 900, 4)
addSpell("God split cut", 150, 70, 200, 5)
addSpell("Planet bomb", 200, 100, 200, 6)
addSpell("Heavenly arrow", 250, 110, 200, 7)
addSpell("Divine wrath", 300, 115, 200, 8)
addSpell("Divine god slicer", 350, 125, 75000, 9)
addSpell("Energy blade", 400, 130, 200, 10)

-- ================================================
-- JIREN SPELLS
-- ================================================
addSpell("Shock tornado", 100, 60, 900, 4)
addSpell("Overheat magnetron", 150, 70, 200, 5)
addSpell("Colossal flash", 200, 100, 200, 6)
addSpell("Overheating blast", 250, 110, 200, 7)
addSpell("Omega heat cannon", 300, 115, 200, 8)
addSpell("Power impact reverse", 350, 125, 35000, 9)
addSpell("Colossal uppercut", 400, 130, 200, 10)

-- ================================================
-- HOUSE SPELLS
-- ================================================
addSpell("House Guest List", 0, 0, 2000)
addSpell("House Kick", 0, 0, 2000)
addSpell("House Subowner List", 0, 0, 2000)

-- ================================================
-- OTHER / TEST SPELLS
-- ================================================
addSpell("Bomb", 0, 0, 2000)
addSpell("Canudo", 1, 0, 2000)
addSpell("Pulo", 1, 0, 2000)
addSpell("Impact", 1, 0, 2000)
addSpell("Fast", 0, 0, 2000)

print("[SpellDataCache] Spell data cache loaded successfully with " .. tostring(#SPELL_DATA_CACHE) .. " spells.")
