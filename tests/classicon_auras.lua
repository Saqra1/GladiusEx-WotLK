-- Run from the addon directory with Lua 5.1: lua tests/classicon_auras.lua
-- Optional first argument: another classicon.lua to check for regressions.
-- Use the real module, profile routing, AceDB and SavedVariables round trips.
local modulePath = arg[1] or "modules/classicon.lua"
local cases = 0

-- Names checked against the 3.3.5a Spell.dbc, including separate aura/rank IDs.
local newBuffs = {
    [55233] = "Vampiric Blood", [49222] = "Bone Shield",
    [61336] = "Survival Instincts", [50334] = "Berserk",
    [31821] = "Aura Mastery", [64205] = "Divine Sacrifice",
    [70940] = "Divine Guardian", [20216] = "Divine Favor",
    [47788] = "Guardian Spirit", [16166] = "Elemental Mastery",
    [47241] = "Metamorphosis", [55694] = "Enraged Regeneration",
    [20230] = "Retaliation", [20594] = "Stoneform",
    [20572] = "Blood Fury", [26297] = "Berserking",
}
local newDebuffs = {
    [12798] = "Revenge Stun", [50518] = "Ravage", [12494] = "Frostbite",
    [55080] = "Shattered Barrier", [58373] = "Glyph of Hamstring",
}
local auraAliases = {[53562] = "Ravage", [64701] = "Elemental Mastery"}
-- Verified in Spell.dbc: horror/disarm, sleep/DoT, backlash/DoT, instant/haste.
local sameNameEffects = {
    {name = "Psychic Horror", filter = "HARMFUL", ids = {64044, 64058}},
    {name = "Wyvern Sting", filter = "HARMFUL", ids = {49012, 49010, 19386, 24131}},
    {name = "Unstable Affliction", filter = "HARMFUL", ids = {31117, 47843, 30108, 43523}},
    {name = "Elemental Mastery", filter = "HELPFUL", ids = {16166, 64701}},
}
local effectNames = {}
for _, effect in ipairs(sameNameEffects) do
    for _, id in ipairs(effect.ids) do effectNames[id] = effect.name end
end
for _, id in ipairs({24132, 24133, 27068, 49011}) do effectNames[id] = "Wyvern Sting" end

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

