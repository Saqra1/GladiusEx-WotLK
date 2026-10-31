-- Run from the addon directory with Lua 5.1: lua tests/spec_detection.lua
-- Exercise both embedded detectors with real data and callback dispatch.
local cases = 0
local function noop() end
local function equal(actual, expected, context)
    assert(actual == expected, context .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function loadFile(path, ...)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a"):gsub("^\239\187\191", "")
    file:close()
    return assert(loadstring(source, "@" .. path))(...)
end

local function setup(base)
    LibStub = nil
    strmatch = string.match
    GetAccountExpansionLevel = function() return 2 end
    geterrorhandler = function() return error end
    COMBATLOG_FILTER_FRIENDLY_UNITS = 1
    CombatLog_Object_IsA = function(flags, filter)
        equal(type(flags), "number", "combat-log source flags must be numeric")
        equal(filter, COMBATLOG_FILTER_FRIENDLY_UNITS, "friendly filter")
        return flags == 1
    end
    local frame
    CreateFrame = function()
        frame = {RegisterEvent = noop, SetScript = function(self, event, handler) self[event] = handler end}
        return frame
    end
    loadFile("libs/LibStub/LibStub.lua")
    loadFile("libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
    LibStub:NewLibrary("AceTimer-3.0", 1).Embed = function(_, lib)
        lib.ScheduleTimer = function() return 1 end
        lib.CancelTimer = noop
    end
    local ns = {}
    loadFile(base .. "/Data_WotLK.lua", "Test", ns)
    local lib = loadFile(base .. "/LibSpecDetection-1.0.lua", "Test", ns)
    local detections = {}
    lib.RegisterCallback(detections, "SPEC_DETECTED", function(event, unit, guid, specID, enemy)
        detections[#detections + 1] = {guid = guid, specID = specID, enemy = enemy}
    end)
    local function cast(guid, spellID, flags, kind)
        -- Book pp. 388-389: eight base fields, followed by spell ID/name/school.
        frame.OnEvent(frame, "COMBAT_LOG_EVENT_UNFILTERED", 100, kind or "SPELL_CAST_SUCCESS",
            guid, "Priest", flags or 1, "target-guid", "Target", 0, spellID, "Priest spell", 2)
    end
    return lib, cast, detections
end

for _, base in ipairs({"libs/LibSpecDetection-1.0", "libs/LibCooldownTracker-1.0/libs/LibSpecDetection-1.0"}) do
    local function test(name, run)
        run()
        cases = cases + 1
        print("ok - " .. base .. ": " .. name)
    end
    test("priest casts identify the caster and preserve friendly/enemy classification", function()
        local lib, cast, detections = setup(base)
        cast("disc-guid", 10060)
        equal(lib:GetSpecID("disc-guid"), 256, "Power Infusion identifies Discipline")
        equal(lib:IsEnemy("disc-guid"), false, "teammate is friendly")
        equal(detections[1].guid, "disc-guid", "caster receives detection")
        equal(detections[1].specID, 256, "callback includes the spec")
        equal(lib:GetSpecID("target-guid"), nil, "spell recipient is not classified")
        cast("disc-guid", 10060)
        equal(#detections, 1, "repeated casts do not repeat detection")
        cast("holy-guid", 47788, 2)
        equal(lib:GetSpecID("holy-guid"), 257, "Guardian Spirit identifies Holy")
        equal(lib:IsEnemy("holy-guid"), true, "hostile flags are respected")
        cast("unknown-guid", 6358)
        cast("failed-guid", 10060, 1, "SPELL_CAST_FAILED")
        equal(lib:GetSpecID("unknown-guid"), nil, "unmapped spells do not guess a spec")
        equal(lib:GetSpecID("failed-guid"), nil, "failed casts do not identify a spec")
    end)
    test("every Penance cast rank identifies Discipline", function()
        local lib, cast = setup(base)
        for _, spellID in ipairs({47540, 53005, 53006, 53007}) do
            local guid = "priest-" .. spellID
            cast(guid, spellID)
            equal(lib:GetSpecID(guid), 256, "Penance rank " .. spellID)
        end
    end)
end

print("Passed " .. cases .. " spec detection tests")
