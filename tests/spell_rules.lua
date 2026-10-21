-- Run from the addon directory with Lua 5.1: lua tests/spell_rules.lua
arg[2] = "harness"
local harness = assert(loadfile("tests/classicon_auras.lua"))()
arg[2] = nil
local setup, reload, equal = harness.setup, harness.reload, harness.equal
local cases = 0
local function test(name, run)
    run()
    cases = cases + 1
    print("ok - " .. name)
end
local lists = {
    {module = "ClassIcon", group = "auraList", new = "newAura", field = "classIconAuras"},
    {module = "Auras", group = "filters", new = "newAura", field = "aurasFilterAuras"},
    {module = "Alerts", group = "auras", new = "newAura", field = "aurasSpells"},
    {module = "Alerts", group = "casts", new = "newCast", field = "castsSpells"},
}
local function options(state, list, unit)
    local module = state.modules[list.module]
    if list.module == "Auras" then module.db[unit].aurasFilterType = 1 end
    local all = module:GetOptions(unit)
    harness.validateOptions(all)
    return module, all[list.group].args
end
local function group(state, groups, key)
    return assert(groups[state.addon:SpellRuleKey(key)], "missing spell controls: " .. tostring(key))
end
local function add(state, list, unit, name, id, exact)
    local module, groups = options(state, list, unit)
    local args = groups[list.new].args
    args.name.set({}, name)
    if id then args.spellID.set({}, tostring(id)) end
    if exact then args.checkSpellID.set({}, true) end
    assert(not args.add.disabled(), "new spell enabled")
    args.add.func({})
    return module, groups
end

