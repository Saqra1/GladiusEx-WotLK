local GladiusEx = _G.GladiusEx
local L = LibStub("AceLocale-3.0"):GetLocale("GladiusEx")
local LSM = LibStub("LibSharedMedia-3.0")
local min, max, abs = math.min, math.max, math.abs

local function coordinate_text(value)
    if abs(value) < 0.005 then value = 0 end
    return (string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", ""))
end

local function valid_coordinate(value)
    return type(value) == "number" and value == value and abs(value) <= 1000000
end

function GladiusEx:GetPositioningBounds(group)
    local left, bottom, right, top
    local function include(frame)
        if not frame or not frame:IsShown() then return end
        local l, b, r, t = frame:GetLeft(), frame:GetBottom(), frame:GetRight(), frame:GetTop()
        if not l or not b or not r or not t or r <= l or t <= b then return end
        local scale = frame:GetEffectiveScale()
        l, b, r, t = l * scale, b * scale, r * scale, t * scale
        left, bottom = left and min(left, l) or l, bottom and min(bottom, b) or b
        right, top = right and max(right, r) or r, top and max(top, t) or t
    end

    for i = 1, self.arena_size or 0 do
        local unit = group == "arena" and ("arena" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
        local button = self.buttons[unit]
        if button and button:IsShown() and not button.soft_hidden then
            include(button)
            for name, module in self:IterateModules() do
                if self:IsModuleEnabled(unit, name) then
                    local get_frames = module.GetPositioningFrames or module.GetFrames
                    local frames = get_frames and get_frames(module, unit)
                    if frames then
                        for _, frame in ipairs(frames) do include(frame) end
                    end
                end
            end
        end
    end
    return left, bottom, right, top
end

-- Use the first visible unit's health bar and class icon, excluding widgets
-- such as cooldowns and auras. Unit order stays the same for every growth direction.
function GladiusEx:GetGroupPositionReference(group)
    for i = 1, self.arena_size or 0 do
        local unit = group == "arena" and ("arena" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
        local button = self.buttons[unit]
        if button and button:IsShown() and not button.soft_hidden then
            local left, top
            local function include(frame)
                if not frame or not frame:IsShown() then return end
                local l, t = frame:GetLeft(), frame:GetTop()
                if not l or not t or frame:GetWidth() <= 0 or frame:GetHeight() <= 0 then return end
                local scale = frame:GetEffectiveScale()
                left = left and min(left, l * scale) or l * scale
                top = top and max(top, t * scale) or t * scale
            end
            for _, name in ipairs({"HealthBar", "ClassIcon"}) do
                local module = self:GetModule(name, true)
                if module and self:IsModuleEnabled(unit, name) then include(module.frame and module.frame[unit]) end
            end
            -- Keep positioning available if both display modules are disabled.
            if not left then include(button) end
            if left then return left, top, unit end
        end
    end
end

-- Coordinates locate that top-left corner relative to screen center, in
-- UIParent units. Existing saved layout origins remain compatible.
function GladiusEx:GetGroupPosition(group)
    local left, top, unit = self:GetGroupPositionReference(group)
    if not left then return end
    local screen_x, screen_y = UIParent:GetCenter()
    local scale = UIParent:GetEffectiveScale()
    return left / scale - screen_x, top / scale - screen_y, unit
end

function GladiusEx:CaptureGroupPosition(group)
    local anchor = self:GetAnchorFrames(group)
    local db = self.db[group]
    anchor.position_before_layout = nil
    if anchor.position_db == db and anchor.position_grouped and db.groupButtons then
        local x, y, unit = self:GetGroupPosition(group)
        if x then anchor.position_before_layout = {x = x, y = y, unit = unit} end
    end
    anchor.position_db, anchor.position_grouped = db, db.groupButtons
end

function GladiusEx:RestoreGroupPosition(group)
    local anchor = self:GetAnchorFrames(group)
    local position = anchor.position_before_layout
    anchor.position_before_layout = nil
    if not position or InCombatLockdown() or not self.db[group].groupButtons then return end
    local _, _, unit = self:GetGroupPosition(group)
    -- A hidden/removed first unit hands the reference to the next visible one
    -- without moving the remaining rows to close the gap.
    if unit == position.unit then self:MoveGroupPosition(group, position.x, position.y) end
end

function GladiusEx:UpdatePositionValues(group)
    local panel = self.positioning_panel
    if not group or not panel or panel.group ~= group then return end
    local x, y = self:GetGroupPosition(group)
    if not x then return end
    if not panel.x:HasFocus() then panel.x:SetText(coordinate_text(x)) end
    if not panel.y:HasFocus() then panel.y:SetText(coordinate_text(y)) end
    panel.title:SetText(string.format(L["GladiusEx - %s"], group == "party" and L["Party"] or L["Arena"]))
    local r, g, b = 0.2, 0.75, 1
    if group == "arena" then r, g, b = 1, 0.6, 0.2 end
    panel:SetBackdropBorderColor(r, g, b, 0.9)
    local font = LSM:Fetch(LSM.MediaType.FONT, self.db.base.globalFont)
    local outline = self.db.base.globalFontOutline
    if font ~= panel.font or outline ~= panel.outline then
        for _, entry in ipairs(panel.labels) do entry[1]:SetFont(font, entry[2], outline) end
        panel.x:SetFont(font, 12, "")
        panel.y:SetFont(font, 12, "")
        panel.font, panel.outline = font, outline
    end
end

function GladiusEx:MoveGroupPosition(group, x, y)
    local current_x, current_y = self:GetGroupPosition(group)
    if not current_x then return false end
    if abs(x - current_x) < 0.0000001 and abs(y - current_y) < 0.0000001 then return true end
    local anchor = self:GetAnchorFrames(group)
    local scale = UIParent:GetEffectiveScale() / anchor:GetEffectiveScale()
    local left, top = anchor:GetLeft(), anchor:GetTop()
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + (x - current_x) * scale, top + (y - current_y) * scale)
    self:SaveAnchorPosition(group)
    return true
end

function GladiusEx:SetGroupPosition(group, x, y)
    if InCombatLockdown() or self.db.base.locked or not self.db[group].groupButtons then return false end
    if not valid_coordinate(x) or not valid_coordinate(y) then return false end
    self:StopAnchorMoving(group)
    if not self:MoveGroupPosition(group, x, y) then return false end
    self:UpdatePositioningOverlay(group)
    return true
end

function GladiusEx:StartAnchorMoving(group)
    if InCombatLockdown() or self.db.base.locked or not self.db[group].groupButtons then return false end
    local anchor = self:GetAnchorFrames(group)
    local editor = anchor and anchor.editor
    if not editor or not editor:IsShown() then return false end
    if not self:SelectPositioningGroup(group) then return false end
    self.positioning_panel.x:ClearFocus()
    self.positioning_panel.y:ClearFocus()
    anchor:StartMoving()
    anchor.dragging = true
    self:UpdatePositionValues(group)
    return true
end

function GladiusEx:StopAnchorMoving(group)
    local anchor = self:GetAnchorFrames(group)
    if not anchor or not anchor.dragging then return end
    anchor.dragging = nil
    anchor:StopMovingOrSizing()
    self:SaveAnchorPosition(group)
    self:UpdatePositionValues(group)
end

function GladiusEx:SetPositioningMode(enabled)
    if InCombatLockdown() then return false end
    self:ClearPositioningSelection()
    for _, group in ipairs({"arena", "party"}) do self:StopAnchorMoving(group) end
    self.db.base.locked = not enabled
    if enabled and not self:IsArenaShown() and not self:IsPartyShown() then
        local existing_test = self:IsTesting()
        self:SetTesting(existing_test or 3)
        self.positioning_preview = not existing_test
    elseif not enabled and self.positioning_preview then
        self:SetTesting(false)
    else
        self:UpdateFrames()
    end
    return true
end

function GladiusEx:ClearPositioningSelection()
    local panel = self.positioning_panel
    if not panel then return end
    if panel.group then self:StopAnchorMoving(panel.group) end
    panel.group = nil
    panel:Hide()
end

function GladiusEx:SelectPositioningGroup(group)
    if InCombatLockdown() or self.db.base.locked or not self.db[group].groupButtons then return false end
    local anchor = self:GetAnchorFrames(group)
    if not anchor or not anchor.editor or not anchor.editor:IsShown() or not anchor.editor.has_bounds then return false end
    local panel = self.positioning_panel or self:CreatePositioningPanel()
    if panel.group ~= group then
        if panel.group then self:StopAnchorMoving(panel.group) end
        panel.x:ClearFocus()
        panel.y:ClearFocus()
    end
    panel.group = group
    self:UpdatePositionValues(group)
    self:UpdatePositioningOverlay(group)
    panel:Show()
    return true
end

function GladiusEx:CreatePositioningPanel()
    -- This window is independent of both group origins and their drag surfaces.
    local panel = CreateFrame("Frame", "GladiusExPositioningPanel", UIParent)
    panel:SetSize(400, 76)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(200)
    panel:SetToplevel(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:SetBackdrop({bgFile = [[Interface\Buttons\WHITE8X8]], edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = self:AdjustPixels(panel, 1)})
    panel:SetBackdropColor(0.025, 0.035, 0.05, 0.97)
    panel.labels = {}

    local header = CreateFrame("Frame", nil, panel)
    header:SetSize(400, 25)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    header:SetFrameStrata("DIALOG")
    header:SetFrameLevel(panel:GetFrameLevel() + 1)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if InCombatLockdown() or self.db.base.locked then return end
        panel.x:ClearFocus()
        panel.y:ClearFocus()
        panel:StartMoving()
        panel.dragging = true
    end)
    header:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        panel.dragging = nil
    end)
    panel.header = header

    local function label(text, size, parent)
        parent = parent or panel
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFont(LSM:Fetch(LSM.MediaType.FONT, self.db.base.globalFont), size, self.db.base.globalFontOutline)
        fs:SetTextColor(1, 1, 1, 1)
        fs:SetText(text)
        panel.labels[#panel.labels + 1] = {fs, size}
        return fs
    end
    panel.title = label("", 12)
    panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
    local hint = label(L["Health + class icon top-left. Enter to apply."], 10)
    hint:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 7)

    local function field(axis, offset)
        local text = label(axis:upper(), 11)
        text:SetPoint("TOPLEFT", panel, "TOPLEFT", offset, -33)
        local box = CreateFrame("EditBox", nil, panel)
        box:SetSize(104, 20)
        box:SetPoint("TOPLEFT", panel, "TOPLEFT", offset + 18, -29)
        box:SetFrameStrata("DIALOG")
        box:SetFrameLevel(panel:GetFrameLevel() + 2)
        box:EnableMouse(true)
        box:SetAutoFocus(false)
        box:SetNumeric(false) -- Numeric-only edit boxes reject minus signs and decimals.
        box:SetMaxLetters(16)
        box:SetFont(LSM:Fetch(LSM.MediaType.FONT, self.db.base.globalFont), 12, "")
        box:SetTextInsets(5, 5, 0, 0)
        box:SetBackdrop({bgFile = [[Interface\Buttons\WHITE8X8]], edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1})
        box:SetBackdropColor(0.02, 0.025, 0.04, 1)
        box:SetBackdropBorderColor(0.35, 0.45, 0.55, 1)

        local function apply(step)
            local group = panel.group
            if not group then return false end
            local value = tonumber(box:GetText())
            local x, y = self:GetGroupPosition(group)
            -- Step the exact position unless the user is editing a new value.
            if step and not box:HasFocus() then value = axis == "x" and x or y end
            if valid_coordinate(value) and step then value = value + step end
            if not valid_coordinate(value) or not x then
                box:SetTextColor(1, 0.3, 0.3, 1)
                return false
            end
            if axis == "x" then x = value else y = value end
            if not self:SetGroupPosition(group, x, y) then return false end
            box:ClearFocus()
            self:UpdatePositionValues(group)
            return true
        end
        box:SetScript("OnEnterPressed", function() apply() end)
        box:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" then box:SetFocus() end
        end)
        box:SetScript("OnEscapePressed", function() box:ClearFocus(); self:UpdatePositionValues(panel.group) end)
        box:SetScript("OnTabPressed", function()
            if apply() then panel[axis == "x" and "y" or "x"]:SetFocus() end
        end)
        box:SetScript("OnEditFocusGained", function() box:HighlightText() end)
        box:SetScript("OnEditFocusLost", function()
            box:SetTextColor(1, 1, 1, 1)
            self:UpdatePositionValues(panel.group)
        end)

        local function step_button(step, offset, texture)
            local button = CreateFrame("Button", nil, panel)
            button:SetSize(22, 22)
            button:SetPoint("LEFT", box, "RIGHT", offset, 0)
            button:SetFrameStrata("DIALOG")
            button:SetFrameLevel(panel:GetFrameLevel() + 2)
            button:EnableMouse(true)
            button:SetNormalTexture(texture .. "-Up")
            button:SetPushedTexture(texture .. "-Down")
            button:SetHighlightTexture(texture .. "-Highlight")
            button:SetScript("OnClick", function() apply(step) end)
            return button
        end
        local texture = axis == "x" and [[Interface\Buttons\UI-SpellbookIcon-]] or [[Interface\Buttons\UI-ScrollBar-Scroll]]
        box.decrease = step_button(-1, 4, texture .. (axis == "x" and "PrevPage" or "DownButton"))
        box.increase = step_button(1, 30, texture .. (axis == "x" and "NextPage" or "UpButton"))
        return box
    end
    panel.x, panel.y = field("x", 12), field("y", 210)

    local done = CreateFrame("Button", nil, panel)
    done:EnableMouse(true)
    done:SetSize(50, 20)
    done:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -34, -5)
    done:SetFrameStrata("DIALOG")
    done:SetFrameLevel(panel:GetFrameLevel() + 2)
    done:SetBackdrop({bgFile = [[Interface\Buttons\WHITE8X8]], edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1})
    done:SetBackdropColor(0.12, 0.2, 0.27, 1)
    done:SetBackdropBorderColor(0.35, 0.55, 0.7, 1)
    local done_text = label(L["Done"], 11, done)
    done_text:SetPoint("CENTER", done, "CENTER", 0, 0)
    done:SetScript("OnClick", function() self:SetPositioningMode(false) end)
    panel.done = done

    local close = CreateFrame("Button", nil, panel)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -5)
    close:SetFrameStrata("DIALOG")
    close:SetFrameLevel(panel:GetFrameLevel() + 2)
    close:EnableMouse(true)
    local close_text = label("x", 12, close)
    close_text:SetPoint("CENTER", close, "CENTER", 0, 0)
    close:SetScript("OnClick", function() self:ClearPositioningSelection() end)
    panel.close = close
    panel:SetScript("OnHide", function()
        panel.group = nil
        if panel.dragging then panel:StopMovingOrSizing(); panel.dragging = nil end
        panel.x:ClearFocus()
        panel.y:ClearFocus()
    end)
    panel:Hide()
    self.positioning_panel = panel
    return panel
