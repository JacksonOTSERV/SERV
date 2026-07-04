-- Spellbar Helper Library
-- Provides helper functions for spell cooldown synchronization with client

-- Opcode for spellbar cooldown trigger
local GameReceiveOpcodeCooldown = 204

-- Send cooldown update to client spellbar
-- @param player Player object
-- @param spellName string Name of the spell (must match the name in spellbar)
-- @param cooldownMs number Cooldown duration in milliseconds
function sendSpellbarCooldown(player, spellName, cooldownMs)
    if not player then
        print("[SpellBar] ERROR: player is nil")
        return false
    end
    
    if not player:isPlayer() then
        print("[SpellBar] ERROR: not a player")
        return false
    end
    
    -- Default cooldown if not specified
    cooldownMs = cooldownMs or 2000
    
    -- Format: cooldown@spellName
    local payload = tostring(cooldownMs) .. "@" .. spellName
    
    player:sendExtendedOpcode(GameReceiveOpcodeCooldown, payload)
    return true
end

-- Auto-send cooldown based on spell data from cache
-- @param player Player object  
-- @param spellName string Name of the spell
function sendSpellbarCooldownAuto(player, spellName)
    if not player then
        print("[SpellBar] ERROR: player is nil in sendSpellbarCooldownAuto")
        return false
    end
    
    if not player:isPlayer() then
        print("[SpellBar] ERROR: not a player in sendSpellbarCooldownAuto")
        return false
    end
    
    -- Lookup cooldown from cache
    local cooldown = 2000 -- default
    local spellNameLower = spellName:lower()
    
    if SPELL_DATA_CACHE and SPELL_DATA_CACHE[spellNameLower] then
        cooldown = SPELL_DATA_CACHE[spellNameLower].cooldown or 2000
    end
    
    return sendSpellbarCooldown(player, spellName, cooldown)
end

print("[SpellBar] Helper library loaded successfully!")
