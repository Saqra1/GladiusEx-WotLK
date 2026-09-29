-- Run from the addon directory with Lua 5.1: lua tests/enemy_status.lua
-- Optional first argument: a different GladiusEx.lua to check for regressions.
-- Load the real core, status tag and health bar; mock only WoW/Ace and rendering.
local units, modules, messages = {}, {}, {}
local arenaActive = true
local inCombat = true
local function noop() end
local function data(unit) return units[unit] or {} end
UnitExists = function(unit) return data(unit).exists end
UnitGUID = function(unit) return data(unit).guid end
UnitName = function(unit) return data(unit).name end
UnitHealth = function(unit) return data(unit).health or 0 end
UnitHealthMax = function(unit) return data(unit).maxHealth or 0 end
UnitIsDeadOrGhost = function(unit) return data(unit).dead end
UnitIsConnected = function(unit) return data(unit).exists end
UnitClass = function() return "Rogue", "ROGUE" end
IsActiveBattlefieldArena = function() return arenaActive end
InCombatLockdown = function() return inCombat end
UNKNOWN = "Unknown"

local addon = {
    SetDefaultModulePrototype = noop,
    SetDefaultModuleLibraries = noop,
    SetDefaultModuleState = noop,
    GetModule = function(_, name) return modules[name] end,
    NewModule = function(_, name)
        local module = {RegisterEvent = noop, RegisterMessage = noop}
        modules[name] = module
        return module
    end,
}
local locale = setmetatable({}, {__index = function(_, key) return key end})
local libs = {
    ["AceAddon-3.0"] = {NewAddon = function() return addon end},
    ["AceLocale-3.0"] = {GetLocale = function() return locale end},
    ["LibFunctional-1.0"] = {},
    ["LibSharedMedia-3.0"] = {},
    ["LibSpecDetection-1.0"] = {},
}
LibStub = function(name) return assert(libs[name], name) end
local function loadAddonFile(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    -- WoW accepts the UTF-8 BOM already present in the addon's Lua files.
    source = source:gsub("^\239\187\191", "")
    assert(loadstring(source, "@" .. path))()
end
loadAddonFile(arg[1] or "GladiusEx.lua")
loadAddonFile("modules/tags.lua")
loadAddonFile("modules/healthbar.lua")
local tags, healthbar = modules.Tags, modules.HealthBar
local status = tags:GetBuiltinTags()["name:status"]

-- Keep the real event/state/GUID/ShowUnit/HideFrames and display functions.
addon.IsTesting = function() return false end
addon.CheckArenaSize = noop
addon.GetArenaSize = function() return 1 end
addon.UpdateAnchor = noop
addon.UpdateBackground = noop
addon.UpdateUnit = noop
addon.IterateModules = function() return function() end end
addon.HideUnit = noop
addon.arena_parent = {Hide = noop}
addon.party_parent = {Hide = noop}
addon.SendMessage = function(_, event, unit)
    messages[#messages + 1] = {event, unit}
end
addon.RefreshUnit = function(_, unit)
    healthbar:UpdateHealthEvent("refresh", unit)
    addon.buttons[unit].text = status(unit)
end

local function equal(actual, expected, context)
    assert(actual == expected, (context or "value") .. ": expected " ..
        tostring(expected) .. ", got " .. tostring(actual))
end

local function reset(known)
    units, messages = {}, {}
    guid_to_unitid = {}
    arenaActive = true
    inCombat = true
    addon.arena_size = 1
    addon.db = {base = {debug = false}}
    addon.buttons = {}
    healthbar.frame, healthbar.db = {}, {}
    for _, unit in ipairs({"arena1", "arena2", "party1"}) do
        addon.buttons[unit] = {
            SetAlpha = function(self, alpha) self.alpha = alpha end,
            IsShown = function() return true end,
        }
        healthbar.frame[unit] = {
            SetMinMaxValues = function(self, low, high) self.low, self.high = low, high end,
            SetValue = function(self, value) self.value = value end,
        }
        healthbar.db[unit] = {healthBarInverse = false}
        units[unit] = {exists = true, guid = unit .. "-guid", name = unit .. "name", health = 100, maxHealth = 100}
    end
    if known ~= false then
        addon:ARENA_OPPONENT_UPDATE("ARENA_OPPONENT_UPDATE", "arena1", "seen")
    else
        units.arena1 = {}
    end
end

local function availability(reason)
    addon:ARENA_OPPONENT_UPDATE("ARENA_OPPONENT_UPDATE", "arena1", reason)
end
local function died(guid)
    -- WoW 3.3.5a combat-log layout (no later hideCaster argument).
    addon:COMBAT_LOG_EVENT_UNFILTERED("COMBAT_LOG_EVENT_UNFILTERED", 1, "UNIT_DIED",
        "source-guid", "source", 0, guid or "arena1-guid", "arena1name", 0)
end
local function refresh()
    addon:UNIT_HEALTH("UNIT_HEALTH", "arena1")
    addon:UNIT_NAME_UPDATE("UNIT_NAME_UPDATE", "arena1")
    inCombat = false
    addon:UpdateArenaFrames()
    inCombat = true
    addon:RefreshUnit("arena1")
end
local function expect(text)
    equal(status("arena1"), text, "enemy status")
    equal(addon.buttons.arena1.alpha, 1, "enemy opacity")
    equal(not not addon:ShouldDisplayUnitAsLeft("arena1"), false, "enemy must not be LEFT")
end

local passed, failed = 0, 0
local function test(name, run)
    reset()
    local ok, err = pcall(run)
    if ok then
        passed = passed + 1
        print("PASS " .. name)
    else
        failed = failed + 1
        print("FAIL " .. name .. ": " .. err)
    end
end

for _, reason in ipairs({"unseen", "destroyed", "cleared"}) do
    test(reason .. " preserves stealth despite stale death data", function()
        if reason == "destroyed" then availability("unseen") end
        units.arena1.dead, units.arena1.health = true, 0
        availability(reason)
        expect("STEALTH")
        refresh()
        expect("STEALTH")
        units.arena1 = {}
        refresh()
        expect("STEALTH")
    end)
    test("death then " .. reason .. " stays DEAD", function()
        died()
        units.arena1 = {}
        availability(reason)
        refresh()
        expect("DEAD")
        equal(healthbar.frame.arena1.value, 0, "dead health bar")
        assert(healthbar.frame.arena1.high > 0, "dead bar needs a valid range")
    end)
    test(reason .. " then death becomes DEAD", function()
        units.arena1 = {}
        availability(reason)
        -- Name/portrait updates can remove the live GUID lookup while hidden.
        addon:UpdateUnitGUID("UNIT_PORTRAIT_UPDATE", "arena1")
        died()
        refresh()
        expect("DEAD")
    end)
    test(reason .. " then seen restores name", function()
        availability(reason)
        availability("seen")
        expect("arena1name")
    end)
end

test("destroyed cannot replace an unseen enemy with LEFT", function()
    availability("unseen")
    units.arena1 = {}
    availability("destroyed")
    expect("STEALTH")
end)

test("stale positive health cannot erase a combat-log death", function()
    died()
    refresh()
    expect("DEAD")
    availability("unseen")
    refresh()
    expect("DEAD")
end)

test("living seen update clears confirmed death", function()
    died()
    availability("unseen")
    availability("seen")
    expect("arena1name")
    equal(addon.buttons.arena1.confirmedDead, nil)
end)

test("seen corpse retains confirmed death", function()
    died()
    units.arena1.dead, units.arena1.health = true, 0
    availability("seen")
    expect("DEAD")
end)

test("destroyed alone does not invent departure, death or stealth", function()
    units.arena1 = {}
    availability("destroyed")
    refresh()
    expect("arena1name")
    availability("unseen")
    expect("STEALTH")
end)

test("inverse health bar also remains empty after death and disappearance", function()
    healthbar.db.arena1.healthBarInverse = true
    died()
    units.arena1 = {}
    availability("destroyed")
    refresh()
    expect("DEAD")
    equal(healthbar.frame.arena1.value, healthbar.frame.arena1.high, "inverse dead health bar")
end)

test("API death flag alone cannot turn a rogue into DEAD", function()
    units.arena1.dead, units.arena1.health = true, 0
    refresh()
    expect("arena1name")
    availability("unseen")
    expect("STEALTH")
end)

test("unknown opponents keep unknown until identified", function()
    reset(false)
    for _, reason in ipairs({"unseen", "destroyed", "cleared"}) do
        availability(reason)
        expect("unknown")
    end
end)

test("new GUID cannot inherit the previous occupant's stealth", function()
    availability("unseen")
    units.arena1.guid, units.arena1.name = "new-guid", "New opponent"
    addon:UNIT_NAME_UPDATE("UNIT_NAME_UPDATE", "arena1")
    expect("New opponent")
end)

test("new GUID cannot inherit confirmed death", function()
    died()
    units.arena1.guid, units.arena1.name = "new-guid", "New opponent"
    addon:UNIT_NAME_UPDATE("UNIT_NAME_UPDATE", "arena1")
    expect("New opponent")
    died("arena1-guid")
    expect("New opponent")
end)

test("unrelated and malformed deaths do not affect enemies", function()
    died("pet-guid")
    addon:COMBAT_LOG_EVENT_UNFILTERED("COMBAT_LOG_EVENT_UNFILTERED", 1, "UNIT_DIED")
    expect("arena1name")
    equal(addon.buttons.arena2.confirmedDead, nil, "empty slot death")
    arenaActive = false
    died()
    expect("arena1name")
end)

test("system departure messages do not label enemies LEFT", function()
    units.arena1.exists = nil
    availability("unseen")
    addon:CHAT_MSG_SYSTEM("CHAT_MSG_SYSTEM", "arena1name has left the battle")
    expect("STEALTH")
end)

test("party death and departure behavior remains independent", function()
    units.party1.dead, units.party1.health = true, 0
    addon:UNIT_HEALTH("UNIT_HEALTH", "party1")
    equal(status("party1"), "DEAD")
    units.party1.exists = nil
    addon:CHAT_MSG_SYSTEM("CHAT_MSG_SYSTEM", "party1name has left the battle")
    equal(status("party1"), "LEFT")
    units.party1.exists, units.party1.dead, units.party1.health = true, nil, 100
    addon:UNIT_HEALTH("UNIT_HEALTH", "party1")
    equal(status("party1"), "party1name")
end)

test("leaving an arena clears cached enemy state", function()
    died()
    addon:HideFrames()
    equal(addon.buttons.arena1.confirmedDead, nil)
    equal(addon.buttons.arena1.guid, nil)
    equal(addon.buttons.arena1.knownName, nil)
    equal(addon.buttons.arena1.unit_state, nil)
    availability("seen")
    expect("arena1name")
end)

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