end

function GladiusEx:CreatePositioningOverlay(group, anchor)
    local editor = CreateFrame("Frame", "GladiusExPositioning" .. group, anchor)
    editor:SetFrameStrata("HIGH")
    editor:SetFrameLevel(200)
    editor:EnableMouse(true)
    editor:RegisterForDrag("LeftButton")
    editor:SetScript("OnDragStart", function() self:StartAnchorMoving(group) end)
    editor:SetScript("OnDragStop", function()
        self:StopAnchorMoving(group)
        self:UpdatePositioningOverlay(group)
    end)
    editor:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" then self:ShowOptionsDialog(); return end
        if button ~= "LeftButton" or not self:SelectPositioningGroup(group) then return end
        local x, y = self:GetGroupPosition(group)
        if IsShiftKeyDown() then
            self:SetGroupPosition(group, 0, y)
        elseif IsAltKeyDown() then
            self:SetGroupPosition(group, x, 0)
        elseif IsControlKeyDown() then
            local other_group = group == "party" and "arena" or "party"
            local other = self:GetAnchorFrames(other_group)
            if not other or not other.editor or not other.editor:IsShown() then return end
            local other_x, other_y = self:GetGroupPosition(other_group)
            if not other_x then return end
            local grow = self.db[group].growDirection
            if grow == "UP" or grow == "DOWN" or grow == "VCENTER" then
                self:SetGroupPosition(group, x, other_y)
            else
                self:SetGroupPosition(group, other_x, y)
            end
        end
    end)

    editor:SetScript("OnHide", function()
        self:StopAnchorMoving(group)
        if self.positioning_panel and self.positioning_panel.group == group then self:ClearPositioningSelection() end
    end)
    anchor:SetScript("OnUpdate", function(_, elapsed)
        local frame = editor
        if InCombatLockdown() or self.db.base.locked then
            self:StopAnchorMoving(group)
            frame:Hide()
        elseif anchor.dragging then
            self:UpdatePositionValues(group)
        else
            frame.elapsed = (frame.elapsed or 0) + elapsed
            if frame.elapsed >= 0.15 then
                frame.elapsed = 0
                self:UpdatePositioningOverlay(group)
            end
        end
    end)
    return editor
