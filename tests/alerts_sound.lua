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
    local player = {dead = false, ghost = false}
    UnitHealth = function() return health.value end
    UnitHealthMax = function() return health.maximum end
    UnitIsDeadOrGhost = function(unit)
        if unit == "player" then return player.dead or player.ghost end
        return health.dead
    end
    local state = harness.setup(nil, true)
    state.addon.buttons = {}
    GetLocale = function() return "enUS" end
    local path = "libs/LibSharedMedia-3.0/LibSharedMedia-3.0/LibSharedMedia-3.0.lua"
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a"):gsub("^\239\187\191", "")
    file:close()
    assert(loadstring(source, "@" .. path))()
    local media = LibStub("LibSharedMedia-3.0")
    media:Register("sound", soundName, soundPath)
    media:Register("sound", "Empty", "")
    state.health, state.player, state.sounds, state.media = health, player, {}, media
    state.flashes, state.flashStarts = {}, 0
    PlaySoundFile = function(...)
        equal(select("#", ...), 1, "3.3.5a playback uses only the file path")
        state.sounds[#state.sounds + 1] = (...)
    end
    local alerts = state.modules.Alerts
    alerts.frame = {arena1 = {}, arena2 = {}, player = {}, party1 = {}, party2 = {}, party3 = {}, party4 = {}}
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

for _, group in ipairs({"arena", "party"}) do
    test(group .. " death suppression stops flashes and silences health, aura and cast alerts until resurrection", function()
        local state, alerts = setup()
        local target = group .. "1"
        local companion = group .. "2"
        local other = group == "arena" and "party1" or "arena1"
        local events = {}
        alerts.RegisterEvent = function(_, event, handler) events[event] = handler end
        alerts:OnEnable()
        local function fire(event)
            assert(events[event], event .. " is registered")
            alerts[events[event]](alerts, event)
        end
        alerts:GetOptions(group).general.args.disableWhenDead.set({}, true)
        alerts.db[group].healthSound = soundName
        alerts.db[group].aurasSpells[49010] = {priority = 20, color = color, sound = soundName}
        alerts.db[group].castsSpells[49010] = {priority = 30, color = color, sound = soundName}
        state.auras.HARMFUL = {{name = "Wyvern Sting", id = 49010}}
        local function trigger(unit)
            alerts:UNIT_HEALTH(nil, unit)
            alerts:UNIT_AURA(nil, unit)
            alerts:UNIT_SPELLCAST_START(nil, unit, 49010)
        end
        trigger(target)
        alerts:SetAlert(other, "other", 10, color, soundName)
        equal(#state.sounds, 4, "all alert kinds work while alive")
        state.player.dead = true
        fire("PLAYER_DEAD")
        equal(state.flashes[target], nil, "death immediately stops an active flash")
        equal(state.flashes[other], color, "other group's flashes remain active")
        trigger(companion)
        alerts:UNIT_SPELLCAST_STOP(nil, target, 49010)
        equal(state.flashes[target], nil, "priority fallback stays hidden while dead")
        equal(state.flashes[companion], nil, "new alerts stay hidden while dead")
        equal(#state.sounds, 4, "new health, aura and cast alerts stay silent while dead")
        state.player.dead, state.player.ghost = false, true
        fire("PLAYER_ALIVE")
        equal(state.flashes[target], nil, "releasing spirit keeps alerts suppressed")
        alerts:SetAlert(target, "ghost", 5, color, soundName)
        equal(#state.sounds, 4, "ghost alerts stay silent")
        state.player.ghost = false
        fire("PLAYER_UNGHOST")
        equal(state.flashes[target], color, "resurrection restores the active aura flash")
        equal(state.flashes[companion], color, "alerts tracked while dead resume flashing")
        equal(#state.sounds, 4, "resurrection does not replay sounds from while dead")
        alerts:Reset(companion)
        trigger(companion)
        equal(#state.sounds, 7, "new alerts sound normally after resurrection")
        state.player.dead = true
        fire("PLAYER_DEAD")
        state.player.dead = false
        fire("PLAYER_ALIVE")
        equal(state.flashes[companion], color, "resurrection without releasing restores flashes")
    end)

    test(group .. " death suppression is optional and toggles immediately in Alerts General", function()
        local state, alerts = setup()
        local target, other = group .. "1", group == "arena" and "party" or "arena"
        local options = alerts:GetOptions(group)
        harness.validateOptions(options)
        local control = options.general.args.disableWhenDead
        equal(control.type, "toggle", "General exposes the toggle")
        equal(control.get(), false, "suppression is off by default")
        state.player.dead = true
        alerts:SetAlert(target, "active", 10, color, soundName)
        equal(#state.sounds, 1, "default preserves alerts while dead")
        equal(state.flashes[target], color, "default preserves flashing while dead")
        control.set({}, true)
        equal(control.get(), true, "toggle saves its value")
        equal(alerts.db[other].disableWhenDead, false, "other group retains its choice")
        equal(state.flashes[target], nil, "enabling while dead immediately stops flashing")
        control.set({}, false)
        equal(state.flashes[target], color, "disabling while dead immediately restores flashing")
        equal(#state.sounds, 1, "toggling does not repeat an existing sound")
        alerts:SetAlert(target, "new", 20, color, soundName)
        equal(#state.sounds, 2, "disabling restores new sounds while dead")
        alerts.IsUnitEnabled = function() return false end
        equal(control.disabled(), true, "disabled module disables the control")
    end)

    test(group .. " death suppression persists through reloads and profile copies", function()
        local state, alerts = setup()
        local other = group == "arena" and "party" or "arena"
        alerts:GetOptions(group).general.args.disableWhenDead.set({}, true)
        state = harness.reload(state)
        alerts = state.modules.Alerts
        equal(alerts:GetOptions(group).general.args.disableWhenDead.get(), true, "choice survives reload")
        equal(alerts.db[other].disableWhenDead, false, "other group remains independent")
        state.addon.dbi:SetProfile("Copy")
        state.addon.dbi:CopyProfile("Default")
        equal(alerts.db[group].disableWhenDead, true, "choice is copied with the profile")
        state.addon.dbi:ResetProfile()
        equal(alerts.db[group].disableWhenDead, false, "profile reset restores the default")
    end)
end

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

test("party health, aura and cast sounds exclude the player while keeping visual alerts", function()
    local state, alerts = setup()
    alerts.db.party.healthSound = soundName
    alerts.db.party.aurasSpells[49010] = {priority = 20, color = color, sound = soundName}
    alerts.db.party.castsSpells[49010] = {priority = 30, color = color, sound = soundName}
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 49010}}
    for index, unit in ipairs({"player", "party1", "party2", "party3", "party4"}) do
        alerts:UNIT_HEALTH(nil, unit)
        alerts:UNIT_AURA(nil, unit)
        alerts:UNIT_SPELLCAST_START(nil, unit, "Wyvern Sting", "Rank 6", 1, 49010)
        equal(#state.sounds, (index - 1) * 3, unit .. " only party members sound")
        equal(alerts:IsAlertActive(unit, "health"), 10, unit .. " health alert remains active")
        equal(alerts:IsAlertActive(unit, "aura_number:49010"), 20, unit .. " aura alert remains active")
        equal(alerts:IsAlertActive(unit, "cast_number:49010"), 30, unit .. " cast alert remains active")
        equal(state.flashes[unit], color, unit .. " visual alerts still flash")
    end
end)

test("healer-only party aura sounds require a healing specialization", function()
    local state, alerts = setup()
    alerts.db.party.aurasSpells[49010] = {priority = 20, color = color, sound = soundName, healerOnlySound = true}
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 49010}}
    local expectedSounds = 0
    for _, spec in ipairs({
        {65, true}, {105, true}, {256, true}, {257, true}, {264, true},
        {66, false}, {70, false}, {102, false}, {103, false}, {258, false},
        {262, false}, {263, false}, {250, false}, {62, false}, {false, false},
    }) do
        alerts:Reset("party1")
        state.addon.buttons.party1 = {specID = spec[1] or nil}
        alerts:UNIT_AURA(nil, "party1")
        if spec[2] then expectedSounds = expectedSounds + 1 end
        equal(#state.sounds, expectedSounds, "specialization " .. tostring(spec[1]))
        equal(state.flashes.party1, color, "healer filtering preserves flashing")
        equal(alerts:IsAlertActive("party1", "aura_number:49010"), 20, "visual alert remains active")
        alerts:UNIT_AURA(nil, "party1")
        equal(#state.sounds, expectedSounds, "repeated aura events do not replay sound")
    end
    equal(state.sounds[1], soundPath, "selected sound is used")
    alerts.frame.party4 = {}
    alerts:UNIT_AURA(nil, "party4")
    equal(#state.sounds, expectedSounds, "a missing unit button cannot identify a healer")
    state.addon.buttons.party1 = {specID = 256}
    state.auras.HARMFUL = {}
    alerts:UNIT_AURA(nil, "party1")
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 49010}}
    alerts.db.party.aurasSpells[49010].flash = false
    alerts:UNIT_AURA(nil, "party1")
    equal(#state.sounds, expectedSounds + 1, "reapplied CC sounds again on a healer")
    equal(state.flashes.party1, nil, "healer-only sound works with flashing disabled")
end)

test("healer-only aura sound is optional per rule and does not filter other alert kinds or arena", function()
    local state, alerts = setup()
    state.addon.buttons.party1 = {specID = 258}
    alerts.db.party.healthSound = soundName
    alerts.db.party.aurasSpells[49010] = {priority = 20, color = color, sound = soundName, healerOnlySound = true}
    alerts.db.party.aurasSpells[118] = {priority = 10, color = color, sound = soundName}
    alerts.db.party.castsSpells[49010] = {priority = 30, color = color, sound = soundName}
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 49010}, {name = "Polymorph", id = 118}}
    alerts:UNIT_AURA(nil, "party1")
    equal(#state.sounds, 1, "an unrestricted rule still sounds on a damage spec")
    alerts:UNIT_HEALTH(nil, "party1")
    alerts:UNIT_SPELLCAST_START(nil, "party1", 49010)
    equal(#state.sounds, 3, "health and cast sounds still work on damage specs")
    alerts.db.arena.aurasSpells[49010] = {priority = 20, color = color, sound = soundName, healerOnlySound = true}
    alerts:UNIT_AURA(nil, "arena1")
    equal(#state.sounds, 4, "arena aura sounds are unaffected by a copied party setting")
    alerts:GetOptions("party").auras.args["number:49010"].args.healerOnlySound.set({}, false)
    alerts:Reset("party1")
    alerts:UNIT_AURA(nil, "party1")
    equal(#state.sounds, 6, "turning the filter off restores sounds for any party specialization")
end)

test("party settings expose healer-only sound through their player unit", function()
    local state, alerts = setup()
    SlashCmdList = {}
    local file = assert(io.open("options.lua", "rb"))
    local source = file:read("*a"):gsub("^\239\187\191", "")
    file:close()
    assert(loadstring(source, "@options.lua"))()
    alerts.db.party.aurasSpells[49010] = {priority = 20, color = color}
    alerts.db.arena.aurasSpells[49010] = {priority = 20, color = color}
    for _, unit in ipairs({"player", "party1", "party", "arena1", "arena"}) do
        local options = state.addon:SetupModuleOptions(unit, "Alerts", alerts, 1).args
        local hidden = unit == "arena1" or unit == "arena"
        equal(options.auras.args.newAura.args.healerOnlySound.hidden, hidden, unit .. " new aura visibility")
        local control = options.auras.args["number:49010"].args.healerOnlySound
        equal(control.hidden, hidden, unit .. " existing aura visibility")
        local enabled = options.auras.args["number:49010"].args.enabled
        equal(enabled.type, "toggle", unit .. " exposes the aura enable control")
        equal(enabled.get(), true, unit .. " existing auras start enabled")
        if not hidden then
            control.set({}, true)
            equal(alerts.db.party.aurasSpells[49010].healerOnlySound, true, "real party page writes party settings")
            control.set({}, false)
        end
        harness.validateOptions(options)
    end
end)

test("party healer-only sound options persist through spell edits, reloads and profile copies", function()
    local state, alerts = setup()
    alerts.db.party.aurasSpells[118] = {priority = 20, color = color}
    local options = alerts:GetOptions("party")
    local existing = options.auras.args["number:118"].args.healerOnlySound
    equal(existing.get(), false, "existing rules start unrestricted")
    equal(existing.hidden, false, "party aura rules offer the option")
    local args = options.auras.args.newAura.args
    equal(args.healerOnlySound.get(), false, "new rules start unrestricted")
    args.name.set({}, "Wyvern Sting")
    args.spellID.set({}, "49010, 24131")
    args.healerOnlySound.set({}, true)
    local arenaOptions = alerts:GetOptions("arena")
    equal(arenaOptions.auras.args.newAura.args.healerOnlySound.hidden, true, "arena hides the new rule control")
    equal(arenaOptions.auras.args.newAura.args.healerOnlySound.get(), false, "pending choices are separate")
    args.add.func()
    local controls = options.auras.args["string:Wyvern Sting"].args
    equal(controls.healerOnlySound.get(), true, "new name rule retains its choice")
    controls.checkSpellID.set({}, true)
    controls = options.auras.args["number:49010"].args
    equal(controls.healerOnlySound.get(), true, "switching to exact IDs retains its choice")
    controls.spellID.set({}, "24131, 49010")
    state = harness.reload(state)
    alerts = state.modules.Alerts
    options = alerts:GetOptions("party")
    controls = options.auras.args["number:24131"].args
    equal(controls.healerOnlySound.get(), true, "choice survives ID reordering and reload")
    harness.validateOptions(options)
    alerts.db.arena.aurasSpells[49010] = {priority = 20, color = color}
    equal(alerts:GetOptions("arena").auras.args["number:49010"].args.healerOnlySound.hidden, true,
        "arena hides the existing rule control")
    state.addon.dbi:SetProfile("Copy")
    state.addon.dbi:CopyProfile("Default")
    controls = alerts:GetOptions("party").auras.args["number:24131"].args
    equal(controls.healerOnlySound.get(), true, "choice is copied with the profile")
    controls.healerOnlySound.set({}, false)
    equal(controls.healerOnlySound.get(), false, "copied profile can disable the filter")
    state.addon.dbi:SetProfile("Default")
    options = alerts:GetOptions("party")
    controls = options.auras.args["number:24131"].args
    equal(controls.healerOnlySound.get(), true, "original profile remains independent")
    alerts.db.party.auras = false
    assert(controls.healerOnlySound.disabled(), "disabled aura rules disable the control")
    assert(options.auras.args.newAura.args.healerOnlySound.disabled(), "disabled auras disable the new rule control")
    alerts.db.party.auras = true
    alerts.IsUnitEnabled = function() return false end
    assert(controls.healerOnlySound.disabled(), "disabled module disables the control")
end)

for _, unit in ipairs({"arena1", "player"}) do
    test(unit .. " aura alerts can be disabled and restored immediately without losing settings", function()
        local state, alerts = setup()
        local target = unit == "player" and "party1" or "arena1"
        local companion = unit == "player" and "party2" or "arena2"
        local other = unit == "player" and "arena1" or "party1"
        alerts.frame = {[target] = {}, [companion] = {}, [other] = {}}
        local rule = {priority = 50, color = color, sound = soundName}
        alerts.db[unit].aurasSpells[49010] = rule
        alerts.db[other].aurasSpells[49010] = {priority = 50, color = color, sound = soundName}
        state.auras.HARMFUL = {{name = "Wyvern Sting", id = 49010}}
        alerts:UNIT_HEALTH(nil, target)
        for frame in pairs(alerts.frame) do alerts:UNIT_AURA(nil, frame) end
        equal(#state.sounds, 3, "enabled aura alerts sound normally")
        local controls = alerts:GetOptions(unit).auras.args["number:49010"].args
        equal(controls.enabled.get(), true, "existing aura starts enabled")
        controls.enabled.set({}, false)
        equal(controls.enabled.get(), false, "aura can be turned off")
        equal(alerts.db[unit].aurasSpells[49010], rule, "the original rule is retained")
        equal(rule.priority, 50, "priority is retained")
        equal(rule.color, color, "color is retained")
        equal(rule.sound, soundName, "sound is retained")
        equal(state.flashes[target], alerts.db[unit].healthColor, "another active alert resumes flashing")
        equal(state.flashes[companion], nil, "other frames stop the disabled aura flash immediately")
        equal(state.flashes[other], color, "the other group's aura remains active")
        alerts:UNIT_AURA(nil, target)
        alerts:UNIT_AURA(nil, companion)
        equal(#state.sounds, 3, "disabled auras stay silent")
        assert(not alerts:IsAlertActive(target, "aura_number:49010"), "disabled aura is inactive")
        equal(alerts:GetOptions(unit).auras.args["number:49010"].args.enabled.get(), false,
            "the disabled aura stays listed when options rebuild")
        controls.enabled.set({}, true)
        equal(state.flashes[target], color, "reenabling restores the active aura flash")
        equal(state.flashes[companion], color, "reenabling refreshes all matching frames")
        equal(#state.sounds, 5, "reenabling an active aura sounds once per matching frame")
        controls.enabled.set({}, true)
        equal(#state.sounds, 5, "repeated enabling does not repeat the active alert")
        alerts.db[unit].auras = false
        assert(controls.enabled.disabled(), "the group aura switch disables the control")
    end)

    test(unit .. " disabled aura choices survive spell edits, reloads and profile copies", function()
        local state, alerts = setup()
        local options = alerts:GetOptions(unit)
        local input = options.auras.args.newAura.args
        input.name.set({}, "Wyvern Sting")
        input.spellID.set({}, "49010, 24131")
        input.priority.set({}, 42)
        input.sound.set({}, soundName)
        input.flash.set({}, false)
        input.healerOnlySound.set({}, true)
        input.add.func()
        local controls = options.auras.args["string:Wyvern Sting"].args
        equal(controls.enabled.get(), true, "new auras start enabled")
        controls.enabled.set({}, false)
        controls.checkSpellID.set({}, true)
        controls = options.auras.args["number:49010"].args
        equal(controls.enabled.get(), false, "switching to exact IDs preserves the choice")
        controls.spellID.set({}, "24131, 49010")
        state = harness.reload(state)
        alerts = state.modules.Alerts
        options = alerts:GetOptions(unit)
        harness.validateOptions(options)
        controls = options.auras.args["number:24131"].args
        equal(controls.enabled.get(), false, "the disabled aura stays listed after reordering IDs and reloading")
        equal(controls.priority.get(), 42, "saved priority is retained")
        equal(controls.sound.get(), soundName, "saved sound is retained")
        equal(controls.flash.get(), false, "saved flashing choice is retained")
        equal(controls.healerOnlySound.get(), true, "saved healer filter is retained")
        state.addon.dbi:SetProfile("Copy")
        state.addon.dbi:CopyProfile("Default")
        controls = alerts:GetOptions(unit).auras.args["number:24131"].args
        equal(controls.enabled.get(), false, "copied profiles retain disabled auras")
        controls.enabled.set({}, true)
        equal(controls.enabled.get(), true, "copied profiles can reenable the aura")
        state.addon.dbi:SetProfile("Default")
        controls = alerts:GetOptions(unit).auras.args["number:24131"].args
        equal(controls.enabled.get(), false, "reenabling the copy leaves the original disabled")
        controls.delete.func()
        state = harness.reload(state)
        equal(state.modules.Alerts:GetOptions(unit).auras.args["number:24131"], nil,
            "deletion still removes the saved aura")
    end)
end

test("a disabled exact aura rule suppresses its IDs without falling back to a name rule", function()
    local state, alerts = setup()
    alerts.frame = {arena1 = {}}
    alerts.db.arena.aurasSpells["Wyvern Sting"] = {priority = 10, color = color, sound = soundName}
    local options = alerts:GetOptions("arena1")
    local input = options.auras.args.newAura.args
    input.name.set({}, "Wyvern Sting")
    input.spellID.set({}, "49010, 24131")
    input.checkSpellID.set({}, true)
    input.sound.set({}, soundName)
    input.add.func()
    local control = options.auras.args["number:49010"].args.enabled
    control.set({}, false)
    for _, id in ipairs({49010, 24131}) do
        state.auras.HARMFUL = {{name = "Wyvern Sting", id = id}}
        alerts:UNIT_AURA(nil, "arena1")
        equal(#state.sounds, 0, "every listed ID stays silent while disabled")
        equal(state.flashes.arena1, nil, "every listed ID stays without flashing while disabled")
    end
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 19386}}
    alerts:UNIT_AURA(nil, "arena1")
    equal(#state.sounds, 1, "unlisted IDs still use the separate name rule")
    control.set({}, true)
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 24131}}
    alerts:UNIT_AURA(nil, "arena1")
    equal(#state.sounds, 2, "reenabling restores every listed exact ID")
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

test("comma-separated aura IDs share sound and flashing controls without duplicate sounds", function()
    local state, alerts = setup()
    local options = alerts:GetOptions("arena")
    local input = options.auras.args.newAura.args
    input.name.set({}, "Wyvern Sting")
    input.spellID.set({}, "49010, 24131")
    input.checkSpellID.set({}, true)
    input.add.func({})
    local controls = options.auras.args["number:49010"].args
    controls.sound.set({}, soundName)
    controls.flash.set({}, false)
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 24131}}
    alerts:UNIT_AURA(nil, "arena1")
    equal(#state.sounds, 1, "non-first ID uses the configured sound")
    equal(state.flashStarts, 0, "non-first ID obeys the flashing toggle")
    state.auras.HARMFUL[2] = {name = "Wyvern Sting", id = 49010}
    alerts:UNIT_AURA(nil, "arena1")
    equal(#state.sounds, 1, "another listed ID does not duplicate the active alert sound")
    controls.flash.set({}, true)
    assert(state.flashes.arena1, "flashing can be enabled for the group while active")
    state.auras.HARMFUL[2] = nil
    alerts:UNIT_AURA(nil, "arena1")
    equal(#state.sounds, 1, "the remaining ID keeps the same active alert")
    state.auras.HARMFUL = {}
    alerts:UNIT_AURA(nil, "arena1")
    equal(state.flashes.arena1, nil, "last removal stops the flash")
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 24131}}
    alerts:UNIT_AURA(nil, "arena1")
    equal(#state.sounds, 2, "reapplication plays the group sound again")
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
