-- Guild Buffs System
GuildBuffs = {}

-- Config matching UI (Row * 2 + Choice)
GuildBuffs.Config = {
    -- Row 1 (Lvl 2)
    [1] = {name="HP Regen", type="cond", sub="regen", val=3, cost=100000},
    [2] = {name="MP Regen", type="cond", sub="regen", val=5, cost=100000},
    -- Row 2 (Lvl 4)
    [3] = {name="Crit Chance", type="stats", sub="crit_chance", val=5, cost=150000},
    [4] = {name="Crit Damage", type="stats", sub="crit_dmg", val=10, cost=150000},
    -- Row 3 (Lvl 6)
    [5] = {name="Mov Speed", type="cond", sub="speed", val=10, cost=200000}, -- +10 Speed
    [6] = {name="Atk Speed", type="cond", sub="haste", val=10, cost=200000}, -- +10%
    -- Row 4 (Lvl 8)
    [7] = {name="Phys Prot", type="stats", sub="prot_phys", val=5, cost=250000},
    [8] = {name="Ele Prot", type="stats", sub="prot_ele", val=3, cost=250000},
    -- Row 5 (Lvl 10)
    [9] = {name="Life Steal", type="stats", sub="lifesteal", val=5, cost=300000},
    [10] = {name="Mana Steal", type="stats", sub="manasteal", val=3, cost=300000},
    -- Row 6 (Lvl 12)
    [11] = {name="Magic Lvl", type="cond", sub="ml", val=2, cost=350000},
    [12] = {name="Skills", type="cond", sub="skills", val=3, cost=350000},
    -- Row 7 (Lvl 14)
    [13] = {name="Prot Monster", type="stats", sub="prot_mob", val=5, cost=400000},
    [14] = {name="Prot Player", type="stats", sub="prot_pvp", val=3, cost=400000},
    -- Row 8 (Lvl 16)
    [15] = {name="Dmg Monster", type="stats", sub="dmg_mob", val=8, cost=450000},
    [16] = {name="Dmg Player", type="stats", sub="dmg_pvp", val=4, cost=450000},
    -- Row 9 (Lvl 18) -- Difficult in Lua, placeholders/attempts
    [17] = {name="Mana Reduct", type="stats", sub="manareduct", val=10, cost=500000},
    [18] = {name="CD Reduct", type="stats", sub="cdreduct", val=10, cost=500000},
}

local BUFF_STORAGE = 50600
local DURATION = 24 * 3600

-- Persistence Helpers
local function getBuffExpiry(guildId, buffId)
    local q = db.storeQuery("SELECT `expiry` FROM `guild_buffs` WHERE `guild_id` = " .. guildId .. " AND `buff_id` = " .. buffId)
    if q then
         local expiry = result.getNumber(q, "expiry")
         result.free(q)
         return expiry
    end
    return 0
end

local function setBuffExpiry(guildId, buffId, expiry)
    local current = getBuffExpiry(guildId, buffId)
    if current > 0 then
        db.query("UPDATE `guild_buffs` SET `expiry` = " .. expiry .. " WHERE `guild_id` = " .. guildId .. " AND `buff_id` = " .. buffId)
    else
        db.query("INSERT INTO `guild_buffs` (`guild_id`, `buff_id`, `expiry`) VALUES (" .. guildId .. ", " .. buffId .. ", " .. expiry .. ")")
    end
end

function GuildBuffs.buy(guild, buffId)
    local buff = GuildBuffs.Config[buffId]
    if not buff then return false, "Buff not found." end
    
    local guildId = guild:getId()
    local currentExpiry = getBuffExpiry(guildId, buffId)
    
    -- Check Balance if expired
    if currentExpiry < os.time() then
        if guild:getBankBalance() < buff.cost then
            return false, "Not enough gold ("..buff.cost..")."
        end
        guild:setBankBalance(guild:getBankBalance() - buff.cost)
    end
    
    -- Set/Extend Expiry
    local newExpiry = (currentExpiry > os.time()) and (currentExpiry + DURATION) or (os.time() + DURATION)
    setBuffExpiry(guildId, buffId, newExpiry)
    
    -- Apply to online members
    for _, player in ipairs(Game.getPlayers()) do
        local pGuild = player:getGuild()
        if pGuild and pGuild:getId() == guild:getId() then
            GuildBuffs.checkConditions(player)
        end
    end
    
    return true
