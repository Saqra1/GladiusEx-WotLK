-- Run from the addon directory with Lua 5.1: lua tests/sound_widget.lua
local widgetPath = arg[1] or "libs/AceGUI-3.0-SharedMediaWidgets/SoundWidget.lua"
local prototypesPath = arg[2] or "libs/AceGUI-3.0-SharedMediaWidgets/prototypes.lua"
local function noop() end
local frames = {}
local Frame = {}
Frame.__index = Frame
for _, method in ipairs({"SetBackdrop", "SetBackdropBorderColor", "SetTexCoord", "SetJustifyH",
    "SetTextColor", "SetNormalTexture", "SetPushedTexture", "SetDisabledTexture", "SetHighlightTexture",
    "SetClampedToScreen", "EnableMouse", "EnableMouseWheel", "SetOrientation", "SetThumbTexture", "SetDesaturated"}) do
    Frame[method] = noop
end
function Frame:ClearAllPoints() self.points = {} end
function Frame:SetPoint(point, relative, relativePoint, x, y)
    self.points[point] = {relative = relative, point = relativePoint, x = x or 0, y = y or 0}
end
function Frame:SetAllPoints(relative) self.allPoints = relative end
function Frame:SetTexture(path) self.texture = path end
function Frame:SetParent(parent) self.parent = parent end
function Frame:GetParent() return self.parent end
function Frame:SetFrameLevel(level) self.level = level end
function Frame:GetFrameLevel() return self.level end
function Frame:SetFrameStrata(strata) self.strata = strata end
function Frame:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM" end
function Frame:SetWidth(width) self.width = width end
function Frame:GetWidth() return self.width or self.parent:GetWidth() end
function Frame:SetHeight(height) self.height = height end
function Frame:GetHeight() return self.height or self.parent:GetHeight() end
function Frame:SetScript(event, handler) self.scripts[event] = handler end
function Frame:Show() self.shown = true end
function Frame:Hide()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Frame:Enable() self.enabled = true end
function Frame:Disable() self.enabled = false end
function Frame:SetText(text) self.text = text end
function Frame:GetText() return self.text end
function Frame:GetStringWidth() return #(self.text or ""):gsub("[\128-\191]", "") * 8 end
function Frame:SetMinMaxValues(low, high) self.low, self.high = low, high end
function Frame:SetValueStep(step) self.step = step end
function Frame:GetValue() return self.value or 0 end
function Frame:SetValue(value)
    self.value = math.min(self.high or value, math.max(self.low or value, value))
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, self.value) end
end
function CreateFrame(kind, name, parent)
    local frame = setmetatable({kind = kind, parent = parent, scripts = {}, points = {},
        level = parent and parent:GetFrameLevel() + 1 or 0}, Frame)
    frames[#frames + 1] = frame
    return frame
end
function Frame:CreateTexture(_, layer)
    local texture = CreateFrame("Texture", nil, self)
    texture.layer = layer
    return texture
end
function Frame:CreateFontString() return CreateFrame("FontString", nil, self) end
UIParent = CreateFrame("Frame")
UIParent:SetHeight(900)
UIParent:SetWidth(1200)
wipe = function(t) for key in pairs(t) do t[key] = nil end end
strmatch = string.match

dofile("libs/LibStub/LibStub.lua")
local gui = LibStub:NewLibrary("AceGUI-3.0", 1)
gui.version = 17
function gui:RegisterWidgetType(_, constructor, version)
    if version > self.version then self.constructor, self.version = constructor, version end
end
function gui:RegisterAsWidget(widget)
    function widget:SetHeight(height) self.frame:SetHeight(height) end
    function widget:SetWidth(width) self.frame:SetWidth(width) end
    function widget:Fire(event, value) self.lastEvent, self.lastValue = event, value end
end
function gui:ClearFocus()
    if self.focus then self.focus:ClearFocus() end
    self.focus = nil
end
function gui:SetFocus(widget)
    if self.focus ~= widget then self:ClearFocus() end
    self.focus = widget
end
local sounds = {}
for i = 1, 40 do sounds[string.format("Sound %02d", i)] = "sound" .. i .. ".wav" end
local media = LibStub:NewLibrary("LibSharedMedia-3.0", 1)
function media:HashTable() return sounds end
function media:Fetch(_, key) return sounds[key] end
local played, playCount
playCount = 0
PlaySoundFile = function(path) played, playCount = path, playCount + 1 end
dofile(prototypesPath)
-- The sound list must not depend on whichever shared dropdown another addon installed.
local shared = LibStub("AceGUISharedMediaWidgets-1.0")
shared.GetDropDownFrame = function() error("sound list must own its visible rows") end
shared.ReturnDropDownFrame = shared.GetDropDownFrame
dofile(widgetPath)
assert(gui.constructor, "fixed sound widget must replace installed version 17")
local widget = gui.constructor()
widget:OnAcquire()
widget:SetList(sounds)
widget:SetValue("Sound 40")

local cases = 0
local function toggle(control)
    local button = (control or widget).frame.dropButton
    button.scripts.OnClick(button)
end
local function preview(row) row.soundbutton.scripts.OnClick(row.soundbutton) end
local function test(name, run)
    run()
    cases = cases + 1
    print("ok - " .. name)
end
local function checkRows(dropdown)
    local visible = 0
    for index, row in ipairs(dropdown.rows) do
        if row.shown then
            visible = visible + 1
            assert(row:GetParent() == dropdown and dropdown.kind == "Frame", "rows must render directly in the menu")
            local anchor = row.points.TOPLEFT
            assert(anchor.relative == dropdown and anchor.x == 14 and anchor.y == -13 - (index - 1) * 18)
            local right = anchor.x + row:GetWidth()
            assert(right <= dropdown:GetWidth() - (dropdown.slider.shown and 28 or 14), "rows must stop before the scrollbar")
            assert(-anchor.y + row:GetHeight() <= dropdown:GetHeight() - 12, "rows must fit inside the menu")
            assert(row.soundbutton:GetParent() == row and row.soundbutton:GetFrameLevel() > row:GetFrameLevel())
            assert(row.soundbutton.points.RIGHT.relative == row and row.soundbutton.points.RIGHT.x == -1)
            assert(row.speaker:GetParent() == row.soundbutton and row.speaker.layer == "OVERLAY")
            assert(row.speaker.allPoints == row.soundbutton, "speaker graphic must cover its preview button")
            assert(row.speaker.texture == [[Interface\Common\VoiceChat-Speaker]])
            assert(row.speakeron:GetParent() == row.soundbutton and row.speakeron.layer == "HIGHLIGHT")
            assert(row.text:GetStringWidth() <= row:GetWidth() - 38, "labels must leave room for the speaker")
        end
    end
    assert(visible == dropdown.visibleCount)
    assert(dropdown:GetHeight() <= UIParent:GetHeight() * 2/5)
    for _, frame in ipairs(frames) do assert(frame.kind ~= "ScrollFrame", "sound rows must bypass scroll-child texture clipping") end
end

test("selected sound preview draws above the control", function()
    assert(widget.soundbutton:GetFrameLevel() > widget.frame:GetFrameLevel())
    widget.soundbutton.scripts.OnClick(widget.soundbutton)
    assert(played == sounds["Sound 40"])
end)

test("speaker icons and their buttons stay inside the visible list", function()
    toggle()
    local dropdown = widget.dropdown
    assert(#dropdown.keys == 40 and #dropdown.rows < 40 and dropdown.slider.shown)
    assert(dropdown.slider.step == 1)
    checkRows(dropdown)
    preview(dropdown.rows[1])
    assert(played == sounds["Sound 01"] and widget.lastEvent == nil and widget.dropdown == dropdown)
end)

test("scrollbar and mouse wheel reach every sound without moving the preview column", function()
    local dropdown = widget.dropdown
    dropdown.slider:SetValue(dropdown.slider.high)
    checkRows(dropdown)
    local last = dropdown.rows[dropdown.visibleCount]
    assert(last.soundKey == "Sound 40" and last.check.shown)
    preview(last)
    assert(played == sounds["Sound 40"] and widget.dropdown == dropdown and widget.lastEvent == nil)
    dropdown.scripts.OnMouseWheel(dropdown, 1)
    assert(dropdown.slider:GetValue() == dropdown.slider.high - 3)
    checkRows(dropdown)
    dropdown.slider:SetValue(0)
    assert(dropdown.rows[1].soundKey == "Sound 01")
    for _, row in ipairs(dropdown.rows) do assert(not row.check.shown, "reused rows must clear old checkmarks") end
    dropdown.scripts.OnMouseWheel(dropdown, -100)
    assert(dropdown.rows[dropdown.visibleCount].soundKey == "Sound 40")
    checkRows(dropdown)
end)

test("short lists hide spare rows and selection closes before notifying", function()
    toggle()
    widget:SetList({["Sound 01"] = sounds["Sound 01"], ["Sound 02"] = sounds["Sound 02"]})
    toggle()
    local dropdown = widget.dropdown
    assert(dropdown.visibleCount == 2 and not dropdown.slider.shown)
    checkRows(dropdown)
    local row = dropdown.rows[2]
    row.scripts.OnClick(row)
    assert(widget.lastEvent == "OnValueChanged" and widget.lastValue == "Sound 02")
    assert(widget.dropdown == nil and not dropdown.shown)
end)

test("long and Unicode labels preserve full preview and selection keys", function()
    local longName = "ZZ Long sound " .. string.rep("very long sound ", 20)
    local unicodeName = "ZZZ" .. string.rep("\232\173\166", 80)
    local choices = {[longName] = "long.wav", [unicodeName] = "unicode.wav"}
    for name, path in pairs(sounds) do choices[name] = path end
    widget:SetList(choices)
    widget.lastEvent = nil
    widget:SetWidth(350)
    toggle()
    local dropdown = widget.dropdown
    dropdown.slider:SetValue(dropdown.slider.high)
    checkRows(dropdown)
    for _, row in ipairs(dropdown.rows) do
        if row.soundKey == longName or row.soundKey == unicodeName then
            assert(row.text:GetText() ~= row.soundKey and row.text:GetText():sub(-3) == "...")
            if row.soundKey == unicodeName then assert((#row.text:GetText() - 6) % 3 == 0) end
            preview(row)
            assert(played == choices[row.soundKey] and widget.dropdown == dropdown and widget.lastEvent == nil)
        end
    end
    local row = dropdown.rows[dropdown.visibleCount]
    row.scripts.OnClick(row)
    assert(widget.lastValue == unicodeName)
end)

test("reopened menus refit smaller controls and shorter screens", function()
    widget:SetWidth(100)
    UIParent:SetHeight(450)
    toggle()
    assert(widget.dropdown:GetWidth() == 200 and widget.dropdown.visibleCount < 18)
    checkRows(widget.dropdown)
    toggle()
    UIParent:SetHeight(900)
end)

test("blank and None entries preview inherited sounds while silent entries stay silent", function()
    widget:SetList({[""] = "inherited.wav", None = "inherited.wav", Silent = ""})
    widget.lastEvent = nil
    toggle()
    local dropdown = widget.dropdown
    for _, row in ipairs(dropdown.rows) do
        if row.shown then
            local before = playCount
            preview(row)
            if row.soundKey == "Silent" then assert(playCount == before)
            else assert(playCount == before + 1 and played == "inherited.wav") end
            assert(widget.dropdown == dropdown and widget.lastEvent == nil)
        end
    end
    toggle()
end)

test("focus changes, hiding, disabling and release close the private menu", function()
    widget:SetList(sounds)
    toggle()
    local dropdown = widget.dropdown
    local other = gui.constructor()
    other:OnAcquire()
    other:SetList(sounds)
    toggle(other)
    assert(widget.dropdown == nil and not dropdown.shown and other.dropdown ~= dropdown)
    toggle()
    assert(other.dropdown == nil)
    widget.frame:Hide()
    assert(widget.dropdown == nil and not dropdown.shown)
    widget.frame:Show()
    toggle()
    widget:SetDisabled(true)
    local before = playCount
    widget.soundbutton.scripts.OnClick(widget.soundbutton)
    toggle()
    assert(widget.dropdown == nil and not widget.soundbutton.enabled and playCount == before)
    widget:SetDisabled(false)
    toggle()
    widget:OnRelease()
    assert(widget.dropdown == nil and not dropdown.shown and widget.list == nil and widget.value == nil)
end)

test("empty lists safely reuse a menu after release", function()
    widget:OnAcquire()
    widget:SetList({})
    toggle()
    assert(widget.dropdown.visibleCount == 0 and not widget.dropdown.slider.shown)
    checkRows(widget.dropdown)
    toggle()
end)

test("the older nested widget cannot replace the fixed sound list", function()
    local constructor = gui.constructor
    dofile("libs/AceGUI-3.0-SharedMediaWidgets/AceGUI-3.0-SharedMediaWidgets/SoundWidget.lua")
    assert(gui.constructor == constructor and gui.version == 18)
end)

print("Passed " .. cases .. " sound widget tests")
