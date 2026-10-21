local GladiusEx = _G.GladiusEx
local L = LibStub("AceLocale-3.0"):GetLocale("GladiusEx")

function GladiusEx:SpellRuleKey(spell)
    return type(spell) .. ":" .. tostring(spell)
end

function GladiusEx:ParseSpellID(value)
    local id = tonumber(value)
    if id and id > 0 and id <= 4294967295 and id % 1 == 0 then return id end
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

local function saveDetails(profile, field, spell, name, id)
    profile.spellRuleDetails = profile.spellRuleDetails or {}
    profile.spellRuleDetails[field] = profile.spellRuleDetails[field] or {}
    profile.spellRuleDetails[field][spell] = { name = name, spellID = id }
end

function GladiusEx:SpellRuleName(profile, field, spell)
    if type(spell) == "string" then return spell end
    return GetSpellInfo(spell) or details(profile, field, spell).name or L["Spell ID"]
end

function GladiusEx:GetSpellRule(profile, field, name, id)
    local rules = profile[field]
    local exact = id and rules[id]
    if exact then return exact, id end
    return rules[name], name
end

local function idOptions(getName, getID, setID, getCheck, setCheck, disabled)
    return {
        spellID = {
            type = "input", name = L["Spell ID"], order = 1.1,
            desc = L["Optional. Entering an ID alone keeps name matching enabled."],
            get = function() return getID() and tostring(getID()) or "" end,
            validate = function(info, value)
                if value:match("^%s*$") then return true end
                local id = GladiusEx:ParseSpellID(value)
                if not id then return L["Enter a positive whole spell ID, or leave it empty."] end
                local name = GetSpellInfo(id)
                return not name or name == getName() or L["The spell ID must have the same spell name."]
            end,
            set = function(info, value)
                local id = GladiusEx:ParseSpellID(value)
                if not id and not value:match("^%s*$") then return end
                local name = id and GetSpellInfo(id)
                if name and name ~= getName() then return end
                setID(id)
            end,
            disabled = disabled,
        },
        checkSpellID = {
            type = "toggle", name = L["Check Spell ID"], order = 1.2,
            desc = L["Match only this exact spell ID. Leave unchecked to match all spells with this name."],
            get = getCheck,
            set = function(info, value) setCheck(value) end,
            disabled = function() return disabled() or not getID() end,
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
            if name ~= state.name then state.spellID, state.check = nil, false end
            state.name = name
            if id then state.spellID = id end
        end,
        disabled = disabled,
    }
    local controls = idOptions(
        function() return state.name end,
        function() return state.spellID end,
        function(id) state.spellID = id; if not id then state.check = false end end,
        function() return not not state.check end,
        function(check) state.check = check and state.spellID ~= nil end,
        disabled)
    args.spellID, args.checkSpellID = controls.spellID, controls.checkSpellID
    args.add.disabled = function()
        return disabled() or not state.name or (state.check and not state.spellID)
    end
    args.add.func = function()
        if args.add.disabled() then return end
        local spell = state.check and state.spellID or state.name
        module.db[unit][field][spell] = buildValue()
        saveDetails(module.db[unit], field, spell, state.name, state.spellID)
        groups[self:SpellRuleKey(spell)] = setup(spell)
        state.name, state.spellID, state.check = nil, nil, false
        self:UpdateFrames()
    end
end

function GladiusEx:ConfigureSpellRule(module, unit, field, groups, spell, group, setup, disabled)
    local function name() return self:SpellRuleName(module.db[unit], field, spell) end
    local function id()
        return type(spell) == "number" and spell or details(module.db[unit], field, spell).spellID
    end
    local function move(newSpell, newName, newID)
        local profile = module.db[unit]
        if spell ~= newSpell then
            profile[field][newSpell] = profile[field][spell]
            -- Explicit deletions keep AceDB from restoring default rules.
            profile[field][spell] = false
            groups[self:SpellRuleKey(spell)] = nil
            if profile.spellRuleDetails and profile.spellRuleDetails[field] then
                profile.spellRuleDetails[field][spell] = nil
            end
        end
        saveDetails(profile, field, newSpell, newName, newID)
        groups[self:SpellRuleKey(newSpell)] = setup(newSpell)
        self:UpdateFrames()
    end
    local label = name()
    if type(spell) == "number" then label = label .. " (" .. spell .. ")" end
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
            move(newName, newName, newID)
        end,
        disabled = disabled,
    }
    local controls = idOptions(name, id,
        function(newID)
            if type(spell) == "number" then
                move(newID or name(), name(), newID)
            else
                move(spell, name(), newID)
            end
        end,
        function() return type(spell) == "number" end,
        function(check)
            local newID = id()
            if check and not newID then return end
            move(check and newID or name(), name(), newID)
        end, disabled)
    group.args.spellID, group.args.checkSpellID = controls.spellID, controls.checkSpellID
    group.args.delete.func = function()
        local profile = module.db[unit]
        profile[field][spell] = false
        if profile.spellRuleDetails and profile.spellRuleDetails[field] then
            profile.spellRuleDetails[field][spell] = nil
        end
        groups[self:SpellRuleKey(spell)] = nil
        self:UpdateFrames()
    end
    return group
end
