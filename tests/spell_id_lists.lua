-- Run from the addon directory with Lua 5.1: lua tests/spell_id_lists.lua
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
    {module = "ClassIcon", field = "classIconAuras", section = "auraList", new = "newAura"},
    {module = "Auras", field = "aurasFilterAuras", section = "filters", new = "newAura"},
    {module = "Alerts", field = "aurasSpells", section = "auras", new = "newAura"},
    {module = "Alerts", field = "castsSpells", section = "casts", new = "newCast"},
}
local function options(state, list, unit)
    local module = state.modules[list.module]
    if list.module == "Auras" then module.db[unit].aurasFilterType = 1 end
    local all = module:GetOptions(unit)
    harness.validateOptions(all)
    return module, all[list.section].args
end
local function controls(state, groups, spell)
    return assert(groups[state.addon:SpellRuleKey(spell)], "missing controls: " .. tostring(spell)).args
end
local function add(state, list, unit, name, ids, exact, priority)
    local module, groups = options(state, list, unit)
    local input = groups[list.new].args
    input.name.set({}, name)
    input.spellID.set({}, ids)
    input.checkSpellID.set({}, exact)
    if priority and input.priority then input.priority.set({}, priority) end
    input.add.func({})
    return module, groups
end

for _, unit in ipairs({"arena", "party"}) do
    local other = unit == "arena" and "party" or "arena"
    for _, list in ipairs(lists) do
        local label = unit .. " " .. list.module .. "/" .. list.section
        test(label .. ": lists keep optional matching, settings, copies and resets", function()
            local state = setup(nil, true)
            local module, groups = add(state, list, unit, "Wyvern Sting", " 49010,24131, 49010 ", false)
            local args = controls(state, groups, "Wyvern Sting")
            equal(args.spellID.get({}), "49010, 24131", "spaces normalized and duplicate removed")
            equal(args.checkSpellID.get({}), false, "IDs alone keep name matching")
            local original = module.db[unit][list.field]["Wyvern Sting"]
            equal(state.addon:GetSpellRule(module.db[unit], list.field, "Wyvern Sting", 990001), original, "name covers unlisted IDs")
            args.checkSpellID.set({}, true)
            args = controls(state, groups, 49010)
            if args.priority then args.priority.set({}, 7) end
            if args.color then args.color.set({}, 0.2, 0.3, 0.4, 0.5) end
            for session = 1, 3 do
                state = reload(state)
                module, groups = options(state, list, unit)
                args = controls(state, groups, 49010)
                equal(args.spellID.get({}), "49010, 24131", "list saved")
                equal(args.checkSpellID.get({}), true, "exact mode saved")
                equal(groups[state.addon:SpellRuleKey(24131)], nil, "one visible entry")
                for _, id in ipairs({49010, 24131}) do
                    local rule, key = state.addon:GetSpellRule(module.db[unit], list.field, "Wyvern Sting", id)
                    equal(key, 49010, "members use one alert key")
                    equal(rule, module.db[unit][list.field][49010], "members share settings")
                    if args.priority then equal(type(rule) == "table" and rule.priority or rule, 7, "priority shared") end
                    if args.color then equal(rule.color.a, 0.5, "color shared") end
                end
                equal(state.addon:GetSpellRule(module.db[unit], list.field, "Wyvern Sting", 990001), false, "unlisted ID excluded")
                equal(module.db[other][list.field][49010], nil, "other side unchanged")
            end
            state.addon.dbi:SetProfile("Copy")
            state.addon.dbi:CopyProfile("Default")
            module, groups = options(state, list, unit)
            controls(state, groups, 49010).checkSpellID.set({}, false)
            args = controls(state, groups, "Wyvern Sting")
            equal(args.spellID.get({}), "49010, 24131", "unchecking retains list")
            args.spellID.set({}, "")
            state = reload(state)
            module, groups = options(state, list, unit)
            args = controls(state, groups, "Wyvern Sting")
            equal(args.spellID.get({}), "", "cleared list saved")
            assert(args.checkSpellID.disabled(), "empty list disables exact mode")
            equal(state.addon:GetSpellRule(module.db[unit], list.field, "Wyvern Sting", 990001),
                module.db[unit][list.field]["Wyvern Sting"], "name matching restored")
            state.addon.dbi:SetProfile("Default")
            module, groups = options(state, list, unit)
            equal(controls(state, groups, 49010).checkSpellID.get({}), true, "source mode unchanged by copy")
            controls(state, groups, 49010).delete.func({})
            state = reload(state)
            module, groups = options(state, list, unit)
            for _, id in ipairs({49010, 24131}) do
                equal(module.db[unit][list.field][id], false, "deleting group removes every ID")
                equal(groups[state.addon:SpellRuleKey(id)], nil, "deleted member stays hidden")
            end
            state.addon.dbi:ResetProfile()
            state = reload(state)
            module = state.modules[list.module]
            equal(module.db[unit][list.field][49010], nil, "reset clears custom group")
        end)

        test(label .. ": invalid lists cannot partially change a rule", function()
            local state = setup(nil, true)
            local module, groups = add(state, list, unit, "Wyvern Sting", "49010, 24131", true)
            for _, input in ipairs({controls(state, groups, 49010), groups[list.new].args}) do
                if input.add then input.name.set({}, "Wyvern Sting") end
                for _, invalid in ipairs({",49010", "49010,", "49010,,24131", "49010;24131", "49010,0",
                    "49010,-1", "49010,1.5", "49010,1e3", "49010,4294967296", "49010,64044"}) do
                    assert(input.spellID.validate({}, invalid) ~= true, "invalid list rejected: " .. invalid)
                    input.spellID.set({}, invalid)
                    local rule, key = state.addon:GetSpellRule(module.db[unit], list.field, "Wyvern Sting", 24131)
                    equal(key, 49010, "failed edit preserves membership")
                    assert(rule, "failed edit preserves settings")
                end
            end
        end)

        test(label .. ": moving IDs splits overlapping groups without losing other settings", function()
            local state = setup(nil, true)
            add(state, list, unit, "Wyvern Sting", "49010, 24131", true, 4)
            local module, groups = add(state, list, unit, "Wyvern Sting", "24131", true, 8)
            equal(controls(state, groups, 49010).spellID.get({}), "49010", "old group retains its other ID")
            equal(controls(state, groups, 24131).spellID.get({}), "24131", "new rule owns moved ID")
            controls(state, groups, 49010).spellID.set({}, "49010, 19386")
            for session = 1, 3 do
                state = reload(state)
                module, groups = options(state, list, unit)
                local first, firstKey = state.addon:GetSpellRule(module.db[unit], list.field, "Wyvern Sting", 19386)
                local second, secondKey = state.addon:GetSpellRule(module.db[unit], list.field, "Wyvern Sting", 24131)
                equal(firstKey, 49010, "edited list owns new member")
                equal(secondKey, 24131, "separate ID remains independent")
                if controls(state, groups, 49010).priority then
                    equal(type(first) == "table" and first.priority or first, 4, "old settings retained")
                    equal(type(second) == "table" and second.priority or second, 8, "moved ID settings retained")
                end
                if list.module == "ClassIcon" then
                    equal(module:GetImportantAura(unit, "Wyvern Sting", 24132), 9, "remaining default ranks retained")
                end
            end
        end)
    end

    test(unit .. ": default aura ranks appear together and can be split, deleted and reset", function()
        local state = setup()
        local module, groups = options(state, lists[1], unit)
        equal(controls(state, groups, 118).spellID.get({}), "118, 12824, 12825, 12826, 28271, 28272", "Polymorph ranks and variants grouped")
        equal(groups[state.addon:SpellRuleKey(12826)], nil, "repeated rank row removed")
        add(state, lists[1], unit, "Polymorph", "12826", true, 3)
        state = reload(state)
        module, groups = options(state, lists[1], unit)
        equal(module:GetImportantAura(unit, "Polymorph", 12826), 3, "custom rank keeps own priority")
        equal(module:GetImportantAura(unit, "Polymorph", 12824), 9, "other ranks keep default priority")
        equal(controls(state, groups, 118).spellID.get({}), "118, 12824, 12825, 28271, 28272", "customized rank separated")
        controls(state, groups, 118).delete.func({})
        for session = 1, 3 do
            state = reload(state)
            module, groups = options(state, lists[1], unit)
            for _, id in ipairs({118, 12824, 12825, 28271, 28272}) do equal(module:GetImportantAura(unit, id), false, "whole default group stays deleted") end
            equal(module:GetImportantAura(unit, 12826), 3, "separate rank survives deletion")
        end
        state.addon.dbi:ResetProfile()
        module, groups = options(state, lists[1], unit)
        equal(controls(state, groups, 118).spellID.get({}), "118, 12824, 12825, 12826, 28271, 28272", "reset restores one default group")
    end)
