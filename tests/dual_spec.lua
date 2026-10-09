-- Run from GladiusEx with Lua 5.1: lua tests/dual_spec.lua
-- Optional arguments: LibDualSpec file and AceDB file to test.
-- Uses the real LibStub, CallbackHandler, AceDB and AceDBOptions libraries.
local libraryPath = arg[1] or "libs/LibDualSpec-1.0/LibDualSpec-1.0.lua"
local aceDBPath = arg[2] or "libs/AceDB-3.0/AceDB-3.0.lua"
local major, charKey = "LibDualSpec-1.0", "Tester - TestRealm"
local cases = 0

local function equal(actual, expected, context)
    assert(actual == expected, context .. ": expected " .. tostring(expected) ..
        ", got " .. tostring(actual))
end

local function setup(group, loggedIn, oldLibrary, modernTalentGroup)
    LibStub = nil
    strmatch = string.match
    GetLocale = function() return "enUS" end
    GetRealmName = function() return "TestRealm" end
    GetCVar = function() return "test" end
    UnitName = function() return "Tester" end
    UnitClass = function() return "Shaman", "SHAMAN" end
    UnitRace = function() return "Draenei", "DRAENEI" end
    UnitFactionGroup = function() return "Alliance" end
    NORMAL_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE = "", ""
    local state = {group = group, loggedIn = loggedIn, errors = {}}
    GetActiveTalentGroup = function() return state.group end
    GetNumTalentGroups = function() return 2 end
    GetActiveSpecGroup = modernTalentGroup
    IsLoggedIn = function() return state.loggedIn end
    geterrorhandler = function()
        return function(message) state.errors[#state.errors + 1] = message end
    end
    CreateFrame = function()
        return {
            events = {}, scripts = {},
            RegisterEvent = function(self, event) self.events[event] = true end,
            UnregisterEvent = function(self, event) self.events[event] = nil end,
            UnregisterAllEvents = function(self) self.events = {} end,
            SetScript = function(self, name, handler) self.scripts[name] = handler end,
            GetScript = function(self, name) return self.scripts[name] end,
        }
    end
    dofile("libs/LibStub/LibStub.lua")
    dofile("libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
    dofile(aceDBPath)
    dofile("libs/AceDBOptions-3.0/AceDBOptions-3.0.lua")
    dofile(oldLibrary or libraryPath)
    state.lib = LibStub(major)
    function state:event(event, newGroup)
        self.group = newGroup
        local frame = self.lib.eventFrame
        assert(frame.events[event], "event not registered: " .. event)
        frame:GetScript("OnEvent")(frame, event)
        equal(#self.errors, 0, "callback errors")
    end
    function state:database(settings, current, name)
        current = current or "Primary"
        local saved = {
            profileKeys = {[charKey] = current},
            profiles = {
                Primary = {marker = "primary settings"},
                Secondary = {marker = "secondary settings"},
            },
            namespaces = {[major] = {char = {[charKey] = settings}}},
        }
        local db = LibStub("AceDB-3.0"):New(saved)
        self.lib:EnhanceDatabase(db, name or "Test addon")
        return db, saved
    end
    return state
end

local function test(name, run)
    run()
    cases = cases + 1
    print("PASS " .. name)
end

test("numbered profiles survive login and talent switches", function()
    local state = setup(2, false)
    local settings = {[1] = "Primary", [2] = "Secondary", enabled = true}
    local db, saved = state:database(settings)
    state:event("PLAYER_TALENT_UPDATE", 2)
    equal(db:GetCurrentProfile(), "Secondary", "secondary login")
    equal(settings[1], "Primary", "primary assignment")
    equal(settings[2], "Secondary", "secondary assignment")
    state:event("PLAYER_TALENT_UPDATE", 1)
    equal(db.profile.marker, "primary settings", "primary settings preserved")
    state:event("PLAYER_TALENT_UPDATE", 2)
    equal(db.profile.marker, "secondary settings", "secondary settings preserved")
    equal(saved.profileKeys[charKey], "Secondary", "saved active profile")
end)

test("numbered mappings take priority over stale legacy fields", function()
    local state = setup(1, false)
    local settings = {[1] = "Primary", [2] = "Secondary", profile = "Obsolete",
        talentGroup = 2, enabled = true}
    local db = state:database(settings, "Default")
    state:event("PLAYER_TALENT_UPDATE", 1)
    equal(db:GetCurrentProfile(), "Primary", "explicit primary mapping")
    equal(settings[2], "Secondary", "explicit secondary mapping")
    equal(settings.profile, nil, "legacy alternate migrated")
    equal(settings.talentGroup, nil, "legacy talent group migrated")
end)

test("legacy alternate migrates using the last saved talent group", function()
    for _, field in ipairs({"specGroup", "talentGroup"}) do
        local state = setup(2, false)
        local settings = {profile = "Secondary", enabled = true, [field] = 1}
        local db = state:database(settings)
        state:event("PLAYER_TALENT_UPDATE", 2)
        equal(db:GetCurrentProfile(), "Secondary", field .. " secondary login")
        equal(settings[1], "Primary", field .. " primary preserved")
        state:event("PLAYER_TALENT_UPDATE", 1)
        equal(db:GetCurrentProfile(), "Primary", field .. " switch back")
    end
end)

test("missing and malformed settings do not stop other databases", function()
    local state = setup(1, false)
    local bad = state:database({enabled = true, [1] = false, [2] = {}}, "Primary", "Bad")
    local missing = state:database({enabled = true}, "Primary", "Missing")
    local good = state:database({enabled = true, [1] = "Primary", [2] = "Secondary"}, "Primary", "Good")
    state:event("PLAYER_TALENT_UPDATE", 1)
    state:event("PLAYER_TALENT_UPDATE", 2)
    equal(bad:GetCurrentProfile(), "Primary", "malformed mapping fallback")
    equal(missing:GetCurrentProfile(), "Primary", "missing mapping fallback")
    equal(good:GetCurrentProfile(), "Secondary", "other database still switched")
end)

test("manual profile changes remain assigned to the active spec", function()
    local state = setup(1, false)
    local db = state:database({enabled = true, [1] = "Primary", [2] = "Secondary"})
    state:event("PLAYER_TALENT_UPDATE", 1)
    db:SetProfile("ManualPrimary")
    state:event("PLAYER_TALENT_UPDATE", 2)
    equal(db:GetCurrentProfile(), "Secondary", "secondary unchanged")
    state:event("PLAYER_TALENT_UPDATE", 1)
    equal(db:GetCurrentProfile(), "ManualPrimary", "manual primary retained")
end)

test("legacy alternate options and indexed API both work", function()
    local state = setup(1, false)
    local db = state:database({enabled = true, [1] = "Primary", [2] = "Secondary"})
    local options = LibStub("AceDBOptions-3.0"):GetOptionsTable(db)
    state.lib:EnhanceOptions(options, db)
    local plugin, info = options.plugins[major], {handler = options.handler}
    state:event("PLAYER_TALENT_UPDATE", 1)
    equal(plugin.dualProfile.get(info), "Secondary", "old options getter")
    plugin.dualProfile.set(info, "NewSecondary")
    equal(db:GetCurrentProfile(), "Primary", "alternate selection leaves primary active")
    equal(db:GetDualSpecProfile(2), "NewSecondary", "indexed getter")
    db:SetDualSpecProfile("NewPrimary", 1)
    equal(db:GetCurrentProfile(), "NewPrimary", "active assignment applied")
    state:event("PLAYER_TALENT_UPDATE", 2)
    equal(db:GetCurrentProfile(), "NewSecondary", "alternate selection applied")
    equal(plugin.dualProfile.get(info), "NewPrimary", "alternate reverses with spec")
    local ok = pcall(db.SetDualSpecProfile, db, nil)
    equal(ok, false, "reject nil profile at setter")
    equal(pcall(db.SetDualSpecProfile, db, "Bad", 3), false, "reject invalid group")
end)

test("disable and re-enable preserve both assignments", function()
    local state = setup(1, false)
    local settings = {enabled = true, [1] = "Primary", [2] = "Secondary"}
    local db = state:database(settings)
    state:event("PLAYER_TALENT_UPDATE", 1)
    db:SetDualSpecEnabled(false)
    state:event("PLAYER_TALENT_UPDATE", 2)
    equal(db:GetCurrentProfile(), "Primary", "disabled switching")
    equal(settings[2], "Secondary", "disabled assignment retained")
    db:SetProfile("ChangedWhileDisabled")
    db:SetDualSpecEnabled(true)
    equal(db:GetCurrentProfile(), "Secondary", "re-enabled switching")
    equal(settings[1], "Primary", "primary retained on re-enable")
    equal(settings[2], "Secondary", "secondary retained on re-enable")
end)

test("deleted alternate profile is not recreated", function()
    local state = setup(1, false)
    local db, saved = state:database({enabled = true, [1] = "Primary", [2] = "Secondary"})
    state:event("PLAYER_TALENT_UPDATE", 1)
    db:DeleteProfile("Secondary")
    state:event("PLAYER_TALENT_UPDATE", 2)
    equal(db:GetCurrentProfile(), "Primary", "deleted alternate fallback")
    equal(saved.profiles.Secondary, nil, "deleted profile stays deleted")
    equal(#state.errors, 0, "deletion callback errors")
end)

test("database reset reattaches methods and callbacks", function()
    local state = setup(1, false)
    local db = state:database({enabled = true, [1] = "Primary", [2] = "Secondary"})
    state:event("PLAYER_TALENT_UPDATE", 1)
    db:ResetDB("Reset")
    equal(db:IsDualSpecEnabled(), nil, "reset disables switching")
    db:SetDualSpecEnabled(true)
    db:SetDualSpecProfile("ResetSecondary")
    state:event("PLAYER_TALENT_UPDATE", 2)
    equal(db:GetCurrentProfile(), "ResetSecondary", "reset alternate")
    db:SetProfile("ManualAfterReset")
    state:event("PLAYER_TALENT_UPDATE", 1)
    state:event("PLAYER_TALENT_UPDATE", 2)
    equal(db:GetCurrentProfile(), "ManualAfterReset", "reset callbacks reattached")
    equal(#state.errors, 0, "reset callback errors")
end)

test("talent readiness requires a valid native group", function()
    local state = setup(nil, false)
    local db = state:database({enabled = true, [1] = "Primary", [2] = "Secondary"})
    state:event("ADDON_LOADED", 1)
    equal(db:GetCurrentProfile(), "Primary", "pre-login addon event ignored")
    state:event("PLAYER_TALENT_UPDATE", nil)
    equal(state.lib.specLoaded, nil, "nil group ignored")
    state:event("PLAYER_TALENT_UPDATE", 3)
    equal(state.lib.specLoaded, nil, "out-of-range group ignored")
    state:event("PLAYER_TALENT_UPDATE", 2)
    equal(db:GetCurrentProfile(), "Secondary", "valid talent event initializes")
    state:event("PLAYER_TALENT_UPDATE", 0)
    equal(db:GetCurrentProfile(), "Secondary", "invalid later group ignored")
end)

test("alternate selections before talent readiness are preserved", function()
    local state = setup(nil, false)
    local db = state:database({enabled = true, [1] = "Primary", [2] = "Secondary"})
    db:SetDualSpecProfile("PendingAlternate")
    equal(db:GetDualSpecProfile(), "PendingAlternate", "pending alternate getter")
    state:event("PLAYER_TALENT_UPDATE", 2)
    equal(db:GetCurrentProfile(), "Secondary", "current mapping preserved")
    equal(db:GetDualSpecProfile(), "PendingAlternate", "pending alternate applied")
    state:event("PLAYER_TALENT_UPDATE", 1)
    equal(db:GetCurrentProfile(), "PendingAlternate", "pending alternate switches")
end)

test("deleting a pending alternate before login does not recreate it", function()
    local state = setup(nil, false)
    local db, saved = state:database({enabled = true, [1] = "Primary", [2] = "Secondary"})
    db:SetDualSpecProfile("Secondary")
    db:DeleteProfile("Secondary")
    state:event("PLAYER_TALENT_UPDATE", 1)
    state:event("PLAYER_TALENT_UPDATE", 2)
    equal(db:GetCurrentProfile(), "Primary", "deleted pending alternate fallback")
    equal(saved.profiles.Secondary, nil, "pending alternate stays deleted")
end)

test("disabled pending selection resolves on the first valid talent group", function()
    local state = setup(nil, false)
    local settings = {enabled = false, [1] = "Primary", [2] = "Secondary"}
    local db = state:database(settings)
    db:SetDualSpecProfile("PendingSecondary")
    state:event("PLAYER_TALENT_UPDATE", 1)
    state:event("PLAYER_TALENT_UPDATE", 2)
    db:SetDualSpecEnabled(true)
    equal(db:GetCurrentProfile(), "PendingSecondary", "pending assignment belongs to secondary")
    equal(settings[1], "Primary", "primary assignment preserved")
end)

test("later indexed selections override an earlier pending alternate", function()
    local state = setup(nil, false)
    local db = state:database({enabled = true, [1] = "Primary", [2] = "Secondary"})
    db:SetDualSpecProfile("PendingAlternate")
    db:SetDualSpecProfile("ExplicitPrimary", 1)
    state:event("PLAYER_TALENT_UPDATE", 2)
    equal(db:GetDualSpecProfile(1), "ExplicitPrimary", "later primary selection wins")
    state:event("PLAYER_TALENT_UPDATE", 1)
    equal(db:GetCurrentProfile(), "ExplicitPrimary", "explicit primary is applied")
end)

test("a later pending selection overrides earlier indexed assignments", function()
    local state = setup(nil, false)
    local db = state:database({enabled = true, [1] = "Primary", [2] = "Secondary"})
    db:SetDualSpecProfile("EarlierPrimary", 1)
    db:SetDualSpecProfile("PendingAlternate")
    state:event("PLAYER_TALENT_UPDATE", 2)
    equal(db:GetDualSpecProfile(1), "PendingAlternate", "later alternate selection wins")
end)

test("loading after login applies the correct assignment immediately", function()
    local state = setup(2, true)
    local db = state:database({enabled = true, [1] = "Primary", [2] = "Secondary"})
    equal(db:GetCurrentProfile(), "Secondary", "late-loaded secondary assignment")
end)

test("native 3.3.5a talent data takes precedence over compatibility facades", function()
    local state = setup(2, true, nil, function() return 1 end)
    local db = state:database({enabled = true, [1] = "Primary", [2] = "Secondary"})
    equal(db:GetCurrentProfile(), "Secondary", "native talent group selected")
end)

-- The original revision-12 fixture keeps load-order checks self-contained.
-- Also check revision 4 when RatingBuster is installed alongside this checkout.
local oldCopies = {
    "tests/fixtures/lib_dual_spec_v12.lua",
}
local ratingBusterPath = "../RatingBuster/libs/LibDualSpec-1.0/LibDualSpec-1.0.lua"
local ratingBusterFile = io.open(ratingBusterPath, "rb")
if ratingBusterFile then
    ratingBusterFile:close()
    oldCopies[#oldCopies + 1] = ratingBusterPath
end
for _, oldLibrary in ipairs(oldCopies) do
        test("old library load order: " .. oldLibrary, function()
            -- Old copies are allowed to use the compatibility alias.
            local state = setup(1, false, oldLibrary)
            GetActiveSpecGroup = GetActiveTalentGroup
            local db = state:database({enabled = true, profile = "Secondary",
                specGroup = 1, talentGroup = 1})
            local options = LibStub("AceDBOptions-3.0"):GetOptionsTable(db)
            state.lib:EnhanceOptions(options, db)
            local plugin = options.plugins[major]
            state.loggedIn = true
            dofile(libraryPath)
            state.lib = LibStub(major)
            equal(options.plugins[major], plugin, "existing options reference retained")
            state:event("PLAYER_TALENT_UPDATE", 2)
            equal(db:GetCurrentProfile(), "Secondary", "previously registered database upgraded")
            local handler = state.lib.eventFrame:GetScript("OnEvent")
            dofile(oldLibrary)
            equal(state.lib.eventFrame:GetScript("OnEvent"), handler, "later old copy cannot replace fork")
            equal(#state.errors, 0, "upgrade callback errors")
        end)
end

print(string.format("%d dual-spec cases passed against %s", cases, aceDBPath))
