local GladiusEx = _G.GladiusEx
local L = LibStub("AceLocale-3.0"):GetLocale("GladiusEx")

-- globals
local pairs = pairs
local min, max = math.min, math.max
local tinsert, tremove = table.insert, table.remove
local UnitBuff, UnitDebuff, UnitHealth, UnitHealthMax, UnitIsDeadOrGhost = UnitBuff, UnitDebuff, UnitHealth, UnitHealthMax, UnitIsDeadOrGhost
local UnitAura = UnitAura
local GetTime = GetTime

local function GetDefaultCastsSpells()
    local h = { priority = 10, color = { r = 0, g = 1, b = 0, a = 1 } }
    local cc = { priority = 20, color = { r = 1, g = 0, b = 0, a = 1 } }
    return {
        [GladiusEx:SafeGetSpellName(2060)]    = h,     -- Greater Heal
        [GladiusEx:SafeGetSpellName(8936)]    = h,     -- Regrowth
        [GladiusEx:SafeGetSpellName(50464)]   = h,     -- Nourish
        
        [GladiusEx:SafeGetSpellName(118)]      = cc,    -- Polymorph
        [GladiusEx:SafeGetSpellName(5782)]     = cc,    -- Fear
        [GladiusEx:SafeGetSpellName(51514)]    = cc,    -- Hex
        [GladiusEx:SafeGetSpellName(20066)]    = cc,    -- Repentance
        [GladiusEx:SafeGetSpellName(33786)]    = cc,    -- Cyclone
        [GladiusEx:SafeGetSpellName(1513)]     = cc,    -- Scare Beast
        [GladiusEx:SafeGetSpellName(339)]      = cc,    -- Entangling Roots
        [GladiusEx:SafeGetSpellName(2637)]     = cc,    -- Hibernate
    }
end

local function GetDefaultAuraSpells()
    local cc = { priority = 15, color = { r = 1, g = 1, b = 1, a = 1 } }
    local im = { priority = 15, color = { r = 1, g = 1, b = 0, a = 1 } }
    return {
    }
end

local Alerts = GladiusEx:NewGladiusExModule("Alerts", {
        minAlpha = 0.2,
        maxAlpha = 0.6,
        duration = 0.35,
        ease = "OUT",
        blendMode = "BLEND",

        health = true,
        healthThreshold = 0.25,
        healthPriority = 10,
        healthColor = { r = 1, g = 0, b = 0, a = 1 },

        casts = true,
        castsSpells = GetDefaultCastsSpells(),

        auras = true,
        aurasSpells = GetDefaultAuraSpells(),
    })

function Alerts:OnEnable()
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("UNIT_HEALTH")
    self:RegisterEvent("UNIT_NAME_UPDATE", "UNIT_HEALTH")
    self:RegisterEvent("UNIT_SPELLCAST_START")
    self:RegisterEvent("UNIT_SPELLCAST_STOP")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_STOP")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_STOP")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_START")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_STOP")

    if not self.frame then
        self.frame = {}
    end
end

function Alerts:OnDisable()
    self:UnregisterAllEvents()

    for unit in pairs(self.frame) do
        self.frame[unit]:SetAlpha(0)
    end
end

function Alerts:CreateFrame(unit)
    local button = GladiusEx.buttons[unit]
    if not button then return end

    -- create frame
    self.frame[unit] = CreateFrame("Frame", "GladiusEx" .. self:GetName() .. unit, button)
    self.frame[unit].texture = self.frame[unit]:CreateTexture("GladiusEx" .. self:GetName() .. "Texture" .. unit, "OVERLAY")
    self.frame[unit].texture:SetAllPoints()
    self.frame[unit].ag = self.frame[unit]:CreateAnimationGroup()
    self.frame[unit].ag.aa = self.frame[unit].ag:CreateAnimation("Alpha")
end