end

test("legacy customized and deleted ranks survive grouping in inactive profiles too", function()
    local saved = {namespaces = {}}
    for _, namespace in ipairs({"ClassIcon", "party_ClassIcon"}) do
        saved.namespaces[namespace] = {profiles = {
            Default = {classIconAurasUseIDs = true, classIconAuras = {[118] = 4, [12824] = false, [12825] = 7}},
            Other = {classIconAurasUseIDs = true, classIconAuras = {[118] = false, [12826] = 0}},
        }}
    end
    local state = setup(saved)
    for session = 1, 3 do
        for _, unit in ipairs({"arena", "party"}) do
            local module, groups = options(state, lists[1], unit)
            equal(module:GetImportantAura(unit, 118), 4, "rank one custom priority")
            equal(module:GetImportantAura(unit, 12824), false, "deleted rank retained")
            equal(module:GetImportantAura(unit, 12825), 7, "rank three custom priority")
            equal(module:GetImportantAura(unit, 12826), 9, "unmodified rank retained")
            equal(controls(state, groups, 118).spellID.get({}), "118", "different settings remain separate")
            equal(controls(state, groups, 12825).spellID.get({}), "12825", "other custom setting separate")
        end
        state.addon.dbi:SetProfile("Other")
        for _, unit in ipairs({"arena", "party"}) do
            equal(state.module:GetImportantAura(unit, 118), false, "inactive profile deletion")
            equal(state.module:GetImportantAura(unit, 12826), 0, "inactive profile zero priority")
            equal(state.module:GetImportantAura(unit, 12824), 9, "inactive profile other rank")
        end
        state.addon.dbi:SetProfile("Default")
        state = reload(state)
    end
end)

