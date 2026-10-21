-- Run from the addon directory with Lua 5.1: lua tests/options_tree.lua
-- Optional widget source and installed version allow checking other embedded copies.
local widgetPath = arg[1] or "libs/AceGUI-3.0/widgets/AceGUIContainer-TreeGroup.lua"
local installedVersion = tonumber(arg[2]) or 50
local function noop() end
floor = math.floor
FONT_COLOR_CODE_CLOSE = "|r"

local Frame = {}
Frame.__index = Frame
for _, name in ipairs({"SetPoint", "ClearAllPoints", "SetBackdrop", "SetBackdropColor",
    "SetBackdropBorderColor", "SetResizable", "SetMinResize", "SetMaxResize",
    "EnableMouseWheel", "SetAllPoints", "SetTexture", "SetTexCoord", "SetNormalFontObject",
    "SetHighlightFontObject", "LockHighlight", "UnlockHighlight", "SetValueStep"}) do
    Frame[name] = noop
end
function Frame:SetScript(event, callback) self.scripts[event] = callback end
function Frame:SetParent(parent) self.parent = parent end
function Frame:GetParent() return self.parent end
function Frame:SetFrameLevel(level) self.level = level end
function Frame:GetFrameLevel() return self.level or 0 end
function Frame:SetWidth(width) self.width = width end
function Frame:GetWidth() return self.width or 600 end
function Frame:SetHeight(height) self.height = height end
function Frame:GetHeight() return self.height or 300 end
function Frame:EnableMouse(enabled) self.mouse = enabled end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Frame:SetValue(value) self.value = value end
function Frame:GetValue() return self.value or 0 end
function Frame:SetMinMaxValues(low, high) self.low, self.high = low, high end
function Frame:SetText(text) self.textValue = text end
function Frame:GetText() return self.textValue end
function CreateFrame(kind, name, parent, template)
    local frame = setmetatable({parent = parent, scripts = {}, shown = true, mouse = true}, Frame)
    if template == "OptionsListButtonTemplate" then
        frame.text = CreateFrame("FontString", nil, frame)
        frame.toggle = CreateFrame("Button", nil, frame)
        frame.toggle.SetNormalTexture, frame.toggle.SetPushedTexture = noop, noop
    end
    return frame
end
function Frame:CreateTexture() return CreateFrame("Texture", nil, self) end
UIParent = CreateFrame("Frame")
local tooltipShows = 0
GameTooltip = {SetOwner = noop, ClearAllPoints = noop, SetPoint = noop,
    SetText = noop, Hide = noop, Show = function() tooltipShows = tooltipShows + 1 end}

local gui = {version = installedVersion, count = 0}
function gui:GetWidgetVersion() return self.version end
function gui:GetNextWidgetNum() self.count = self.count + 1; return self.count end
function gui:RegisterWidgetType(_, constructor, version)
    self.constructor, self.version = constructor, version
end
function gui:RegisterAsContainer(widget)
    widget.frame.obj = widget
    widget.events = {}
    function widget:Fire(event, ...) if self.events[event] then self.events[event](self, event, ...) end end
    return widget
end
gui.ClearFocus = noop
LibStub = function(name) assert(name == "AceGUI-3.0"); return gui end
dofile(widgetPath)
assert(gui.constructor, "patched TreeGroup must replace installed version " .. installedVersion)

local cases = 0
local function test(name, run)
    run()
    cases = cases + 1
    print("PASS " .. name)
end
local function newWidget()
    local widget = gui.constructor()
    widget.frame:SetParent(CreateFrame("Frame", nil, UIParent))
    widget:OnAcquire()
    widget:EnableButtonTooltips(false)
    return widget
end
local function hover(button)
    if button:IsVisible() and button.mouse then button.scripts.OnEnter(button) end
end
local root = {args = {
    arena = {name = "Arena"},
    party = {args = {Alerts = {args = {casts = {args = {Polymorph = {name = "Polymorph"}}}}}}},
}}
local function checkPath(widget, path)
    widget.events.OnButtonEnter = function(_, _, value)
        local option = root
        for _, key in ipairs(path) do option = assert(option.args[key], "missing parent " .. key) end
        option = assert(option.args[value], "stale tree button: " .. value)
        assert(option.name)
        widget.hovers = (widget.hovers or 0) + 1
    end
end

test("reusing the main tree for Alerts cannot hover the old Arena row", function()
    local widget = newWidget()
    checkPath(widget, {})
    widget:SetTree({{value = "arena", text = "Arena"}})
    hover(widget.buttons[1])
    assert(widget.hovers == 1)
    widget.frame:Hide()
    widget:SetTree(nil) -- AceConfigDialog's OnRelease callback
    widget:OnRelease()
    widget.frame:SetParent(UIParent) -- AceGUI's pool release
    widget:OnAcquire()
    checkPath(widget, {"party", "Alerts", "casts"})
    widget.treeframe:SetHeight(0) -- layout is not ready yet
    widget:SetTree({{value = "Polymorph", text = "Polymorph"}})
    widget.frame:SetParent(CreateFrame("Frame", nil, UIParent))
    widget.frame:Show()
    hover(widget.buttons[1])
    assert(widget.hovers == 1, "old row must remain inactive until redraw")
    widget.treeframe:SetHeight(300)
    widget:RefreshTree()
    hover(widget.buttons[1])
    assert(widget.hovers == 2, "new row must become interactive after redraw")
end)

test("clearing a tree deactivates its rows before options paths are recycled", function()
    local widget = newWidget()
    widget:SetTree({{value = "arena", text = "Arena"}})
    widget:SetTree(nil)
    widget.events.OnButtonEnter = function() error("hover after clearing options") end
    hover(widget.buttons[1])
    assert(not widget.buttons[1]:IsVisible() and not widget.buttons[1].mouse)
end)

test("a deferred redraw hides old rows until the first frame update", function()
    local widget = newWidget()
    widget:SetTree({{value = "arena", text = "Arena"}})
    widget.frame:SetParent(UIParent)
    widget:SetTree({{value = "Polymorph", text = "Polymorph"}})
    checkPath(widget, {"party", "Alerts", "casts"})
    hover(widget.buttons[1])
    assert(not widget.hovers)
    assert(widget.frame.scripts.OnUpdate, "deferred redraw scheduled")
    widget.frame.scripts.OnUpdate(widget.frame)
    hover(widget.buttons[1])
    assert(widget.hovers == 1)
end)

test("zero-height redraws and shorter trees deactivate unused rows", function()
    local widget = newWidget()
    widget:SetTree({{value = "arena", text = "Arena"}, {value = "party", text = "Party"}})
    widget:SetTree({{value = "arena", text = "Arena"}})
    assert(not widget.buttons[2]:IsVisible() and not widget.buttons[2].mouse)
    widget.treeframe:SetHeight(0)
    widget:RefreshTree()
    assert(not widget.buttons[1]:IsVisible() and not widget.buttons[1].mouse)
    widget.treeframe:SetHeight(300)
    widget:RefreshTree()
    assert(widget.buttons[1]:IsVisible() and widget.buttons[1].mouse)
end)

test("tooltips work with both old and new AceGUI cores", function()
    local widget = newWidget()
    widget:EnableButtonTooltips(true)
    widget:SetTree({{value = "arena", text = "Arena"}})
    local before = tooltipShows
    hover(widget.buttons[1]) -- older core has only GameTooltip
    gui.tooltip = GameTooltip
    hover(widget.buttons[1])
    assert(tooltipShows == before + 2)
end)

print(cases .. " options tree regression checks passed")