function Alerts:Update(unit)
    local testing = GladiusEx:IsTesting(unit)

    -- create frame
    if not self.frame[unit] then
        self:CreateFrame(unit)
    end

    -- frame
    local parent = GladiusEx:GetAttachFrame(unit, "Frame")
    self.frame[unit]:ClearAllPoints()
    self.frame[unit]:SetAllPoints()
    self.frame[unit]:SetFrameLevel(100)

    -- texture
    self.frame[unit].texture:SetTexture(1, 1, 1)
    self.frame[unit].texture:SetBlendMode(self.db[unit].blendMode)

    -- animation group
    self.frame[unit]:SetAlpha(self.db[unit].maxAlpha)
    self.frame[unit].ag:SetLooping("BOUNCE")
    self.frame[unit].ag.aa:SetChange(-(self.db[unit].maxAlpha - self.db[unit].minAlpha))
    self.frame[unit].ag.aa:SetDuration(self.db[unit].duration)
    self.frame[unit].ag.aa:SetSmoothing(self.db[unit].ease)
    self.frame[unit].ag:Stop()

    self.frame[unit]:Hide()
end

function Alerts:Show(unit)
end

function Alerts:Reset(unit)
    if not self.frame[unit] then return end

    self:StopFlash(unit)
    self:ClearAllAlerts(unit)
end

function Alerts:Test(unit)
    self:ClearAllAlerts(unit)
    self:SetAlert(unit, "test", 1, { r = 1, g = 0, b = 0, a = 1 })
end

function Alerts:Refresh(unit)
end

function Alerts:SetFlashColor(unit, color)
    self.frame[unit].texture:SetVertexColor(color.r, color.g, color.b, color.a)
end

function Alerts:StartFlash(unit, color)
    local f = self.frame[unit]
    f.texture:SetVertexColor(color.r, color.g, color.b, color.a)

    f:SetAlpha(self.db[unit].maxAlpha)
    f:Show()
    f.ag:Play()
end

function Alerts:StopFlash(unit)
    self.frame[unit].ag:Stop()
    self.frame[unit].ag:SetScript("OnLoop", nil)
    self.frame[unit]:SetAlpha(0)
    self.frame[unit]:Hide()
end

local loop_queue = {}
function Alerts:QueueLoopEvent(unit, count, func)
    if not loop_queue[unit] then loop_queue[unit] = {} end

    tinsert(loop_queue[unit], { ["start"] = GetTime(), ["count"] = count, ["func"] = func })

    if #loop_queue[unit] == 1 then
        self.frame[unit].ag:SetScript("OnLoop",    function(ag, loopState)
            if loopState == "REVERSE" then
                local start_threshold = GetTime() - 0.3
                for i = #loop_queue[unit], 1, -1 do
                    local q = loop_queue[unit][i]
                    if start_threshold >= q.start then
                        q.count = q.count - 1
                        if q.count <= 0 then
                            self[q.func](self, unit)
                            tremove(loop_queue[unit], i)
                        end
                    end
                end
                if #loop_queue[unit] == 0 then
                    ag:SetScript("OnLoop", nil)
                end
            end
        end)
    end
end

local alerts = {}
local alerts_color = {}
function Alerts:SetAlert(unit, alert, priority, color)
    assert(type(unit) == "string")
    assert(type(alert) == "string")
    assert(type(priority) == "number")
    assert(type(color) == "table")
    if not alerts[unit] then alerts[unit] = { count = 0, priority = 0, current = false, alerts = {} } end
    if not alerts_color[unit] then alerts_color[unit] = {} end

    if not alerts[unit].alerts[alert] then
        alerts[unit].alerts[alert] = priority
        alerts_color[unit][alert] = color
        alerts[unit].count = alerts[unit].count + 1

        if alerts[unit].count == 1 or alerts[unit].priority < priority then
            alerts[unit].priority = priority
            alerts[unit].current = alert
            self:StartFlash(unit, color)
        end
    end
end

function Alerts:UpdateAlertColor(unit)
    -- find new alert
    local new_alert
    local new_priority = 0
    for alert, priority in pairs(alerts[unit].alerts) do
        if priority and priority > new_priority then
            new_alert = alert
            new_priority = priority
        end
    end
    GladiusEx:Log(unit, new_alert, new_priority, alerts[unit].priority)
    if new_alert then
        local cur_alert = alerts[unit].current
        if not alerts[unit][cur_alert] or new_priority > alerts[unit].priority then
            alerts[unit].priority = new_priority
            alerts[unit].current = new_alert
            self:SetFlashColor(unit, alerts_color[unit][new_alert])
        end
    else
        alerts[unit].priority = 0
        alerts[unit].current = false
        self:StopFlash(unit)
    end
end

