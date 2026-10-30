-- Run from the addon directory with Lua 5.1: lua tests/positioning.lua
-- Exercise the real editor UI and persistence with scaled frame geometry.
local function noop() end
local combat, modifier, focused = false, nil, nil
local all_frames = {}
local units = {}
InCombatLockdown = function() return combat end
UnitExists = function(unit) return units[unit] and units[unit].exists end
UnitIsDeadOrGhost = function(unit) return units[unit] and units[unit].dead end
UnitHealth = function(unit) return units[unit] and units[unit].health or 0 end
UnitGUID = function(unit) return units[unit] and units[unit].guid end
GetNumPartyMembers = function() return 2 end
GetNumArenaOpponents = function() return 0 end
IsActiveBattlefieldArena = function() return true end
IsShiftKeyDown = function() return modifier == "shift" end
IsAltKeyDown = function() return modifier == "alt" end
IsControlKeyDown = function() return modifier == "control" end
GetScreenResolutions = function() return "1600x900" end
GetCurrentResolution = function() return 1 end
local addon = {SetDefaultModulePrototype = noop, SetDefaultModuleLibraries = noop, SetDefaultModuleState = noop}
local locale = setmetatable({}, {__index = function(_, key) return key end})
local libs = {
    ["AceAddon-3.0"] = {NewAddon = function() return addon end},
    ["AceLocale-3.0"] = {GetLocale = function() return locale end},
    ["LibFunctional-1.0"] = {}, ["LibSpecDetection-1.0"] = {},
    ["LibSharedMedia-3.0"] = {MediaType = {FONT = "font"}, Fetch = function(_, _, name) return name end},
}
LibStub = function(name, silent) if silent then return libs[name] end; return assert(libs[name], name) end
local function load_file(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a"):gsub("^\239\187\191", "")
    file:close()
    assert(loadstring(source, "@" .. path))()
end
load_file("GladiusEx.lua")
load_file("positioning.lua")

local points = {
    TOPLEFT = {0, 1}, TOP = {0.5, 1}, TOPRIGHT = {1, 1},
    LEFT = {0, 0.5}, CENTER = {0.5, 0.5}, RIGHT = {1, 0.5},
    BOTTOMLEFT = {0, 0}, BOTTOM = {0.5, 0}, BOTTOMRIGHT = {1, 0},
}
local Frame = {}
Frame.__index = Frame
function Frame:GetEffectiveScale() return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
function Frame:Bounds()
    local scale, left, bottom = self:GetEffectiveScale(), 0, 0
    if self.point then
        local point, relative, relative_point, x, y = unpack(self.point)
        local l, b, r, t = relative:Bounds()
        local p, q = points[point], points[relative_point]
        left = l + (r - l) * q[1] + (x - self.width * p[1]) * scale
        bottom = b + (t - b) * q[2] + (y - self.height * p[2]) * scale
    end
    return left, bottom, left + self.width * scale, bottom + self.height * scale
end
function Frame:GetLeft() return select(1, self:Bounds()) / self:GetEffectiveScale() end
function Frame:GetBottom() return select(2, self:Bounds()) / self:GetEffectiveScale() end
function Frame:GetRight() return select(3, self:Bounds()) / self:GetEffectiveScale() end
function Frame:GetTop() return select(4, self:Bounds()) / self:GetEffectiveScale() end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:GetCenter()
    local l, b, r, t = self:Bounds()
    return (l + r) / 2 / self:GetEffectiveScale(), (b + t) / 2 / self:GetEffectiveScale()
end
function Frame:SetPoint(point, relative, relative_point, x, y) self.point = {point, relative, relative_point, x or 0, y or 0} end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetSize(width, height) self.width, self.height = width, height end
function Frame:SetScale(scale) self.scale = scale end
function Frame:SetScript(event, callback) self.scripts[event] = callback end
function Frame:Show() self.shown = true end
local function hidden(frame)
    if frame.scripts.OnHide then frame.scripts.OnHide(frame) end
    for _, child in ipairs(frame.children) do if child.shown then hidden(child) end end
end
function Frame:Hide() if self.shown then self.shown = false; hidden(self) end end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Frame:SetFrameStrata(strata) self.strata = strata end
function Frame:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM" end
function Frame:SetFrameLevel(level) self.level = level end
function Frame:GetFrameLevel() return self.level or (self.parent and self.parent:GetFrameLevel() + 1) or 0 end
function Frame:EnableMouse(enabled) self.mouse = enabled end
function Frame:SetAlpha(value) self.alpha = value end
function Frame:SetMovable(enabled) self.movable = enabled end
function Frame:StartMoving() assert(self.movable); self.moving = true end
function Frame:StopMovingOrSizing() self.moving = false end
function Frame:SetClampedToScreen(enabled) self.clamped = enabled end
function Frame:SetClampRectInsets(l, r, t, b) self.clamp_insets = {l, r, t, b} end
function Frame:DragBy(x, y)
    assert(self.moving)
    local scale = self:GetEffectiveScale()
    if self.clamped then
        local l, b, r, t = self:Bounds()
        local il, ir, it, ib = unpack(self.clamp_insets or {0, 0, 0, 0})
        local sl, sb, sr, st = UIParent:Bounds()
        x = math.max(sl - l - il * scale, math.min(x, sr - r - ir * scale))
        y = math.max(sb - b - ib * scale, math.min(y, st - t - it * scale))
    end
    local l, t = self:GetLeft(), self:GetTop()
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l + x / scale, t + y / scale)
end
function Frame:ClearFocus()
    if focused == self then
        focused = nil
        if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
    end
end
function Frame:SetFocus()
    if focused == self then return end
    if focused then focused:ClearFocus() end
    focused = self
    if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