end

function GuildBuffs.onKill(creature, target)
    if not creature or not target then return end
    if not creature:isPlayer() or not target:isMonster() then return end
    
    local guild = creature:getGuild()
    if not guild then return end
    
    local guildId = guild:getId()
    -- Check Exp Boost (ID 1)
    local expiry = getBuffExpiry(guildId, 1)
    
    if expiry > os.time() then
        -- Apply Bonus
        local cfg = GuildBuffs.Config[1]
        local val = cfg.val or 50 -- 50%
        
        local baseExp = target:getExperience()
        local stage = Game.getExperienceStage(creature:getLevel()) or 1
        
        -- Formula: Base * Stage * (Percent / 100)
        local extraExp = math.floor(baseExp * stage * (val / 100))
        
        if extraExp > 0 then
            creature:addExperience(extraExp, true)
        end
    end
end

function GuildBuffs.checkConditions(player)
    local guild = player:getGuild()
    if not guild then return end
    
    local guildId = guild:getId()
    local conditions = {} -- Aggregate similar conditions
    
    local activeCount = 0
    for id, buff in pairs(GuildBuffs.Config) do
        local expiry = getBuffExpiry(guildId, id)
        if expiry > os.time() then
            if buff.type == "cond" then
                GuildBuffs.applyCondition(player, buff, id)
            end
            activeCount = activeCount + 1
        end
    end
    
    if activeCount > 0 then
        player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE, player)
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "[Guild Buffs] " .. activeCount .. " buffs ativos.")
    end
end

function GuildBuffs.applyCondition(player, buff, subId)
    -- This creates a temporary condition attached to the player
    -- We use subId to generate unique subId for condition if needed, but Conditions are usually by Type+ID.
    local condition
    
    if buff.sub == "regen" then
        condition = Condition(CONDITION_REGENERATION, CONDITIONID_DEFAULT + subId)
        condition:setTicks(-1) -- Infinite while logged in (refresh on login)
        if buff.name == "HP Regen" then
            condition:setParameter(CONDITION_PARAM_HEALTHGAIN, buff.val)
            condition:setParameter(CONDITION_PARAM_HEALTHTICKS, 2000)
        elseif buff.name == "MP Regen" then
            condition:setParameter(CONDITION_PARAM_MANAGAIN, buff.val)
            condition:setParameter(CONDITION_PARAM_MANATICKS, 2000)
        end
        
    elseif buff.sub == "speed" then
        condition = Condition(CONDITION_HASTE, CONDITIONID_DEFAULT + subId)
        condition:setTicks(-1)
        condition:setParameter(CONDITION_PARAM_SPEED, buff.val)
        
    elseif buff.sub == "haste" then
        condition = Condition(CONDITION_HASTE, CONDITIONID_DEFAULT + subId)
        condition:setTicks(-1)
        -- Formula for atk speed? Standard haste is movement. 
        -- For attack speed, standard TFS doesn't support generic Attack Speed condition easily without source.
        -- Assuming user meant Movement Speed or Haste spell effect.
        -- If Attack Speed, we emulate via 'onAttack' or FastAttack weapon? Not doable here.
        -- Fallback: Use Haste (Move) + small generic speed
        condition:setParameter(CONDITION_PARAM_TICKS, -1)
        condition:setFormula(0.1, 0, 0.1, 0) -- 10%
        
    elseif buff.sub == "ml" then
        condition = Condition(CONDITION_ATTRIBUTES, CONDITIONID_DEFAULT + subId)
        condition:setTicks(-1)
        condition:setParameter(CONDITION_PARAM_STAT_MAGICPOINTS, buff.val)
        
    elseif buff.sub == "skills" then
        condition = Condition(CONDITION_ATTRIBUTES, CONDITIONID_DEFAULT + subId)
        condition:setTicks(-1)
        condition:setParameter(CONDITION_PARAM_SKILL_MELEE, buff.val)
        condition:setParameter(CONDITION_PARAM_SKILL_FIST, buff.val)
        condition:setParameter(CONDITION_PARAM_SKILL_CLUB, buff.val)
        condition:setParameter(CONDITION_PARAM_SKILL_SWORD, buff.val)
        condition:setParameter(CONDITION_PARAM_SKILL_AXE, buff.val)
        condition:setParameter(CONDITION_PARAM_SKILL_DISTANCE, buff.val)
        condition:setParameter(CONDITION_PARAM_SKILL_SHIELD, buff.val)
    end
    
    if condition then
        player:addCondition(condition)
    end