end

function GladiusEx:UpdatePositioningOverlay(group)
    local anchor = self:GetAnchorFrames(group)
    local editor = anchor.editor
    if self.db.base.locked or not self.db[group].groupButtons or InCombatLockdown() then
        editor:Hide()
        return
    end
    local left, bottom, right, top = self:GetPositioningBounds(group)
    editor.has_bounds = left ~= nil
    if not left then editor:Hide(); return end

    local scale = anchor:GetEffectiveScale()
    local padding = 4 * self:GetPerfectScale()
    editor:ClearAllPoints()
    editor:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", (left - padding) / scale - anchor:GetLeft(), (bottom - padding) / scale - anchor:GetTop())
    editor:SetSize((right - left + padding * 2) / scale, (top - bottom + padding * 2) / scale)
    local selected = self.positioning_panel and self.positioning_panel.group == group
    local r, g, b = 0.2, 0.75, 1
    if group == "arena" then r, g, b = 1, 0.6, 0.2 end
    editor:SetBackdrop({bgFile = [[Interface\Buttons\WHITE8X8]], edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = self:AdjustPixels(editor, 1)})
    editor:SetBackdropColor(r, g, b, selected and 0.18 or 0.08)
    editor:SetBackdropBorderColor(r, g, b, 0.9)

    anchor:SetClampRectInsets(editor:GetLeft() - anchor:GetLeft(), editor:GetRight() - anchor:GetRight(),
        editor:GetTop() - anchor:GetTop(), editor:GetBottom() - anchor:GetBottom())
    self:UpdatePositionValues(group)
    editor:Show()
end