for _, unit in ipairs({"arena", "party"}) do
    local other = unit == "arena" and "party" or "arena"
    for _, list in ipairs(lists) do
        test(unit .. " " .. list.module .. "/" .. list.group .. ": optional IDs persist and switch matching", function()
            local state = setup(nil, true)
            local name, id, sibling = "Wyvern Sting", 49010, 24131
            local module, groups = add(state, list, unit, name, id, false)
            local rule = module.db[unit][list.field][name]
            local controls = group(state, groups, name).args
            if controls.priority then controls.priority.set({}, 7) end
            if controls.color then controls.color.set({}, 0.2, 0.3, 0.4, 0.5) end
            rule = module.db[unit][list.field][name]
            equal(controls.checkSpellID.get({}), false, "ID alone does not enable exact matching")
            equal(state.addon:GetSpellRule(module.db[unit], list.field, name, sibling), rule, "name accepts another effect")
            equal(module.db[other][list.field][name], nil, "other group unchanged")
            state = reload(state)
            module, groups = options(state, list, unit)
            controls = group(state, groups, name).args
            equal(controls.spellID.get({}), tostring(id), "optional ID saved")
            equal(controls.checkSpellID.get({}), false, "unchecked state saved")
            controls.checkSpellID.set({}, true)
            equal(module.db[unit][list.field][name], false, "name rule moved")
            for session = 1, 3 do
                state = reload(state)
                module, groups = options(state, list, unit)
                controls = group(state, groups, id).args
                equal(controls.name.get({}), name, "name retained for exact rule")
                equal(controls.spellID.get({}), tostring(id), "exact ID saved")
                equal(controls.checkSpellID.get({}), true, "checked state saved")
                if controls.priority then equal(controls.priority.get({}), 7, "priority retained through toggle/reload") end
                if controls.color then
                    local r, g, b, a = controls.color.get({})
                    equal(r, 0.2, "red retained")
                    equal(g, 0.3, "green retained")
                    equal(b, 0.4, "blue retained")
                    equal(a, 0.5, "alpha retained")
                end
                equal(state.addon:GetSpellRule(module.db[unit], list.field, name, sibling), false, "other effect rejected")
            end
            controls.spellID.set({}, tostring(sibling))
            equal(module.db[unit][list.field][id], false, "old ID removed")
            controls = group(state, groups, sibling).args
            controls.checkSpellID.set({}, false)
            state = reload(state)
            module, groups = options(state, list, unit)
            controls = group(state, groups, name).args
            equal(controls.spellID.get({}), tostring(sibling), "ID retained when unchecked")
            equal(controls.checkSpellID.get({}), false, "name matching restored")
            controls.spellID.set({}, "")
            equal(group(state, groups, name).args.spellID.get({}), "", "optional ID cleared")
            controls = group(state, groups, name).args
            assert(controls.checkSpellID.disabled(), "checkbox requires an ID")
            controls.spellID.set({}, tostring(id))
            group(state, groups, name).args.checkSpellID.set({}, true)
            group(state, groups, id).args.delete.func({})
            state = reload(state)
            module, groups = options(state, list, unit)
            equal(module.db[unit][list.field][id], false, "ID deletion saved")
            equal(groups[state.addon:SpellRuleKey(id)], nil, "deleted control absent")
            state.addon.dbi:SetProfile("Other")
            equal(module.db[unit][list.field][id], nil, "different profile unchanged")
            state.addon.dbi:SetProfile("Default")
            equal(module.db[unit][list.field][id], false, "original profile deletion retained")
        end)

        test(unit .. " " .. list.module .. "/" .. list.group .. ": same-name rules coexist and input is validated", function()
            local state = setup(nil, true)
            local module, groups = add(state, list, unit, "Wyvern Sting", 49010, true)
            add(state, list, unit, "Wyvern Sting", 24131, true)
            module, groups = options(state, list, unit)
            assert(group(state, groups, 49010) and group(state, groups, 24131), "separate exact entries")
            local controls = group(state, groups, 49010).args
            for _, invalid in ipairs({"0", "-1", "1.5", "1e999", "4294967296"}) do
                assert(controls.spellID.validate({}, invalid) ~= true, "invalid ID rejected")
                controls.spellID.set({}, invalid)
                equal(module.db[unit][list.field][49010] and true, true, "invalid ID edit preserves rule")
            end
            assert(controls.spellID.validate({}, "64044") ~= true, "ID must agree with spell name")
            controls.spellID.set({}, "64044")
            assert(module.db[unit][list.field][49010], "mismatched ID edit ignored")
            add(state, list, unit, "newAura")
            module, groups = options(state, list, unit)
            assert(groups[list.new].args.add and group(state, groups, "newAura"), "reserved UI name preserved")
            local input = groups[list.new].args
            input.name.set({}, "64044")
            equal(input.name.get({}), "Psychic Horror", "numeric input resolves a name")
            equal(input.spellID.get({}), "64044", "numeric input prefills optional ID")
            equal(input.checkSpellID.get({}), false, "numeric input keeps checkbox off")
            input.name.set({}, "   ")
            assert(input.add.disabled(), "empty name cannot be added")
        end)

        test(unit .. " " .. list.module .. "/" .. list.group .. ": profile copies and resets keep matching mode", function()
            local state = setup(nil, true)
            add(state, list, unit, "Wyvern Sting", 49010, false)
            state.addon.dbi:SetProfile("Copy")
            state.addon.dbi:CopyProfile("Default")
            local module, groups = options(state, list, unit)
            local controls = group(state, groups, "Wyvern Sting").args
            equal(controls.spellID.get({}), "49010", "optional ID copied")
            equal(controls.checkSpellID.get({}), false, "unchecked state copied")
            controls.checkSpellID.set({}, true)
            state = reload(state)
            module, groups = options(state, list, unit)
            equal(group(state, groups, 49010).args.checkSpellID.get({}), true, "copy exact mode persists")
            state.addon.dbi:SetProfile("Default")
            module, groups = options(state, list, unit)
            equal(group(state, groups, "Wyvern Sting").args.checkSpellID.get({}), false, "source mode unchanged")
            state.addon.dbi:SetProfile("Copy")
            state.addon.dbi:ResetProfile()
            equal(module.db[unit][list.field][49010], nil, "reset removes custom exact rule")
            state = reload(state)
            module, groups = options(state, list, unit)
            equal(module.db[unit][list.field][49010], nil, "reset persists")
        end)
    end