end
function Frame:HasFocus() return focused == self end
function Frame:SetText(text) self.text = tostring(text) end
function Frame:GetText() return self.text or "" end
function Frame:SetTextColor(...) self.text_color = {...} end
function Frame:SetFont(...) self.font = {...} end
function Frame:SetAutoFocus(value) self.auto_focus = value end
function Frame:SetNumeric(value) self.numeric = value end
function Frame:CreateFontString() return CreateFrame("FontString", nil, self) end
Frame.SetMaxLetters, Frame.SetTextInsets, Frame.HighlightText = noop, noop, noop
Frame.SetBackdrop, Frame.SetBackdropColor, Frame.SetBackdropBorderColor = noop, noop, noop
Frame.SetNormalTexture, Frame.SetPushedTexture, Frame.SetHighlightTexture = noop, noop, noop
Frame.SetToplevel, Frame.RegisterForDrag = noop, noop
CreateFrame = function(kind, name, parent)
    local frame = setmetatable({kind = kind, name = name, parent = parent, scale = 1, width = 0, height = 0,
        shown = true, scripts = {}, children = {}}, Frame)
    if parent then parent.children[#parent.children + 1] = frame end
    all_frames[#all_frames + 1] = frame
    frame.order = #all_frames
    return frame
end
addon.IterateModules = function() return pairs(addon.test_modules) end
addon.GetModule = function(_, name) return addon.test_modules[name] end
addon.ShowOptionsDialog = function() addon.options_opened = true end
local function near(actual, expected, context)
    assert(math.abs(actual - expected) < 0.000001, (context or "coordinate") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function equal(actual, expected, context)
    assert(actual == expected, (context or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function copy(t)
    local result = {}
    for k, v in pairs(t) do result[k] = type(v) == "table" and copy(v) or v end
    return result
end
local function same(actual, expected)
    for k, v in pairs(expected) do
        if type(v) == "table" then same(actual[k], v) else equal(actual[k], v, tostring(k)) end
    end
    for k in pairs(actual) do assert(expected[k] ~= nil, "unexpected key " .. tostring(k)) end
end
local function snapshot(group)
    local result = {}
    for unit, frame in pairs(addon.buttons) do
        if not group or addon:GetUnitAnchorType(unit) == group then result[unit] = {frame:Bounds()} end
    end
    return result
end
local function unchanged(before)
    for unit, bounds in pairs(before) do
        local after = {addon.buttons[unit]:Bounds()}
        for i = 1, 4 do near(after[i], bounds[i], unit .. " stays in place") end
    end
end
local function click_at(x, y)
    local ranks = {BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8}
    local hit
    for _, frame in ipairs(all_frames) do
        if frame.mouse and frame:IsVisible() then
            local l, b, r, t = frame:Bounds()
            if x >= l and x <= r and y >= b and y <= t then
                local rank, level = ranks[frame:GetFrameStrata()], frame:GetFrameLevel()
                if not hit or rank > ranks[hit:GetFrameStrata()] or
                    (rank == ranks[hit:GetFrameStrata()] and (level > hit:GetFrameLevel() or
                    (level == hit:GetFrameLevel() and frame.order > hit.order))) then hit = frame end
            end
        end
    end
    assert(hit, "click must reach an interactive frame")
    if hit.scripts.OnMouseDown then hit.scripts.OnMouseDown(hit, "LeftButton") end
    if hit.scripts.OnClick then hit.scripts.OnClick(hit, "LeftButton") end
    return hit
end
local function click(frame)
    local l, b, r, t = frame:Bounds()
    return click_at((l + r) / 2, (b + t) / 2)
end
local function select_group(group)
    assert(addon:SelectPositioningGroup(group))
    return addon.positioning_panel
end
local function setup(grow, group_scale, hidden_self, count, ui_scale)
    combat, modifier, focused = false, nil, nil
    all_frames, addon.positioning_panel = {}, nil
    UIParent = CreateFrame("Frame")
    UIParent:SetSize(1600, 900)
    UIParent:SetScale(ui_scale or 1)
    addon.party_parent, addon.arena_parent = CreateFrame("Frame", nil, UIParent), CreateFrame("Frame", nil, UIParent)
    addon.db = {base = {locked = false, globalFont = "font", globalFontOutline = "OUTLINE"}}
    addon.buttons, addon.test_modules, addon.arena_size = {}, {HealthBar = {frame = {}}, ClassIcon = {frame = {}}}, count or 3
    addon.positioning_preview, addon.test, addon.options_opened = nil, false, false
    for _, group in ipairs({"party", "arena"}) do
        local db = {x = {}, y = {}, frameScale = group_scale or 1, growDirection = grow,
            margin = 15, groupButtons = true, modules = {HealthBar = true, ClassIcon = true}}
        addon.db[group] = db
        db.x["anchor_" .. group] = (group == "party" and 100 or 900) * UIParent:GetEffectiveScale()
        db.y["anchor_" .. group] = 650 * UIParent:GetEffectiveScale()
        local anchor, background = addon:CreateAnchor(group)
        addon[group .. "_anchor"], addon[group .. "_background"] = anchor, background
        addon:UpdateAnchor(group)
        for i = 1, addon.arena_size do
            local unit = group == "arena" and ("arena" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
            addon.db[unit] = db
            local frame = CreateFrame("Frame", nil, addon[group .. "_parent"])
            addon.buttons[unit] = frame
            frame:SetScale(db.frameScale)
            frame.frame_width, frame.frame_height = 210, 84
            frame:SetSize(210, 84)
            frame.wleft, frame.wright, frame.wtop, frame.wbottom = i == 1 and 347 or 42, 80, 0, 12
            addon:UpdateUnitPosition(unit)
            local health = CreateFrame("StatusBar", nil, frame)
            health:SetSize(120, 40)
            health:SetPoint("TOPLEFT", frame, "TOPLEFT", group == "party" and 2 or 44, -2)
            addon.test_modules.HealthBar.frame[unit] = health
            local icon = CreateFrame("Frame", nil, frame)
            icon:SetSize(40, 80)
            local point = group == "party" and "TOPRIGHT" or "TOPLEFT"
            icon:SetPoint(point, frame, point, group == "party" and -2 or 2, -2)
            addon.test_modules.ClassIcon.frame[unit] = icon
        end
        addon:SaveAnchorPosition(group)
    end
    if hidden_self then addon.buttons.player:Hide() end
end
local function update()
    addon:UpdateAnchorHandle("party")
    addon:UpdateAnchorHandle("arena")
end
local function check_editor(group)
    local left, bottom, right, top
    for unit, frame in pairs(addon.buttons) do
        if addon:GetUnitAnchorType(unit) == group and frame:IsShown() and not frame.soft_hidden then
            local l, b, r, t = frame:Bounds()
            left, bottom = left and math.min(left, l) or l, bottom and math.min(bottom, b) or b
            right, top = right and math.max(right, r) or r, top and math.max(top, t) or t
        end
    end
    local editor = addon[group .. "_anchor"].editor
    assert(editor:IsShown())
    local l, b, r, t = editor:Bounds()
    local padding = 4 * addon:GetPerfectScale()
    near(l, left - padding); near(b, bottom - padding); near(r, right + padding); near(t, top + padding)
    local x, y = addon:GetGroupPosition(group)
    local first
    for i = 1, addon.arena_size do
        local unit = group == "arena" and ("arena" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
        if addon.buttons[unit]:IsShown() and not addon.buttons[unit].soft_hidden then first = unit; break end
    end
    local hl, _, _, ht = addon.test_modules.HealthBar.frame[first]:Bounds()
    local il, _, _, it = addon.test_modules.ClassIcon.frame[first]:Bounds()
    near(x, math.min(hl, il) / UIParent:GetEffectiveScale() - 800)
    near(y, math.max(ht, it) / UIParent:GetEffectiveScale() - 450)
    local panel = addon.positioning_panel
    if panel and panel.group == group then
        assert(math.abs(tonumber(panel.x:GetText()) - x) <= 0.005001)
        assert(math.abs(tonumber(panel.y:GetText()) - y) <= 0.005001)
        near(panel:GetEffectiveScale(), UIParent:GetEffectiveScale(), "controls keep the UI scale")
    end
    equal(editor.mouse, true)
    equal(addon[group .. "_anchor"].mouse, false, "hidden layout origin does not intercept clicks")
end
local passed = 0
local function test(name, run) run(); passed = passed + 1; print("PASS " .. name) end

for _, grow in ipairs({"DOWN", "UP", "VCENTER", "LEFT", "RIGHT", "HCENTER"}) do
    for _, scale in ipairs({0.64, 1, 1.35}) do
        for _, ui_scale in ipairs({0.64, 1}) do
            test(grow .. " scales " .. scale .. "/" .. ui_scale, function()
                setup(grow, scale, true, 3, ui_scale)
                local before, settings = snapshot(), copy(addon.db)
                update(); check_editor("party"); check_editor("arena")
                equal(addon.positioning_panel, nil, "properties stay closed until a group is selected")
                unchanged(before); same(addon.db, settings)
            end)
        end
    end
end

test("party uses the health left edge and enemies include the class icon on the left", function()
    setup("DOWN", 0.64, true, 3, 0.64); update()
    local party_health = addon.test_modules.HealthBar.frame.party1
    local enemy_icon = addon.test_modules.ClassIcon.frame.arena1
    local party_x, party_y, party_unit = addon:GetGroupPosition("party")
    local arena_x, arena_y, arena_unit = addon:GetGroupPosition("arena")
    local scale = UIParent:GetEffectiveScale()
    near(party_x, party_health:GetLeft() * party_health:GetEffectiveScale() / scale - 800)
    near(party_y, party_health:GetTop() * party_health:GetEffectiveScale() / scale - 450)
    near(arena_x, enemy_icon:GetLeft() * enemy_icon:GetEffectiveScale() / scale - 800)
    near(arena_y, enemy_icon:GetTop() * enemy_icon:GetEffectiveScale() / scale - 450)
    equal(party_unit, "party1"); equal(arena_unit, "arena1")
    local before = snapshot()
    assert(addon:SetGroupPosition("party", party_x, party_y))
    assert(addon:SetGroupPosition("arena", arena_x, arena_y))
    unchanged(before)
end)

test("the first visible unit skips hidden and soft-hidden rows in unit order", function()
    setup("UP", 1, true); update()
    local _, _, unit = addon:GetGroupPosition("party"); equal(unit, "party1")
    addon.buttons.party1.soft_hidden = true
    _, _, unit = addon:GetGroupPosition("party"); equal(unit, "party2")
    addon.buttons.player:Show()
    _, _, unit = addon:GetGroupPosition("party"); equal(unit, "player")
    addon.buttons.player:Hide(); addon.buttons.party2:Hide()
    equal(addon:GetGroupPosition("party"), nil)
end)

test("bar resizing preserves the combined top-left across growth directions, scales, and lock states", function()
    for _, grow in ipairs({"DOWN", "UP", "VCENTER", "LEFT", "RIGHT", "HCENTER"}) do
        for _, group_scale in ipairs({0.64, 1.35}) do
            for _, ui_scale in ipairs({0.64, 1}) do
                for _, locked in ipairs({false, true}) do
                    setup(grow, group_scale, true, 3, ui_scale); update()
                    addon.db.base.locked = locked
                    for _, group in ipairs({"party", "arena"}) do
                        local x, y = addon:GetGroupPosition(group)
                        local other = snapshot(group == "party" and "arena" or "party")
                        for _, width in ipairs({283, 157}) do
                            addon:UpdateAnchor(group)
                            for unit, button in pairs(addon.buttons) do
                                if addon:GetUnitAnchorType(unit) == group then
                                    button.frame_width, button.frame_height = width, width / 3
                                    button:SetSize(width, width / 3)
                                    addon.test_modules.HealthBar.frame[unit]:SetSize(width - 90, width / 6)
                                    addon.test_modules.ClassIcon.frame[unit]:SetSize(40, width / 3 - 4)
                                    addon:UpdateUnitPosition(unit)
                                end
                            end
                            addon:UpdateAnchorHandle(group)
                            local actual_x, actual_y = addon:GetGroupPosition(group)
                            near(actual_x, x, grow .. " keeps X after resize")
                            near(actual_y, y, grow .. " keeps Y after resize")
                        end
                        unchanged(other)
                        -- A fresh load reconstructs the same position from the legacy saved origin.
                        addon[group .. "_anchor"].position_db = nil
                        addon:UpdateAnchor(group); addon:UpdateAnchorHandle(group)
                        local reloaded_x, reloaded_y = addon:GetGroupPosition(group)
                        near(reloaded_x, x); near(reloaded_y, y)
                    end
                end
            end
        end
    end
end)

test("hiding the first row changes the reference without moving remaining frames", function()
    setup("DOWN", 1, true); update()
    local before = snapshot()
    addon:UpdateAnchor("party")
    addon.buttons.party1:Hide()
    addon:UpdateAnchorHandle("party")
    unchanged(before)
    local _, _, unit = addon:GetGroupPosition("party"); equal(unit, "party2")
end)

test("grouped unit slots do not move when an individual row's widget bounds change", function()
    for _, grow in ipairs({"DOWN", "UP", "VCENTER", "LEFT", "RIGHT", "HCENTER"}) do
        for _, scale in ipairs({0.64, 1.35}) do
            setup(grow, scale, true, 5); update()
            local before = snapshot()
            for _, unit in ipairs({"party1", "party2", "arena2", "arena3"}) do
                local button = addon.buttons[unit]
                button.wleft, button.wright, button.wtop, button.wbottom = 550, 350, 260, 120
                addon:UpdateUnitPosition(unit)
            end
            unchanged(before)
        end
    end
end)

test("party death, resurrection and queued roster refreshes keep party unit slots fixed", function()
    local original = {}
    for _, name in ipairs({"UpdateUnit", "RefreshUnit", "UpdateArenaFrames", "UpdateBackground", "SendMessage"}) do
        original[name] = addon[name]
    end
    addon.UpdateUnit = function(self, unit) self:UpdateUnitPosition(unit) end
    addon.RefreshUnit, addon.UpdateArenaFrames, addon.UpdateBackground, addon.SendMessage = noop, noop, noop, noop
    for _, hidden_self in ipairs({false, true}) do
        for _, grow in ipairs({"DOWN", "UP", "VCENTER", "LEFT", "RIGHT", "HCENTER"}) do
            setup(grow, 0.64, hidden_self, 3, 0.64); update()
            addon.db.base.hideSelf = hidden_self
            units = {}
            for _, unit in ipairs({"player", "party1", "party2"}) do
                units[unit] = {exists = true, health = 100, guid = unit .. "-guid"}
            end
            addon:UpdatePartyFrames()
            local before = snapshot()
            for _, unit in ipairs({"player", "party1", "party2"}) do
                combat = true
                units[unit].dead, units[unit].health = true, 0
                addon:UNIT_HEALTH("UNIT_HEALTH", unit)
                assert(addon:ShouldDisplayUnitAsDead(unit))
                addon:PARTY_MEMBERS_CHANGED()
                unchanged(before)
                assert(addon:IsUpdatePending())
                combat = false
                addon:PLAYER_REGEN_ENABLED()
                unchanged(before)
                assert(not addon:IsUpdatePending())
                equal(addon.buttons[unit].soft_hidden, unit == "player" and hidden_self)
                units[unit].dead, units[unit].health = nil, 100
                addon:UNIT_HEALTH("UNIT_HEALTH", unit)
                addon:PARTY_MEMBERS_CHANGED()
                assert(not addon:ShouldDisplayUnitAsDead(unit))
                unchanged(before)
            end
        end
    end
    for name in pairs(original) do addon[name] = original[name] end
    addon.SendMessage = original.SendMessage
end)

test("a different profile keeps its saved placement instead of the previous profile's anchor", function()
    setup("DOWN", 1, true); update()
    local previous = addon.db.party
    local old_x, old_y = addon:GetGroupPosition("party")
    local replacement = copy(previous)
    replacement.x.anchor_party = replacement.x.anchor_party + 125
    replacement.y.anchor_party = replacement.y.anchor_party - 65
    addon.db.party, addon.db.player, addon.db.party1, addon.db.party2 = replacement, replacement, replacement, replacement
    addon:UpdateAnchor("party"); addon:UpdateAnchorHandle("party")
    local x, y = addon:GetGroupPosition("party"); near(x, old_x + 125); near(y, old_y - 65)
    near(replacement.x.anchor_party, previous.x.anchor_party + 125)
end)

test("disabled or hidden health and class modules leave positioning available", function()
    setup("DOWN", 1, true); update()
    addon.test_modules.ClassIcon.frame.arena1:Hide()
    local x = addon:GetGroupPosition("arena")
    local health = addon.test_modules.HealthBar.frame.arena1
    near(x, health:GetLeft() - 800)
    addon.db.arena.modules.HealthBar, addon.db.arena.modules.ClassIcon = false, false
    x = addon:GetGroupPosition("arena"); near(x, addon.buttons.arena1:GetLeft() - 800)
    assert(addon:SetGroupPosition("arena", 0, 0))
    local _, y = addon:GetGroupPosition("arena"); near(y, 0)
end)

test("click selects a group and the floating window moves independently", function()
    setup("DOWN", 1, true); update()
    local before, settings = snapshot(), copy(addon.db)
    local editor = addon.party_anchor.editor
    local l, b = editor:Bounds()
    equal(click_at(l + 1, b + 1), editor)
    local panel = addon.positioning_panel
    equal(panel.group, "party"); assert(panel:IsShown())
    equal(panel.parent, UIParent)
    local panel_before = {panel:Bounds()}
    panel.header.scripts.OnDragStart(panel.header)
    assert(panel.moving and not addon.party_anchor.dragging)
    panel:DragBy(120, 80)
    panel.header.scripts.OnDragStop(panel.header)
    near(panel:GetLeft() - panel_before[1], 120)
    near(panel:GetBottom() - panel_before[2], 80)
    unchanged(before); same(addon.db, settings)
    local moved = {panel:Bounds()}
    select_group("arena")
    equal(addon.positioning_panel, panel); equal(panel.group, "arena")
    for i, value in ipairs({panel:Bounds()}) do near(value, moved[i], "selection must not reposition the window") end
end)

test("moving a group leaves the properties window in place", function()
    setup("DOWN", 1, true); update()
    local panel = select_group("party")
    local before = {panel:Bounds()}
    addon:StartAnchorMoving("party")
    addon.party_anchor:DragBy(35, -20)
    addon.party_anchor.scripts.OnUpdate(addon.party_anchor, 0.016)
    addon:StopAnchorMoving("party")
    addon:UpdateAnchorHandle("party")
    for i, value in ipairs({panel:Bounds()}) do near(value, before[i], "group drag must not move the window") end
    assert(addon:SetGroupPosition("party", -100, 80))
    for i, value in ipairs({panel:Bounds()}) do near(value, before[i], "typed coordinates must not move the window") end
end)

test("clicking X and Y focuses the actual fields above an overlapping group", function()
    setup("DOWN", 1, true); update()
    local panel, editor = select_group("party"), addon.party_anchor.editor
    local x, y = editor:GetCenter()
    panel:ClearAllPoints(); panel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    local before = snapshot()
    equal(click(panel.x), panel.x); assert(panel.x:HasFocus())
    assert(not panel.dragging and not addon.party_anchor.dragging)
    unchanged(before)
    panel.x:SetText("-123.5"); panel.x.scripts.OnEnterPressed(panel.x)
    near(addon:GetGroupPosition("party"), -123.5)
    equal(click(panel.y), panel.y); assert(panel.y:HasFocus())
    panel.y:SetText("-46.75"); panel.y.scripts.OnEnterPressed(panel.y)
    local px, py = addon:GetGroupPosition("party"); near(px, -123.5); near(py, -46.75)
end)

test("selection switches coordinates and cancels the previous group's draft", function()
    setup("DOWN", 1, true); update()
    local panel = select_group("party")
    local before = snapshot()
    click(panel.x); panel.x:SetText("999")
    select_group("arena")
    assert(not panel.x:HasFocus())
    unchanged(before)
    local x = addon:GetGroupPosition("arena")
    assert(math.abs(tonumber(panel.x:GetText()) - x) <= 0.005001)
    equal(panel.title:GetText(), "GladiusEx - Arena")
    local text = panel.x:GetText()
    addon:SetGroupPosition("party", 0, 0)
    equal(panel.x:GetText(), text, "only the selected group's coordinates are shown")
end)

test("mouse input remains usable at different group and UI scales", function()
    for _, group_scale in ipairs({0.64, 1.35}) do
        for _, ui_scale in ipairs({0.64, 1}) do
            setup("DOWN", group_scale, true, 3, ui_scale); update()
            local panel = select_group("party")
            equal(click(panel.x), panel.x); assert(panel.x:HasFocus())
            panel.x:SetText("-36.25"); panel.x.scripts.OnEnterPressed(panel.x)
            near(addon:GetGroupPosition("party"), -36.25)
            equal(click(panel.y), panel.y); assert(panel.y:HasFocus())
            panel.y:SetText("17.5"); panel.y.scripts.OnEnterPressed(panel.y)
            local _, y = addon:GetGroupPosition("party"); near(y, 17.5)
        end
    end
end)

test("arrow clicks move only the selected coordinate by one at different scales", function()
    for _, group_scale in ipairs({0.64, 1.35}) do
        for _, ui_scale in ipairs({0.64, 1}) do
            setup("DOWN", group_scale, true, 3, ui_scale); update()
            local panel = select_group("party")
            assert(addon:SetGroupPosition("party", -13.245, 25.755))
            local other, window = snapshot("arena"), {panel:Bounds()}
            for _, axis in ipairs({"x", "y"}) do
                for _, direction in ipairs({"decrease", "increase", "increase"}) do
                    local x, y = addon:GetGroupPosition("party")
                    local button = panel[axis][direction]
                    equal(click(button), button)
                    local actual_x, actual_y = addon:GetGroupPosition("party")
                    local delta = direction == "decrease" and -1 or 1
                    near(actual_x, x + (axis == "x" and delta or 0))
                    near(actual_y, y + (axis == "y" and delta or 0))
                    assert(math.abs(tonumber(panel[axis]:GetText()) - (axis == "x" and actual_x or actual_y)) <= 0.005001)
                    addon:UpdateAnchor("party"); addon:UpdateAnchorHandle("party")
                    local saved_x, saved_y = addon:GetGroupPosition("party")
                    near(saved_x, actual_x); near(saved_y, actual_y)
                end
            end
            unchanged(other)
            for i, value in ipairs({panel:Bounds()}) do near(value, window[i], "arrows leave the window in place") end
        end
    end
end)

test("arrows use a typed draft and preserve invalid input without moving frames", function()
    setup("DOWN", 1, true); update()
    local panel = select_group("party")
    local _, y = addon:GetGroupPosition("party")
    click(panel.x); panel.x:SetText("-40.5")
    equal(click(panel.x.increase), panel.x.increase)
    near(addon:GetGroupPosition("party"), -39.5)
    assert(not panel.x:HasFocus()); equal(panel.x:GetText(), "-39.5")
    local _, after_y = addon:GetGroupPosition("party"); near(after_y, y)
    click(panel.y); panel.y:SetText("250.25")
    equal(click(panel.y.decrease), panel.y.decrease)
    local x; x, y = addon:GetGroupPosition("party"); near(x, -39.5); near(y, 249.25)
    local before = snapshot()
    for _, draft in ipairs({"-", "hello", "1e309", "1000000"}) do
        click(panel.x); panel.x:SetText(draft)
        equal(click(panel.x.increase), panel.x.increase)
        unchanged(before); equal(panel.x:GetText(), draft); assert(panel.x:HasFocus())
    end
end)

test("arrows follow group selection and cannot move frames when editing is unavailable", function()
    setup("DOWN", 1, true); update()
    local panel = select_group("party")
    local party = snapshot("party")
    select_group("arena")
    local x, y = addon:GetGroupPosition("arena")
    equal(click(panel.x.increase), panel.x.increase)
    local actual_x, actual_y = addon:GetGroupPosition("arena"); near(actual_x, x + 1); near(actual_y, y)
    unchanged(party)
    local before = snapshot()
    combat = true; panel.x.increase.scripts.OnClick(); unchanged(before)
    combat = false; addon.db.base.locked = true; panel.y.decrease.scripts.OnClick(); unchanged(before)
    addon.db.base.locked = false; addon:ClearPositioningSelection()
    panel.x.increase.scripts.OnClick(); unchanged(before)
end)

test("close deselects without exiting edit mode or reopening during updates", function()
    setup("DOWN", 1, true); update()
    local panel = select_group("party")
    local before = {panel:Bounds()}
    equal(click(panel.close), panel.close)
    assert(not panel:IsShown()); equal(panel.group, nil); equal(addon.db.base.locked, false)
    addon.party_anchor.scripts.OnUpdate(addon.party_anchor, 0.2)
    addon.arena_anchor.scripts.OnUpdate(addon.arena_anchor, 0.2)
    assert(not panel:IsShown())
    select_group("arena"); assert(panel:IsShown())
    for i, value in ipairs({panel:Bounds()}) do near(value, before[i]) end
end)

test("hiding the addon also hides the independent properties window", function()
    setup("DOWN", 1, true); update()
    local panel = select_group("party")
    click(panel.x)
    addon:HideFrames()
    assert(not panel:IsShown() and not panel.x:HasFocus()); equal(panel.group, nil)
end)

test("negative and decimal coordinates survive a layout refresh", function()
    setup("DOWN", 1.35, true, 3, 0.64); update()
    local other, settings = snapshot("arena"), copy(addon.db.arena)
    assert(addon:SetGroupPosition("party", -127.25, 84.5))
    local x, y = addon:GetGroupPosition("party"); near(x, -127.25); near(y, 84.5)
    unchanged(other); same(addon.db.arena, settings)
    addon:UpdateAnchor("party"); addon:UpdateAnchorHandle("party")
    x, y = addon:GetGroupPosition("party"); near(x, -127.25); near(y, 84.5)
    equal(select_group("party").x:GetText(), "-127.25")
end)

    test("drag from a group updates coordinates before release", function()
        setup("DOWN", 0.64, true); update()
        local anchor, other = addon.party_anchor, snapshot("arena")
        local editor = anchor.editor
        local target = editor
        local x, y = addon:GetGroupPosition("party")
        local saved_x = addon.db.party.x.anchor_party
        target.scripts.OnDragStart(target)
        local panel = addon.positioning_panel
        assert(anchor.moving and anchor.dragging)
        anchor:DragBy(25, -10)
        anchor.scripts.OnUpdate(anchor, 0.016)
        near(addon:GetGroupPosition("party"), x + 25)
        assert(math.abs(tonumber(panel.x:GetText()) - x - 25) <= 0.005)
        assert(math.abs(tonumber(panel.y:GetText()) - y + 10) <= 0.005)
        equal(addon.db.party.x.anchor_party, saved_x, "save on release")
        target.scripts.OnDragStop(target)
        equal(anchor.dragging, nil); equal(anchor.moving, false)
        near(addon.db.party.x.anchor_party, anchor:GetLeft() * anchor:GetEffectiveScale())
        unchanged(other); check_editor("party")
    end)

test("Enter applies, Tab switches fields, and Escape cancels", function()
    setup("DOWN", 1, true); update()
    local editor = select_group("party")
    equal(click(editor.x), editor.x); assert(editor.x:HasFocus())
    editor.x:SetText("-42.75")
    addon.party_anchor.scripts.OnUpdate(addon.party_anchor, 0.2)
    equal(editor.x:GetText(), "-42.75", "polling must preserve typing")
    editor.x.scripts.OnTabPressed(editor.x)
    near(addon:GetGroupPosition("party"), -42.75); assert(editor.y:HasFocus())
    editor.y:SetText("68.25"); editor.y.scripts.OnEnterPressed(editor.y)
    local x, y = addon:GetGroupPosition("party"); near(x, -42.75); near(y, 68.25)
    editor.x:SetFocus(); editor.x:SetText("999"); editor.x.scripts.OnEscapePressed(editor.x)
    near(addon:GetGroupPosition("party"), -42.75); equal(editor.x:GetText(), "-42.75")
    equal(editor.x.numeric, false, "minus signs and decimals must be accepted")
    equal(editor.x.auto_focus, false)
    equal(editor.x.mouse, true, "coordinate fields accept mouse input")
end)

test("invalid input and unfinished text never change a position", function()
    setup("DOWN", 1, true); update()
    local editor, before = select_group("party"), snapshot()
    for _, text in ipairs({"", "-", "hello", "1e309", "nan", "1000001"}) do
        editor.x:SetFocus(); editor.x:SetText(text); editor.x.scripts.OnEnterPressed(editor.x)
        unchanged(before); assert(editor.x:HasFocus())
        editor.x.scripts.OnEscapePressed(editor.x)
    end
    editor.x:SetFocus(); editor.x:SetText("44"); editor.x:ClearFocus()
    unchanged(before)
end)

test("hidden self and empty groups do not leave stale editor areas", function()
    setup("DOWN", 1, false, 1); update(); check_editor("party")
    addon.buttons.player:Hide(); addon:UpdateAnchorHandle("party")
    equal(addon.party_anchor.editor:IsShown(), false)
    addon.buttons.player:Show(); addon:UpdateAnchorHandle("party"); check_editor("party")
    addon.buttons.player.soft_hidden = true; addon:UpdateAnchorHandle("party")
    equal(addon.party_anchor.editor:IsShown(), false)
end)

test("visible attached elements expand the drag area and hidden ones do not", function()
    setup("DOWN", 1, true); update()
    local button = addon.buttons.party1
    local icon = CreateFrame("Frame", nil, button)
    icon:SetSize(32, 32); icon:SetPoint("TOPRIGHT", button, "TOPLEFT", -5, 0)
    addon.test_modules.Cooldowns = {GetPositioningFrames = function(_, unit) return unit == "party1" and {icon} or {} end,
        GetFrames = function() error("reserved container must not be used") end}
    addon.db.party.modules.Cooldowns = true
    local before = snapshot()
    local x, y = addon:GetGroupPosition("party")
    addon:UpdateAnchorHandle("party")
    near(addon.party_anchor.editor:GetLeft(), icon:GetLeft() - 4 * addon:GetPerfectScale())
    local after_x, after_y = addon:GetGroupPosition("party"); near(after_x, x); near(after_y, y)
    unchanged(before)
    icon:Hide(); addon:UpdateAnchorHandle("party"); check_editor("party")
end)

test("combat interrupts movement and hides editors without moving other frames", function()
    setup("DOWN", 1, true); update()
    assert(addon:StartAnchorMoving("party"))
    addon.party_anchor:DragBy(10, -10)
    combat = true; addon:PLAYER_REGEN_DISABLED()
    assert(not addon.party_anchor.dragging and not addon.party_anchor.moving)
    assert(not addon.party_anchor.editor:IsShown() and not addon.arena_anchor.editor:IsShown())
    assert(not addon.positioning_panel:IsShown()); equal(addon.positioning_panel.group, nil)
    local before = snapshot()
    equal(addon:StartAnchorMoving("party"), false)
    equal(addon:SetGroupPosition("party", 0, 0), false)
    equal(addon:SetPositioningMode(true), false)
    unchanged(before)
    combat = false; update(); check_editor("party")
    assert(not addon.positioning_panel:IsShown(), "returning from combat waits for another selection")
    addon.db.base.locked = true; update()
    assert(not addon.party_anchor.editor:IsShown())
    equal(addon:StartAnchorMoving("party"), false)
end)

test("dragging to screen edges clamps only the moving group", function()
    setup("DOWN", 0.64, true); update()
    local anchor = addon.party_anchor
    addon:StartAnchorMoving("party")
    for _, delta in ipairs({-10000, 10000}) do
        anchor:DragBy(delta, delta)
        local l, b, r, t = anchor.editor:Bounds()
        assert(l >= -0.000001 and b >= -0.000001 and r <= 1600.000001 and t <= 900.000001)
    end
    addon:StopAnchorMoving("party")
end)

test("numeric offscreen placement keeps coordinate controls available", function()
    setup("DOWN", 1, true); update()
    local panel = select_group("party")
    assert(addon:SetGroupPosition("party", -5000, 5000))
    local l, b, r, t = panel:Bounds()
    assert(l >= -0.000001 and b >= -0.000001 and r <= 1600.000001 and t <= 900.000001,
        string.format("coordinate panel outside screen: %.9f, %.9f, %.9f, %.9f", l, b, r, t))
    assert(addon:SetGroupPosition("party", 0, 0))
    local x, y = addon:GetGroupPosition("party"); near(x, 0); near(y, 0)
end)

for _, key in ipairs({"shift", "alt", "control"}) do
    test(key .. " click supports anchor origin and group alignment", function()
        setup("DOWN", 0.64, true); update()
        local editor, other = addon.party_anchor.editor, snapshot("arena")
        modifier = key; editor.scripts.OnMouseDown(editor, "LeftButton")
        local x, y = addon:GetGroupPosition("party")
        if key == "shift" then near(x, 0)
        elseif key == "alt" then near(y, 0)
        else local _, other_y = addon:GetGroupPosition("arena"); near(y, other_y) end
        unchanged(other)
    end)
end

test("saving one group preserves the other's positions and each unit's scale", function()
    setup("DOWN", 0.64, true); update()
    local settings = copy(addon.db.arena)
    addon.buttons.party1:SetScale(1.35)
    addon:SaveAnchorPosition("party")
    near(addon.db.party.x.party1, addon.buttons.party1:GetLeft() * addon.buttons.party1:GetEffectiveScale())
    same(addon.db.arena, settings)
end)

test("global font changes reach editor labels and coordinate fields", function()
    setup("DOWN", 1, true); update()
    local panel = select_group("party")
    addon.db.base.globalFont = "new font"; addon:UpdateAnchorHandle("party")
    equal(panel.title.font[1], "new font")
    equal(panel.x.font[1], "new font")
end)

test("mode switching previews groups, Done locks, and manual previews survive", function()
    setup("DOWN", 1, true)
    local original_update, original_testing = addon.UpdateFrames, addon.SetTesting
    addon.UpdateFrames = function()
        for _, group in ipairs({"party", "arena"}) do addon:UpdateAnchor(group); addon:UpdateAnchorHandle(group) end
    end
    addon.SetTesting = function(_, count)
        addon.positioning_preview, addon.test = nil, count
        if count then addon.party_parent:Show(); addon.arena_parent:Show()
        else addon.party_parent:Hide(); addon.arena_parent:Hide() end
        addon:UpdateFrames()
    end
    addon.party_parent:Hide(); addon.arena_parent:Hide()
    assert(addon:SetPositioningMode(true))
    equal(addon.test, 3); equal(addon.positioning_preview, true)
    local before = snapshot()
    select_group("party").done.scripts.OnClick()
    equal(addon.db.base.locked, true); equal(addon.test, false)
    equal(addon.party_anchor.editor:IsShown(), false); unchanged(before)
    addon.test = 5
    assert(addon:SetPositioningMode(true))
    equal(addon.test, 5); equal(addon.positioning_preview, false)
    addon:SetPositioningMode(false); equal(addon.test, 5, "keep an existing manual preview")
    addon.UpdateFrames, addon.SetTesting = original_update, original_testing
end)

test("idle updates recover an editor when visible frames reappear", function()
    setup("DOWN", 1, false, 1); update()
    local anchor = addon.party_anchor
    addon.buttons.player:Hide(); addon:UpdateAnchorHandle("party")
    assert(not anchor.editor:IsShown())
    addon.buttons.player:Show()
    anchor.scripts.OnUpdate(anchor, 0.2)
    check_editor("party")
end)

-- Load the real attachment modules; only their data sources are stubbed.
libs["LibFunctional-1.0"].merge = function(a, b)
    local result = copy(a)
    for k, v in pairs(b or {}) do result[k] = type(v) == "table" and copy(v) or v end
    return result
end
libs["LibCooldownTracker-1.0"], libs["LibDispellable-1.0"], libs["DRData-1.0"], libs["LibAuraInfo-1.0"] = {}, {}, {}, {}
bit = {bor = noop, lshift = noop, band = noop}
addon.Data = {GetDefaultSpells = function() return {{}, {}} end}
local loaded = {}
addon.GetModule = function(_, name) return addon.test_modules[name] or loaded[name] end
addon.NewModule = function(_, name)
    local module = {GetName = function() return name end}
    loaded[name] = module
    return module
end
load_file("modules/cooldowns.lua")
load_file("modules/auras.lua")
load_file("modules/drtracker.lua")

test("cooldown outline excludes empty slots and detached groups", function()
    setup("DOWN", 1, true)
    local parent = CreateFrame("Frame", nil, addon.buttons.party1)
    parent[1], parent[2] = CreateFrame("Frame", nil, parent), CreateFrame("Frame", nil, parent)
    parent[2]:Hide()
    local module, db = loaded.Cooldowns, {cooldownsDetached = false, cooldownsBackground = {a = 0}}
    module.GetNumGroups = function() return 1 end
    module.GetGroupDB = function() return db end
    module.GetGroupState = function() return {frame = parent} end
    local frames = module:GetPositioningFrames("party1")
    equal(#frames, 1); equal(frames[1], parent[1])
    db.cooldownsBackground.a = 0.5
    equal(module:GetPositioningFrames("party1")[1], parent)
    db.cooldownsDetached = true; equal(#module:GetPositioningFrames("party1"), 0)
    db.cooldownsDetached = false; parent:Hide(); equal(#module:GetPositioningFrames("party1"), 0)
end)

test("aura and diminishing-return outlines follow visible icons", function()
    setup("DOWN", 1, true)
    local parent = CreateFrame("Frame", nil, addon.buttons.party1)
    parent[1], parent[2] = CreateFrame("Frame", nil, parent), CreateFrame("Frame", nil, parent)
    parent[2]:Hide()
    local auras, dr = loaded.Auras, loaded.DRTracker
    auras.db, auras.buffFrame, auras.debuffFrame = {party1 = {aurasBuffs = true}}, {party1 = parent}, {}
    local frames = auras:GetPositioningFrames("party1")
    equal(#frames, 1); equal(frames[1], parent[1])
    auras.db.party1.aurasBuffs = false; equal(#auras:GetPositioningFrames("party1"), 0)
    parent.tracker = {stun = parent[1], fear = parent[2]}; dr.frame = {party1 = parent}
    frames = dr:GetPositioningFrames("party1"); equal(#frames, 1); equal(frames[1], parent[1])
    parent:Hide(); equal(#dr:GetPositioningFrames("party1"), 0)
end)

test("edit and move commands toggle positioning mode", function()
    SlashCmdList = {}
    load_file("options.lua")
    local original, requested = addon.SetPositioningMode, nil
    addon.SetPositioningMode = function(_, enabled) requested = enabled; addon.db.base.locked = not enabled end
    addon.db.base.locked = true
    SlashCmdList.GLADIUSEX("edit"); equal(requested, true)
    SlashCmdList.GLADIUSEX("edit"); equal(requested, false)
    SlashCmdList.GLADIUSEX("move"); equal(requested, true)
    addon.SetPositioningMode = original
end)

print(passed .. " positioning checks passed")
