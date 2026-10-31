-- Run from the addon directory with Lua 5.1: lua tests/arena_roster.lua
-- Optional arguments: alternate core and tags files for regression checks.
local units, refreshed, specQueries = {}, {}, {}
local combat, spectating, testing = false, false, false
local partyCount, opponents = 1, 0
local function noop() end
local function data(unit) return units[unit] or {} end
UnitExists = function(unit) return data(unit).exists end
UnitGUID = function(unit) return data(unit).guid end
UnitName = function(unit) return data(unit).name end
UnitClass = function(unit) return "Class", data(unit).class end
UnitHealth = function(unit) return data(unit).health or 100 end
UnitIsDeadOrGhost = function(unit) return data(unit).dead end
UnitIsConnected = function(unit) return data(unit).exists end
UnitAura = noop
GetSpellInfo = function(id) return id == 5384 and "Feign Death" end
GetNumPartyMembers = function() return partyCount end
GetNumArenaOpponents = function() return opponents end
IsActiveBattlefieldArena = function() return true end
InCombatLockdown = function() return combat end
UNKNOWN = "Unknown"

local addon = {
    SetDefaultModulePrototype = noop, SetDefaultModuleLibraries = noop,
    SetDefaultModuleState = noop, GetModule = noop,
    NewModule = function() return {} end,
}
local locale = setmetatable({}, {__index = function(_, key) return key end})
local libs = {
    ["AceAddon-3.0"] = {NewAddon = function() return addon end},
    ["AceLocale-3.0"] = {GetLocale = function() return locale end},
    ["LibFunctional-1.0"] = {}, ["LibSharedMedia-3.0"] = {},
    ["LibSpecDetection-1.0"] = {GetSpecID = function(_, guid)
        specQueries[#specQueries + 1] = guid
    end},
}
LibStub = function(name) return assert(libs[name], name) end
local function loadAddonFile(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a"):gsub("^\239\187\191", "")
    file:close()
    assert(loadstring(source, "@" .. path))()
end
loadAddonFile(arg[1] or "GladiusEx.lua")
local tags
addon.NewModule = function() tags = {}; return tags end
loadAddonFile(arg[2] or "modules/tags.lua")
local tagFunctions = tags:GetBuiltinTags()

addon.IsTesting = function() return testing end
addon.IsSpectating = function() return spectating end
addon.UpdateUnit = noop
addon.UpdateAnchor = noop
addon.UpdateAnchorHandle = noop
addon.UpdateBackground = noop
addon.SendMessage = noop
addon.IsModuleEnabled = function() return true end
addon.Data = {classIDByClassName = {PRIEST = 5, ROGUE = 4}, specIDToClassID = {[256] = 5}}
local module = {
    Show = noop, Reset = noop,
    Refresh = function(_, unit)
        refreshed[unit] = (refreshed[unit] or 0) + 1
        addon.buttons[unit].text = tagFunctions["name:status"](unit)
    end,
}
addon.IterateModules = function() return pairs({Display = module}) end

local function equal(actual, expected, context)
    assert(actual == expected, (context or "value") .. ": expected " ..
        tostring(expected) .. ", got " .. tostring(actual))
end
local function person(guid, name, class)
    return {exists = true, guid = guid, name = name, class = class or "PRIEST"}
end
local function reset()
    combat, spectating, testing = false, false, false
    partyCount, opponents = 1, 0
    units = {player = person("self", "Me"), party1 = person("teammate", "Teammate")}
    refreshed, specQueries, guid_to_unitid = {}, {}, {}
    addon.db = {base = {debug = false}, arena = {}, party = {}}
    addon.arena_size, addon.seenPlayers, addon.confirmedArenaSize = 2, nil, nil
    addon.buttons = {}
    for unit in pairs(addon.arena_units) do addon.buttons[unit] = {} end
    for unit in pairs(addon.party_units) do addon.buttons[unit] = {} end
    for _, button in pairs(addon.buttons) do
        button.alpha, button.shown = 1, true
        button.SetAlpha = function(self, alpha) self.alpha = alpha end
        button.IsShown = function(self) return self.shown end
        button.Show = function(self) assert(not combat, "protected Show in combat"); self.shown = true end
        button.Hide = function(self) assert(not combat, "protected Hide in combat"); self.shown = false end
    end
    addon.arena_parent = {Hide = noop, IsShown = function() return true end}
    addon.party_parent = {Hide = noop, IsShown = function() return true end}
end
local function seen(unit)
    addon:ARENA_OPPONENT_UPDATE("ARENA_OPPONENT_UPDATE", unit or "arena1", "seen")
end
local function noTeammateEnemy()
    local button = addon.buttons.arena1
    equal(button.alpha, 0, "duplicate enemy visibility")
    if not combat then equal(button.shown, false, "duplicate enemy click target hidden") end
    equal(button.guid, nil, "enemy GUID")
    equal(button.class, nil, "enemy class")
    equal(button.specID, nil, "enemy spec")
    equal(button.knownName, nil, "cached enemy name")
    equal(tagFunctions.name("arena1"), "unknown", "enemy name tag")
    equal(button.knownName, nil, "tag must not cache teammate name")
    equal(addon:GetUnitIdByGUID("teammate"), "party1", "teammate GUID lookup")
end
local passed, failed = 0, 0
local function test(name, run)
    reset()
    local ok, err = pcall(run)
    if ok then passed = passed + 1; print("PASS " .. name)
    else failed = failed + 1; print("FAIL " .. name .. ": " .. err) end
end

test("preparation refresh rejects a teammate in an arena token", function()
    units.arena1 = units.party1
    addon:UpdateAllGUIDs()
    addon:UpdateArenaFrames()
    noTeammateEnemy()
    equal(refreshed.arena1, nil, "duplicate must not reach display refresh")
    addon:RefreshUnit("party1")
    equal(addon.buttons.party1.text, "Teammate", "party frame still works")
end)

test("seen, name, health and portrait updates cannot restore the duplicate", function()
    units.arena1 = units.party1
    addon:UpdateAllGUIDs()
    seen()
    addon:UNIT_NAME_UPDATE("UNIT_NAME_UPDATE", "arena1")
    addon:UNIT_HEALTH("UNIT_HEALTH", "arena1")
    addon:UpdateUnitGUID("UNIT_PORTRAIT_UPDATE", "arena1")
    addon:RefreshUnit("arena1")
    noTeammateEnemy()
end)

test("a previous enemy joining the party loses its cached enemy identity", function()
    units.arena1 = person("teammate", "Teammate")
    units.party1 = {}
    seen()
    addon.buttons.arena1.specID, addon.buttons.arena1.confirmedDead = 256, true
    units.party1 = units.arena1
    addon:PARTY_MEMBERS_CHANGED()
    noTeammateEnemy()
    equal(addon.buttons.arena1.confirmedDead, nil, "old enemy death")
    units.arena1 = {}
    equal(tagFunctions.name("arena1"), "unknown", "no stale teammate after token disappears")
end)

for _, duringCombat in ipairs({false, true}) do
    test("party2 becoming party1 clears the old slot, combat=" .. tostring(duringCombat), function()
        partyCount = 2
        units.party2 = person("remaining", "Remaining", "ROGUE")
        addon:PARTY_MEMBERS_CHANGED()
        addon.buttons.party1.specID, addon.buttons.party2.specID = 256, 261
        equal(addon.buttons.party2.text, "Remaining", "old survivor slot")

        combat = duringCombat
        units.party1, units.party2 = units.party2, {}
        partyCount = 1
        addon:PARTY_MEMBERS_CHANGED()

        local oldSlot = addon.buttons.party2
        equal(oldSlot.alpha, 0, "obsolete party slot hidden immediately")
        equal(oldSlot.soft_hidden, true, "obsolete party slot stays hidden")
        equal(oldSlot.guid, nil, "obsolete identity cleared")
        equal(oldSlot.knownName, nil, "obsolete name cleared")
        equal(oldSlot.class, nil, "obsolete class cleared")
        equal(oldSlot.specID, nil, "obsolete specialization cleared")
        equal(addon:GetUnitIdByGUID("remaining"), "party1", "survivor follows its new unit ID")
        equal(addon:GetUnitIdByGUID("teammate"), nil, "departed member removed")
        equal(addon.buttons.party1.text, "Remaining", "new survivor slot refreshed immediately")
        equal(addon.buttons.party1.class, "ROGUE", "new survivor class refreshed")
        equal(addon.buttons.party1.specID, nil, "survivor cannot inherit departed member's spec")

        addon:UNIT_NAME_UPDATE("UNIT_NAME_UPDATE", "party2")
        addon:UNIT_HEALTH("UNIT_HEALTH", "party2")
        addon:UpdateUnitGUID("UNIT_PORTRAIT_UPDATE", "party2")
        equal(oldSlot.alpha, 0, "late events cannot restore obsolete slot")
        equal(tagFunctions.name("party2"), "party2", "late events cannot restore cached survivor name")

        combat = false
        addon:PLAYER_REGEN_ENABLED()
        equal(oldSlot.alpha, 0, "deferred refresh keeps obsolete slot hidden")
        equal(oldSlot.guid, nil, "deferred refresh keeps obsolete identity cleared")
        equal(addon.buttons.party1.text, "Remaining", "survivor stays in party1")
    end)
end

test("the last teammate leaving in combat hides its party frame", function()
    addon:PARTY_MEMBERS_CHANGED()
    combat = true
    partyCount, units.party1 = 0, {}
    addon:PARTY_MEMBERS_CHANGED()
    equal(addon.buttons.party1.alpha, 0, "departed teammate hidden")
    equal(addon.buttons.party1.guid, nil, "departed teammate identity cleared")
    equal(addon:GetUnitIdByGUID("teammate"), nil, "departed teammate lookup cleared")
    equal(addon.buttons.player.text, "Me", "player remains visible")
end)

test("a combat roster refresh preserves dead members and the hide-self setting", function()
    addon.db.base.hideSelf = true
    addon:PARTY_MEMBERS_CHANGED()
    combat = true
    units.party1.dead, units.party1.health = true, 0
    addon:PARTY_MEMBERS_CHANGED()
    equal(addon.buttons.player.alpha, 0, "hidden player stays hidden")
    equal(addon.buttons.party1.alpha, 1, "dead teammate keeps its slot")
    equal(addon.buttons.party1.text, "DEAD", "dead teammate display refreshed")
    equal(addon.buttons.party1.guid, "teammate", "dead teammate identity retained")
end)

test("a party slot vacated during combat can be reused before combat ends", function()
    addon:PARTY_MEMBERS_CHANGED()
    combat = true
    partyCount, units.party1 = 0, {}
    addon:PARTY_MEMBERS_CHANGED()
    equal(addon.buttons.party1.alpha, 0, "vacant slot hidden")
    partyCount, units.party1 = 1, person("replacement", "Replacement", "ROGUE")
    addon:PARTY_MEMBERS_CHANGED()
    equal(addon.buttons.party1.alpha, 1, "occupied slot visible again")
    equal(addon.buttons.party1.text, "Replacement", "replacement display refreshed")
    equal(addon.buttons.party1.guid, "replacement", "replacement identity refreshed")
end)

test("party identity is retained for synthetic test and spectator units", function()
    for _, mode in ipairs({"test", "spectator"}) do
        testing, spectating = mode == "test", mode == "spectator"
        addon:UpdateAllGUIDs()
        units.party1.exists = nil
        addon:UpdateUnitGUID("UNIT_PORTRAIT_UPDATE", "party1")
        equal(addon.buttons.party1.guid, "teammate", mode .. " identity retained")
        equal(addon.buttons.party1.alpha, 1, mode .. " row stays visible")
    end
end)

for _, event in ipairs({"seen", "name", "refresh"}) do
    test("a real opponent recovers after rejection on " .. event, function()
        units.arena1 = units.party1
        addon:UpdateAllGUIDs()
        addon:UpdateArenaFrames()
        units.arena1 = person("enemy", "Opponent", "ROGUE")
        if event == "seen" then seen()
        elseif event == "name" then addon:UNIT_NAME_UPDATE("UNIT_NAME_UPDATE", "arena1")
        else addon:RefreshUnit("arena1") end
        equal(addon.buttons.arena1.alpha, 1, "real opponent visibility")
        equal(addon.buttons.arena1.shown, true, "real opponent frame shown")
        equal(addon.buttons.arena1.guid, "enemy", "real opponent GUID")
        equal(addon.buttons.arena1.class, "ROGUE", "real opponent class")
        equal(addon.buttons.arena1.text, "Opponent", "real opponent display")
        equal(addon:GetUnitIdByGUID("teammate"), "party1")
        equal(addon:GetUnitIdByGUID("enemy"), "arena1")
    end)
end

test("talent and class callbacks cannot identify a teammate as an enemy", function()
    units.arena1 = units.party1
    addon:IdentifyUnitClass("arena1")
    addon:IdentifyUnitSpecialization("SPEC_DETECTED", "arena1", "teammate", 256)
    equal(addon.buttons.arena1.class, nil)
    equal(addon.buttons.arena1.specID, nil)
end)

test("all party slots and the player are excluded by GUID", function()
    for member in pairs(addon.party_units) do
        units[member] = person(member .. "-guid", member)
        units.arena1 = units[member]
        addon:UpdateUnitGUID("party", member)
        seen()
        equal(addon.buttons.arena1.guid, nil, member .. " rejected")
        equal(addon:GetUnitIdByGUID(units[member].guid), member, member .. " lookup")
    end
end)

test("a duplicate in arena5 cannot inflate the roster", function()
    units.arena5 = units.party1
    addon:CheckArenaSize("arena5")
    equal(addon.arena_size, 2, "arena size")
end)

test("same-name opponents remain valid and survive stealth", function()
    units.arena1 = person("enemy", "Teammate", "ROGUE")
    addon:UpdateAllGUIDs()
    seen()
    equal(addon.buttons.arena1.guid, "enemy")
    units.arena1 = {}
    addon:ARENA_OPPONENT_UPDATE("ARENA_OPPONENT_UPDATE", "arena1", "unseen")
    equal(addon.buttons.arena1.text, "STEALTH")
    equal(addon.buttons.arena1.alpha, 1)
end)

test("spectator and test modes retain their unit handling", function()
    units.arena1 = units.party1
    spectating = true
    addon:UpdateAllGUIDs()
    equal(addon.buttons.arena1.guid, "teammate", "spectator GUID")
    spectating, testing = false, true
    addon:UpdateAllGUIDs()
    equal(addon.buttons.arena1.guid, "teammate", "test GUID")
end)

test("rejection is safe during combat and ends when the opponent is seen", function()
    units.arena1 = units.party1
    combat = true
    addon:UpdateAllGUIDs()
    seen()
    noTeammateEnemy()
    units.arena1 = person("enemy", "Opponent", "ROGUE")
    seen()
    equal(addon.buttons.arena1.alpha, 1)
    equal(addon.buttons.arena1.text, "Opponent")
end)

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