end

test("important aura defaults use exact IDs and retain ranks", function()
    local state = setup()
    for id in pairs(state.module.defaults_arena.classIconAuras) do
        equal(type(id), "number", "every default key is numeric")
    end
    for id, priority in pairs({[56] = 9, [20170] = 0, [12826] = 9, [49012] = 9,
        [43039] = 0.8, [2565] = 8.2, [51209] = 9, [11129] = 2.6, [64701] = 2.6}) do
        equal(state.module:GetImportantAura("arena", id), priority, "spell/rank retained: " .. id)
    end
    for _, pair in ipairs({{64044, 64058}, {49012, 49010}, {31117, 47843}}) do
        assert(state.module:GetImportantAura("arena", pair[1]), "intended effect enabled")
        equal(state.module:GetImportantAura("arena", pair[2]), nil, "different effect not enabled by shared name")
    end
end)

test("new name rules do not replace exact defaults on later reloads", function()
    local state = setup(nil, true)
    for _, unit in ipairs({"arena", "party"}) do
        add(state, lists[1], unit, "Psychic Horror")
    end
    for session = 1, 3 do
        state = reload(state)
        for _, unit in ipairs({"arena", "party"}) do
            equal(state.module:GetImportantAura(unit, "Psychic Horror"), 5, "new name rule kept")
            equal(state.module:GetImportantAura(unit, 64044), 9, "exact default still takes precedence")
            equal(state.module.db[unit].classIconAurasUseIDs, true, "migration marker saved")
        end
    end
    state.addon.dbi:SetProfile("New")
    add(state, lists[1], "arena", "Psychic Horror")
    state = reload(state)
    equal(state.module:GetImportantAura("arena", 64044), 9, "new profile marked before reload")
    state.addon.dbi:ResetProfile()
    add(state, lists[1], "arena", "Psychic Horror")
    state = reload(state)
    equal(state.module:GetImportantAura("arena", 64044), 9, "reset profile marked before reload")
end)

test("legacy name priorities and deletions migrate without replacing explicit IDs", function()
    local saved = {namespaces = {}}
    for _, namespace in ipairs({"ClassIcon", "party_ClassIcon"}) do
        saved.namespaces[namespace] = {profiles = {
            Default = {classIconAuras = {["Psychic Horror"] = false, ["Wyvern Sting"] = 6.7,
                [49012] = 8.8, ["Custom Aura"] = 4}, classIconMode = "PORTRAIT2D"},
            Other = {classIconAuras = {["Wyvern Sting"] = false}},
        }}
    end
    local state = setup(saved)
    for session = 1, 3 do
        for _, unit in ipairs({"arena", "party"}) do
            local module = state.module
            equal(module:GetImportantAura(unit, 64044), false, "old name deletion carries to exact ID")
            equal(module:GetImportantAura(unit, 19386), 6.7, "old priority carries to rank one")
            equal(module:GetImportantAura(unit, 49011), 6.7, "old priority carries to other ranks")
            equal(module:GetImportantAura(unit, 49012), 8.8, "explicit ID takes precedence")
            equal(module:GetImportantAura(unit, "Wyvern Sting"), 6.7, "user name rule retained")
            equal(module:GetImportantAura(unit, "Custom Aura"), 4, "custom name retained")
            equal(module.db[unit].classIconMode, "PORTRAIT2D", "unrelated settings retained")
        end
        state.addon.dbi:SetProfile("Other")
        equal(state.module:GetImportantAura("arena", 49012), false, "inactive profile migrated too")
        equal(state.module:GetImportantAura("party", 19386), false, "inactive party deletion migrated")
        state.addon.dbi:SetProfile("Default")
        state = reload(state)
    end
end)

