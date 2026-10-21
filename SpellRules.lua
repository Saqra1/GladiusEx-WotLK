local GladiusEx = _G.GladiusEx
local L = LibStub("AceLocale-3.0"):GetLocale("GladiusEx")

function GladiusEx:SpellRuleKey(spell)
    return type(spell) .. ":" .. tostring(spell)
end

function GladiusEx:ParseSpellID(value)
    local id = tonumber(value)
    if id and id > 0 and id <= 4294967295 and id % 1 == 0 then return id end
end

function GladiusEx:ParseSpellIDs(value)
    if value:match("^%s*$") then return {} end
    local ids, seen = {}, {}
    for part in (value .. ","):gmatch("(.-),") do
        local digits = part:match("^%s*(%d+)%s*$")
        local id = digits and self:ParseSpellID(digits)
        if not id then return end
        if not seen[id] then ids[#ids + 1], seen[id] = id, true end
    end
    return ids
end

function GladiusEx:ParseSpellName(value)
    value = value:match("^%s*(.-)%s*$")
    if value == "" or value:find("[%c\127]") then return nil end
    local id = tonumber(value)
    if id then
        id = self:ParseSpellID(value)
        if not id then return nil end
        return GetSpellInfo(id) or value, id
    end
    return GetSpellInfo(value) or value
end

local function details(profile, field, spell)
    local lists = profile.spellRuleDetails
    return lists and lists[field] and lists[field][spell] or {}
end

local function saveDetails(profile, field, spell, name, ids, owner)
    profile.spellRuleDetails = profile.spellRuleDetails or {}
    profile.spellRuleDetails[field] = profile.spellRuleDetails[field] or {}
    profile.spellRuleDetails[field][spell] = {
        name = name, spellID = ids[1] or false,
        spellIDs = table.concat(ids, ", "), group = owner,
    }
end

local function deleteRule(module, unit, field, spell)
    local profile = module.db[unit]
    local defaults = module.dbi_arena.profile == profile and module.defaults_arena or module.defaults_party
    local default = defaults[field] and defaults[field][spell]
    profile[field][spell] = type(default) == "table" and {disabled = true} or false
end

function GladiusEx:SpellRuleIDs(profile, field, spell)
    local saved = details(profile, field, spell)
    if saved.spellIDs ~= nil then return self:ParseSpellIDs(saved.spellIDs) or {} end
    if type(spell) == "number" then return {spell} end
    local id = saved.spellID
    if id ~= nil then return id and {id} or {} end
    local rule = profile[field][spell]
    return type(rule) == "table" and rule.spellID and {rule.spellID} or {}
end

function GladiusEx:SpellRuleID(profile, field, spell)
    return self:SpellRuleIDs(profile, field, spell)[1]
end

local function enabled(rule)
    return rule and (type(rule) ~= "table" or not rule.disabled)
end

function GladiusEx:SpellRuleOwner(profile, field, spell)
    local owner = details(profile, field, spell).group
    if owner and enabled(profile[field][owner]) then return owner end
    return spell
end

function GladiusEx:SpellRuleName(profile, field, spell)
    if type(spell) == "string" then return spell end
    return GetSpellInfo(spell) or details(profile, field, spell).name or L["Spell ID"]
end

function GladiusEx:GetSpellRule(profile, field, name, id)
    local rules = profile[field]
    local exactID = id or (type(name) == "number" and name)
    local exact = exactID and rules[exactID]
    if enabled(exact) then
        local owner = self:SpellRuleOwner(profile, field, exactID)
        return rules[owner], owner
    end
    local rule = rules[name]
    if type(rule) == "table" and rule.disabled then return false, name end
    return rule, name
end

-- Keep each ID available for a direct lookup, with one editable rule per group.
function GladiusEx:GroupImportantSpellRules(profile, field)
    local buckets, sorted = {}, {}
    for spell, value in pairs(profile[field]) do
        local saved = details(profile, field, spell)
        if type(spell) == "number" and type(value) == "number" and
            not saved.group and saved.spellIDs == nil then
            sorted[#sorted + 1] = spell
        end
    end
    table.sort(sorted)
    for _, id in ipairs(sorted) do
        local name = GetSpellInfo(id) or details(profile, field, id).name or tostring(id)
        local value = profile[field][id]
        buckets[name] = buckets[name] or {}
        local ids = buckets[name][value] or {}
        buckets[name][value] = ids
        ids[#ids + 1] = id
    end
    for name, priorities in pairs(buckets) do
        for _, ids in pairs(priorities) do
            for _, id in ipairs(ids) do saveDetails(profile, field, id, name, ids, ids[1]) end
        end
    end
end

function GladiusEx:RemoveSpellRule(module, unit, field, groups, spell)
    local profile = module.db[unit]
    local keys = type(spell) == "number" and self:SpellRuleIDs(profile, field, spell) or {spell}
    for _, key in ipairs(keys) do
        deleteRule(module, unit, field, key)
        if profile.spellRuleDetails and profile.spellRuleDetails[field] then
            profile.spellRuleDetails[field][key] = nil
        end
        groups[self:SpellRuleKey(key)] = nil
    end
end

function GladiusEx:WriteSpellRule(module, unit, field, groups, name, ids, exact, value, setup)
    local profile = module.db[unit]
    local function write(newIDs, newName, newValue, check)
        local key = check and newIDs[1] or newName
        if check then
            for _, id in ipairs(newIDs) do
                profile[field][id] = newValue
                saveDetails(profile, field, id, newName, newIDs, key)
            end
        else
            profile[field][key] = newValue
            saveDetails(profile, field, key, newName, newIDs)
        end
        groups[self:SpellRuleKey(key)] = setup(key)
    end
    if exact then
        local replacing, owners = {}, {}
        for _, id in ipairs(ids) do
            replacing[id] = true
            if enabled(profile[field][id]) then
                owners[self:SpellRuleOwner(profile, field, id)] = true
            end
        end
        -- Moving an ID to another rule leaves the other ranks and settings intact.
        for owner in pairs(owners) do
            local remaining = {}
            for _, id in ipairs(self:SpellRuleIDs(profile, field, owner)) do
                if not replacing[id] then remaining[#remaining + 1] = id end
            end
            local oldValue, oldName = profile[field][owner], self:SpellRuleName(profile, field, owner)
            self:RemoveSpellRule(module, unit, field, groups, owner)
            if #remaining > 0 then write(remaining, oldName, oldValue, true) end
        end
    end
    write(ids, name, value, exact)
end

local function idOptions(getName, getIDs, setIDs, getCheck, setCheck, disabled)
    local function validate(value)
        local ids = GladiusEx:ParseSpellIDs(value)
        if not ids then return L["Enter positive whole spell IDs separated by commas, or leave it empty."] end
        for _, id in ipairs(ids) do
            local name = GetSpellInfo(id)
            if name and name ~= getName() then return L["Every spell ID must have the same spell name."] end
        end
        return true
    end
    return {
        spellID = {
            type = "input", name = L["Spell IDs"], order = 1.1, width = "full",
            desc = L["Optional. Separate IDs with commas. Leave Check Spell IDs off to match by name."],
            get = function() return table.concat(getIDs(), ", ") end,
            validate = function(info, value) return validate(value) end,
            set = function(info, value)
                if validate(value) == true then setIDs(GladiusEx:ParseSpellIDs(value)) end
            end,
            disabled = disabled,
        },
        checkSpellID = {
            type = "toggle", name = L["Check Spell IDs"], order = 1.2,
            desc = L["Match any listed spell ID. Leave unchecked to match all spells with this name."],
            get = getCheck,
            set = function(info, value) setCheck(value) end,
            disabled = function() return disabled() or #getIDs() == 0 end,
        },
    }
end

-- Shared controls for important auras, aura filters, and cast/aura alerts.
function GladiusEx:ConfigureNewSpellRule(module, unit, field, groups, args, buildValue, setup, disabled)
    module.pendingSpellRules = module.pendingSpellRules or {}
    local profile = module.db[unit]
    module.pendingSpellRules[profile] = module.pendingSpellRules[profile] or {}
    local pending = module.pendingSpellRules[profile]
    pending[field] = pending[field] or {}
    local state = pending[field]
    args.name = {
        type = "input", name = L["Spell name"], desc = L["Name of the spell"], order = 1,
        get = function() return state.name or "" end,
        validate = function(info, value)
            return self:ParseSpellName(value) ~= nil or L["Enter a spell name."]
        end,
        set = function(info, value)
            local name, id = self:ParseSpellName(value)
            if name ~= state.name then state.spellIDs, state.check = nil, false end
            state.name = name
            if id then state.spellIDs = {id} end
        end,
        disabled = disabled,
    }
    local controls = idOptions(
        function() return state.name end,
        function() return state.spellIDs or {} end,
        function(ids) state.spellIDs = ids; if #ids == 0 then state.check = false end end,
        function() return not not state.check end,
        function(check) state.check = check and state.spellIDs and #state.spellIDs > 0 end,
        disabled)
    args.spellID, args.checkSpellID = controls.spellID, controls.checkSpellID
    args.add.disabled = function()
        return disabled() or not state.name or (state.check and (not state.spellIDs or #state.spellIDs == 0))
    end
    args.add.func = function()
        if args.add.disabled() then return end
        self:WriteSpellRule(module, unit, field, groups, state.name, state.spellIDs or {},
            state.check, buildValue(), setup)
        state.name, state.spellIDs, state.check = nil, nil, false
        self:UpdateFrames()
    end
end

function GladiusEx:ConfigureSpellRule(module, unit, field, groups, spell, group, setup, disabled)
    local function name() return self:SpellRuleName(module.db[unit], field, spell) end
    local function ids()
        return self:SpellRuleIDs(module.db[unit], field, spell)
    end
    local function move(newName, newIDs, exact)
        local profile = module.db[unit]
        local value = profile[field][spell]
        self:RemoveSpellRule(module, unit, field, groups, spell)
        self:WriteSpellRule(module, unit, field, groups, newName, newIDs, exact, value, setup)
        self:UpdateFrames()
    end
    local label = name()
    if type(spell) == "number" then
        label = #ids() > 1 and L["%s (%d IDs)"]:format(label, #ids()) or label .. " (" .. spell .. ")"
    end
    group.name, group.desc = label, label
    group.args.name = {
        type = "input", name = L["Spell name"], desc = L["Name of the spell"], order = 1,
        get = name,
        validate = function(info, value)
            return self:ParseSpellName(value) ~= nil or L["Enter a spell name."]
        end,
        set = function(info, value)
            local newName, newID = self:ParseSpellName(value)
            if not newName then return end
            if newName == name() then return end
            move(newName, newID and {newID} or {}, false)
        end,
        disabled = disabled,
    }
    local controls = idOptions(name, ids,
        function(newIDs) move(name(), newIDs, type(spell) == "number" and #newIDs > 0) end,
        function() return type(spell) == "number" end,
        function(check)
            local newIDs = ids()
            if check and #newIDs == 0 then return end
            move(name(), newIDs, check)
        end, disabled)
    group.args.spellID, group.args.checkSpellID = controls.spellID, controls.checkSpellID
    if type(spell) == "number" and group.args.priority then
        local setPriority = group.args.priority.set
        group.args.priority.set = function(info, value)
            setPriority(info, value)
            for _, id in ipairs(ids()) do module.db[unit][field][id] = module.db[unit][field][spell] end
        end
    end
    group.args.delete.func = function()
        self:RemoveSpellRule(module, unit, field, groups, spell)
        self:UpdateFrames()
    end
    return group
end