end

-- Event Handlers

function GuildBuffs.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
    if not creature or not attacker then return primaryDamage, primaryType, secondaryDamage, secondaryType end
    
    local targetIsPlayer = creature:isPlayer()
    local attackerIsPlayer = attacker:isPlayer()
    
    -- --- ATTACKER BUFFS (Damage, Crit, Leech) ---
    if attackerIsPlayer then
        local guild = attacker:getGuild()
        if guild then
            local gid = guild:getId()
            local function has(id) 
                return getBuffExpiry(gid, id) > os.time()
            end
            
            -- Dmg Monster (ID 15)
            if not targetIsPlayer and has(15) then
                 primaryDamage = primaryDamage * 1.08
                 secondaryDamage = secondaryDamage * 1.08
            end
            -- Dmg Player (ID 16)
            if targetIsPlayer and has(16) then
                 primaryDamage = primaryDamage * 1.04
                 secondaryDamage = secondaryDamage * 1.04
            end
            
            -- Crit Chance/Dmg (ID 3, 4)
            if has(3) then -- 5% chance
                if math.random(100) <= 5 then
                    local mult = 1.2 -- Base crit
                    if has(4) then mult = 1.3 end -- +10%
                    primaryDamage = primaryDamage * mult
                    secondaryDamage = secondaryDamage * mult
                    attacker:getPosition():sendMagicEffect(CONST_ME_CRITICAL_HIT) -- 69 or generic
                    -- Note: visual effect might need tuning to version
                end
            end
            
            -- Life Steal (ID 9)
            if has(9) then
                local steal = (math.abs(primaryDamage) + math.abs(secondaryDamage)) * 0.05
                if steal > 0 then
                    attacker:addHealth(steal)
                    attacker:getPosition():sendMagicEffect(CONST_ME_MAGIC_RED)
                end
            end
            
             -- Mana Steal (ID 10)
            if has(10) then
                local steal = (math.abs(primaryDamage) + math.abs(secondaryDamage)) * 0.03
                if steal > 0 then
                    attacker:addMana(steal)
                    attacker:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
                end
            end
        end
    end
    
    -- --- DEFENDER BUFFS (Protection) ---
    if targetIsPlayer then
        local guild = creature:getGuild()
        if guild then
            local gid = guild:getId()
            local function has(id) 
                return getBuffExpiry(gid, id) > os.time()
            end
            
            -- Phys Prot (ID 7)
            if has(7) and (primaryType == COMBAT_PHYSICALDAMAGE or secondaryType == COMBAT_PHYSICALDAMAGE) then
                 primaryDamage = primaryDamage * 0.95
                 secondaryDamage = secondaryDamage * 0.95
            end
             -- Ele Prot (ID 8) - All non-phys
            if has(8) and (primaryType ~= COMBAT_PHYSICALDAMAGE) then
                 primaryDamage = primaryDamage * 0.97 -- 3%
                 secondaryDamage = secondaryDamage * 0.97
            end
            
            -- Prot Monster (ID 13)
            if not attackerIsPlayer and has(13) then
                 primaryDamage = primaryDamage * 0.95
                 secondaryDamage = secondaryDamage * 0.95
            end
            -- Prot Player (ID 14)
            if attackerIsPlayer and has(14) then
                 primaryDamage = primaryDamage * 0.97
                 secondaryDamage = secondaryDamage * 0.97
            end
        end
    end
    
    return primaryDamage, primaryType, secondaryDamage, secondaryType
end

print("[GuildBuffs] System loaded.")