test("aura whitelist and blacklist match exact effects", function()
    local state = setup(nil, true)
    local module = add(state, lists[2], "arena", "Wyvern Sting", 49010, true)
    module.db.arena.aurasFilterWhat = 6
    equal(module:IsAuraFiltered("arena1", "Wyvern Sting", 4, 49010), true, "whitelist accepts exact ID")
    equal(module:IsAuraFiltered("arena1", "Wyvern Sting", 4, 24131) and true or false, false, "whitelist rejects sibling")
    module.db.arena.aurasFilterType = 2
    equal(module:IsAuraFiltered("arena1", "Wyvern Sting", 4, 49010), false, "blacklist rejects exact ID")
    equal(module:IsAuraFiltered("arena1", "Wyvern Sting", 4, 24131), true, "blacklist accepts sibling")
    equal(module:IsAuraFiltered("arena1", "Wyvern Sting", 2, 49010), false, "buff filtering gets ID too")
    module.db.arena.aurasFilterWhat = 4
    equal(module:IsAuraFiltered("arena1", "Wyvern Sting", 2, 49010), true, "filter scope retained")
end)

local function prepareAlerts(state)
    local alerts = state.modules.Alerts
    alerts.frame = {arena1 = {}, party1 = {}}
    alerts.StartFlash, alerts.SetFlashColor, alerts.StopFlash, alerts.QueueLoopEvent = function() end, function() end, function() end, function() end
    state.addon.Log = function() end
    return alerts
end
test("aura alerts select exact effects and clear removed rules", function()
    local state = setup(nil, true)
    add(state, lists[3], "arena", "Wyvern Sting", 49010, true)
    local alerts = prepareAlerts(state)
    local key = "aura_number:49010"
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 24131}}
    alerts:UNIT_AURA(nil, "arena1")
    equal(alerts:IsAlertActive("arena1", key), nil, "sibling produces no alert")
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 49010}}
    alerts:UNIT_AURA(nil, "arena1")
    assert(alerts:IsAlertActive("arena1", key), "exact aura produces alert")
    local _, groups = options(state, lists[3], "arena")
    group(state, groups, 49010).args.delete.func({})
    alerts:UNIT_AURA(nil, "arena1")
    equal(alerts:IsAlertActive("arena1", key), false, "deleted rule clears active alert")
end)

