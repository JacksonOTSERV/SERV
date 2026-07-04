-- Outfit Window Server Script
-- Handles outfit customization window for outfits, auras, wings, shaders, healthbars, skins

local OPCODE_OUTFIT_REQUEST = 33  -- Client sends requests on this opcode
local OPCODE_OUTFIT_RESPONSE = 12 -- Server sends responses on this opcode

-- Configuration: Define available outfits per vocation/level
-- You can customize these tables with your server's outfits

local OUTFIT_DATA = {
    -- Outfit types/categories that will be shown
    --"Auras", "Wings", "Shaders", "Healthbars", "Skins"
    outfitTypes = {"Outfits", "Skins"},
    
    -- Available outfits (lookType and level requirement)
    Outfits = {
        {lookType = 128, level = 1, name = "Citizen"},
        {lookType = 129, level = 1, name = "Hunter"},
        {lookType = 130, level = 1, name = "Mage"},
        {lookType = 131, level = 1, name = "Knight"},
        {lookType = 132, level = 20, name = "Nobleman"},
        {lookType = 133, level = 50, name = "Summoner"},
        {lookType = 134, level = 80, name = "Warrior"},
        {lookType = 144, level = 100, name = "Barbarian"},
    },
    
    -- Available auras
   -- Auras = {
     --   {lookType = 1, name = "Fire Aura"},
     --   {lookType = 2, name = "Ice Aura"},
     --   {lookType = 3, name = "Energy Aura"},
     --   {lookType = 4, name = "Earth Aura"},
    --    {lookType = 5, name = "Holy Aura"},
    --    {lookType = 6, name = "Death Aura"},
    --},
    
    -- Available wings
   -- Wings = {
      --  {lookType = 1, name = "Angel Wings"},
      --  {lookType = 2, name = "Demon Wings"},
      --  {lookType = 3, name = "Dragon Wings"},
     --   {lookType = 4, name = "Fairy Wings"},
      --  {lookType = 5, name = "Phoenix Wings"},
   -- },
    
    -- Available shaders (visual effects)
   -- Shaders = {
     --   {name = "outfit_golden"},
    --    {name = "outfit_silver"},
   --     {name = "outfit_fire"},
   --     {name = "outfit_ice"},
     --   {name = "outfit_rainbow"},
   -- },
    
    -- Available healthbar styles
    --Healthbars = {
      --  {name = "default.png"},
      --  {name = "red.png"},
       -- {name = "blue.png"},
      --  {name = "green.png"},
        --{name = "gold.png"},
    --},
    
    -- Available skins (alternate outfit looks)
    Skins = {
        {lookType = 1200, name = "Dragon Skin"},
        {lookType = 1201, name = "Warrior Skin"},
        {lookType = 1202, name = "Mage Skin"},
    },
}

-- Player outfit storage (in-memory cache, you may want to save to DB)
local playerOutfits = {}

local function sendJSON(player, opcode, data)
    local msg = json.encode(data)
    player:sendExtendedOpcode(opcode, msg)
end

local function getPlayerOutfitData(player)
    -- Filter outfits based on player's level and other conditions
    local playerLevel = player:getLevel()
    local filteredData = {
        outfitTypes = OUTFIT_DATA.outfitTypes,
        Outfits = {},
        --Auras = OUTFIT_DATA.Auras,
        --Wings = OUTFIT_DATA.Wings,
        --Shaders = OUTFIT_DATA.Shaders,
        --Healthbars = OUTFIT_DATA.Healthbars,
        Skins = OUTFIT_DATA.Skins,
    }
    
    -- Filter outfits by level requirement
    for _, outfit in ipairs(OUTFIT_DATA.Outfits) do
        if playerLevel >= outfit.level then
            table.insert(filteredData.Outfits, outfit)
        end
    end
    
    -- You can add additional filtering here:
    -- - Check if player owns the outfit in the database
    -- - Check vocation requirements
    -- - Check VIP/premium status
    -- - etc.
    
    return filteredData
end

local function handleOpenOutfit(player)
    local outfitData = getPlayerOutfitData(player)
    sendJSON(player, OPCODE_OUTFIT_RESPONSE, {
        type = "update",
        outfitData = outfitData
    })
end

local function handleChangeOutfit(player, params)
    if not params then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, "Invalid outfit parameters.")
        return
    end
    
    local currentOutfit = player:getOutfit()
    local newOutfit = {
        lookType = currentOutfit.lookType,
        lookHead = currentOutfit.lookHead,
        lookBody = currentOutfit.lookBody,
        lookLegs = currentOutfit.lookLegs,
        lookFeet = currentOutfit.lookFeet,
        lookAddons = currentOutfit.lookAddons,
    }
    
    -- Apply outfit change
    if params.type and params.type.lookType then
        -- Verify player can use this outfit (level check)
        local playerLevel = player:getLevel()
        local canUse = false
        for _, outfit in ipairs(OUTFIT_DATA.Outfits) do
            if outfit.lookType == params.type.lookType and playerLevel >= outfit.level then
                canUse = true
                break
            end
        end
        
        if canUse then
            newOutfit.lookType = params.type.lookType
        else
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, "You don't meet the requirements for this outfit.")
            return
        end
    end
    
    -- Apply skin change (alternative to outfit)
    if params.skins and params.skins.lookType then
        newOutfit.lookType = params.skins.lookType
    end
    
    -- Apply aura
    --[[
    if params.aura and params.aura.lookType then
        if player.setAura then
            player:setAura(params.aura.lookType)
        end
    else
        if player.setAura then
            player:setAura(0)
        end
    end
    ]]

    -- Apply wings
    --[[
    if params.wings and params.wings.lookType then
        if player.setWings then
            player:setWings(params.wings.lookType)
        end
    else
        if player.setWings then
            player:setWings(0)
        end
    end
    ]]

    -- Apply shader (if supported by your server)
    --[[
    if params.shader and params.shader.name then
        if player.setShader then
            player:setShader(params.shader.name)
        end
    else
        if player.setShader then
            player:setShader("")
        end
    end
    ]]

    -- Apply healthbar (stored in player storage or custom attribute)
    --[[
    if params.healthBar and params.healthBar.name then
        player:setStorageValue(65530, params.healthBar.name) -- Use a storage value for healthbar
    else
        player:setStorageValue(65530, "")
    end
    ]]
    
    -- Set the new outfit
    player:setOutfit(newOutfit)
    
    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Outfit updated successfully!")
end

-- Extended Opcode Handler
local outfitWindowEvent = CreatureEvent("OutfitWindowOpcode")

function outfitWindowEvent.onExtendedOpcode(player, opcode, buffer)
    if opcode ~= OPCODE_OUTFIT_REQUEST then
        return false
    end
    
    local status, data = pcall(json.decode, buffer)
    if not status or not data then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_RED, "Invalid outfit request.")
        return false
    end
    
    if data.type == "openOutfit" then
        handleOpenOutfit(player)
    elseif data.type == "changeOutfit" then
        handleChangeOutfit(player, data.params)
    end
    
    return true
end

-- DESATIVADO: substituido pelo sistema de vocacoes (game_heroes)
-- outfitWindowEvent:register()

-- Login event to ensure player has handler
local outfitLoginEvent = CreatureEvent("OutfitWindowLogin")

function outfitLoginEvent.onLogin(player)
    player:registerEvent("OutfitWindowOpcode")
    return true
end

-- DESATIVADO: substituido pelo sistema de vocacoes (game_heroes)
-- outfitLoginEvent:register()

print(">> Outfit Window Script loaded successfully.")