function Alerts:ClearAlert(unit, alert, count)
    if alerts[unit] and alerts[unit].alerts[alert] then
        alerts[unit].alerts[alert] = false
        alerts[unit].count = alerts[unit].count - 1

        if count and count > 0 then
            self:QueueLoopEvent(unit, count or 1, "UpdateAlertColor")
        else
            self:UpdateAlertColor(unit)
        end
    end
end

function Alerts:IsAlertActive(unit, alert)
    return alerts[unit] and alerts[unit].alerts[alert]
end

function Alerts:ClearAllAlerts(unit)
    alerts[unit] = nil
    if self.auraAlertKeys then self.auraAlertKeys[unit] = nil end
    if self.castAlertKeys then self.castAlertKeys[unit] = nil end
    if self.castSuccesses then self.castSuccesses[unit] = nil end
    if self.castEvents then self.castEvents[unit] = nil end
    if self.pendingCastStarts then self.pendingCastStarts[unit] = nil end
end

function Alerts:UNIT_AURA(event, unit)
    if not self.frame[unit] then return end
    if not self.db[unit].auras then return end

    local active = {}
    for _, filter in ipairs({"HELPFUL", "HARMFUL"}) do
        for index = 1, 40 do
            local name, _, _, _, _, _, _, _, _, _, id = UnitAura(unit, index, filter)
            if not name then break end
            local aura, key = GladiusEx:GetSpellRule(self.db[unit], "aurasSpells", name, id)
            if aura then active[GladiusEx:SpellRuleKey(key)] = aura end
        end
    end
    self.auraAlertKeys = self.auraAlertKeys or {}
    for key in pairs(self.auraAlertKeys[unit] or {}) do
        if not active[key] then self:ClearAlert(unit, "aura_" .. key) end
    end
    for key, aura in pairs(active) do
        self:SetAlert(unit, "aura_" .. key, aura.priority, aura.color)
    end
    self.auraAlertKeys[unit] = active
end

function Alerts:UNIT_HEALTH(event, unit)
    if not self.frame[unit] then return end
    if not self.db[unit].health then return end

    local health = UnitHealth(unit)
    local healthMax = UnitHealthMax(unit)

    if not UnitIsDeadOrGhost(unit) and (health / healthMax) <= self.db[unit].healthThreshold then
        self:SetAlert(unit, "health", self.db[unit].healthPriority, self.db[unit].healthColor)
    else
        self:ClearAlert(unit, "health")
    end
end

function Alerts:HasExactCastRule(unit, name)
    for spell, rule in pairs(self.db[unit].castsSpells) do
        if rule and type(spell) == "number" and GladiusEx:SpellRuleName(self.db[unit], "castsSpells", spell) == name then
            return true
        end
    end
    return false
end

function Alerts:ShowCastAlert(unit, name, id, succeeded)
    if not self.frame[unit] or not self.db[unit].casts then return end
    local cast, key = GladiusEx:GetSpellRule(self.db[unit], "castsSpells", name, id)
    if not cast then return end
    local alert = "cast_" .. GladiusEx:SpellRuleKey(key)
    self.castAlertKeys = self.castAlertKeys or {}
    if succeeded then
        self.castSuccesses = self.castSuccesses or {}
        local last = self.castSuccesses[unit]
        if last and last.key == alert and GetTime() - last.time < 0.05 then return end
        self.castSuccesses[unit] = {key = alert, time = GetTime()}
        if self:IsAlertActive(unit, alert) then return end
        self:SetAlert(unit, alert, cast.priority, cast.color)
        self:ClearAlert(unit, alert, 1)
    else
        local old = self.castAlertKeys[unit]
        if old and old.alert ~= alert then self:ClearAlert(unit, old.alert) end
        self.castAlertKeys[unit] = {alert = alert, name = name}
        self:SetAlert(unit, alert, cast.priority, cast.color)
    end
end

function Alerts:UNIT_SPELLCAST_START(event, unit, spell, rank, lineID, spellID)
    if not self.frame[unit] or not self.db[unit].casts then return end
    if type(spell) == "number" then spellID, spell = spell, GetSpellInfo(spell) end
    if not spell then return end
    -- Older unit events omit IDs. Wait for the combat log when an exact rule
    -- could apply, instead of guessing an enemy's rank from its spell name.
    if not spellID and self:HasExactCastRule(unit, spell) then
        local recent = self.castEvents and self.castEvents[unit]
        if recent and recent.name == spell and GetTime() - recent.time < 0.05 then
            spellID = recent.id
        else
            self.pendingCastStarts = self.pendingCastStarts or {}
            self.pendingCastStarts[unit] = spell
            return
        end
    end
    self:ShowCastAlert(unit, spell, spellID, false)
