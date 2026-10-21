-- Run from the addon directory with Lua 5.1: lua tests/cooldowns.lua
-- Exercise the real tracker, combat-log callbacks, options and profile routing.
local modulePath = arg[1] or "modules/cooldowns.lua"
local cases = 0
local function noop() end
local function equal(actual, expected, context)
    assert(actual == expected, context .. ": expected " .. tostring(expected) ..
        ", got " .. tostring(actual))
end
local function loadFile(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a"):gsub("^\239\187\191", "")
    file:close()
    assert(loadstring(source, "@" .. path))()
end
local function frame()
    return {
        scripts = {},
        RegisterEvent = noop, UnregisterAllEvents = noop,
        SetScript = function(self, name, handler) self.scripts[name] = handler end,
        GetScript = function(self, name) return self.scripts[name] end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetTexture = noop, SetText = noop,
    }
end
local function setup(withSpectate, unitClass, saved, unitRace)
    unitClass = unitClass or "PALADIN"
    unitRace = unitRace or "Human"
    local unitGUIDs = {player = "GUID-player", party1 = "GUID-party1", arena1 = "GUID-arena1"}
    local clock = {now = 100}
    LibStub = nil
    strmatch = string.match
    strjoin = function(separator, ...) return table.concat({...}, separator) end
    wipe = function(t) for key in pairs(t) do t[key] = nil end end
    -- Sorting concatenates disjoint bytes; combat events below use zero flags.
    bit = {bor = function(a, b) return a + b end,
        lshift = function(a, b) return a * 2^b end, band = function() return 0 end}
    COMBATLOG_OBJECT_REACTION_HOSTILE = 64
    GetAccountExpansionLevel = function() return 2 end
    GetRealmName = function() return "TestRealm" end
    UnitName = function(unit) return unit or "Tester" end
    UnitGUID = function(unit) return unitGUIDs[unit] end
    UnitClass = function() return unitClass, unitClass end
    UnitRace = function() return unitRace, unitRace end
    UnitFactionGroup = function() return "Alliance" end
    UnitBuff = noop
    GetTime = function() return clock.now end
    IsInInstance = function() return true, "arena" end
    GetSpellInfo = function(id)
        return id == 31821 and "Aura Mastery" or ("Spell " .. id), "", "icon"
    end
    geterrorhandler = function() return error end
    DEFAULT_CHAT_FRAME = {AddMessage = error}
    LOCALIZED_CLASS_NAMES_MALE = setmetatable({}, {__index = function(_, key) return key end})
    CLASS_BUTTONS = {}
    CreateFrame = frame
    loadFile("libs/LibStub/LibStub.lua")
    loadFile("libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
    loadFile("libs/AceDB-3.0/AceDB-3.0.lua")
    loadFile("libs/LibFunctional-1.0/functional.lua")
    local modules = {}
    local addon = {
        SetDefaultModulePrototype = function(self, prototype) self.prototype = prototype end,
        SetDefaultModuleLibraries = noop, SetDefaultModuleState = noop,
        GetModule = function(_, name) return modules[name] end,
        NewModule = function(self, name)
            local module = setmetatable({GetName = function() return name end,
                RegisterEvent = noop, RegisterMessage = noop}, {__index = self.prototype})
            modules[name] = module
            return module
        end,
    }
    LibStub:NewLibrary("AceAddon-3.0", 1).NewAddon = function() return addon end
    local locale = setmetatable({}, {__index = function(_, key) return key end})
    LibStub:NewLibrary("AceLocale-3.0", 1).GetLocale = function() return locale end
    LibStub:NewLibrary("LibSharedMedia-3.0", 1)
    LibStub:NewLibrary("LibSpecDetection-1.0", 1)
    LibStub:NewLibrary("AceGUI-3.0", 1).WidgetVersions = {}
    loadFile("GladiusEx.lua")
    loadFile("Data_WotLK.lua")
    loadFile("libs/LibCooldownTracker-1.0/cooldowns_spelldata.lua")
    for _, class in ipairs({"deathknight", "druid", "hunter", "mage", "paladin",
        "priest", "rogue", "shaman", "warlock", "warrior", "racials", "items"}) do
        loadFile("libs/LibCooldownTracker-1.0/cooldowns_wotlk_" .. class .. ".lua")
    end
    loadFile("libs/LibCooldownTracker-1.0/library.lua")
    local tracker = LibStub("LibCooldownTracker-1.0")
    if withSpectate then
        modules.Spectate = {UnitBuff = UnitBuff, UnitClass = UnitClass,
            UnitRace = UnitRace, UnitFactionGroup = UnitFactionGroup,
            GetUnitCooldownInfo = function(unit, spellid)
                return tracker:GetUnitCooldownInfo(unit, spellid)
            end}
    end
    loadFile(modulePath)
    addon.UpdateFrames = noop
    addon.IsSpectating = function() return false end
    addon.GetUnitIdByGUID = function(_, guid) return guid:sub(6) end
    addon.GetGrowSimplePositions = function() return {} end
    addon.GetPositions = function() return {} end
    addon.db = {base = {}}
    addon.buttons = {party1 = {specID = 65}, arena1 = {specID = 65}}
    addon.dbi = LibStub("AceDB-3.0"):New(saved or {}, nil, "Default")
    local module = modules.Cooldowns
    module:OnInitialize()
    module.IsUnitEnabled = function() return true end
    module:OnEnable()
    for _, unit in ipairs({"party1", "arena1"}) do
        local icon = frame()
        icon.icon, icon.count = frame(), frame()
        module:GetGroupState(unit, 1).frame = {icon}
    end
    local function cast(unit, spellid)
        tracker.frame:GetScript("OnEvent")(tracker.frame, "COMBAT_LOG_EVENT_UNFILTERED",
            GetTime(), "SPELL_CAST_SUCCESS", UnitGUID(unit), unit, 0,
            UnitGUID(unit), unit, 0, spellid)
    end
    return addon, module, tracker, cast, unitGUIDs, clock
end
local function test(name, run)
    run()
    cases = cases + 1
    print("ok - " .. name)
end

for _, withSpectate in ipairs({false, true}) do
    local path = withSpectate and "spectator adapter" or "direct tracker"
    test(path .. ": Aura Mastery is selectable and appears after detection", function()
        local addon, module, tracker, cast = setup(withSpectate)
        local spell = assert(tracker:GetCooldownData(31821), "Aura Mastery registered")
        equal(spell.cooldown, 120, "Wrath cooldown")
        equal(spell.duration, 6, "Wrath duration")
        module:GetGroupDB("party1", 1).cooldownsSpells = {[31821] = true}
        for _, spec in ipairs({65, 66, 70}) do
            addon.buttons.party1.specID = spec
            local options = module:GetOptions("party")
            local paladin = options.group1.args.cooldowns.args.PALADIN.args
            local toggle = paladin.spec65.args.spell31821
            assert(toggle and toggle.get({arg = 31821}), "Aura Mastery option enabled")
            equal(paladin.spec66.args.spell31821, nil, "Holy talent not duplicated under Protection")
            equal(paladin.spec70.args.spell31821, nil, "Holy talent not duplicated under Retribution")
            module:UpdateGroupIcons("party1", 1)
            local icon = module:GetGroupState("party1", 1).frame[1]
            equal(icon.spellid, nil, "undetected talent hidden")
            cast("party1", 31821)
            equal(icon.shown, true, "detected talent shown by combat callback")
            equal(icon.spellid, 31821, "Aura Mastery icon")
            equal(icon.tracked.cooldown_end, 220, "cooldown starts on cast")
            equal(icon.tracked.used_end, 106, "active duration starts on cast")
            equal(tracker:GetUnitCooldownInfo("arena1", 31821), nil, "other unit not detected")
            toggle.set({arg = 31821}, false)
            module:UpdateGroupIcons("party1", 1)
            equal(icon.shown, false, "disabled talent hidden")
            equal(module:GetGroupDB("arena", 1).cooldownsSpells[31821], true, "arena selection isolated")
            toggle.set({arg = 31821}, true)
            tracker.tracked_players = {}
            icon.spellid = nil
        end
    end)
    test(path .. ": baseline spells and the detection opt-out still display", function()
        local _, module = setup(withSpectate)
        local db = module:GetGroupDB("party1", 1)
        db.cooldownsSpells = {[642] = true}
        module:UpdateGroupIcons("party1", 1)
        local icon = module:GetGroupState("party1", 1).frame[1]
        equal(icon.spellid, 642, "baseline visible before use")
        db.cooldownsSpells = {[31821] = true}
        db.cooldownsHideTalentsUntilDetected = false
        module:UpdateGroupIcons("party1", 1)
        equal(icon.spellid, 31821, "talent visible when detection filter disabled")
    end)
    test(path .. ": pet cooldowns appear after detection on either side", function()
        local addon, module, _, cast, unitGUIDs = setup(withSpectate, "WARLOCK")
        for _, unit in ipairs({"party1", "arena1"}) do
            local pet = unit == "party1" and "partypet1" or "arenapet1"
            unitGUIDs[pet] = "GUID-" .. pet
            addon.buttons[unit].specID = 267
            module:GetGroupDB(unit, 1).cooldownsSpells = {[19244] = true}
            local icon = module:GetGroupState(unit, 1).frame[1]
            module:UpdateGroupIcons(unit, 1)
            equal(icon.shown, false, "unseen pet ability hidden")
            cast(pet, 19244)
            equal(icon.shown, true, "detected pet ability visible")
            equal(icon.spellid, 19244, "Spell Lock icon")
            equal(icon.tracked.cooldown_end, 124, "pet cooldown tracked")
        end
    end)
    test(path .. ": Gnaw belongs to the death knight and tracks the actual ghoul cast", function()
        local addon, module, tracker, cast, unitGUIDs, clock = setup(withSpectate, "DEATHKNIGHT")
        for _, unit in ipairs({"party1", "arena1"}) do
            local pet = unit == "party1" and "partypet1" or "arenapet1"
            unitGUIDs[pet] = "GUID-" .. pet
            addon.buttons[unit].specID = 252
            local db = module:GetGroupDB(unit, 1)
            local options = module:GetOptions(unit).group1.args.cooldowns.args.DEATHKNIGHT.args
            assert(options.pets.args.spell47481, "Gnaw selectable under Pet")
            equal(options.base.args.spell47481, nil, "Gnaw not baseline")
            equal(options.spec252.args.spell47481, nil, "Gnaw not a player talent")
            db.cooldownsSpells = {[47481] = true}
            module:UpdateGroupIcons(unit, 1)
            local icon = module:GetGroupState(unit, 1).frame[1]
            equal(icon.shown, false, "unknown pet ability hidden")
            cast(pet, 47481)
            equal(icon.shown, true, "ghoul cast updates owner icon")
            equal(icon.spellid, 47481, "Gnaw icon")
            equal(icon.tracked.cooldown_end, clock.now + 60, "sixty-second cooldown")
            equal(icon.tracked.used_end, clock.now + 3, "three-second stun")
            equal(tracker:GetCooldownInfoByGUID(UnitGUID(unit), 47481), icon.tracked,
                "cooldown belongs to owner GUID")
            equal(tracker:GetCooldownInfoByGUID(UnitGUID(pet), 47481), nil,
                "cooldown not stranded on pet GUID")
        end
        local previous = tracker:GetUnitCooldownInfo("arena1", 47481)
        unitGUIDs.arenapet1 = "GUID-new-ghoul"
        clock.now = 125
        cast("arenapet1", 47481)
        local current = tracker:GetUnitCooldownInfo("arena1", 47481)
        assert(current ~= previous, "new ghoul has independent cooldown state")
        equal(current.cooldown_end, 185, "new ghoul cast starts a fresh cooldown")
        equal(tracker:GetUnitCooldownInfo("party1", 47481).cooldown_end, 160,
            "another death knight is unaffected")
    end)
end

test("unresolved pet casts are not assigned to an unrelated death knight", function()
    local _, _, tracker, cast, unitGUIDs = setup(false, "DEATHKNIGHT")
    unitGUIDs.unknownpet = "GUID-unknown-ghoul"
    cast("unknownpet", 47481)
    cast("missingpet", 47481)
    equal(tracker:GetUnitCooldownInfo("party1", 47481), nil, "party not misidentified")
    equal(tracker:GetUnitCooldownInfo("arena1", 47481), nil, "enemy not misidentified")
end)

local expectedGroups = dofile("tests/fixtures/cooldown_groups.lua")
local expectedRacials = dofile("tests/fixtures/racial_cooldowns.lua")
for _, withSpectate in ipairs({false, true}) do
    local path = withSpectate and "spectator adapter" or "direct tracker"
    test(path .. ": Undead test frames show racial cooldowns in both groups", function()
        local addon, module = setup(withSpectate)
        addon.IsTesting = function(_, unit) return unit == "party1" or unit == "arena1" end
        addon.testing = {party1 = {unitClass = "PRIEST", specID = 256, unitRace = "Undead"},
            arena1 = {unitClass = "MAGE", specID = 64, unitRace = "Undead"}}
        for _, unit in ipairs({"party1", "arena1"}) do
            for group = 1, 2 do
                module:GetGroupDB(unit, group).cooldownsSpells = {[7744] = true}
                module:GetGroupState(unit, group).frame = {frame()}
                local icon = module:GetGroupState(unit, group).frame[1]
                icon.icon, icon.count = frame(), frame()
            end
            for _, race in ipairs({"Undead", "Scourge"}) do
                addon.testing[unit].unitRace = race
                module:Test(unit)
                for group = 1, 2 do
                    local icon = module:GetGroupState(unit, group).frame[1]
                    equal(icon.shown, true, race .. " racial visible in group " .. group)
                    equal(icon.spellid, 7744, "Will of the Forsaken icon")
                end
            end
            addon.testing[unit].unitRace = "Human"
            module:Test(unit)
            for group = 1, 2 do
                equal(module:GetGroupState(unit, group).frame[1].shown, false,
                    "changing the test race hides the Undead racial")
            end
        end
    end)
    test(path .. ": every Wrath racial and class variant tracks on both sides", function()
        for id, expected in pairs(expectedRacials) do
            local addon, module, tracker, cast = setup(withSpectate, "PALADIN", nil, expected[1])
            local spell = assert(tracker:GetCooldownData(id), "racial registered: " .. id)
            equal(spell.race, expected[1], "racial token")
            equal(spell.cooldown, expected[3], "racial base cooldown")
            equal(spell.duration, expected[4] or nil, "racial duration")
            for _, unit in ipairs({"party1", "arena1"}) do
                local groups = module:GetOptions(unit).group1.args.cooldowns.args
                local group = assert(groups[expected[1]], "racial option group")
                equal(group.name, addon.Data.raceNamesByID[expected[2]], "readable race label")
                assert(group.args["spell" .. id], "racial selectable")
                module:GetGroupDB(unit, 1).cooldownsSpells = {[id] = true}
                for _, variant in ipairs(expected[5]) do
                    equal(addon.Data.raceIDsByRacialTraits[variant], expected[2], "race discovery for variant")
                    equal(addon.Data.raceNamesByID[expected[1]], expected[2], "native race token lookup")
                    if variant ~= id then equal(group.args["spell" .. variant], nil, "no duplicate option") end
                    tracker.tracked_players = {}
                    cast(unit, variant)
                    local icon = module:GetGroupState(unit, 1).frame[1]
                    equal(icon.shown, true, "racial cast visible")
                    equal(icon.spellid, id, "canonical racial icon for " .. variant)
                    equal(icon.tracked.cooldown_end, 100 + expected[3], "racial cooldown end")
                    equal(icon.tracked.used_end, expected[4] and 100 + expected[4] or nil, "racial duration end")
                end
            end
        end
    end)
    test(path .. ": only the unit's own racials appear in its cooldown icons", function()
        local _, module, tracker = setup(withSpectate, "PALADIN", nil, "Human")
        local racials = {}
        for id in pairs(expectedRacials) do racials[id] = true end
        for _, unit in ipairs({"party1", "arena1"}) do
            module:GetGroupDB(unit, 1).cooldownsSpells = racials
            module:UpdateGroupIcons(unit, 1)
            local icon = module:GetGroupState(unit, 1).frame[1]
            equal(icon.spellid, 59752, "human racial selected")
        end
        for id, spell in tracker:IterateCooldowns("PALADIN", 65, "Human") do
            if spell.race then equal(spell.race, "Human", "foreign racial excluded: " .. id) end
        end
    end)
end

test("racial CC breaks preserve reciprocal PvP trinket lockouts", function()
    for _, data in ipairs({{7744, 42292, 45, "Scourge"}, {42292, 7744, 45, "Scourge"},
        {59752, 42292, 120, "Human"}, {42292, 59752, 120, "Human"}}) do
        local _, _, tracker, cast = setup(false, "PALADIN", nil, data[4])
        cast("party1", data[1])
        equal(tracker:GetUnitCooldownInfo("party1", data[1]).cooldown_end, 220, "used ability full cooldown")
        equal(tracker:GetUnitCooldownInfo("party1", data[2]).cooldown_end, 100 + data[3], "shared lockout")
        equal(tracker:GetUnitCooldownInfo("arena1", data[2]), nil, "another unit unaffected")
    end
    local _, _, tracker, cast, _, clock = setup(false, "PALADIN", nil, "Scourge")
    cast("party1", 7744)
    clock.now = 150
    cast("party1", 42292)
    equal(tracker:GetUnitCooldownInfo("party1", 7744).cooldown_end, 220, "short shared lockout cannot shorten full cooldown")
end)

test("spectator race API returns localized labels and native tokens for racial filtering", function()
    local addon, module = setup(false)
    local source = assert(io.open("modules/spectate.lua", "rb"))
    local body = assert(source:read("*a"):match("(function Spectate%.UnitRace%(unit%).-\nend)"))
    source:close()
    local spectating = true
    local adapter = {units = {}, IsSpectating = function() return spectating end,
        IsArenaUnit = function(_, unit) return unit == "arena1" end}
    local environment = {GladiusEx = addon, Spectate = adapter,
        L = setmetatable({}, {__index = function(_, key) return "Localized " .. key end}),
        UnitRace = function() return "Native race", "NativeToken" end}
    setfenv(assert(loadstring(body, "@modules/spectate.lua:UnitRace")), environment)()
    for _, expected in pairs(expectedRacials) do
        adapter.units.party1 = {raceID = expected[2]}
        local label, token = adapter.UnitRace("party1")
        equal(label, "Localized " .. addon.Data.raceNamesByID[expected[2]], "localized race label")
        equal(token, expected[1], "native token required by tracker")
    end
    local label, token = adapter.UnitRace("arena1")
    equal(label, "Native race", "arena unit delegates to native API")
    equal(token, "NativeToken", "native arena token preserved")
    spectating = false
    label, token = adapter.UnitRace("party1")
    equal(token, "NativeToken", "ordinary party delegates to native API")
    addon.Data.raceNamesByID.Scourge = nil -- Older expansion data lacks this reverse alias.
    equal(module:GetOptions("party").group1.args.cooldowns.args.Scourge.name, "Undead",
        "racial options keep a readable label with older race tables")
end)

local expectedPets = dofile("tests/fixtures/pet_cooldowns.lua")
for _, withSpectate in ipairs({false, true}) do
    local path = withSpectate and "spectator adapter" or "direct tracker"
    test(path .. ": pet ranks match original Wrath data and update their owner's frame", function()
        for _, class in ipairs({"DEATHKNIGHT", "HUNTER", "MAGE", "PRIEST", "SHAMAN", "WARLOCK"}) do
            local addon, module, tracker, cast, unitGUIDs = setup(withSpectate, class)
            for id, expected in pairs(expectedPets) do
                if expected[1] == class then
                    local spell = assert(tracker:GetCooldownData(id), "pet spell " .. id)
                    equal(spell.pet, true, "pet classification for " .. id)
                    equal(spell.cooldown, expected[2], "base cooldown for " .. id)
                    equal(spell.duration, expected[3] or nil, "duration for " .. id)
                    for _, unit in ipairs({"party1", "arena1"}) do
                        local pet = unit == "party1" and "partypet1" or "arenapet1"
                        unitGUIDs[pet] = "GUID-" .. pet
                        addon.buttons[unit].specID = spell.specID and spell.specID[1] or nil
                        module:GetGroupDB(unit, 1).cooldownsSpells = {[id] = true}
                        for _, rank in ipairs(expected[4]) do
                            tracker.tracked_players = {}
                            module:UpdateGroupIcons(unit, 1)
                            local icon = module:GetGroupState(unit, 1).frame[1]
                            equal(icon.shown, false, "pet ability hidden before detection")
                            cast(pet, rank)
                            equal(icon.shown, true, "pet rank detected: " .. rank)
                            equal(icon.spellid, id, "canonical icon for pet rank " .. rank)
                            equal(icon.tracked.cooldown_end, 100 + expected[2], "pet cooldown end")
                            equal(icon.tracked.used_end, expected[3] and 100 + expected[3] or nil,
                                "pet active duration")
                            equal(tracker:GetUnitCooldownInfo(unit, id), icon.tracked, "owner stores state")
                            equal(tracker:GetCooldownInfoByGUID(UnitGUID(pet), id), nil,
                                "state not stranded on pet GUID")
                        end
                    end
                end
            end
        end
    end)
    test(path .. ": Spirit Wolves without a pet token resolve through summon events", function()
        local addon, module, tracker = setup(withSpectate, "SHAMAN")
        local onEvent = tracker.frame:GetScript("OnEvent")
        local function combat(event, source, dest, spell)
            onEvent(tracker.frame, "COMBAT_LOG_EVENT_UNFILTERED", GetTime(), event,
                source, "Source", 0, dest, "Destination", 0, spell)
        end
        for _, unit in ipairs({"party1", "arena1"}) do
            addon.buttons[unit].specID = 263
            local wolf = "GUID-wolf-" .. unit
            combat("SPELL_SUMMON", UnitGUID(unit), wolf, 51533)
            for _, id in ipairs({58861, 58875}) do
                module:GetGroupDB(unit, 1).cooldownsSpells = {[id] = true}
                combat("SPELL_CAST_SUCCESS", wolf, wolf, id)
                local icon = module:GetGroupState(unit, 1).frame[1]
                equal(icon.shown, true, "guardian cast updates owner frame")
                equal(icon.spellid, id, "guardian ability icon")
                assert(tracker:GetUnitCooldownInfo(unit, id), "guardian state stored on owner")
            end
            -- A summon created by another summon still belongs to the same player.
            combat("SPELL_SUMMON", wolf, wolf .. "-child", 51533)
            combat("SPELL_CAST_SUCCESS", wolf .. "-child", wolf, 58861)
            assert(tracker:GetUnitCooldownInfo(unit, 58861), "nested summon ownership")
        end
        onEvent(tracker.frame, "PLAYER_ENTERING_WORLD")
        combat("SPELL_CAST_SUCCESS", "GUID-wolf-arena1", "GUID-wolf-arena1", 58861)
        equal(tracker:GetUnitCooldownInfo("arena1", 58861), nil, "old arena summon cache cleared")
    end)
end

test("pet audit excludes basic attacks and passive procs from cooldown tracking", function()
    local _, _, tracker = setup(false, "HUNTER")
    for _, id in ipairs({17253, 50871, 66491, 66492, 66493, 66494, 66495}) do
        equal(tracker:GetCooldownData(id), nil, "not a hunter pet cooldown: " .. id)
    end
end)

for _, class in ipairs({"DEATHKNIGHT", "DRUID", "HUNTER", "MAGE", "PALADIN",
    "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"}) do
    test(class .. ": catalog options match Wrath baseline, talent and pet groups", function()
        local _, module, tracker = setup(false, class)
        for _, side in ipairs({"party", "arena"}) do
            local options = module:GetOptions(side).group1.args.cooldowns.args[class].args
            local seen = {}
            for group, category in pairs(options) do
                local ordered = {}
                for _, toggle in pairs(category.args) do
                    local expected = assert(expectedGroups[toggle.arg], "audited spell " .. toggle.arg)
                    equal(expected[1], class, "class for " .. toggle.arg)
                    equal(expected[2], group, "group for " .. toggle.arg)
                    assert(not seen[toggle.arg], "spell appears in only one group")
                    seen[toggle.arg] = true
                    ordered[#ordered + 1] = toggle
                end
                table.sort(ordered, function(a, b) return a.order < b.order end)
                for i = 2, #ordered do
                    local a, b = tracker:GetCooldownData(ordered[i - 1].arg), tracker:GetCooldownData(ordered[i].arg)
                    assert(a.name <= b.name, "full spell names sorted alphabetically")
                end
                if group ~= "base" then assert(options.base.order < category.order, "baseline first") end
            end
            for id, expected in pairs(expectedGroups) do
                if expected[1] == class then
                    local spell = assert(tracker:GetCooldownData(id), "catalog spell " .. id)
                    if not spell.cooldown or spell.cooldown < 600 or spell.usable_in_arena then
                        assert(seen[id], "spell available in options: " .. id)
                    end
                end
            end
        end
    end)
end

test("Preparation remains selectable and tracked despite its ten-minute cooldown", function()
    local addon, module, _, cast = setup(false, "ROGUE")
    addon.buttons.party1.specID = 261
    local options = module:GetOptions("party").group1.args.cooldowns.args.ROGUE.args
    assert(options.spec261.args.spell14185, "Preparation option")
    module:GetGroupDB("party1", 1).cooldownsSpells = {[14185] = true}
    cast("party1", 14185)
    local icon = module:GetGroupState("party1", 1).frame[1]
    equal(icon.spellid, 14185, "Preparation visible after use")
    equal(icon.tracked.cooldown_end, 700, "Preparation cooldown tracked")
    equal(module:GetOptions("party").group1.args.cooldowns.args.WARLOCK.args.base.args.spell1122,
        nil, "arena-ineligible long cooldown still excluded")
end)

local function serialize(value)
    if type(value) == "table" then
        local entries = {}
        for key, entry in pairs(value) do
            entries[#entries + 1] = "[" .. serialize(key) .. "]=" .. serialize(entry)
        end
        return "{" .. table.concat(entries, ",") .. "}"
    end
    if type(value) == "string" then return string.format("%q", value) end
    return tostring(value)
end
test("cooldown selections survive SavedVariables reload and remain isolated by side", function()
    local addon, module = setup(false)
    local options = module:GetOptions("party").group1.args.cooldowns.args.PALADIN.args
    options.spec65.args.spell31821.set({arg = 31821}, false)
    options.spec66.args.spell64205.set({arg = 64205}, true)
    local aceDB = LibStub("AceDB-3.0")
    aceDB.frame:GetScript("OnEvent")(aceDB.frame, "PLAYER_LOGOUT")
    local saved = assert(loadstring("return " .. serialize(addon.dbi.sv)))()
    addon, module = setup(false, "PALADIN", saved)
    equal(module:GetGroupDB("party", 1).cooldownsSpells[31821], false, "disabled default persists")
    equal(module:GetGroupDB("party", 1).cooldownsSpells[64205], true, "enabled addition persists")
    equal(module:GetGroupDB("arena", 1).cooldownsSpells[31821], true, "arena default unchanged")
    equal(module:GetGroupDB("arena", 1).cooldownsSpells[64205], nil, "arena addition unchanged")
end)

test("old spell selections migrate without restoring disabled cooldowns", function()
    local saved = {namespaces = {party_Cooldowns = {profiles = {Default = {
        groups = {group_1 = {cooldownsSpells = {
            [19647] = false, [51490] = true, [48141] = true,
        }}},
    }}}}}
    local addon, module = setup(false, "WARLOCK", saved)
    local spells = module:GetGroupDB("party", 1).cooldownsSpells
    equal(spells[19244], false, "disabled Spell Lock rank preserved")
    equal(spells[59159], true, "Thunderstorm rank preserved")
    equal(spells[48181], true, "Haunt selection preserved")
    equal(spells[19647], nil, "old rank selection removed")
    equal(module:GetGroupDB("arena", 1).cooldownsSpells[19244], true, "other side unchanged")
    addon.dbi:SetProfile("Other")
    spells = module:GetGroupDB("party", 1).cooldownsSpells
    spells[19647], spells[19244] = true, false
    addon.dbi:SetProfile("Default")
    addon.dbi:SetProfile("Other")
    equal(module:GetGroupDB("party", 1).cooldownsSpells[19244], false, "canonical disable wins")
end)

test("Haunt and Thunderstorm casts track their canonical icons at every rank", function()
    for _, data in ipairs({{"WARLOCK", 265, 48181, {48181, 59161, 59163, 59164}},
        {"SHAMAN", 262, 59159, {51490, 59156, 59158, 59159}}}) do
        local addon, module, tracker, cast = setup(false, data[1])
        addon.buttons.party1.specID = data[2]
        module:GetGroupDB("party1", 1).cooldownsSpells = {[data[3]] = true}
        for _, rank in ipairs(data[4]) do
            tracker.tracked_players = {}
            cast("party1", rank)
            local icon = module:GetGroupState("party1", 1).frame[1]
            equal(icon.shown, true, "rank cast detected")
            equal(icon.spellid, data[3], "canonical icon for rank " .. rank)
            equal(icon.tracked.detected, true, "canonical tracked state")
        end
    end
end)

print("Passed " .. cases .. " Cooldowns tests")
