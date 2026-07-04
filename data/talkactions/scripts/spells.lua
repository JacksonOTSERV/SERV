local function stringLower(str)
    return string.lower(str or "")
end

function onSay(player, words, param)
    local text = ""
    local spells = {}

    for _, spell in ipairs(player:getInstantSpells()) do
        local spellNameLower = stringLower(spell.name)
        if spell.level ~= 0 and spellNameLower ~= "fight kubu" then
            if spell.manapercent and spell.manapercent > 0 then
                spell.mana = spell.manapercent .. "%"
            end
            table.insert(spells, spell)
        end
    end

    if player:getStorageValue(4241) > 0 then
        local fightKubuSpell = {
            name = "Fight kubu",
            level = 125,
            mana = "0",
            mlevel = "0"
        }
        table.insert(spells, fightKubuSpell)
    end

    table.sort(spells, function(a, b) return a.level < b.level end)

    local prevLevel = -1
    for i, spell in ipairs(spells) do
        local line = ""
        if prevLevel ~= spell.level then
            if i ~= 1 then
                line = "\n"
            end
            line = line .. "-- Técnicas para level " .. spell.level .. ": --\n"
            prevLevel = spell.level
        end

        local magicLevelText = spell.mlevel or "N/A"
        text = text .. line .. "  " .. spell.name .. " - Ki Points: " .. spell.mana .. "\n - Ki level: " .. magicLevelText .. "\n"
    end

    player:showTextDialog(12637, text)
    return false
end