end

function Alerts:UNIT_SPELLCAST_SUCCEEDED(event, unit, spell, rank, lineID, spellID)
    if not self.frame[unit] or not self.db[unit].casts then return end
    if type(spell) == "number" then spellID, spell = spell, GetSpellInfo(spell) end
    if not spell then return end
    if not spellID and self:HasExactCastRule(unit, spell) then return end
    self:ShowCastAlert(unit, spell, spellID, true)
end

function Alerts:UNIT_SPELLCAST_STOP(event, unit, spell)
    if not self.frame[unit] or not self.db[unit].casts then return end
    if type(spell) == "number" then spell = GetSpellInfo(spell) end
    if self.pendingCastStarts and (not spell or self.pendingCastStarts[unit] == spell) then
        self.pendingCastStarts[unit] = nil
    end
    local current = self.castAlertKeys and self.castAlertKeys[unit]
    if current and (not spell or spell == current.name) then
        self:ClearAlert(unit, current.alert)
        self.castAlertKeys[unit] = nil
    end
end

function Alerts:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, kind, sourceGUID, sourceName, sourceFlags,
        destGUID, destName, destFlags, spellID, spellName, spellSchool, extraID, extraName)
    if kind ~= "SPELL_CAST_START" and kind ~= "SPELL_CAST_SUCCESS" and
        kind ~= "SPELL_CAST_FAILED" and kind ~= "SPELL_INTERRUPT" then return end
    local unit = GladiusEx:GetUnitIdByGUID(kind == "SPELL_INTERRUPT" and destGUID or sourceGUID)
    if not unit or not self.frame[unit] or not self.db[unit].casts then return end
    local name = kind == "SPELL_INTERRUPT" and extraName or spellName
    if not self:HasExactCastRule(unit, name) then return end
    if kind == "SPELL_CAST_FAILED" or kind == "SPELL_INTERRUPT" then
        self:UNIT_SPELLCAST_STOP(event, unit, name)
    else
        self.castEvents = self.castEvents or {}
        self.castEvents[unit] = {name = name, id = spellID, time = GetTime()}
        local pending = self.pendingCastStarts and self.pendingCastStarts[unit] == name
        if pending then self.pendingCastStarts[unit] = nil end
        -- Channels can report CAST_SUCCESS when they start, without CAST_START.
        self:ShowCastAlert(unit, name, spellID, kind == "SPELL_CAST_SUCCESS" and not pending)
    end
end

