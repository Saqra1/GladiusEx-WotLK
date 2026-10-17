-- Run from the addon directory with Lua 5.1: lua tests/classicon_auras.lua
-- Optional first argument: another classicon.lua to check for regressions.
-- Use the real module, profile routing, AceDB and SavedVariables round trips.
local modulePath = arg[1] or "modules/classicon.lua"
local cases = 0

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

local function setup(saved)
    LibStub = nil
    strmatch = string.match
    wipe = function(t) for key in pairs(t) do t[key] = nil end end
    GetRealmName = function() return "TestRealm" end
    UnitName = function() return "Tester" end
    UnitClass = function() return "Mage", "MAGE" end
    UnitRace = function() return "Human", "HUMAN" end
    UnitFactionGroup = function() return "Alliance" end
    GetTime = function() return 100 end
    GetSpellInfo = function(id)
        if type(id) == "number" then return "Spell " .. id end
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
            return aura.name, "", "icon", 1, nil, 10, 110, "player", nil, nil, aura.id
        end
    end
    loadFile("libs/LibStub/LibStub.lua")
    loadFile("libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
    loadFile("libs/AceDB-3.0/AceDB-3.0.lua")
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
    LibStub:NewLibrary("AceGUI-3.0", 1).WidgetVersions = {}
    loadFile("GladiusEx.lua")
    loadFile(modulePath)
    addon.UpdateFrames = noop
    addon.dbi = LibStub("AceDB-3.0"):New(saved or {}, nil, "Default")
    local module = modules.ClassIcon
    module:OnInitialize()
    module.IsUnitEnabled = function() return true end
    state.addon, state.module = addon, module
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
    return setup(assert(loadstring("return " .. saved))())
end

local function remove(module, options, name)
    options.auraList.args[name].args.delete.func({"auraList", name, "delete"})
    equal(options.auraList.args[name], nil, "deleted option removed immediately")
end

local function add(options, name, priority)
    local args = options.auraList.args.newAura.args
    args.name.set({}, name)
    args.priority.set({}, priority)
    args.add.func({})
end

local function test(name, run)
    run()
    cases = cases + 1
    print("ok - " .. name)
end

for _, unit in ipairs({"arena", "party"}) do
    local other = unit == "arena" and "party" or "arena"
    test(unit .. ": default deletion survives reloads and a fresh session", function()
        local state = setup()
        local module = state.module
        local options = module:GetOptions(unit)
        local name = state.addon:SafeGetSpellName(118)
        local default = module.db[unit].classIconAuras[name]
        remove(module, options, name)
        equal(module:GetImportantAura(unit, name) and true or false, false, "deleted lookup")
        equal(module.db[other].classIconAuras[name], default, "other configuration unchanged")
        for session = 1, 3 do
            state = reload(state)
            module = state.module
            equal(module:GetOptions(unit).auraList.args[name], nil, "deleted option after reload")
            equal(module:GetImportantAura(unit, name), false, "saved deletion after reload")
            equal(module.db[other].classIconAuras[name], default, "other configuration after reload")
            equal(module.defaults_arena.classIconAuras[name], default, "arena defaults unchanged")
            equal(module.defaults_party.classIconAuras[name], default, "party defaults unchanged")
        end
    end)

    test(unit .. ": custom deletion and re-adding default/custom auras persist", function()
        local state = setup()
        local module, name = state.module, "Custom Aura"
        local defaultName = state.addon:SafeGetSpellName(642)
        local options = module:GetOptions(unit)
        add(options, name, 4.2)
        equal(module:GetImportantAura(unit, name), 4.2, "new custom priority")
        remove(module, options, name)
        remove(module, options, defaultName)
        state = reload(state)
        module, options = state.module, state.module:GetOptions(unit)
        equal(options.auraList.args[name], nil, "custom deletion after reload")
        equal(options.auraList.args[defaultName], nil, "default deletion after reload")
        add(options, name, 3.1)
        add(options, defaultName, 6.3)
        state = reload(state)
        module, options = state.module, state.module:GetOptions(unit)
        equal(module:GetImportantAura(unit, name), 3.1, "custom re-add after reload")
        equal(module:GetImportantAura(unit, defaultName), 6.3, "default re-add after reload")
        assert(options.auraList.args[name] and options.auraList.args[defaultName])
    end)

    test(unit .. ": priority edits preserve deletions and unrelated settings", function()
        local state = setup()
        local module = state.module
        local options = module:GetOptions(unit)
        local name, deleted = state.addon:SafeGetSpellName(118), state.addon:SafeGetSpellName(642)
        module.db[unit].classIconMode = "PORTRAIT2D"
        module.db[unit].classIconGlossColor.r = 0.25
        remove(module, options, deleted)
        options.auraList.args[name].set({"auraList", name, "priority"}, 4.7)
        local zero = state.addon:SafeGetSpellName(1715)
        assert(module:GetOptions(unit).auraList.args[zero], "zero priority remains editable")
        state = reload(state)
        module = state.module
        equal(module:GetImportantAura(unit, name), 4.7, "edited priority after reload")
        equal(module:GetOptions(unit).auraList.args[deleted], nil, "deletion retained")
        equal(module.db[unit].classIconMode, "PORTRAIT2D", "icon mode retained")
        equal(module.db[unit].classIconGlossColor.r, 0.25, "color retained")
        equal(module.db[other].classIconGlossColor.r, 1, "other configuration color unchanged")
    end)

    test(unit .. ": renaming a default keeps its old name deleted", function()
        local state = setup()
        local module = state.module
        local options = module:GetOptions(unit)
        local name = state.addon:SafeGetSpellName(118)
        local priority = module:GetImportantAura(unit, name)
        options.auraList.args[name].set({"auraList", name, "name"}, "Renamed Aura")
        state = reload(state)
        module, options = state.module, state.module:GetOptions(unit)
        equal(options.auraList.args[name], nil, "old name remains deleted")
        equal(module:GetImportantAura(unit, "Renamed Aura"), priority, "renamed priority")
        options.auraList.args["Renamed Aura"].set({"auraList", "Renamed Aura", "name"}, "Renamed Aura")
        equal(module:GetImportantAura(unit, "Renamed Aura"), priority, "unchanged name preserves aura")
    end)

    test(unit .. ": deleted buffs and debuffs are ignored in combat scans", function()
        local state = setup()
        local module = state.module
        local options = module:GetOptions(unit)
        local removed, kept = state.addon:SafeGetSpellName(118), "Custom Aura"
        remove(module, options, removed)
        add(options, kept, 3)
        state = reload(state)
        module = state.module
        local combatUnit = unit == "arena" and "arena1" or "party1"
        for _, filter in ipairs({"HARMFUL", "HELPFUL"}) do
            state.auras[filter] = {{name = removed, id = 118}, {name = kept, id = 99999}}
            equal(module:ScanAuras(combatUnit), kept, "scan skips deleted aura in " .. filter)
            state.auras[filter][2] = nil
            equal(module:ScanAuras(combatUnit), nil, "no tracked aura in " .. filter)
            equal(module:handle_aura(combatUnit, removed, 0), false, "single aura lookup ignores deletion")
            state.auras[filter] = {}
        end
    end)
end

test("profile switches keep arena and party edits isolated", function()
    local state = setup()
    local module = state.module
    local arenaName, partyName = state.addon:SafeGetSpellName(118), state.addon:SafeGetSpellName(642)
    local arenaDefault, partyDefault = module:GetImportantAura("arena", arenaName), module:GetImportantAura("party", partyName)
    remove(module, module:GetOptions("arena"), arenaName)
    add(module:GetOptions("party"), "Profile Aura", 2)
    state.addon.dbi:SetProfile("Other")
    equal(module:GetImportantAura("arena", arenaName), arenaDefault, "fresh profile arena default")
    equal(module:GetImportantAura("party", "Profile Aura"), nil, "custom aura absent in other profile")
    remove(module, module:GetOptions("party"), partyName)
    add(module:GetOptions("arena"), "Other Aura", 4)
    state.addon.dbi:SetProfile("Default")
    equal(module:GetOptions("arena").auraList.args[arenaName], nil, "original arena deletion retained")
    equal(module:GetImportantAura("party", partyName), partyDefault, "other profile party deletion isolated")
    equal(module:GetImportantAura("party", "Profile Aura"), 2, "original custom aura retained")
    equal(module:GetImportantAura("arena", "Other Aura"), nil, "other profile custom aura isolated")
    state = reload(state)
    module = state.module
    equal(module:GetOptions("arena").auraList.args[arenaName], nil, "profile deletion after reload")
    state.addon.dbi:SetProfile("Other")
    equal(module:GetImportantAura("arena", arenaName), arenaDefault, "other profile arena after reload")
    equal(module:GetOptions("party").auraList.args[partyName], nil, "other profile deletion after reload")
    equal(module:GetImportantAura("arena", "Other Aura"), 4, "other profile custom after reload")
end)

print("Passed " .. cases .. " Important Auras tests")
