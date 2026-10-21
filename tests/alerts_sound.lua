-- Run from the addon directory with Lua 5.1: lua tests/alerts_sound.lua
arg[2] = "harness"
local harness = assert(loadfile("tests/classicon_auras.lua"))()
arg[2] = nil
local equal = harness.equal
local cases = 0
local soundName, soundPath = "Test alert", [[Interface\AddOns\Test\alert.wav]]
local color = {r = 1, g = 0, b = 0, a = 1}

local function test(name, run)
    run()
    cases = cases + 1
    print("ok - " .. name)
end

local function setup()
    local health = {value = 20, maximum = 100, dead = false}
    UnitHealth = function() return health.value end
    UnitHealthMax = function() return health.maximum end
    UnitIsDeadOrGhost = function() return health.dead end
    local state = harness.setup(nil, true)
    GetLocale = function() return "enUS" end
    local path = "libs/LibSharedMedia-3.0/LibSharedMedia-3.0/LibSharedMedia-3.0.lua"
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a"):gsub("^\239\187\191", "")
    file:close()
    assert(loadstring(source, "@" .. path))()
    local media = LibStub("LibSharedMedia-3.0")
    media:Register("sound", soundName, soundPath)
    media:Register("sound", "Empty", "")
    state.health, state.sounds, state.media = health, {}, media
    state.flashes, state.flashStarts = {}, 0
    PlaySoundFile = function(...)
        equal(select("#", ...), 1, "3.3.5a playback uses only the file path")
        state.sounds[#state.sounds + 1] = (...)
    end
    local alerts = state.modules.Alerts
    alerts.frame = {arena1 = {}, arena2 = {}, party1 = {}}
    alerts.StartFlash = function(_, unit, flashColor)
        state.flashes[unit] = flashColor
        state.flashStarts = state.flashStarts + 1
    end
    alerts.SetFlashColor = function(_, unit, flashColor)
        assert(state.flashes[unit], "color changes require an existing flash")
        state.flashes[unit] = flashColor
    end
    alerts.StopFlash = function(_, unit) state.flashes[unit] = nil end
    alerts.QueueLoopEvent = function() end
    state.addon.Log = function() end
    state.addon.GetUnitIdByGUID = function(_, guid)
        if guid == "enemy" then return "arena1" end
    end
    return state, alerts
end

test("built-in sounds are registered without another media addon", function()
    local state = setup()
    GladiusExDB = nil
    state.addon:OnInitialize()
    equal(state.media:Fetch("sound", "Raid warning (GladiusEx)", true),
        [[Sound\Interface\RaidWarning.wav]], "raid warning available")
    equal(state.media:Fetch("sound", "Ready check (GladiusEx)", true),
        [[Sound\Interface\ReadyCheck.wav]], "ready check available")
end)

test("silent defaults and missing media do not play fallback sounds", function()
    local state, alerts = setup()
    state.media:SetDefault("sound", soundName)
    for index, sound in ipairs({false, "None", "Missing sound", "Empty"}) do
        alerts:SetAlert("arena1", "silent" .. index, 10, color, sound or nil)
    end
    alerts:Test("arena1")
    equal(#state.sounds, 0, "disabled, unavailable and test alerts remain silent")
    equal(alerts.db.arena.healthSound, "None", "health is silent by default")
    local options = alerts:GetOptions("arena")
    for spell, rule in pairs(alerts.db.arena.castsSpells) do
        if rule then
            equal(options.casts.args[state.addon:SpellRuleKey(spell)].args.sound.get(),
                "None", "legacy spell rules are silent")
        end
    end
end)

test("each newly active alert sounds once, including lower-priority alerts", function()
    local state, alerts = setup()
    alerts:SetAlert("arena1", "high", 20, color, soundName)
    alerts:SetAlert("arena1", "high", 20, color, soundName)
    alerts:SetAlert("arena1", "low", 10, color, soundName)
    equal(#state.sounds, 2, "only new alerts sound")
    equal(state.sounds[1], soundPath, "registered file played")
    alerts:ClearAlert("arena1", "high")
    equal(#state.sounds, 2, "priority fallback does not sound again")
    alerts:SetAlert("arena1", "high", 20, color, soundName)
    alerts:SetAlert("arena2", "high", 20, color, soundName)
    equal(#state.sounds, 4, "reactivation and another unit each sound")
    alerts:Reset("arena1")
    alerts:SetAlert("arena1", "high", 20, color, soundName)
    equal(#state.sounds, 5, "reset permits a new alert")
end)

test("low health sounds on threshold crossings and respects group settings", function()
    local state, alerts = setup()
    alerts.db.arena.healthSound = soundName
    alerts:UNIT_HEALTH(nil, "arena1")
    alerts:UNIT_HEALTH(nil, "arena1")
    alerts:UNIT_HEALTH(nil, "party1")
    equal(#state.sounds, 1, "persistent low health and silent party do not repeat")
    state.health.value = 50
    alerts:UNIT_HEALTH(nil, "arena1")
    state.health.value = 10
    alerts:UNIT_HEALTH(nil, "arena1")
    equal(#state.sounds, 2, "second threshold crossing sounds")
    state.health.dead = true
    alerts:UNIT_HEALTH(nil, "arena1")
    equal(#state.sounds, 2, "death clears the alert silently")
    state.health.dead = false
    alerts.db.arena.health = false
    alerts:UNIT_HEALTH(nil, "arena1")
    equal(#state.sounds, 2, "disabled health alerts stay silent")
end)

test("aura sounds follow exact spell rules without repeating on refresh", function()
    local state, alerts = setup()
    alerts.db.arena.aurasSpells[49010] = {priority = 10, color = color, sound = soundName}
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 24131}}
    alerts:UNIT_AURA(nil, "arena1")
    equal(#state.sounds, 0, "unmatched rank stays silent")
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 49010}}
    alerts:UNIT_AURA(nil, "arena1")
    alerts:UNIT_AURA(nil, "arena1")
    equal(#state.sounds, 1, "refresh does not repeat")
    state.auras.HARMFUL = {}
    alerts:UNIT_AURA(nil, "arena1")
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 49010}}
    alerts:UNIT_AURA(nil, "arena1")
    equal(#state.sounds, 2, "reapplication sounds")
end)

test("sound-only aura alerts never flash and sound again after reapplication", function()
    local state, alerts = setup()
    alerts.db.arena.aurasSpells[49010] = {priority = 50, color = color, sound = soundName, flash = false}
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 49010}}
    alerts:UNIT_AURA(nil, "arena1")
    alerts:UNIT_AURA(nil, "arena1")
    equal(state.flashStarts, 0, "sound-only aura never starts flashing")
    equal(#state.sounds, 1, "sound plays once while active")
    equal(alerts:IsAlertActive("arena1", "aura_number:49010"), 50, "sound-only aura remains tracked")
    state.auras.HARMFUL = {}
    alerts:UNIT_AURA(nil, "arena1")
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 49010}}
    alerts:UNIT_AURA(nil, "arena1")
    equal(#state.sounds, 2, "reapplication plays sound again")
    equal(state.flashStarts, 0, "reapplication still does not flash")
end)

test("sound-only auras do not override or hide other flashing alerts", function()
    local state, alerts = setup()
    alerts.db.arena.aurasSpells[49010] = {priority = 50, color = color, sound = soundName, flash = false}
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 49010}}
    alerts:UNIT_HEALTH(nil, "arena1")
    local healthColor = alerts.db.arena.healthColor
    alerts:UNIT_AURA(nil, "arena1")
    equal(state.flashes.arena1, healthColor, "sound-only aura cannot replace the health flash")
    state.health.value = 100
    alerts:UNIT_HEALTH(nil, "arena1")
    equal(state.flashes.arena1, nil, "sound-only aura cannot keep the frame flashing")
    alerts.db.arena.aurasSpells[64044] = {priority = 0, color = color}
    state.auras.HARMFUL[2] = {name = "Psychic Horror", id = 64044}
    alerts:UNIT_AURA(nil, "arena1")
    equal(state.flashes.arena1, color, "a new visual alert flashes beside a sound-only aura")
    alerts:UpdateAlertColor("arena1")
    equal(state.flashes.arena1, color, "priority-zero visual alert remains eligible")
    state.auras.HARMFUL[2] = nil
    alerts:UNIT_AURA(nil, "arena1")
    equal(state.flashes.arena1, nil, "removing the visual aura stops flashing")
    equal(#state.sounds, 1, "visual priority changes do not repeat the aura sound")
end)

test("aura flashing can be toggled immediately without replaying sound", function()
    local state, alerts = setup()
    alerts.db.arena.aurasSpells[49010] = {priority = 50, color = color, sound = soundName}
    alerts.db.party.aurasSpells[49010] = {priority = 50, color = color, sound = soundName}
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 49010}}
    for _, unit in ipairs({"arena1", "arena2", "party1"}) do alerts:UNIT_AURA(nil, unit) end
    local controls = alerts:GetOptions("arena").auras.args["number:49010"].args
    equal(controls.flash.get(), true, "existing rules flash by default")
    controls.flash.set({}, false)
    equal(state.flashes.arena1, nil, "first arena frame stops immediately")
    equal(state.flashes.arena2, nil, "second arena frame stops immediately")
    equal(state.flashes.party1, color, "party setting is independent")
    equal(#state.sounds, 3, "disabling flashing does not replay sound")
    alerts:UNIT_HEALTH(nil, "arena1")
    local healthColor = alerts.db.arena.healthColor
    equal(state.flashes.arena1, healthColor, "health still flashes beside the sound-only aura")
    controls.flash.set({}, true)
    equal(state.flashes.arena1, color, "higher-priority aura replaces the health flash")
    equal(state.flashes.arena2, color, "hidden frame starts flashing again")
    controls.flash.set({}, false)
    equal(state.flashes.arena1, healthColor, "disabling aura flash restores the health flash")
    equal(state.flashes.arena2, nil, "frame without another visual alert stops flashing")
    equal(#state.sounds, 3, "toggling flashing never replays sound")
end)

test("test mode clears old flashes without creating an unconditional alert", function()
    local state, alerts = setup()
    alerts:SetAlert("arena1", "previous", 10, color)
    equal(state.flashes.arena1, color, "previous flash is visible")
    alerts.db.arena.health, alerts.db.arena.casts, alerts.db.arena.auras = false, false, false
    alerts:Test("arena1")
    equal(state.flashes.arena1, nil, "disabled alerts leave test frames without flashing")
    equal(alerts:IsAlertActive("arena1", "previous"), nil, "previous alert is cleared")
    equal(alerts:IsAlertActive("arena1", "test"), nil, "no synthetic test alert is created")
    alerts.db.arena.auras = true
    alerts.db.arena.aurasSpells[49010] = {priority = 50, color = color, sound = soundName, flash = false}
    alerts:Test("arena1")
    equal(state.flashes.arena1, nil, "sound-only aura configuration does not force a test flash")
    equal(#state.sounds, 0, "test frames do not force sounds")
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 49010}}
    alerts:UNIT_AURA(nil, "arena1")
    equal(state.flashes.arena1, nil, "actual sound-only aura still does not flash")
    equal(#state.sounds, 1, "actual aura still plays its configured sound")
    alerts:Test("arena1")
    alerts:Test("arena1")
    equal(state.flashes.arena1, nil, "repeated test refreshes remain without flashing")
    equal(#state.sounds, 1, "test refreshes do not replay sound")
end)

test("disabled groups stay silent while another group has Alerts enabled", function()
    local state, alerts = setup()
    alerts.IsUnitEnabled = function(_, unit) return unit:match("^arena") ~= nil end
    alerts.db.party.healthSound = soundName
    alerts:UNIT_HEALTH(nil, "party1")
    alerts.db.arena.healthSound = soundName
    alerts:UNIT_HEALTH(nil, "arena1")
    equal(#state.sounds, 1, "only the enabled group sounds")
end)

for _, exact in ipairs({false, true}) do
    test((exact and "exact" or "name") .. " cast sounds once across start, stop and success events", function()
        local state, alerts = setup()
        alerts.db.arena.castsSpells[exact and 49010 or "Wyvern Sting"] =
            {priority = 10, color = color, sound = soundName}
        alerts:UNIT_SPELLCAST_START(nil, "arena1", "Wyvern Sting", "Rank 6", 1, 49010)
        alerts:UNIT_SPELLCAST_START(nil, "arena1", "Wyvern Sting", "Rank 6", 1, 49010)
        alerts:COMBAT_LOG_EVENT_UNFILTERED(nil, 100, "SPELL_CAST_START", "enemy", "Enemy", 0,
            nil, nil, 0, 49010, "Wyvern Sting")
        equal(#state.sounds, 1, "duplicate starts sound once")
        alerts:UNIT_SPELLCAST_STOP(nil, "arena1", "Wyvern Sting")
        alerts:UNIT_SPELLCAST_SUCCEEDED(nil, "arena1", "Wyvern Sting", "Rank 6", 1, 49010)
        alerts:COMBAT_LOG_EVENT_UNFILTERED(nil, 100, "SPELL_CAST_SUCCESS", "enemy", "Enemy", 0,
            nil, nil, 0, 49010, "Wyvern Sting")
        equal(#state.sounds, 1, "completion does not repeat the start sound")
    end)
end

test("instant casts and channel events sound once in either event order", function()
    local state, alerts = setup()
    alerts.db.arena.castsSpells[49010] = {priority = 10, color = color, sound = soundName}
    alerts:UNIT_SPELLCAST_SUCCEEDED(nil, "arena1", 49010)
    alerts:COMBAT_LOG_EVENT_UNFILTERED(nil, 100, "SPELL_CAST_SUCCESS", "enemy", "Enemy", 0,
        nil, nil, 0, 49010, "Wyvern Sting")
    equal(#state.sounds, 1, "instant cast sounds once")
    alerts:ClearAllAlerts("arena1")
    alerts:COMBAT_LOG_EVENT_UNFILTERED(nil, 100, "SPELL_CAST_SUCCESS", "enemy", "Enemy", 0,
        nil, nil, 0, 49010, "Wyvern Sting")
    alerts:UNIT_SPELLCAST_START("UNIT_SPELLCAST_CHANNEL_START", "arena1", "Wyvern Sting")
    equal(#state.sounds, 2, "combat log before channel start sounds once")
    alerts:ClearAllAlerts("arena1")
    alerts:UNIT_SPELLCAST_START("UNIT_SPELLCAST_CHANNEL_START", "arena1", "Wyvern Sting")
    alerts:COMBAT_LOG_EVENT_UNFILTERED(nil, 100, "SPELL_CAST_SUCCESS", "enemy", "Enemy", 0,
        nil, nil, 0, 49010, "Wyvern Sting")
    equal(#state.sounds, 3, "channel start before combat log sounds once")
end)

for _, unit in ipairs({"arena", "party"}) do
    test(unit .. " sound selections persist through ID changes, reloads and profile copies", function()
        local state, alerts = setup()
        local other = unit == "arena" and "party" or "arena"
        local options = alerts:GetOptions(unit)
        harness.validateOptions(options)
        equal(options.health.args.healthSound.dialogControl, "LSM30_Sound", "preview widget used")
        equal(options.health.args.healthSound.values()[soundName], soundPath, "media sounds listed")
        options.health.args.healthSound.set({}, soundName)
        for _, kind in ipairs({"casts", "auras"}) do
            local field = kind .. "Spells"
            local args = options[kind].args[kind == "casts" and "newCast" or "newAura"].args
            args.name.set({}, "Wyvern Sting")
            args.spellID.set({}, "49010")
            args.sound.set({}, soundName)
            if kind == "auras" then
                equal(args.flash.get(), true, "new auras flash by default")
                args.flash.set({}, false)
            end
            -- Building another group's options must not change this pending sound.
            alerts:GetOptions(other)
            args.add.func()
            local controls = options[kind].args["string:Wyvern Sting"].args
            equal(controls.sound.get(), soundName, "new rule retains selected sound")
            controls.checkSpellID.set({}, true)
            equal(alerts.db[unit][field][49010].sound, soundName, "ID toggle retains sound")
            if kind == "auras" then
                equal(alerts.db[unit][field][49010].flash, false, "ID toggle retains flashing choice")
            end
            equal(alerts.db[other][field][49010], nil, "other group unchanged")
        end
        state = harness.reload(state)
        alerts = state.modules.Alerts
        equal(alerts.db[unit].healthSound, soundName, "health selection survives reload")
        equal(alerts.db[unit].aurasSpells[49010].flash, false, "flashing choice survives reload")
        for _, field in ipairs({"castsSpells", "aurasSpells"}) do
            equal(alerts.db[unit][field][49010].sound, soundName, "spell selection survives reload")
        end
        state.addon.dbi:SetProfile("Copy")
        state.addon.dbi:CopyProfile("Default")
        options = alerts:GetOptions(unit)
        equal(options.health.args.healthSound.get(), soundName, "health selection copied")
        equal(options.auras.args["number:49010"].args.flash.get(), false, "flashing choice copied")
        options.auras.args["number:49010"].args.flash.set({}, true)
        options.casts.args["number:49010"].args.sound.set({}, "None")
        state.addon.dbi:SetProfile("Default")
        equal(alerts.db[unit].castsSpells[49010].sound, soundName, "original profile unchanged")
        equal(alerts.db[unit].aurasSpells[49010].flash, false, "original flashing choice unchanged")
        alerts.db[unit].health, alerts.db[unit].casts, alerts.db[unit].auras = false, false, false
        options = alerts:GetOptions(unit)
        assert(options.health.args.healthSound.disabled(), "disabled health control")
        assert(options.casts.args["number:49010"].args.sound.disabled(), "disabled cast control")
        assert(options.auras.args["number:49010"].args.sound.disabled(), "disabled aura control")
        assert(options.auras.args["number:49010"].args.flash.disabled(), "disabled aura flashing control")
        state.addon.dbi:ResetProfile()
        equal(alerts.db[unit].healthSound, "None", "profile reset restores silence")
    end)
end

print("Passed " .. cases .. " alert sound tests")
