-- G1R_CheatMenu -- keyboard-driven in-game cheat menu for Gothic 1 Remake (UE4SS Lua mod).
--
-- The menu is a plain UMG overlay built from Lua (one UserWidget, Borders + TextBlocks). It is never
-- clicked: all input comes from RegisterKeyBind, so no mouse cursor, focus change or widget hook is
-- needed. Keys and layout are in config.lua.
--
-- Every game function, class and id used below is declared in the game's own files (the
-- executable's reflection data and G1R\Script\PrecompiledScript_Shipping.Cache).
--
-- UI rules for this game build:
--   * widgets are created once via WidgetBlueprintLibrary:Create and hidden by moving them
--     off-screen, never by toggling Visibility on a live widget;
--   * Visibility is written as a property, not through the SetVisibility UFUNCTION;
--   * engine calls only happen on the game thread.

local MOD, VERSION = "G1R_CheatMenu", "1.1.0"

local print, tostring, tonumber, type, pcall, ipairs, pairs = print, tostring, tonumber, type, pcall, ipairs, pairs
local math, string, table, rawget, rawset = math, string, table, rawget, rawset

local function log(m) print("[" .. MOD .. "] " .. tostring(m) .. "\n") end

-- pcall-wrapped call, returning fn()'s result or nil on a caught Lua error.
local function try(fn)
    local ok, r = pcall(fn)
    if ok then return r end
    return nil
end

local function isValid(obj)
    if type(obj) ~= "userdata" then return false end
    local ok, v = pcall(function() return obj:IsValid() end)
    return (ok and v == true) and true or false
end

-- ------------------------------------------------------------------------- configuration --
local Config = {
    toggleKeys = { "F7" },
    upKeys = { "UP_ARROW", "NUM_EIGHT" }, downKeys = { "DOWN_ARROW", "NUM_TWO" },
    leftKeys = { "LEFT_ARROW", "NUM_FOUR" }, rightKeys = { "RIGHT_ARROW", "NUM_SIX" },
    selectKeys = { "RETURN", "NUM_FIVE" }, backKeys = { "BACKSPACE", "DECIMAL" },
    x = 60, y = 140, width = 480, rows = 14, debug = false,
}
do
    local ok, user = pcall(require, "config")
    if ok and type(user) == "table" then
        for k, v in pairs(user) do Config[k] = v end
    else
        log("config.lua not loaded, using defaults (" .. tostring(user) .. ")")
    end
end
local function dbg(m) if Config.debug then log(m) end end

local okUEH, UEHelpers = pcall(require, "UEHelpers")
if not okUEH then UEHelpers = nil end

local StaticFindObject = rawget(_G, "StaticFindObject")
local StaticConstructObject = rawget(_G, "StaticConstructObject")
local FindAllOf = rawget(_G, "FindAllOf")
local FindFirstOf = rawget(_G, "FindFirstOf")
local LoadAsset = rawget(_G, "LoadAsset")
local FName = rawget(_G, "FName")

-- ----------------------------------------------------------------------------- scheduling --
local LoopInGameThreadWithDelay = rawget(_G, "LoopInGameThreadWithDelay")
local LoopAsync = rawget(_G, "LoopAsync")
local ExecuteInGameThread = rawget(_G, "ExecuteInGameThread")

local function inGameThread(fn)
    if type(ExecuteInGameThread) == "function" then
        ExecuteInGameThread(function() pcall(fn) end)
    else
        pcall(fn)
    end
end

-- Calls decide() about every ms. decide() returns a function when there is game-thread work this
-- cycle, nil otherwise. Prefers the delayed-action system (body already on the game thread); the
-- LoopAsync fallback only marshals to the game thread when there is work.
local function gameLoop(ms, decide)
    if type(LoopInGameThreadWithDelay) == "function" then
        LoopInGameThreadWithDelay(ms, function()
            local ok, work = pcall(decide)
            if ok and type(work) == "function" then pcall(work) end
        end)
    elseif type(LoopAsync) == "function" then
        local ticking = false
        LoopAsync(ms, function()
            local ok, work = pcall(decide)
            if ok and type(work) == "function" and not ticking then
                ticking = true
                inGameThread(function() pcall(work); ticking = false end)
            end
            return false
        end)
    end
end

-- ---------------------------------------------------------------------------- game access --
local SCRIPT_PACKAGES = { "/Script/Angelscript.", "/Script/AngelscriptCode.", "/Script/G1R.", "/Script/Engine." }

local objCache = {}
local function lib(path)
    local h = objCache[path]
    if isValid(h) then return h end
    h = try(function() return StaticFindObject(path) end)
    if isValid(h) then objCache[path] = h else h = nil end
    return h
end

-- class default object of a static function library, looked up in the script packages
local function libraryObject(className)
    for _, pkg in ipairs(SCRIPT_PACKAGES) do
        local cdo = lib(pkg .. "Default__" .. className)
        if cdo then return cdo end
    end
    return nil
end

local function scriptClass(name)
    for _, pkg in ipairs(SCRIPT_PACKAGES) do
        local c = lib(pkg .. name)
        if c then return c end
    end
    return nil
end

local function stateLib() return libraryObject("Module_GAS_GASCharacterStateMixinsStatics") end

local function world()
    local gi = UEHelpers and try(function() return UEHelpers.GetGameInstance() end)
    if not isValid(gi) then return nil end
    local w = try(function() return gi:GetWorld() end)
    return isValid(w) and w or nil
end

local function gameplayStatics()
    local gs = UEHelpers and try(function() return UEHelpers.GetGameplayStatics() end)
    return isValid(gs) and gs or nil
end

local function controller()
    local w, gs = world(), gameplayStatics()
    if not (w and gs) then return nil end
    local pc = try(function() return gs:GetPlayerController(w, 0) end)
    return isValid(pc) and pc or nil
end

-- result of the first lookup that yields a live object
local function firstValid(lookups)
    for _, lookup in ipairs(lookups) do
        local obj = try(lookup)
        if isValid(obj) then return obj end
    end
    return nil
end

-- controller, pawn, character state (pawn/state are nil outside a running game)
local function player()
    local pc = controller()
    if not pc then return nil end
    local pawn = try(function() return pc.Pawn end)
    if not isValid(pawn) then return pc end
    local state = firstValid({
        function() return pawn.PlayerState end,
        function() return pawn.m_CharacterState end,
    })
    return pc, pawn, state
end