test("cast alerts use unit-event and combat-log IDs without guessing ranks", function()
    local state = setup(nil, true)
    add(state, lists[4], "arena", "Wyvern Sting", 49010, true)
    local alerts = prepareAlerts(state)
    local key = "cast_number:49010"
    alerts:UNIT_SPELLCAST_START(nil, "arena1", "Wyvern Sting")
    equal(alerts:IsAlertActive("arena1", key), nil, "name-only unit event waits for exact ID")
    alerts:UNIT_SPELLCAST_START(nil, "arena1", "Wyvern Sting", "Rank 1", 1, 24131)
    equal(alerts:IsAlertActive("arena1", key), nil, "different rank/effect does not alert")
    alerts:UNIT_SPELLCAST_START(nil, "arena1", "Wyvern Sting", "Rank 6", 1, 49010)
    assert(alerts:IsAlertActive("arena1", key), "unit event exact ID alerts")
    alerts:UNIT_SPELLCAST_STOP(nil, "arena1", "Wyvern Sting")
    equal(alerts:IsAlertActive("arena1", key), false, "stop clears exact alert")
    alerts:UNIT_SPELLCAST_START(nil, "arena1", 49010)
    assert(alerts:IsAlertActive("arena1", key), "spectator numeric event alerts")
    alerts:UNIT_SPELLCAST_STOP(nil, "arena1")
    state.addon.GetUnitIdByGUID = function(_, guid) if guid == "enemy" then return "arena1" end end
    alerts:COMBAT_LOG_EVENT_UNFILTERED(nil, 100, "SPELL_CAST_START", "enemy", "Enemy", 0, nil, nil, 0, 49010, "Wyvern Sting")
    assert(alerts:IsAlertActive("arena1", key), "combat log supplies missing ID")
    alerts:COMBAT_LOG_EVENT_UNFILTERED(nil, 100, "SPELL_INTERRUPT", "friend", "Friend", 0, "enemy", "Enemy", 0, 2139, "Counterspell", 64, 49010, "Wyvern Sting")
    equal(alerts:IsAlertActive("arena1", key), false, "interrupt clears exact cast")
    local successes = 0
    alerts.QueueLoopEvent = function() successes = successes + 1 end
    alerts:UNIT_SPELLCAST_SUCCEEDED(nil, "arena1", 49010)
    alerts:COMBAT_LOG_EVENT_UNFILTERED(nil, 100, "SPELL_CAST_SUCCESS", "enemy", "Enemy", 0, nil, nil, 0, 49010, "Wyvern Sting")
    equal(successes, 1, "duplicate unit/combat-log success produces one alert")
    alerts:ClearAllAlerts("arena1")
    alerts:UNIT_SPELLCAST_START("UNIT_SPELLCAST_CHANNEL_START", "arena1", "Wyvern Sting")
    alerts:COMBAT_LOG_EVENT_UNFILTERED(nil, 100, "SPELL_CAST_SUCCESS", "enemy", "Enemy", 0, nil, nil, 0, 49010, "Wyvern Sting")
    assert(alerts:IsAlertActive("arena1", key), "channel success begins a persistent alert")
    alerts:UNIT_SPELLCAST_STOP("UNIT_SPELLCAST_CHANNEL_STOP", "arena1")
    equal(alerts:IsAlertActive("arena1", key), false, "channel stop clears alert")
    alerts:ClearAllAlerts("arena1")
    alerts:COMBAT_LOG_EVENT_UNFILTERED(nil, 100, "SPELL_CAST_SUCCESS", "enemy", "Enemy", 0, nil, nil, 0, 49010, "Wyvern Sting")
    alerts:UNIT_SPELLCAST_START("UNIT_SPELLCAST_CHANNEL_START", "arena1", "Wyvern Sting")
    assert(alerts:IsAlertActive("arena1", key), "channel uses observed ID if combat log arrives first")
end)