test("grouped aura and cast alerts use every ID and keep one active alert", function()
    local state = setup(nil, true)
    local alerts = state.modules.Alerts
    alerts.frame = {arena1 = {}}
    alerts.StartFlash, alerts.SetFlashColor, alerts.StopFlash, alerts.QueueLoopEvent = function() end, function() end, function() end, function() end
    state.addon.Log = function() end
    add(state, lists[3], "arena", "Wyvern Sting", "49010, 24131", true)
    local auraKey = "aura_number:49010"
    state.auras.HARMFUL = {{name = "Wyvern Sting", id = 49010}, {name = "Wyvern Sting", id = 24131}}
    alerts:UNIT_AURA(nil, "arena1")
    assert(alerts:IsAlertActive("arena1", auraKey), "group has one aura alert")
    equal(alerts:IsAlertActive("arena1", "aura_number:24131"), nil, "second member has no duplicate alert")
    table.remove(state.auras.HARMFUL, 1)
    alerts:UNIT_AURA(nil, "arena1")
    assert(alerts:IsAlertActive("arena1", auraKey), "removing one member retains alert")
    state.auras.HARMFUL = {}
    alerts:UNIT_AURA(nil, "arena1")
    equal(alerts:IsAlertActive("arena1", auraKey), false, "last removal clears alert")
    add(state, lists[4], "arena", "Wyvern Sting", "49010, 24131", true)
    alerts:UNIT_SPELLCAST_START(nil, "arena1", "Wyvern Sting")
    equal(alerts:IsAlertActive("arena1", "cast_number:49010"), nil, "name-only cast still waits for ID")
    for _, id in ipairs({49010, 24131}) do
        alerts:UNIT_SPELLCAST_START(nil, "arena1", "Wyvern Sting", "Rank 1", 1, id)
        assert(alerts:IsAlertActive("arena1", "cast_number:49010"), "cast member uses shared alert")
        alerts:UNIT_SPELLCAST_STOP(nil, "arena1", "Wyvern Sting")
    end
end)

test("grouped IDs work in aura whitelists and blacklists", function()
    local state = setup(nil, true)
    local module = add(state, lists[2], "arena", "Wyvern Sting", "49010, 24131", true)
    module.db.arena.aurasFilterWhat = 6
    for _, id in ipairs({49010, 24131}) do
        equal(module:IsAuraFiltered("arena1", "Wyvern Sting", 4, id), true, "whitelist accepts every member")
    end
    equal(module:IsAuraFiltered("arena1", "Wyvern Sting", 4, 990001) and true or false, false, "whitelist excludes unlisted ID")
    module.db.arena.aurasFilterType = 2
    for _, id in ipairs({49010, 24131}) do
        equal(module:IsAuraFiltered("arena1", "Wyvern Sting", 4, id), false, "blacklist excludes every member")
    end
    equal(module:IsAuraFiltered("arena1", "Wyvern Sting", 4, 990001), true, "blacklist accepts unlisted ID")
end)

print("Passed " .. cases .. " spell ID list tests")