function Alerts:GetOptions(unit)
    local options
    options = {
        general = {
            type = "group",
            name = L["General"],
            order = 1,
            args = {
                bar = {
                    type = "group",
                    name = L["Alert animation"],
                    desc = L["Alert animation settings"],
                    inline = true,
                    order = 1,
                    args = {
                        minAlpha = {
                            type = "range",
                            name = L["Alpha low"],
                            desc = L["Low transparency alpha value of the animation"],
                            set = function(info, value)
                                self.db[unit].minAlpha = value
                                self.db[unit].maxAlpha = max(value + 0.1, self.db[unit].maxAlpha)
                                GladiusEx:UpdateFrames()
                            end,
                            min = 0, max = 0.9, bigStep = 0.1,
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 1,
                        },
                        maxAlpha = {
                            type = "range",
                            name = L["Alpha high"],
                            desc = L["High transparency alpha value of the animation"],
                            set = function(info, value)
                                self.db[unit].minAlpha = min(value - 0.1, self.db[unit].minAlpha)
                                self.db[unit].maxAlpha = value
                                GladiusEx:UpdateFrames()
                            end,
                            min = 0.1, max = 1, bigStep = 0.1,
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 2,
                        },
                        duration = {
                            type = "range",
                            name = L["Duration"],
                            desc = L["Duration of each animation cycle, in seconds"],
                            min = 0.1, softMax = 1, bigStep = 0.05,
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 3,
                        },
                        ease = {
                            type = "select",
                            name = L["Ease"],
                            desc = L["Animation ease method"],
                            values = {
                                ["IN"] = L["In"],
                                ["IN_OUT"] = L["In-Out"],
                                ["OUT"] = L["Out"],
                                ["NONE"] = L["None"],
                            },
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 4,
                        },
                        blendMode = {
                            type = "select",
                            name = L["Blend mode"],
                            desc = L["Overlay blend mode"],
                            values = {
                                ["ADD"] = L["Add"],
                                -- ["ALPHAKEY"] = L["Alpha key"],
                                ["BLEND"] = L["Blend"],
                                -- ["DISABLE"] = L["Disable"],
                                -- ["MOD"] = L["Mod"],
                            },
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 5,
                        },
                    },
                },
            },
        },
        health = {
            type = "group",
            name = L["Low health"],
            desc = L["Low health settings"],
            order = 2,
            args = {
                health = {
                    type = "toggle",
                    name = L["Low health alert"],
                    desc = L["Toggle low health alerts"],
                    disabled = function() return not self:IsUnitEnabled(unit) end,
                    order = 1,
                },
                sep = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 11,
                },
                healthThreshold = {
                    type = "range",
                    name = L["Low health threshold"],
                    desc = L["Minimum health percent to fire the alert"],
                    min = 0, max = 1, bigStep = 0.05, isPercent = true,
                    disabled = function() return not self.db[unit].health or not self:IsUnitEnabled(unit) end,
                    order = 20,
                },
                sep2 = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 21,
                },
                healthPriority = {
                    type = "range",
                    name = L["Alert priority"],
                    desc = L["Select what priority the alert should have - higher equals more priority"],
                    min = 0, max = 100, step = 1,
                    disabled = function() return not self.db[unit].health or not self:IsUnitEnabled(unit) end,
                    order = 30,
                },
                healthColor = {
                    type = "color",
                    name = L["Alert color"],
                    name = L["Alert overlay color"],
                    get = function(info) return GladiusEx:GetColorOption(self.db[unit], info) end,
                    set = function(info, r, g, b, a) return GladiusEx:SetColorOption(self.db[unit], info, r, g, b, a) end,
                    hasAlpha = true,
                    disabled = function() return not self.db[unit].health or not self:IsUnitEnabled(unit) end,
                    order = 40,
                },
            },
        },
        casts = {
            type = "group",
            name = L["Casts"],
            childGroups = "tree",
            order = 3,
            args = {
                casts = {
                    type = "toggle",
                    name = L["Casts alerts"],
                    desc = L["Toggle alerts when some spells are being cast"],
                    disabled = function() return not self:IsUnitEnabled(unit) end,
                    order = 1,
                },
                newCast = {
                    type = "group",
                    name = L["New cast"],
                    desc = L["New cast"],
                    inline = true,
                    order = 1,
                    args = {
                        priority = {
                            type= "range",
                            name = L["Alert priority"],
                            desc = L["Select what priority the cast should have - higher equals more priority"],
                            get = function() return self.newCastPriority or "" end,
                            set = function(info, value) self.newCastPriority = value end,
                            disabled = function() return not self.db[unit].casts or not self:IsUnitEnabled(unit) end,
                            min = 0, max = 100, step = 1,
                            order = 2,
                        },
                        color = {
                            type = "color",
                            name = L["Alert color"],
                            name = L["Alert overlay color"],
                            get = function(info) return self.newCastColor.r, self.newCastColor.g, self.newCastColor.b, self.newCastColor.a end,
                            set = function(info, r, g, b, a) self.newCastColor = { r = r, g = g, b = b, a = a } end,
                            hasAlpha = true,
                            disabled = function() return not self.db[unit].casts or not self:IsUnitEnabled(unit) end,
                            order = 3,
                        },
                        add = {
                            type = "execute",
                            name = L["Add new cast"],
                            order = 4,
                        },
                    },
                },
            },
        },
        auras = {
            type = "group",
            name = L["Auras"],
            desc = L["Toggle alerts when some auras are active"],
            childGroups = "tree",
            order = 4,
            args = {
                auras = {
                    type = "toggle",
                    name = L["Auras alerts"],
                    disabled = function() return not self:IsUnitEnabled(unit) end,
                    order = 1,
                },
                newAura = {
                    type = "group",
                    name = L["New aura"],
                    desc = L["New aura"],
                    inline = true,
                    order = 1,
                    args = {
                        priority = {
                            type= "range",
                            name = L["Alert priority"],
                            desc = L["Select what priority the aura should have - higher equals more priority"],
                            get = function() return self.newAuraPriority or "" end,
                            set = function(info, value) self.newAuraPriority = value end,
                            disabled = function() return not self.db[unit].auras or not self:IsUnitEnabled(unit) end,
                            min = 0, max = 100, step = 1,
                            order = 2,
                        },
                        color = {
                            type = "color",
                            name = L["Alert color"],
                            get = function(info) return self.newAuraColor.r, self.newAuraColor.g, self.newAuraColor.b, self.newAuraColor.a end,
                            set = function(info, r, g, b, a) self.newAuraColor = { r = r, g = g, b = b, a = a } end,
                            hasAlpha = true,
                            disabled = function() return not self.db[unit].auras or not self:IsUnitEnabled(unit) end,
                            order = 3,
                        },
                        add = {
                            type = "execute",
                            name = L["Add new aura"],
                            order = 4,
                        },
                    },
                },
            },
        },
    }

    -- set some initial values
    self.newCastPriority = 5
    self.newCastColor = { r = 1, g = 0, b = 0, a = 1 }
    self.newAuraPriority = 5
    self.newAuraColor = { r = 1, g = 0, b = 0, a = 1 }

    -- setup casts
    for cast, rule in pairs(self.db[unit].castsSpells) do
        if rule then options.casts.args[GladiusEx:SpellRuleKey(cast)] = self:SetupCastOptions(options, unit, cast) end
    end

    -- setup auras
    for aura, rule in pairs(self.db[unit].aurasSpells) do
        if rule then options.auras.args[GladiusEx:SpellRuleKey(aura)] = self:SetupAuraOptions(options, unit, aura) end
    end
    GladiusEx:ConfigureNewSpellRule(self, unit, "castsSpells", options.casts.args,
        options.casts.args.newCast.args,
        function() return {priority = self.newCastPriority, color = self.newCastColor} end,
        function(cast) return self:SetupCastOptions(options, unit, cast) end,
        function() return not self:IsUnitEnabled(unit) or not self.db[unit].casts end)
    GladiusEx:ConfigureNewSpellRule(self, unit, "aurasSpells", options.auras.args,
        options.auras.args.newAura.args,
        function() return {priority = self.newAuraPriority, color = self.newAuraColor} end,
        function(aura) return self:SetupAuraOptions(options, unit, aura) end,
        function() return not self:IsUnitEnabled(unit) or not self.db[unit].auras end)

    return options
