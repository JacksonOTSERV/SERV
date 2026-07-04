-- Spellbar Opcode Handler (Server-Side)
-- Handles communication with modules/game_spellbar

-- Helper to load JSON
local json = nil
pcall(function()
    json = dofile('data/lib/json.lua')
end)

if not json then
    print("[Error - SpellbarOpcode] Could not load 'data/lib/json.lua'.")
end

local GameReceiveSpellBar = 203
local GameReceiveOpcodeCooldown = 204

function onExtendedOpcode(player, opcode, buffer)
    if not json then return false end

    if opcode == 33 then
        local status, json_data = pcall(function() return json.decode(buffer) end)
        if not status or type(json_data) ~= 'table' then 
            return false 
        end

        if json_data.type == "updateSpellBar" then
            local spells = {}
            local instantSpells = player:getInstantSpells()

            for _, spell in ipairs(instantSpells) do
                local spellName = spell.name or ""
                local spellNameLower = spellName:lower()
                
                -- Lookup from cache — only include spells with a slot defined
                local cachedData = SPELL_DATA_CACHE and SPELL_DATA_CACHE[spellNameLower]

                if not cachedData or not cachedData.slot then
                    -- Skip spells not explicitly slotted in the cache
                else
                    table.insert(spells, {
                        name = spellName,
                        level = cachedData.level or 0,
                        mglevel = cachedData.magiclevel or 0,
                        exhaust = cachedData.cooldown or 2000,
                        slot = cachedData.slot
                    })
                end
            end

            local response = {
                type = "load",
                healthPotion = player:getItemCount(12780), -- Magic senzu bean
                manaPotion = player:getItemCount(12779),   -- Senzu bean
                spells = spells
            }
            
            player:sendExtendedOpcode(GameReceiveSpellBar, json.encode(response))

        elseif json_data.type == "usePotion" then
            -- Try both keys
            local potionId = nil
            if json_data.potionId then potionId = tonumber(json_data.potionId) end
            if not potionId and json_data.id then potionId = tonumber(json_data.id) end
            
            -- Fallback: regex
            if not potionId then
                local regex_id = buffer:match('"potionId"%s*:%s*(%d+)') or buffer:match('"id"%s*:%s*(%d+)')
                if regex_id then
                    potionId = tonumber(regex_id)
                end
            end
            
            if not potionId then
                 return
            end

            local healthAmount = 0
            local manaAmount = 0
            
            -- Config values based on user input
            if potionId == 12780 then -- Magic senzu bean
                healthAmount = 18000
                manaAmount = 18000
            elseif potionId == 12779 then -- Senzu bean
                healthAmount = 9000
                manaAmount = 9000
            end
            
            if healthAmount > 0 then
                if player:getItemCount(potionId) > 0 then
                    if player:removeItem(potionId, 1) then
                        player:addHealth(healthAmount)
                        player:addMana(manaAmount)
                        player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE, player)
                        
                        local response = {
                            type = "updatePotions",
                            healthPotion = player:getItemCount(12780),
                            manaPotion = player:getItemCount(12779)
                        }
                        player:sendExtendedOpcode(GameReceiveSpellBar, json.encode(response))
                    else
                        player:sendCancelMessage("Cannot use this potion.")
                    end
                else
                    player:sendCancelMessage("You do not have this potion.")
                end
            else
                print("[SpellBar] Unknown potion ID: " .. potionId)
            end
        end
    end
    return true
end