local function setup(saved, spellModules)
    LibStub = nil
    strmatch = string.match
    wipe = function(t) for key in pairs(t) do t[key] = nil end end
    GetRealmName = function() return "TestRealm" end
    UnitName = function() return "Tester" end
    UnitClass = function() return "Mage", "MAGE" end
    UnitRace = function() return "Human", "HUMAN" end
    UnitFactionGroup = function() return "Alliance" end
    bit = {band = function(a, b)
        local value, bitValue = 0, 1
        while a > 0 and b > 0 do
            if a % 2 == 1 and b % 2 == 1 then value = value + bitValue end
            a, b, bitValue = math.floor(a / 2), math.floor(b / 2), bitValue * 2
        end
        return value
    end}
    GetTime = function() return 100 end
    GetSpellInfo = function(id)
        if type(id) == "number" then
            if id == 999999 then return nil end -- Unknown/custom server ID.
            return newBuffs[id] or newDebuffs[id] or auraAliases[id] or effectNames[id] or "Spell " .. id
        end
    end
    geterrorhandler = function() return error end
    CreateFrame = function()
        return {
            scripts = {},
            RegisterEvent = function() end,
            SetScript = function(self, name, handler) self.scripts[name] = handler end,
            GetScript = function(self, name) return self.scripts[name] end,
        }
    end
    local state = {auras = {HARMFUL = {}, HELPFUL = {}}}
    UnitAura = function(unit, index, filter)
        local aura = state.auras[filter][index]
        if aura then
            return aura.name, "", aura.icon or "icon:" .. tostring(aura.id), 1, nil,
                aura.duration or 10, aura.expires or 110, "player", nil, nil, aura.id
        end
    end
    loadFile("libs/LibStub/LibStub.lua")
    loadFile("libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
    loadFile("libs/AceDB-3.0/AceDB-3.0.lua")
    loadFile("libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua")
    loadFile("libs/LibFunctional-1.0/functional.lua")

    local modules = {}
    local function noop() end
    local addon = {
        SetDefaultModulePrototype = function(self, prototype) self.prototype = prototype end,
        SetDefaultModuleLibraries = noop,
        SetDefaultModuleState = noop,
        GetModule = function(_, name) return modules[name] end,
        NewModule = function(self, name)
            local module = setmetatable({GetName = function() return name end},
                {__index = self.prototype})
            modules[name] = module
            return module
        end,
    }
    LibStub:NewLibrary("AceAddon-3.0", 1).NewAddon = function() return addon end
    local locale = setmetatable({}, {__index = function(_, key) return key end})
    LibStub:NewLibrary("AceLocale-3.0", 1).GetLocale = function() return locale end
    LibStub:NewLibrary("LibSharedMedia-3.0", 1)
    LibStub:NewLibrary("LibSpecDetection-1.0", 1)
    LibStub:NewLibrary("LibDispellable-1.0", 1)
    -- An optional completion widget must not get the chance to erase exact IDs.
    LibStub:NewLibrary("AceGUI-3.0", 1).WidgetVersions = {Aura_EditBox = 1}
    loadFile("GladiusEx.lua")
    loadFile("SpellRules.lua")
    loadFile(modulePath)
    addon.UpdateFrames = noop
    addon.dbi = LibStub("AceDB-3.0"):New(saved or {}, nil, "Default")
    local module = modules.ClassIcon
    module:OnInitialize()
    module.IsUnitEnabled = function() return true end
    if spellModules then
        addon.GetGrowSimplePositions = function() return {TOPLEFT = "Top left"} end
        addon.GetPositions = function() return {TOPLEFT = "Top left"} end
        loadFile("modules/auras.lua")
        loadFile("modules/alerts.lua")
        for _, name in ipairs({"Auras", "Alerts"}) do
            modules[name]:OnInitialize()
            modules[name].IsUnitEnabled = function() return true end
        end
    end
    state.addon, state.module = addon, module
    state.modules, state.spellModules = modules, spellModules
    return state
end

-- Serialize plain SavedVariables data, then load it into a fresh addon/library
-- instance so no metatables or Lua table identities survive the reload.
local function serialize(value)
    if type(value) == "table" then
        local entries = {}
        for key, entry in pairs(value) do
            entries[#entries + 1] = "[" .. serialize(key) .. "]=" .. serialize(entry)
        end
        return "{" .. table.concat(entries, ",") .. "}"
    elseif type(value) == "string" then
        return string.format("%q", value)
    else
        assert(type(value) == "number" or type(value) == "boolean")
        return tostring(value)
    end
end

local function reload(state)
    local aceDB = LibStub("AceDB-3.0")
    aceDB.frame:GetScript("OnEvent")(aceDB.frame, "PLAYER_LOGOUT")
    local saved = serialize(state.addon.dbi.sv)
    return setup(assert(loadstring("return " .. saved))(), state.spellModules)
end

local function optionKey(aura)
    return type(aura) .. ":" .. tostring(aura)
end

local function validateOptions(options)
    LibStub("AceConfigRegistry-3.0"):ValidateOptionsTable({
        type = "group", name = "ClassIcon", args = options,
    }, "ClassIcon")
end

local function remove(module, options, name)
    options.auraList.args[optionKey(name)].args.delete.func({"auraList", optionKey(name), "delete"})
    equal(options.auraList.args[optionKey(name)], nil, "deleted option removed immediately")
end

local function add(options, name, priority)
    local args = options.auraList.args.newAura.args
    args.name.set({}, tostring(name))
    args.priority.set({}, priority)
    if tonumber(name) then args.checkSpellID.set({}, true) end
    args.add.func({})
end

local function test(name, run)
    run()
    cases = cases + 1
    print("ok - " .. name)
end

if arg[2] == "harness" then
    return {setup = setup, reload = reload, equal = equal, validateOptions = validateOptions}
end

for _, unit in ipairs({"arena", "party"}) do
    local other = unit == "arena" and "party" or "arena"
    test(unit .. ": missing Wrath auras are enabled and detected after reload", function()
        local state = reload(setup())
        local module = state.module
        local combatUnit = unit == "arena" and "arena1" or "party1"
        local options = module:GetOptions(unit)
        for filter, auras in pairs({HELPFUL = newBuffs, HARMFUL = newDebuffs}) do
            for id, name in pairs(auras) do
                assert(module:GetImportantAura(unit, id) > 0, name .. " enabled")
                assert(options.auraList.args[optionKey(id)], name .. " editable")
                state.auras[filter] = {{name = name, id = id}}
                equal(module:ScanAuras(combatUnit), name, name .. " detected")
            end
            state.auras[filter] = {}
        end
        for id, name in pairs(auraAliases) do
            local filter = id == 53562 and "HARMFUL" or "HELPFUL"
            state.auras[filter] = {{name = GetSpellInfo(id), id = id}}
            equal(module:ScanAuras(combatUnit), name, "another aura/rank ID detected")
            state.auras[filter] = {}
        end
        state.auras.HELPFUL = {{name = "Aura Mastery", id = 31821}}
        state.auras.HARMFUL = {{name = GetSpellInfo(118), id = 118}}
        equal(module:ScanAuras(combatUnit), GetSpellInfo(118), "crowd control outranks new buffs")
    end)

    test(unit .. ": new defaults preserve saved deletions and custom priorities", function()
        local state = setup()
        local module = state.module
        local options = module:GetOptions(unit)
        remove(module, options, 31821)
        options.auraList.args[optionKey(47788)].args.priority.set({}, 9.8)
        remove(module, options, 642)
        for session = 1, 3 do
            state = reload(state)
            module = state.module
            equal(module:GetImportantAura(unit, 31821), false, "new default deletion retained")
            equal(module:GetImportantAura(unit, 47788), 9.8, "custom priority retained")
            equal(module:GetImportantAura(unit, 642), false, "existing deletion retained")
            equal(module:GetImportantAura(other, 31821), module.defaults_arena.classIconAuras[31821], "other list retains default")
            assert(module:GetImportantAura(unit, 55233) > 0, "unspecified new default enabled")
        end
    end)

    test(unit .. ": default deletion survives reloads and a fresh session", function()
        local state = setup()
        local module = state.module
        local options = module:GetOptions(unit)
        local name = 118
        local default = module.db[unit].classIconAuras[name]
        remove(module, options, name)
        equal(module:GetImportantAura(unit, name) and true or false, false, "deleted lookup")
        equal(module.db[other].classIconAuras[name], default, "other configuration unchanged")
        for session = 1, 3 do
            state = reload(state)
            module = state.module
            equal(module:GetOptions(unit).auraList.args[optionKey(name)], nil, "deleted option after reload")
            equal(module:GetImportantAura(unit, name), false, "saved deletion after reload")
            equal(module.db[other].classIconAuras[name], default, "other configuration after reload")
            equal(module.defaults_arena.classIconAuras[name], default, "arena defaults unchanged")
            equal(module.defaults_party.classIconAuras[name], default, "party defaults unchanged")
        end
    end)

    test(unit .. ": custom deletion and re-adding default/custom auras persist", function()
        local state = setup()
        local module, name = state.module, "Custom Aura"
        local defaultName = 642
        local options = module:GetOptions(unit)
        add(options, name, 4.2)
        equal(module:GetImportantAura(unit, name), 4.2, "new custom priority")
        remove(module, options, name)
        remove(module, options, defaultName)
        state = reload(state)
        module, options = state.module, state.module:GetOptions(unit)
        equal(options.auraList.args[optionKey(name)], nil, "custom deletion after reload")
        equal(options.auraList.args[optionKey(defaultName)], nil, "default deletion after reload")
        add(options, name, 3.1)
        add(options, defaultName, 6.3)
        state = reload(state)
        module, options = state.module, state.module:GetOptions(unit)
        equal(module:GetImportantAura(unit, name), 3.1, "custom re-add after reload")
        equal(module:GetImportantAura(unit, defaultName), 6.3, "default re-add after reload")
        assert(options.auraList.args[optionKey(name)] and options.auraList.args[optionKey(defaultName)])
    end)

    test(unit .. ": priority edits preserve deletions and unrelated settings", function()
        local state = setup()
        local module = state.module
        local options = module:GetOptions(unit)
        local name, deleted = 118, 642
        module.db[unit].classIconMode = "PORTRAIT2D"
        module.db[unit].classIconGlossColor.r = 0.25
        remove(module, options, deleted)
        options.auraList.args[optionKey(name)].args.priority.set({}, 4.7)
        local zero = 1715
        assert(module:GetOptions(unit).auraList.args[optionKey(zero)], "zero priority remains editable")
        state = reload(state)
        module = state.module
        equal(module:GetImportantAura(unit, name), 4.7, "edited priority after reload")
        equal(module:GetOptions(unit).auraList.args[optionKey(deleted)], nil, "deletion retained")
        equal(module.db[unit].classIconMode, "PORTRAIT2D", "icon mode retained")
        equal(module.db[unit].classIconGlossColor.r, 0.25, "color retained")
        equal(module.db[other].classIconGlossColor.r, 1, "other configuration color unchanged")
    end)

    test(unit .. ": renaming a default keeps its old name deleted", function()
        local state = setup()
        local module = state.module
        local options = module:GetOptions(unit)
        local name = 118
        local priority = module:GetImportantAura(unit, name)
        options.auraList.args[optionKey(name)].args.name.set({}, "Renamed Aura")
        state = reload(state)
        module, options = state.module, state.module:GetOptions(unit)
        equal(options.auraList.args[optionKey(name)], nil, "old name remains deleted")
        equal(module:GetImportantAura(unit, "Renamed Aura"), priority, "renamed priority")
        options.auraList.args[optionKey("Renamed Aura")].args.name.set({}, "Renamed Aura")
        equal(module:GetImportantAura(unit, "Renamed Aura"), priority, "unchanged name preserves aura")
    end)

    test(unit .. ": deleted buffs and debuffs are ignored in combat scans", function()
        local state = setup()
        local module = state.module
        local options = module:GetOptions(unit)
        local removed, kept = 118, "Custom Aura"
        remove(module, options, removed)
        add(options, kept, 3)
        state = reload(state)
        module = state.module
        local combatUnit = unit == "arena" and "arena1" or "party1"
        for _, filter in ipairs({"HARMFUL", "HELPFUL"}) do
            state.auras[filter] = {{name = GetSpellInfo(removed), id = 118}, {name = kept, id = 99999}}
            equal(module:ScanAuras(combatUnit), kept, "scan skips deleted aura in " .. filter)
            state.auras[filter][2] = nil
            equal(module:ScanAuras(combatUnit), nil, "no tracked aura in " .. filter)
            equal(module:handle_aura(combatUnit, removed, 0), false, "single aura lookup ignores deletion")
            state.auras[filter] = {}
        end
    end)

    test(unit .. ": exact IDs distinguish effects and override shared names", function()
        local state = setup()
        local module, options = state.module, state.module:GetOptions(unit)
        local combatUnit = unit .. "1"
        for _, effect in ipairs(sameNameEffects) do
            add(options, effect.name, 8)
            add(options, tostring(effect.ids[1]), 3)
            add(options, tostring(effect.ids[2]), 0)
        end
        state = reload(state)
        module = state.module
        for _, effect in ipairs(sameNameEffects) do
            for index, id in ipairs(effect.ids) do
                local priority = index == 1 and 3 or index == 2 and 0 or module.defaults_arena.classIconAuras[id] or 8
                equal(module:GetImportantAura(combatUnit, effect.name, id), priority, "exact ID before name")
                state.auras[effect.filter] = {{name = effect.name, id = id}}
                equal(module:ScanAuras(combatUnit), priority > 0 and effect.name or nil, "scan " .. id)
                local accepted, actual = module:handle_aura(combatUnit, effect.name, 0, id)
                equal(accepted, priority > 0, "single aura uses same precedence")
                equal(actual, priority > 0 and priority or nil, "single aura priority")
            end
            state.auras[effect.filter] = {
                {name = effect.name, id = effect.ids[2], expires = 999},
                {name = effect.name, id = effect.ids[1], expires = 111},
            }
            local _, icon, _, expires = module:ScanAuras(combatUnit)
            equal(icon, "icon:" .. effect.ids[1], "same-name effect selects exact icon")
            equal(expires, 111, "same-name effect selects exact expiration")
            -- A lowered ID priority must also lose to a different aura.
            add(module:GetOptions(unit), "Competing Aura", 5)
            state.auras[effect.filter] = {
                {name = effect.name, id = effect.ids[1]},
                {name = "Competing Aura", id = 99998},
            }
            equal(module:ScanAuras(combatUnit), "Competing Aura", "ID priority determines winner")
            state.auras[effect.filter] = {{name = effect.name}} -- No spell ID available.
            equal(module:ScanAuras(combatUnit), effect.name, "missing ID retains name fallback")
            equal(module:GetImportantAura(other, effect.ids[1]), module.defaults_arena.classIconAuras[effect.ids[1]], "other group keeps defaults")
            state.auras[effect.filter] = {}
        end
        validateOptions(module:GetOptions(unit))
    end)

    test(unit .. ": adding, editing, renaming and deleting IDs survive reloads", function()
        local state = setup()
        local module, options = state.module, state.module:GetOptions(unit)
        local name = "Psychic Horror"
        add(options, name, 8)
        local namePriority = module:GetImportantAura(unit, name)
        add(options, " 064044 ", 4.2)
        local group = options.auraList.args[optionKey(64044)]
        equal(group.name, "Psychic Horror (64044)", "readable ID label")
        equal(group.args.spellID.get({}), "64044", "input retains numeric ID")
        equal(options.auraList.args.newAura.args.name.get({}), "", "add clears input")
        equal(group.args.name.dialogControl, nil, "ID editing bypasses name completion")
        equal(options.auraList.args.newAura.args.name.dialogControl, nil, "ID creation bypasses name completion")
        validateOptions(options)
        for session = 1, 3 do
            state = reload(state)
            module, options = state.module, state.module:GetOptions(unit)
            equal(module:GetImportantAura(unit, 64044), 4.2, "numeric SavedVariables key retained")
            equal(module:GetImportantAura(unit, "64044"), nil, "no numeric string key created")
            equal(module:GetImportantAura(unit, name), namePriority, "name customization preserved")
            equal(module:GetImportantAura(other, 64044), 9, "other group unchanged")
            validateOptions(options)
        end
        group = options.auraList.args[optionKey(64044)]
        group.args.priority.set({}, 6.4)
        group.args.spellID.set({}, "064044")
        equal(module:GetImportantAura(unit, 64044), 6.4, "normalized unchanged ID is not deleted")
        state = reload(state)
        module, options = state.module, state.module:GetOptions(unit)
        equal(module:GetImportantAura(unit, 64044), 6.4, "priority edit after reload")
        options.auraList.args[optionKey(64044)].args.spellID.set({}, "64058")
        equal(options.auraList.args[optionKey(64044)], nil, "renamed ID removed immediately")
        state = reload(state)
        module, options = state.module, state.module:GetOptions(unit)
        equal(module:GetImportantAura(unit, 64044), false, "old ID deletion persisted")
        equal(module:GetImportantAura(unit, name, 64044), namePriority, "deleted ID falls back to name")
        equal(module:GetImportantAura(unit, 64058), 6.4, "new ID keeps priority")
        remove(module, options, 64058)
        for session = 1, 3 do
            state = reload(state)
            module, options = state.module, state.module:GetOptions(unit)
            equal(options.auraList.args[optionKey(64058)], nil, "deleted ID absent after reload")
            equal(module:GetImportantAura(unit, 64058), false, "ID tombstone retained")
            equal(module:GetImportantAura(unit, name, 64058), namePriority, "deletion restores name rule")
        end
        add(options, "64058", 0)
        state = reload(state)
        module = state.module
        equal(module:GetImportantAura(unit, name, 64058), 0, "re-added zero overrides name after reload")
        equal(module:GetImportantAura(unit, name, 64044), namePriority, "other effect still matches name")
        assert(module:GetOptions(unit).auraList.args[optionKey(64058)], "zero ID remains editable")
    end)

    test(unit .. ": name rules can become exact IDs and return to names", function()
        local state = setup()
        local module, options = state.module, state.module:GetOptions(unit)
        local name, id, sibling = "Psychic Horror", 64044, 64058
        add(options, name, 6)
        local group = options.auraList.args[optionKey(name)]
        group.args.spellID.set({}, tostring(id))
        equal(group.args.checkSpellID.get({}), false, "ID entry alone keeps name matching")
        group.args.checkSpellID.set({}, true)
        state = reload(state)
        module, options = state.module, state.module:GetOptions(unit)
        equal(module:GetImportantAura(unit, name), false, "name moved to exact rule")
        equal(module:GetImportantAura(unit, name, id), 6, "exact ID enabled")
        equal(module:GetImportantAura(unit, name, sibling), false, "same-name sibling untracked")
        for _, filter in ipairs({"HARMFUL", "HELPFUL"}) do
            state.auras[filter] = {{name = name, id = sibling}}
            equal(module:ScanAuras(unit .. "1"), nil, "sibling ignored in " .. filter)
            state.auras[filter] = {{name = name, id = id}}
            equal(module:ScanAuras(unit .. "1"), name, "exact effect matched in " .. filter)
            state.auras[filter] = {}
        end
        options.auraList.args[optionKey(id)].args.checkSpellID.set({}, false)
        state = reload(state)
        module, options = state.module, state.module:GetOptions(unit)
        equal(module:GetImportantAura(unit, id), false, "old exact rule deleted")
        equal(module:GetImportantAura(unit, name, sibling), 6, "unchecked rule matches sibling")
        group = options.auraList.args[optionKey(name)]
        equal(group.args.spellID.get({}), tostring(id), "optional ID retained after unchecking/reload")
        equal(group.args.checkSpellID.get({}), false, "unchecked state persists")
    end)

    test(unit .. ": saved numeric and name keys coexist in valid settings", function()
        local state = setup()
        local auras = state.module.db[unit].classIconAuras
        auras[64044], auras["64044"], auras.newAura, auras.matching = 4, 2, 3, 6
        state = reload(state)
        local module, options = state.module, state.module:GetOptions(unit)
        validateOptions(options)
        for aura, priority in pairs({[64044] = 4, ["64044"] = 2, newAura = 3, matching = 6}) do
            local group = options.auraList.args[optionKey(aura)]
            assert(group, "saved rule has separate controls")
            equal(group.args.priority.get({}), priority, "saved rule editable")
            group.args.priority.set({}, priority + 1)
        end
        state = reload(state)
        module = state.module
        equal(module:GetImportantAura(unit, 64044), 5, "numeric rule edited")
        equal(module:GetImportantAura(unit, "64044"), 3, "legacy string key preserved")
        equal(module:GetImportantAura(unit, "newAura"), 4, "control-name collision preserved")
        equal(module:GetImportantAura(unit, "matching"), 7, "description-name collision preserved")
        remove(module, module:GetOptions(unit), "64044")
        state = reload(state)
        equal(state.module:GetImportantAura(unit, "64044"), false, "legacy string deletion persists")
        equal(state.module:GetImportantAura(unit, 64044), 5, "legacy string deletion keeps exact ID")
    end)

    test(unit .. ": invalid input is rejected and unknown IDs remain editable", function()
        local state = setup()
        local module, options = state.module, state.module:GetOptions(unit)
        local input = options.auraList.args.newAura.args
        for _, value in ipairs({"", "   ", "0", "-1", "64044.5", "1e999"}) do
            assert(input.name.validate({}, value) ~= true, "reject invalid aura: " .. value)
            input.name.set({}, value)
            assert(input.add.disabled(), "cannot add invalid aura")
            input.add.func({}) -- No mutation even if invoked while disabled.
        end
        assert(input.name.validate({}, "Custom Aura") == true, "unknown names remain supported")
        add(options, "999999", 2)
        local group = options.auraList.args[optionKey(999999)]
        equal(group.name, "999999 (999999)", "unknown ID has fallback label")
        for _, value in ipairs({"", "0", "-1", "1.5"}) do
            assert(group.args.name.validate({}, value) ~= true, "invalid edit rejected")
            group.args.name.set({}, value)
            equal(module:GetImportantAura(unit, 999999), 2, "invalid edit preserves original")
        end
        state = reload(state)
        equal(state.module:GetImportantAura(unit, 999999), 2, "unknown numeric ID persists")
        validateOptions(state.module:GetOptions(unit))
    end)
end

test("profile switches keep arena and party edits isolated", function()
    local state = setup()
    local module = state.module
    local arenaName, partyName = 118, 642
    local arenaDefault, partyDefault = module:GetImportantAura("arena", arenaName), module:GetImportantAura("party", partyName)
    remove(module, module:GetOptions("arena"), arenaName)
    add(module:GetOptions("party"), "Profile Aura", 2)
    state.addon.dbi:SetProfile("Other")
    equal(module:GetImportantAura("arena", arenaName), arenaDefault, "fresh profile arena default")
    equal(module:GetImportantAura("party", "Profile Aura"), nil, "custom aura absent in other profile")
    remove(module, module:GetOptions("party"), partyName)
    add(module:GetOptions("arena"), "Other Aura", 4)
    state.addon.dbi:SetProfile("Default")
    equal(module:GetOptions("arena").auraList.args[optionKey(arenaName)], nil, "original arena deletion retained")
    equal(module:GetImportantAura("party", partyName), partyDefault, "other profile party deletion isolated")
    equal(module:GetImportantAura("party", "Profile Aura"), 2, "original custom aura retained")
    equal(module:GetImportantAura("arena", "Other Aura"), nil, "other profile custom aura isolated")
    state = reload(state)
    module = state.module
    equal(module:GetOptions("arena").auraList.args[optionKey(arenaName)], nil, "profile deletion after reload")
    state.addon.dbi:SetProfile("Other")
    equal(module:GetImportantAura("arena", arenaName), arenaDefault, "other profile arena after reload")
    equal(module:GetOptions("party").auraList.args[optionKey(partyName)], nil, "other profile deletion after reload")
    equal(module:GetImportantAura("arena", "Other Aura"), 4, "other profile custom after reload")
end)

test("ID rules follow profile switches, copies and resets for both groups", function()
    local state = setup()
    local module = state.module
    add(module:GetOptions("arena"), "64044", 3)
    add(module:GetOptions("party"), "64044", 7)
    add(module:GetOptions("party"), "64058", 0)
    state.addon.dbi:SetProfile("Other")
    equal(module:GetImportantAura("arena", 64044), 9, "fresh arena profile has no ID rule")
    equal(module:GetImportantAura("party", 64044), 9, "fresh party profile has no ID rule")
    add(module:GetOptions("arena"), "64044", 8)
    add(module:GetOptions("party"), "64044", 1)
    state.addon.dbi:SetProfile("Default")
    equal(module:GetImportantAura("arena1", "Psychic Horror", 64044), 3, "original arena ID rule")
    equal(module:GetImportantAura("party1", "Psychic Horror", 64044), 7, "original party ID rule")
    equal(module:GetImportantAura("party1", "Psychic Horror", 64058), 0, "original party suppression")
    state.addon.dbi:SetProfile("Copy")
    state.addon.dbi:CopyProfile("Default")
    equal(module:GetImportantAura("arena", 64044), 3, "arena ID copied")
    equal(module:GetImportantAura("party", 64044), 7, "party ID copied")
    equal(module:GetImportantAura("party", 64058), 0, "zero ID copied")
    remove(module, module:GetOptions("party"), 64044)
    state = reload(state)
    module = state.module
    equal(module:GetImportantAura("party", 64044), false, "copied profile deletion persists")
    equal(module:GetImportantAura("arena", 64044), 3, "copy arena remains independent")
    state.addon.dbi:ResetProfile()
    equal(module:GetImportantAura("arena", 64044), 9, "reset restores arena ID default")
    equal(module:GetImportantAura("party", 64058), nil, "reset clears party ID rule")
    equal(module:GetImportantAura("party", "Psychic Horror", 64058), nil, "reset retains exact-only defaults")
    state = reload(state)
    module = state.module
    state.addon.dbi:SetProfile("Default")
    equal(module:GetImportantAura("arena", 64044), 3, "source arena survives copy/reset/reload")
    equal(module:GetImportantAura("party", 64044), 7, "source party survives copy/reset/reload")
    equal(module:GetImportantAura("party", 64058), 0, "source suppression survives copy/reset/reload")
    state.addon.dbi:SetProfile("Other")
    equal(module:GetImportantAura("arena", 64044), 8, "other arena profile remains distinct")
    equal(module:GetImportantAura("party", 64044), 1, "other party profile remains distinct")
    validateOptions(module:GetOptions("arena"))
    validateOptions(module:GetOptions("party"))
end)

print("Passed " .. cases .. " Important Auras tests")