end

function Alerts:SetupCastOptions(options, unit, spell)
    return self:SetupSpellOptions(options, unit, spell, "castsSpells", "casts")
end

function Alerts:SetupAuraOptions(options, unit, spell)
    return self:SetupSpellOptions(options, unit, spell, "aurasSpells", "auras")
end

function Alerts:SetupSpellOptions(options, unit, spell, field, kind)
    local disabled = function() return not self:IsUnitEnabled(unit) or not self.db[unit][kind] end
    local group = {
        type = "group", name = tostring(spell), disabled = disabled,
        args = {
            priority = {
                type = "range", name = L["Alert priority"], min = 0, softMax = 100, step = 1, order = 2,
                get = function() return self.db[unit][field][spell].priority end,
                set = function(info, value)
                    self.db[unit][field][spell].priority = value
                    GladiusEx:UpdateFrames()
                end,
            },
            color = {
                type = "color", name = L["Alert overlay color"], hasAlpha = true, order = 3,
                get = function()
                    local c = self.db[unit][field][spell].color
                    return c.r, c.g, c.b, c.a
                end,
                set = function(info, r, g, b, a)
                    self.db[unit][field][spell].color = {r = r, g = g, b = b, a = a}
                    GladiusEx:UpdateFrames()
                end,
            },
            delete = {type = "execute", name = L["Delete"], order = 4, disabled = disabled},
        },
    }
    return GladiusEx:ConfigureSpellRule(self, unit, field, options[kind].args, spell, group,
        function(key) return self:SetupSpellOptions(options, unit, key, field, kind) end, disabled)
end