-- a component of the hero, wherever the game keeps it: as a named property or as a component of
-- the given class, on the character state or on the pawn
local function heroComponent(owners, property, classPath, getter)
    local lookups = {}
    for _, owner in ipairs(owners) do
        if isValid(owner) then
            lookups[#lookups + 1] = function() return owner[property] end
        end
    end
    for _, owner in ipairs(owners) do
        if isValid(owner) and getter then
            lookups[#lookups + 1] = function() return owner[getter](owner) end
        end
    end
    local cls = lib(classPath)
    for _, owner in ipairs(owners) do
        if isValid(owner) and cls then
            lookups[#lookups + 1] = function() return owner:GetComponentByClass(cls) end
        end
    end
    return firstValid(lookups)
end

local function playerASC(pawn, state)
    return heroComponent({ state, pawn }, "AbilitySystemComponent",
        "/Script/G1R.GothicAbilitySystemComponent", "GetAbilitySystemComponent")
end

-- live attribute set (class short name, e.g. "AttributeSet_Health") of the player's ASC
local attrCache = { key = nil, sets = {} }
local function attributeSet(name)
    local _, pawn, state = player()
    if not pawn then return nil end
    local asc = playerASC(pawn, state)
    if not asc then return nil end
    local key = tostring(try(function() return asc:GetAddress() end))
    if attrCache.key ~= key then attrCache = { key = key, sets = {} } end
    if isValid(attrCache.sets[name]) then return attrCache.sets[name] end

    local spawned = try(function() return asc.SpawnedAttributes end)
    local n = spawned and tonumber(try(function() return #spawned end)) or 0
    for i = 1, n do
        local s = try(function() return spawned[i] end)
        if isValid(s) then
            local cn = try(function() return s:GetClass():GetFName():ToString() end)
            if cn then attrCache.sets[cn] = s end
        end
    end
    return attrCache.sets[name]
end

local function readAttr(setName, field)
    local set = attributeSet(setName)
    if not set then return nil end
    local v = try(function() return set[field].CurrentValue end)
    return type(v) == "number" and v or nil
end

local function writeAttr(setName, field, value)
    local set = attributeSet(setName)
    if not set then return false end
    return pcall(function() set[field] = { BaseValue = value, CurrentValue = value } end)
end

-- set <field> to <maxField>; only writes when the value actually differs
local function fillAttr(setName, field, maxField)
    local max = readAttr(setName, maxField)
    if not max then return false end
    if readAttr(setName, field) == max then return true end
    return writeAttr(setName, field, max)
end

local function fmt(n)
    if type(n) ~= "number" then return "?" end
    if n == math.floor(n) then return string.format("%d", n) end
    return string.format("%.1f", n)
end

-- ----------------------------------------------------------------------------- menu state --
-- kept in _G so a UE4SS hot reload (CTRL+R) keeps the toggles that are still active in the game
local S = rawget(_G, "__g1rcm_state")
if not S then
    S = { open = false, stack = {}, status = "", mult = 1,
          god = false, mana = false, stamina = false, breath = false,
          frozen = false, speed = 1, weather = nil }
    rawset(_G, "__g1rcm_state", S)
end
S.open = false

local NOT_IN_GAME = "Not in a running game"

-- --------------------------------------------------------------------------------- cheats --
local function setGodMode(on)
    S.god = on
    -- the game's own developer flag on the combat config; the health refill in the tick loop
    -- below covers damage that does not go through it
    local cfg = libraryObject("CombatConfig")
    local flag = cfg and pcall(function() cfg.m_GodMode = on end)
    dbg("godmode " .. tostring(on) .. " CombatConfig.m_GodMode write ok=" .. tostring(flag))
    return "God mode " .. (on and "ON" or "OFF")
end

local function healFully()
    if not fillAttr("AttributeSet_Health", "Health", "MaxHealth") then return NOT_IN_GAME end
    fillAttr("AttributeSet_Mana", "Mana", "MaxMana")
    fillAttr("AttributeSet_Fatigue", "Fatigue", "MaxFatigue")
    return "Health, mana and stamina restored"
end

local function keepFullTick()
    if S.god then fillAttr("AttributeSet_Health", "Health", "MaxHealth") end
    if S.mana then fillAttr("AttributeSet_Mana", "Mana", "MaxMana") end
    if S.stamina then fillAttr("AttributeSet_Fatigue", "Fatigue", "MaxFatigue") end
    if S.breath then fillAttr("AttributeSet_Oxygen", "Oxygen", "MaxOxygen") end
end

-- ---- stats --
local STATS = {
    { label = "Strength", set = "AttributeSet_Strength", field = "Strength", step = 5,
      inc = "IncreaseStrengthAttributeBy" },
    { label = "Dexterity", set = "AttributeSet_Dexterity", field = "Dexterity", step = 5,
      inc = "IncreaseDexterityAttributeBy" },
    { label = "Max mana", set = "AttributeSet_Mana", field = "MaxMana", step = 5,
      inc = "IncreaseMaxManaAttributeBy", also = "Mana" },
    { label = "Max health", set = "AttributeSet_Health", field = "MaxHealth", step = 10, also = "Health", min = 1 },
    { label = "Learning points", set = "AttributeSet_LevelProgression", field = "SkillPoints", step = 5 },
    { label = "Level", set = "AttributeSet_LevelProgression", field = "Level", step = 1 },
    { label = "Experience", set = "AttributeSet_LevelProgression", field = "Experience", step = 500, xp = true },
}

local function changeStat(def, dir)
    local _, pawn, state = player()
    if not (pawn and state) then return NOT_IN_GAME end
    local cur = readAttr(def.set, def.field)
    if not cur then return def.label .. ": value not found" end
    local target = math.max(def.min or 0, cur + dir * def.step * S.mult)
    local delta = target - cur
    if delta == 0 then return def.label .. ": " .. fmt(cur) end

    local ok
    local L = stateLib()
    if def.xp then
        if delta < 0 then return "Experience can only be increased" end
        ok = L and pcall(function() L:GiveExperience(state, math.floor(delta), pawn) end)
    elseif def.inc then
        ok = L and pcall(function() L[def.inc](L, state, delta, pawn) end)
    else
        ok = writeAttr(def.set, def.field, target)
    end
    if not ok then return def.label .. ": change failed" end
    if def.also then writeAttr(def.set, def.also, target) end
    return ("%s: %s -> %s"):format(def.label, fmt(cur), fmt(readAttr(def.set, def.field) or target))
end

-- ---- faction --
-- A guild is a gameplay effect class named GE_Guild_Human_<Camp>_<Role> in the game's script
-- (Story guild definitions); holding it grants the gameplay tag Guild.Human.<Camp>.<Role>.
-- { camp id, camp name, { role id, role name }... }, ordered by rank within a camp
local CAMPS = {
    { "OldCamp", "Old Camp",
      { "Digger", "Digger" }, { "Shadow", "Shadow" }, { "Guard", "Guard" },
      { "FireMage", "Fire Mage" }, { "OreBaron", "Ore Baron" } },
    { "NewCamp", "New Camp",
      { "Scraper", "Scraper" }, { "Peasant", "Peasant" }, { "Rogue", "Rogue" },
      { "Mercenary", "Mercenary" }, { "WaterMage", "Water Mage" } },
    { "SwampCamp", "Swamp Camp",
      { "Novice", "Novice" }, { "Templar", "Templar" }, { "Guru", "Guru" } },
    { "BanditCamp", "Bandits",
      { "Bandit", "Bandit" } },
}

local GUILDS = {}
for _, camp in ipairs(CAMPS) do
    for i = 3, #camp do
        local role = camp[i]
        GUILDS[#GUILDS + 1] = {
            label = camp[2] .. ": " .. role[2],
            ge = ("GE_Guild_Human_%s_%s"):format(camp[1], role[1]),
            tag = ("Guild.Human.%s.%s"):format(camp[1], role[1]),
        }
    end
end

local function hasGuild(guild)
    local _, pawn, state = player()
    if not pawn then return false end
    local asc, L = playerASC(pawn, state), libraryObject("GothicGASLibrary")
    if not (asc and L and FName) then return false end
    return try(function() return L:HasTag(asc, { TagName = FName(guild.tag) }, true) end) == true
end

local function currentGuildLabel()
    if not select(2, player()) then return "-" end
    for _, g in ipairs(GUILDS) do
        if hasGuild(g) then return g.label end
    end
    return "None"
end

-- Unreal's stock gameplay-ability cheats (EffectApply / EffectRemove by effect name) live on
-- UAbilitySystemCheatManagerExtension, which needs a CheatManager as its outer. Shipping builds
-- do not create one, so both are constructed on demand and kept per player controller.
local cheatObjects = { owner = nil, extension = nil }
local function cheatExtension()
    local pc = controller()
    if not pc then return nil end
    local owner = tostring(try(function() return pc:GetAddress() end))
    if cheatObjects.owner == owner and isValid(cheatObjects.extension) then return cheatObjects.extension end

    local manager = firstValid({
        function() return pc.CheatManager end,
        function()
            local created = StaticConstructObject(lib("/Script/Engine.CheatManager"), pc)
            pc.CheatManager = created
            return created
        end,
    })
    local extensionClass = lib("/Script/GameplayAbilities.AbilitySystemCheatManagerExtension")
    if not (manager and extensionClass) then return nil end
    local extension = try(function() return StaticConstructObject(extensionClass, manager) end)
    if not isValid(extension) then return nil end
    cheatObjects = { owner = owner, extension = extension }
    return extension
end

local function setGuild(guild)
    if not select(2, player()) then return NOT_IN_GAME end
    local ext = cheatExtension()
    if not ext then return "Faction: cheat extension unavailable" end
    pcall(function() ext:EffectRemove("GE_Guild") end) -- drop the current guild first
    if not guild then return "Faction removed" end
    local ok = pcall(function() ext:EffectApply(guild.ge, 1) end)
    return ok and ("Faction set: " .. guild.label) or "Faction change failed"
end

-- ---- skills --
local SKILLS = {
    "Acrobatics", "Sneak", "Diving", "Wallclimbing", "Riding", "Scavenging",
    "Melee_OneHanded_Trained", "Melee_OneHanded_Master", "Melee_TwoHanded_Trained", "Melee_TwoHanded_Master",
    "Melee_Fists_Trained", "Melee_Fists_Master", "Melee_Orc_Trained", "Melee_Orc_Master",
    "Ranged_Bow_Trained", "Ranged_Bow_Master", "Ranged_Crossbow_Trained", "Ranged_Crossbow_Master",
    "Mage_Circle_1", "Mage_Circle_2", "Mage_Circle_3", "Mage_Circle_4", "Mage_Circle_5", "Mage_Circle_6",
    "Picklock_Skilled", "Picklock_Master", "Pickpocket_Skilled", "Pickpocket_Master",
    "Mining_Skilled", "Mining_Master", "Orcish_Skilled", "Orcish_Master",
    "Crafting_Alchemy", "Crafting_Inscription", "Crafting_Blacksmith_Trained", "Crafting_Blacksmith_Master",
    "Hunting_Teeth_Trained", "Hunting_Claw_Trained", "Hunting_Fur_Trained", "Hunting_Skin_Trained",
    "Hunting_Reptiles_Trained", "Hunting_Stings_Trained", "Hunting_StingsBloodfly_Trained",
    "Hunting_Organ_Trained", "Hunting_Fins_Trained", "Hunting_Secretion_Trained", "Hunting_Spines_Trained",
    "Hunting_Scutes_Trained", "Hunting_Scutes_Master", "Hunting_MCPlate_Trained",
    "Hunting_MandibleMineCrawler_Trained", "Hunting_ShadowbeastHorn_Trained", "Hunting_TrollHorn_Trained",
    "Hunting_SkinSwampshark_Trained", "Hunting_TeethSwampshark_Trained", "Hunting_TongueOfFire_Trained",
    "Hunting_SkullArmor_Trained", "Hunting_UluMulu_Trained",
}

local function learnSkill(name)
    local _, pawn, state = player()
    if not (pawn and state) then return NOT_IN_GAME end
    local cls = scriptClass("GE_Skill_" .. name)
    if not cls then return "Skill class not found: " .. name end
    local L = stateLib()
    local ok = L and (pcall(function() L:LearnSkillForFree(state, cls, pawn) end)
        or pcall(function() L:LearnSkill(state, cls, false, pawn) end))
    return ok and ("Learned: " .. name:gsub("_", " ")) or "Learning failed"
end

local function removeSkill(name)
    if not select(2, player()) then return NOT_IN_GAME end
    local ext = cheatExtension()
    if not ext then return "Skills: cheat extension unavailable" end
    local ok = pcall(function() ext:EffectRemove("GE_Skill_" .. name) end)
    return ok and ("Removed: " .. name:gsub("_", " ")) or "Removing failed"
end

-- ---- items --
local ITEMS = {
    { label = "Ore x100",                 id = "ItMi_Orenugget", count = 100 },
    { label = "Ore x1000",                id = "ItMi_Orenugget", count = 1000 },
    { label = "Lockpicks x10",            id = "ItKe_Lockpick", count = 10 },
    { label = "Healing potions x5",       id = "ItFo_Potion_Health_03", count = 5 },
    { label = "Mana potions x5",          id = "ItFo_Potion_Mana_03", count = 5 },
    { label = "Speed potions x3",         id = "ItFo_Potion_Haste_03", count = 3 },
    { label = "Arrows x50",               id = "ItAm_Arrow", count = 50 },
    { label = "Bolts x50",                id = "ItAm_Bolt", count = 50 },
    { label = "Torches x5",               id = "ItMw_1H_Torch", count = 5 },
    { label = "Strength elixir",          id = "ItFo_Potion_Strength_03", count = 1 },
    { label = "Dexterity elixir",         id = "ItFo_Potion_Dex_03", count = 1 },
    { label = "Elixir of life (max HP)",  id = "ItFo_Potion_Health_Perma_03", count = 1 },
    { label = "Elixir of spirit (max MP)", id = "ItFo_Potion_Mana_Perma_03", count = 1 },
}

-- rune item classes are ItAr_Rune_<name>; the two quest-only Milten fireball variants are left out
local RUNES = {}
for _, r in ipairs({
    { "Light", "Light" }, { "Heal", "Heal" },
    { "Fire Bolt", "FireBolt" }, { "Fire Ball", "FireBall" }, { "Storm of Fire", "StormOfFire" },
    { "Fire Rain", "FireRain" }, { "Pyrokinesis", "Pyrokinesis" },
    { "Ice Bolt", "IceBolt" }, { "Ice Block", "IceBlock" }, { "Ice Wave", "IceWave" },
    { "Ball Lightning", "BallLightning" }, { "Chain Lightning", "ChainLightning" },
    { "Fist of Wind", "FistOfWind" }, { "Storm Fist", "StormFist" },
    { "Telekinesis", "Telekinesis" }, { "Sleep", "Sleep" }, { "Charm", "Charm" }, { "Control", "Control" },
    { "Death to the Undead", "DeathToTheUndead" }, { "Breath of Death", "BreathOfDeath" },
    { "Uriziel: Wave of Death", "UrizielWaveOfDeath" },
    { "Teleport: Fire Mages", "TeleportToMagiciansOfFire" },
    { "Teleport: Water Mages", "TeleportToMagiciansOfWater" },
    { "Teleport: Swamp Camp", "TeleportToSwampCamp" },
    { "Teleport: Necromancer", "TeleportToNecromancer" },
    { "Teleport: Sunken Tower", "TeleportToSunkenTower" },
}) do
    RUNES[#RUNES + 1] = { label = r[1], id = "ItAr_Rune_" .. r[2], count = 1 }
end

local function inventory(pawn, state)
    for _, owner in ipairs({ state, pawn }) do
        if isValid(owner) then
            local inv = try(function() return owner.InventoryComponent end)
            if isValid(inv) then return inv end
            local cls = lib("/Script/G1R.InventoryComponent")
            inv = cls and try(function() return owner:GetComponentByClass(cls) end)
            if isValid(inv) then return inv end
        end
    end
    return nil
end

local function giveItem(item)
    local _, pawn, state = player()
    if not pawn then return NOT_IN_GAME end
    local inv = inventory(pawn, state)
    if not inv then return "Inventory not found" end
    local cls = scriptClass(item.id)
    if not cls then return "Item class not found: " .. item.id end
    local ok = pcall(function() inv:AddItemOfClass(cls, item.count) end)
    return ok and ("Added: " .. item.label) or "Adding item failed"
end

-- ---- world --
local function gameTime()
    local list = try(function() return FindAllOf("GameTimeSubsystem") end)
    if type(list) ~= "table" then return nil end
    for _, s in ipairs(list) do
        if isValid(s) then return s end
    end
    return nil
end

local function clockLabel()
    local sub = gameTime()
    if not sub then return "-" end
    local total = try(function() return sub:GetCurrentGameTime().TotalSeconds end)
    local h, m
    pcall(function() local ct = sub:GetCurrentClockTime(); h, m = ct.Hour, ct.Minute end)
    if type(total) ~= "number" or type(h) ~= "number" then return "-" end
    return ("Day %d, %02d:%02d"):format(math.floor(total / 86400), math.floor(h), math.floor(m or 0))
end

local function shiftTime(dir)
    local sub = gameTime()
    if not sub then return NOT_IN_GAME end
    local ok
    if dir > 0 then
        ok = pcall(function() sub:SkipTime({ TotalSeconds = 3600 }) end)
    else
        local total = try(function() return sub:GetCurrentGameTime().TotalSeconds end)
        if type(total) ~= "number" or total < 3600 then return "Cannot go back before day 0" end
        total = total - 3600
        local day = math.floor(total / 86400)
        local rest = total - day * 86400
        local h = math.floor(rest / 3600)
        local m = math.floor((rest - h * 3600) / 60)
        ok = pcall(function() sub:SetCurrentGameTime(day, h, m, 0) end)
    end
    return ok and ("Time: " .. clockLabel()) or "Changing time failed"
end

local function setTimeFrozen(on)
    local sub = gameTime()
    if not sub then return NOT_IN_GAME end
    local ok = pcall(function() if on then sub:FreezeTime() else sub:UnfreezeTime() end end)
    if not ok then return "Freezing time failed" end
    S.frozen = on
    return "Time " .. (on and "frozen" or "running")
end

local SPEEDS = { 0.25, 0.5, 1, 2, 3, 5 }
local function shiftSpeed(dir)
    local w, gs = world(), gameplayStatics()
    if not (w and gs) then return NOT_IN_GAME end
    local idx = 3
    for i, v in ipairs(SPEEDS) do if v == S.speed then idx = i end end
    idx = math.max(1, math.min(#SPEEDS, idx + dir))
    if not pcall(function() gs:SetGlobalTimeDilation(w, SPEEDS[idx]) end) then return "Changing game speed failed" end
    S.speed = SPEEDS[idx]
    return "Game speed: " .. fmt(S.speed) .. "x"
end

-- every live actor of a native class, unwrapped from the out-parameter array
local function actorsOfClass(classPath)
    local w, gs, cls = world(), gameplayStatics(), lib(classPath)
    local out = {}
    if not (w and gs and cls) then return out end
    local raw = {}
    pcall(function() gs:GetAllActorsOfClass(w, cls, raw) end)
    for _, r in ipairs(raw) do
        local a = try(function() return r:get() end) or r
        if isValid(a) then out[#out + 1] = a end
    end
    return out
end

local WEATHER = { [0] = "Sunny", [1] = "Light rain", [2] = "Rain", [3] = "Storm", [4] = "Cloudy" }
local function shiftWeather(dir)
    local ctrl
    for _, path in ipairs({ "/Script/G1R.GothicUltraDynamicController", "/Script/G1R.GothicUltraDynamicWeather" }) do
        ctrl = actorsOfClass(path)[1]
        if ctrl then break end
    end
    if not ctrl then return "Weather controller not found" end
    local id = ((S.weather or 0) + dir) % 5
    local ok = pcall(function() ctrl:SetCurrentWeatherImmediate(id) end)
        or pcall(function() ctrl:SetCurrentWeather(id) end)
    if not ok then return "Changing weather failed" end
    S.weather = id
    return "Weather: " .. WEATHER[id]
end

local function gameStory()
    local story = try(function() return FindFirstOf("GameStory") end)
    return isValid(story) and story or nil
end

local function chapterLabel()
    local story = gameStory()
    local n = story and tonumber(try(function() return story:GetChapter() end))
    return n and fmt(n) or "-"
end

local function shiftChapter(dir)
    local story = gameStory()
    local cur = story and tonumber(try(function() return story:GetChapter() end))
    if not cur then return NOT_IN_GAME end
    local target = math.max(1, math.min(6, math.floor(cur) + dir))
    if target == cur then return "Chapter: " .. fmt(cur) end
    if not pcall(function() story:ChangeChapter(target) end) then return "Changing chapter failed" end
    return "Chapter: " .. fmt(cur) .. " -> " .. chapterLabel()
end

local function clearCrimes()
    local _, pawn, state = player()
    if not (pawn and state) then return NOT_IN_GAME end
    local sub
    local list = try(function() return FindAllOf("CrimeMemorySubsystem") end)
    if type(list) == "table" then
        for _, s in ipairs(list) do if isValid(s) then sub = s; break end end
    end
    if not sub then return "Crime memory not found" end

    local ids, seen = {}, {}
    pcall(function()
        local arr = sub:GetAllCrimesCommitedBy(state)
        for i = 1, #arr do
            local id = arr[i]
            if type(id) == "userdata" then id = try(function() return id:get() end) or id end
            if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
        end
    end)
    for _, id in ipairs(ids) do
        pcall(function() sub:ForgiveCrime(id) end)
        pcall(function() sub:RemoveCrime(id) end)
    end
    return #ids == 0 and "No crimes on record" or ("Cleared " .. #ids .. " crime(s)")
end

-- ---- NPCs --
-- runs action(lib, npcState, playerState, pawn) on every loaded character except the player;
-- action returns true when it did something
local function forEachNpc(action)
    local _, pawn, state = player()
    if not (pawn and state) then return nil end
    local L = stateLib()
    if not L then return nil end
    local selfName = try(function() return pawn:GetFullName() end)
    local done = 0
    for _, actor in ipairs(actorsOfClass("/Script/G1R.GothicCharacter")) do
        if try(function() return actor:GetFullName() end) ~= selfName then
            local st = try(function() return actor.m_CharacterState end)
            if not isValid(st) then st = try(function() return actor.PlayerState end) end
            if isValid(st) and action(L, st, state, pawn) then done = done + 1 end
        end
    end
    return done
end

local function killHostiles()
    local n = forEachNpc(function(L, st, playerState, pawn)
        local rel = tonumber(try(function() return L:GetRelationshipTowards(st, playerState, pawn) end))
        if rel ~= 1 and rel ~= 2 then return false end -- 1 = enemy, 2 = hostile
        return pcall(function() L:Kill(st, true, pawn) end)
    end)
    return n and ("Killed " .. n .. " hostile NPC(s)") or NOT_IN_GAME
end

local function befriendAll()
    local n = forEachNpc(function(L, st, playerState, pawn)
        if not pcall(function() L:SetRelationshipTowards(st, playerState, 5, pawn) end) then return false end
        pcall(function() L:SetRelationshipTowards(playerState, st, 5, pawn) end)
        return true
    end)
    return n and (n .. " loaded NPC(s) are now friendly") or NOT_IN_GAME
end

-- ---- achievements --
-- ids and conditions as declared in the game's own Story/Achievements script
local ACHIEVEMENTS = {
    { id = "ACH_STORY_01",     label = "Complete chapter 2" },
    { id = "ACH_STORY_02",     label = "Complete chapter 3" },
    { id = "ACH_STORY_03",     label = "Complete chapter 4" },
    { id = "ACH_STORY_04",     label = "Complete chapter 5" },
    { id = "ACH_STORY_05",     label = "Complete chapter 6" },
    { id = "ACH_STORY_06",     label = "Enter the Sleeper Temple" },
    { id = "ACH_Story_07",     label = "Learn Orcish level 2" },
    { id = "ACH_Story_08",     label = "Complete the 'Escape Plan' quest" },
    { id = "ACH_Story_09",     label = "Complete Cavalorn's book quests" },
    { id = "ACH_Story_10",     label = "Complete the Chromanin quests" },
    { id = "ACH_Story_11",     label = "Spare Gomez's life" },
    { id = "ACH_Camp_01",      label = "Join the Old Camp" },
    { id = "ACH_Camp_02",      label = "Join the New Camp" },
    { id = "ACH_Camp_03",      label = "Join the Swamp Camp" },
    { id = "ACH_Rank_01",      label = "Rank up in any guild" },
    { id = "ACH_Maps_01",      label = "Get all maps" },
    { id = "ACH_Weapons_01",   label = "Master all melee weapons" },
    { id = "ACH_Weapons_02",   label = "Master all ranged weapons" },
    { id = "ACH_Mage_01",      label = "Reach the 6th magic circle" },
    { id = "ACH_Mage_02",      label = "Transform into all creatures" },
    { id = "ACH_Mage_03",      label = "3 elemental damage types on one enemy" },
    { id = "ACH_Armor_01",     label = "Get the ore armor" },
    { id = "ACH_Armor_02",     label = "Get all mods for an armor" },
    { id = "ACH_Thief_01",     label = "Pickpocket 20 characters" },
    { id = "ACH_Thief_02",     label = "Pick 20 locks" },
    { id = "ACH_Crafter_01",   label = "Craft your first item" },
    { id = "ACH_Crafter_02",   label = "Craft 5 weapons" },
    { id = "ACH_Crafter_03",   label = "Craft 10 potions" },
    { id = "ACH_Crafter_04",   label = "Craft a scroll" },
    { id = "ACH_Fight_01",     label = "Defeat 10 enemies with your fists" },
    { id = "ACH_Fight_02",     label = "Parry 5 times without taking damage" },
    { id = "ACH_Ranged_01",    label = "Kill 10 enemies by headshot" },
    { id = "ACH_Teacher_01",   label = "Learn all lessons" },
    { id = "ACH_Funny_01",     label = "Exhaust all of Mud's dialogue" },
    { id = "ACH_Funny_02",     label = "Kill an enemy by falling damage" },
    { id = "ACH_Hidden_01",    label = "Read 10 books" },
    { id = "ACH_Secret_01",    label = "Sneak into the Old Camp from chapter 4" },
    { id = "ACH_Secret_02",    label = "Visit Xardas' room" },
    { id = "ACH_Challenge_01", label = "Finish the game without sleeping" },
    { id = "ACH_Challenge_02", label = "Finish the game in permadeath mode" },
    { id = "ACH_All",          label = "Get all achievements" },
    { id = "ACH_AllPlus",      label = "Get all achievements (plus)" },
}

local function achievementSubsystem()
    local list = try(function() return FindAllOf("GothicAchievementSubsystem") end)
    if type(list) ~= "table" then return nil end
    for _, s in ipairs(list) do
        if isValid(s) then
            local name = try(function() return s:GetFullName() end)
            if not (name and name:find("Default__", 1, true)) then return s end
        end
    end
    return nil
end

-- property class of UnlockAchievement's first parameter ("NameProperty", "StrProperty", ...), read
-- through reflection so the id is handed over in the type the function really takes
local unlockParamKind
local function unlockParam()
    if unlockParamKind ~= nil then return unlockParamKind or nil end
    local fn = lib("/Script/G1R.GothicAchievementSubsystem:UnlockAchievement")
    local kind
    if fn then
        pcall(function()
            fn:ForEachProperty(function(prop)
                if not kind then kind = prop:GetClass():GetFName():ToString() end
            end)
        end)
    end
    unlockParamKind = kind or false
    dbg("UnlockAchievement parameter type: " .. tostring(kind))
    return kind
end

-- returns "subsystem" / "console" for the way the unlock was sent, or nil when both failed
local function unlockAchievement(id)
    local sub = achievementSubsystem()
    if sub then
        local kind = unlockParam()
        local args = {}
        if kind == "NameProperty" then
            if FName then args = { FName(id) } end
        elseif kind == "StrProperty" then
            args = { id }
        elseif kind == nil then -- reflection gave nothing: try both id types
            if FName then args[#args + 1] = FName(id) end
            args[#args + 1] = id
        end
        for _, arg in ipairs(args) do
            if pcall(function() sub:UnlockAchievement(arg) end) then return "subsystem" end
        end
    end
    -- the game also registers this as a console command
    local ksl = lib("/Script/Engine.Default__KismetSystemLibrary")
    local w, pc = world(), controller()
    if ksl and w and pc and pcall(function()
        ksl:ExecuteConsoleCommand(w, "gothic.achievement.Unlock " .. id, pc)
    end) then return "console" end
    return nil
end

local function unlockOne(ach)
    local via = unlockAchievement(ach.id)
    if not via then return "Unlock failed: " .. ach.id end
    log("unlock " .. ach.id .. " sent via " .. via .. " (parameter type " .. tostring(unlockParamKind) .. ")")
    return "Unlock sent: " .. ach.label
end

local unlockAllArmed = false
local function unlockAll()
    if not unlockAllArmed then
        unlockAllArmed = true
        return "Permanent on your account. Enter again to confirm"
    end
    unlockAllArmed = false
    local sent = 0
    for _, ach in ipairs(ACHIEVEMENTS) do
        if unlockAchievement(ach.id) then sent = sent + 1 end
    end
    return ("Unlock sent for %d of %d achievements"):format(sent, #ACHIEVEMENTS)
end

-- ---------------------------------------------------------------------------------- pages --
-- item fields: label, value() -> right-column text, then one of
--   page = "<name>"          open a sub page
--   run()                    Enter runs it
--   get()/set(bool)          on/off switch (Enter)
--   adjust(dir)              Left/Right (Enter counts as +1); every handler returns the status text
local function onOff(v) return v and "ON" or "OFF" end

local function switch(label, get, set)
    return { label = label, get = get, set = set, value = function() return onOff(get()) end }
end

local Pages = {}

Pages.main = { title = "Cheat Menu", items = {
    { label = "Player", page = "player" },
    { label = "Stats", page = "stats" },
    { label = "Faction", page = "faction", value = currentGuildLabel },
    { label = "Skills", page = "skills" },
    { label = "Items", page = "items" },
    { label = "World", page = "world" },
    { label = "NPCs", page = "npcs" },
    { label = "Achievements", page = "achievements" },
} }

Pages.player = { title = "Player", items = {
    switch("God mode", function() return S.god end, setGodMode),
    switch("Infinite mana", function() return S.mana end,
        function(on) S.mana = on; return "Infinite mana " .. onOff(on) end),
    switch("Infinite stamina", function() return S.stamina end,
        function(on) S.stamina = on; return "Infinite stamina " .. onOff(on) end),
    switch("Infinite breath", function() return S.breath end,
        function(on) S.breath = on; return "Infinite breath " .. onOff(on) end),
    { label = "Restore health, mana, stamina", run = healFully },
    { label = "Clear crimes", run = clearCrimes },
} }

Pages.stats = { title = "Stats", items = {
    { label = "Step multiplier", value = function() return "x" .. S.mult end,
      adjust = function(dir)
          local steps = { 1, 2, 10 }
          local idx = 1
          for i, v in ipairs(steps) do if v == S.mult then idx = i end end
          S.mult = steps[math.max(1, math.min(#steps, idx + dir))]
          return "Step multiplier x" .. S.mult
      end },
} }
for _, def in ipairs(STATS) do
    Pages.stats.items[#Pages.stats.items + 1] = {
        label = def.label,
        value = function() return fmt(readAttr(def.set, def.field)) end,
        adjust = function(dir) return changeStat(def, dir) end,
    }
end

Pages.faction = { title = "Faction", items = {
    { label = "No faction", run = function() return setGuild(nil) end },
} }
for _, g in ipairs(GUILDS) do
    Pages.faction.items[#Pages.faction.items + 1] = {
        label = g.label,
        value = function() return hasGuild(g) and "current" or "" end,
        run = function() return setGuild(g) end,
    }
end

Pages.skills = { title = "Skills", hint = "Enter: learn   Left: remove", items = {} }
for _, name in ipairs(SKILLS) do
    Pages.skills.items[#Pages.skills.items + 1] = {
        label = name:gsub("_", " "),
        adjust = function(dir) return dir > 0 and learnSkill(name) or removeSkill(name) end,
    }
end

Pages.items = { title = "Items", items = {
    { label = "Runes", page = "runes" },
} }
for _, item in ipairs(ITEMS) do
    Pages.items.items[#Pages.items.items + 1] = { label = item.label, run = function() return giveItem(item) end }
end

Pages.runes = { title = "Runes", items = {
    { label = "All runes", run = function()
        local given = 0
        for _, rune in ipairs(RUNES) do
            if giveItem(rune):find("^Added") then given = given + 1 end
        end
        if given == 0 then return select(2, player()) and "Adding runes failed" or NOT_IN_GAME end
        return ("Added %d of %d runes"):format(given, #RUNES)
    end },
} }
for _, rune in ipairs(RUNES) do
    Pages.runes.items[#Pages.runes.items + 1] = { label = rune.label, run = function() return giveItem(rune) end }
end

Pages.world = { title = "World", items = {
    { label = "Time (1 hour steps)", value = clockLabel, adjust = shiftTime },
    switch("Freeze time", function() return S.frozen end, setTimeFrozen),
    { label = "Weather", value = function() return S.weather and WEATHER[S.weather] or "-" end, adjust = shiftWeather },
    { label = "Game speed", value = function() return fmt(S.speed) .. "x" end, adjust = shiftSpeed },
    { label = "Story chapter", value = chapterLabel, enterIgnored = true, adjust = shiftChapter },
} }

Pages.npcs = { title = "NPCs", items = {
    { label = "Kill hostile NPCs (loaded area)", run = killHostiles },
    { label = "Make loaded NPCs friendly", run = befriendAll },
} }

Pages.achievements = { title = "Achievements", hint = "Enter: unlock (permanent)   Backspace: back", items = {
    { label = "Unlock ALL achievements", run = unlockAll },
} }
for _, ach in ipairs(ACHIEVEMENTS) do
    Pages.achievements.items[#Pages.achievements.items + 1] = {
        label = ach.label,
        run = function() return unlockOne(ach) end,
    }
end

-- ------------------------------------------------------------------------------------- UI --
local UI_KEY = "__g1rcm_ui"
local OFFSCREEN = -100000
local ROWS = math.max(4, math.floor(tonumber(Config.rows) or 14))
local W = math.max(360, tonumber(Config.width) or 480)
local ROW_H, TITLE_H, FOOTER_H, PAD = 30, 46, 64, 18
local H = TITLE_H + 8 + ROWS * ROW_H + FOOTER_H

local COLOR = {
    panel     = { R = 0.012, G = 0.010, B = 0.008, A = 0.93 },
    titleBar  = { R = 0.080, G = 0.050, B = 0.015, A = 1.0 },
    highlight = { R = 0.550, G = 0.360, B = 0.070, A = 0.55 },
    title     = { R = 0.900, G = 0.720, B = 0.330, A = 1.0 },
    text      = { R = 0.860, G = 0.830, B = 0.760, A = 1.0 },
    value     = { R = 0.950, G = 0.800, B = 0.420, A = 1.0 },
    muted     = { R = 0.520, G = 0.490, B = 0.430, A = 1.0 },
}

local function teardownUI()
    local old = rawget(_G, UI_KEY)
    if old and isValid(old.widget) then try(function() old.widget:RemoveFromParent() end) end
    rawset(_G, UI_KEY, nil)
end
teardownUI() -- hot reload: never keep a widget built by an older copy of this file

local function setVisibility(obj, value) try(function() obj.Visibility = value end) end

local function toText(s)
    local ktl = lib("/Script/Engine.Default__KismetTextLibrary")
    return ktl and try(function() return ktl:Conv_StringToText(s) end) or nil
end

local function findAsset(path)
    local obj = lib(path)
    if not obj and type(LoadAsset) == "function" then
        pcall(LoadAsset, path)
        obj = lib(path)
    end
    return obj
end
local function bodyFont() return findAsset("/Game/UI/Fonts/NotoSerif-Regular_Font.NotoSerif-Regular_Font") end
local function titleFont() return findAsset("/Game/UI/Fonts/Boucherie-Block_Font.Boucherie-Block_Font") end

local function place(slot, x, y, w, h)
    if not slot then return end
    try(function()
        slot:SetAutoSize(false)
        slot:SetPosition({ X = x, Y = y })
        slot:SetSize({ X = w, Y = h })
    end)
end

-- returns widget, canvas slot
local function addBox(tree, canvas, x, y, w, h, color)
    local cls = lib("/Script/UMG.Border")
    local b = cls and try(function() return StaticConstructObject(cls, tree) end)
    if not isValid(b) then return nil end
    try(function() b:Construct() end)
    try(function() b:SetBrushColor(color) end)
    setVisibility(b, 3)
    local slot = try(function() return canvas:AddChildToCanvas(b) end)
    place(slot, x, y, w, h)
    return b, slot
end

-- justify: 0 left, 1 center, 2 right
local function addText(tree, canvas, x, y, w, h, color, font, size, justify)
    local cls = lib("/Script/UMG.TextBlock")
    local tb = cls and try(function() return StaticConstructObject(cls, tree) end)
    if not isValid(tb) then return nil end
    try(function() tb:Construct() end)
    -- Font.TypefaceFontName is an FName, a plain Lua string does not survive the struct write
    local typeface = UEHelpers and try(function() return UEHelpers.FindOrAddFName("Default") end)
    if isValid(font) and typeface then
        try(function()
            tb.Font = {
                FontObject = font, TypefaceFontName = typeface, Size = size,
                LetterSpacing = 0, SkewAmount = 0, bForceMonospaced = false, MonospacedWidth = 0,
            }
        end)
    end
    try(function() tb.ColorAndOpacity = { SpecifiedColor = color, ColorUseRule = 0 } end)
    if justify and justify ~= 0 then try(function() tb.Justification = justify end) end
    setVisibility(tb, 3)
    local slot = try(function() return canvas:AddChildToCanvas(tb) end)
    place(slot, x, y, w, h)
    return tb
end

local function controllerKey(pc)
    return tostring(try(function() return pc:GetAddress() end)) .. "|" .. tostring(try(function() return pc:GetFullName() end))
end

local function ensureUI()
    local pc = controller()
    if not pc then return nil end
    local ui = rawget(_G, UI_KEY)
    if ui and isValid(ui.widget) and isValid(ui.panelSlot) and ui.pcKey == controllerKey(pc) then return ui end
    teardownUI() -- a new controller means a new world: the old widget is gone from the viewport

    local wlib = lib("/Script/UMG.Default__WidgetBlueprintLibrary")
    local uwC, cpC = lib("/Script/UMG.UserWidget"), lib("/Script/UMG.CanvasPanel")
    if not (wlib and uwC and cpC) then log("UI: UMG classes not found"); return nil end

    local widget = try(function() return wlib:Create(pc, uwC, pc) end)
    local tree = isValid(widget) and try(function() return widget.WidgetTree end)
    if not isValid(tree) then log("UI: could not create the overlay widget"); return nil end

    local root = try(function() return StaticConstructObject(cpC, tree) end)
    if not isValid(root) then log("UI: root canvas failed"); return nil end
    setVisibility(root, 4)
    try(function() tree.RootWidget = root end)

    -- the whole menu lives in one canvas that is parked off-screen while the menu is closed
    local panel = try(function() return StaticConstructObject(cpC, tree) end)
    if not isValid(panel) then log("UI: panel canvas failed"); return nil end
    setVisibility(panel, 3) -- HitTestInvisible: the menu never takes a mouse click from the game
    local panelSlot = try(function() return root:AddChildToCanvas(panel) end)
    if not isValid(panelSlot) then log("UI: panel slot failed"); return nil end
    place(panelSlot, OFFSCREEN, OFFSCREEN, W, H)

    ui = { widget = widget, panelSlot = panelSlot, pcKey = controllerKey(pc), rows = {}, shown = {} }
    local font = bodyFont()

    addBox(tree, panel, 0, 0, W, H, COLOR.panel)
    addBox(tree, panel, 0, 0, W, TITLE_H, COLOR.titleBar)
    ui.title = addText(tree, panel, PAD, 7, W - 2 * PAD - 90, TITLE_H, COLOR.title, titleFont() or font, 22, 0)
    ui.counter = addText(tree, panel, W - PAD - 90, 13, 90, TITLE_H, COLOR.muted, font, 14, 2)
    ui.highlight, ui.highlightSlot = addBox(tree, panel, 6, OFFSCREEN, W - 12, ROW_H, COLOR.highlight)

    local valueW = 170
    for i = 1, ROWS do
        local y = TITLE_H + 8 + (i - 1) * ROW_H + 3
        ui.rows[i] = {
            label = addText(tree, panel, PAD, y, W - 2 * PAD - valueW, ROW_H, COLOR.text, font, 16, 0),
            value = addText(tree, panel, W - PAD - valueW, y, valueW, ROW_H, COLOR.value, font, 16, 2),
        }
    end

    local footerY = TITLE_H + 8 + ROWS * ROW_H + 8
    ui.status = addText(tree, panel, PAD, footerY, W - 2 * PAD, 24, COLOR.value, font, 14, 0)
    ui.hint = addText(tree, panel, PAD, footerY + 26, W - 2 * PAD, 24, COLOR.muted, font, 13, 0)

    setVisibility(widget, 4)
    local added = try(function() widget:AddToViewport(25000); return true end)
    dbg("UI built, AddToViewport ok=" .. tostring(added))
    rawset(_G, UI_KEY, ui)
    return ui
end

-- SetText only when the text of that block actually changed
local function setText(ui, key, tb, s)
    if not isValid(tb) then return end
    if s == nil or s == "" then s = " " end -- a bare space blanks a line, "" does not
    if ui.shown[key] == s then return end
    local t = toText(s)
    if t and pcall(function() tb:SetText(t) end) then ui.shown[key] = s end
end

local function currentFrame() return S.stack[#S.stack] end

local function itemHint(page, item)
    if page.hint then return page.hint end
    if not item then return "" end
    if item.page then return "Enter: open   Backspace: " .. (#S.stack > 1 and "back" or "close") end
    if item.set then return "Enter: on / off   Backspace: back" end
    if item.adjust then return "Left / Right: change   Backspace: back" end
    return "Enter: run   Backspace: back"
end

local function render()
    local ui = ensureUI()
    if not ui then return false end
    local frame = currentFrame()
    local page = Pages[frame.page]
    local items = page.items

    frame.sel = math.max(1, math.min(#items, frame.sel))
    if frame.sel < frame.top then frame.top = frame.sel end
    if frame.sel > frame.top + ROWS - 1 then frame.top = frame.sel - ROWS + 1 end

    setText(ui, "title", ui.title, page.title)
    setText(ui, "counter", ui.counter, #items > ROWS and (frame.sel .. " / " .. #items) or "")
    for i = 1, ROWS do
        local item = items[frame.top + i - 1]
        local label, value = "", ""
        if item then
            label = item.label
            if item.value then
                -- values are read from the game once per page visit / action, not on every
                -- cursor move: reading them (guild tags, attributes) is what costs frame time
                local idx = frame.top + i - 1
                frame.values = frame.values or {}
                if frame.values[idx] == nil then frame.values[idx] = tostring(try(item.value) or "") end
                value = frame.values[idx]
            end
            if item.page and value == "" then value = ">" end
        end
        setText(ui, "label" .. i, ui.rows[i].label, label)
        setText(ui, "value" .. i, ui.rows[i].value, value)
    end
    if isValid(ui.highlightSlot) then
        local y = TITLE_H + 8 + (frame.sel - frame.top) * ROW_H
        try(function() ui.highlightSlot:SetPosition({ X = 6, Y = y }) end)
    end
    setText(ui, "status", ui.status, S.status)
    setText(ui, "hint", ui.hint, itemHint(page, items[frame.sel]))
    try(function() ui.panelSlot:SetPosition({ X = tonumber(Config.x) or 60, Y = tonumber(Config.y) or 140 }) end)
    return true
end

local function closeMenu()
    S.open = false
    local ui = rawget(_G, UI_KEY)
    if ui and isValid(ui.panelSlot) then
        try(function() ui.panelSlot:SetPosition({ X = OFFSCREEN, Y = OFFSCREEN }) end)
    end
end

local function openMenu()
    if #S.stack == 0 then S.stack[1] = { page = "main", sel = 1, top = 1 } end
    S.status = ""
    for _, f in ipairs(S.stack) do f.values = nil end
    S.open = render()
    if not S.open then log("menu could not be shown (no player controller yet?)") end
end

-- ---------------------------------------------------------------------------------- input --
local function runItem(item, dir)
    local fn
    if item.set then
        if dir ~= 0 then return end
        fn = function() return item.set(not item.get()) end
    elseif item.run then
        if dir ~= 0 then return end
        fn = item.run
    elseif item.adjust then
        if dir == 0 and item.enterIgnored then S.status = "Use Left / Right to change this"; return end
        fn = function() return item.adjust(dir == 0 and 1 or dir) end
    else
        return
    end
    local ok, msg = pcall(fn)
    S.status = ok and tostring(msg or "") or "Error, see UE4SS.log"
    if not ok then log("cheat failed: " .. tostring(msg)) end
end

local function handle(action)
    if action == "toggle" then
        if S.open then closeMenu() else openMenu() end
        return
    end
    if not S.open then return end
    if action ~= "select" then unlockAllArmed = false end -- moving away cancels the confirmation

    local frame = currentFrame()
    local items = Pages[frame.page].items
    local item = items[frame.sel]

    if action == "up" then
        frame.sel = frame.sel > 1 and frame.sel - 1 or #items
    elseif action == "down" then
        frame.sel = frame.sel < #items and frame.sel + 1 or 1
    elseif action == "back" then
        if #S.stack <= 1 then closeMenu(); return end
        S.stack[#S.stack] = nil
        S.status = ""
    elseif action == "select" and item and item.page then
        S.stack[#S.stack + 1] = { page = item.page, sel = 1, top = 1 }
        S.status = ""
    elseif item then
        runItem(item, action == "left" and -1 or action == "right" and 1 or 0)
    end
    if action ~= "up" and action ~= "down" then
        for _, f in ipairs(S.stack) do f.values = nil end -- something may have changed: re-read
    end
    render()
end

-- Keybinds are registered once (UE4SS keeps them across a hot reload) and dispatch through a _G
-- trampoline, so a reloaded copy of this file takes over without binding every key twice.
rawset(_G, "__g1rcm_handle", handle)

if not rawget(_G, "__g1rcm_bound") then
    local Key, RegisterKeyBind = rawget(_G, "Key"), rawget(_G, "RegisterKeyBind")
    local bound, missing = {}, {}
    local function bind(names, action)
        for _, name in ipairs(type(names) == "table" and names or { names }) do
            local code = Key and Key[name]
            local ok = code and type(RegisterKeyBind) == "function" and pcall(RegisterKeyBind, code, function()
                -- only the toggle key does anything while the menu is closed
                if action ~= "toggle" and not S.open then return end
                inGameThread(function()
                    local f = rawget(_G, "__g1rcm_handle")
                    if f then f(action) end
                end)
            end)
            if ok then bound[#bound + 1] = name else missing[#missing + 1] = tostring(name) end
        end
    end
    bind(Config.toggleKeys, "toggle")
    bind(Config.upKeys, "up")
    bind(Config.downKeys, "down")
    bind(Config.leftKeys, "left")
    bind(Config.rightKeys, "right")
    bind(Config.selectKeys, "select")
    bind(Config.backKeys, "back")
    rawset(_G, "__g1rcm_bound", true)
    if #missing > 0 then log("unknown key name(s) in config.lua: " .. table.concat(missing, ", ")) end
    if #bound == 0 then log("ERROR: no key could be bound") end
end

-- ----------------------------------------------------------------------------- life cycle --
-- a map load destroys the world the widget belongs to: close the menu and rebuild on next open
local RegisterLoadMapPreHook = rawget(_G, "RegisterLoadMapPreHook")
if type(RegisterLoadMapPreHook) == "function" and not rawget(_G, "__g1rcm_mapHook") then
    local ok = pcall(RegisterLoadMapPreHook, function()
        S.open = false
        teardownUI()
        objCache, attrCache = {}, { key = nil, sets = {} }
    end)
    if ok then rawset(_G, "__g1rcm_mapHook", true) end
end

if not rawget(_G, "__g1rcm_loop") then
    rawset(_G, "__g1rcm_loop", true)
    gameLoop(250, function()
        if S.god or S.mana or S.stamina or S.breath then return keepFullTick end
        return nil
    end)
end

log(("Loaded %s: toggle key %s"):format(VERSION, table.concat(
    type(Config.toggleKeys) == "table" and Config.toggleKeys or { tostring(Config.toggleKeys) }, ", ")))