for _, unit in ipairs({"arena", "party"}) do
    test(unit .. ": every cast preset includes its optional spell ID", function()
        local state = setup(nil, true)
        local module, groups = options(state, lists[4], unit)
        local presets = {
            [2060] = "Greater Heal", [8936] = "Regrowth", [50464] = "Nourish",
            [118] = "Polymorph", [5782] = "Fear", [51514] = "Hex", [20066] = "Repentance",
            [33786] = "Cyclone", [1513] = "Scare Beast", [339] = "Entangling Roots", [2637] = "Hibernate",
        }
        for id, name in pairs(presets) do
            local rule = module.db[unit].castsSpells[name]
            local controls = group(state, groups, name).args
            equal(rule.spellID, id, "preset contains the spell ID")
            equal(controls.spellID.get({}), tostring(id), "preset ID shown in settings")
            equal(controls.checkSpellID.get({}), false, "preset still matches names")
            local healing = id == 2060 or id == 8936 or id == 50464
            equal(rule.priority, healing and 10 or 20, "existing priority retained")
            equal(rule.color.r, healing and 0 or 1, "existing red retained")
            equal(rule.color.g, healing and 1 or 0, "existing green retained")
        end
        state = reload(state)
        module, groups = options(state, lists[4], unit)
        equal(group(state, groups, "Polymorph").args.spellID.get({}), "118", "preset ID available after reload")
        local original = module.db[unit].castsSpells.Polymorph
        equal(state.addon:GetSpellRule(module.db[unit], "castsSpells", "Polymorph", 12826), original, "higher rank still matches")
        group(state, groups, "Polymorph").args.checkSpellID.set({}, true)
        for session = 1, 3 do
            state = reload(state)
            module, groups = options(state, lists[4], unit)
            equal(groups[state.addon:SpellRuleKey("Polymorph")], nil, "moved preset name stays deleted")
            equal(group(state, groups, 118).args.checkSpellID.get({}), true, "opt-in exact match saved")
            equal(state.addon:GetSpellRule(module.db[unit], "castsSpells", "Polymorph", 12826), false, "exact check rejects another rank")
        end
        group(state, groups, 118).args.checkSpellID.set({}, false)
        group(state, groups, "Polymorph").args.spellID.set({}, "")
        for session = 1, 3 do
            state = reload(state)
            module, groups = options(state, lists[4], unit)
            local controls = group(state, groups, "Polymorph").args
            equal(controls.spellID.get({}), "", "cleared preset ID stays empty")
            equal(controls.checkSpellID.get({}), false, "name matching retained after clearing ID")
        end
    end)

    test(unit .. ": deleted cast presets stay deleted after IDs are added", function()
        local state = setup(nil, true)
        local module, groups = options(state, lists[4], unit)
        group(state, groups, "Greater Heal").args.delete.func({})
        for session = 1, 3 do
            state = reload(state)
            module, groups = options(state, lists[4], unit)
            equal(groups[state.addon:SpellRuleKey("Greater Heal")], nil, "deleted preset absent from settings")
            equal(state.addon:GetSpellRule(module.db[unit], "castsSpells", "Greater Heal", 2060), false, "deleted preset cannot alert")
        end
        state.addon.dbi:ResetProfile()
        module, groups = options(state, lists[4], unit)
        equal(group(state, groups, "Greater Heal").args.spellID.get({}), "2060", "reset restores preset with ID")
    end)
end

test("preset IDs preserve old profiles, explicit IDs and saved deletions", function()
    local saved = {namespaces = {}}
    for _, namespace in ipairs({"Alerts", "party_Alerts"}) do
        saved.namespaces[namespace] = {profiles = {
            Default = {
                castsSpells = {
                    ["Greater Heal"] = false,
                    Polymorph = {priority = 33, color = {r = 0.1, g = 0.2, b = 0.3, a = 0.4}},
                    [12826] = {priority = 77, color = {r = 1, g = 1, b = 1, a = 1}},
                },
                spellRuleDetails = {castsSpells = {
                    Polymorph = {spellID = 12826}, Fear = {spellID = false},
                }},
            },
            Other = {castsSpells = {Regrowth = false}},
        }}
    end
    local state = setup(saved, true)
    for session = 1, 3 do
        for _, unit in ipairs({"arena", "party"}) do
            local module, groups = options(state, lists[4], unit)
            equal(groups[state.addon:SpellRuleKey("Greater Heal")], nil, "legacy deletion retained")
            equal(state.addon:GetSpellRule(module.db[unit], "castsSpells", "Greater Heal", 2060), false, "legacy deletion disables alert")
            equal(group(state, groups, "Polymorph").args.spellID.get({}), "12826", "user's optional ID retained")
            equal(group(state, groups, "Fear").args.spellID.get({}), "", "explicitly cleared optional ID retained")
            equal(module.db[unit].castsSpells.Polymorph.priority, 33, "custom priority retained")
            equal(module.db[unit].castsSpells.Polymorph.color.a, 0.4, "custom color retained")
            equal(module.db[unit].castsSpells[12826].priority, 77, "exact-ID rule retained")
        end
        state.addon.dbi:SetProfile("Other")
        local _, groups = options(state, lists[4], "arena")
        equal(groups[state.addon:SpellRuleKey("Regrowth")], nil, "inactive profile deletion retained")
        state.addon.dbi:SetProfile("Default")
        state = reload(state)
    end
end)

print("Passed " .. cases .. " spell rule tests")
