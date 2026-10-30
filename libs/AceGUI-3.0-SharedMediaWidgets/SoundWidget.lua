-- Widget is based on the AceGUIWidget-DropDown.lua supplied with AceGUI-3.0
-- Widget created by Yssaril

local AceGUI = LibStub("AceGUI-3.0")
local Media = LibStub("LibSharedMedia-3.0")

local AGSMW = LibStub("AceGUISharedMediaWidgets-1.0")

do
	local widgetType = "LSM30_Sound"
	local widgetVersion = 18

	local function CloseDropDown(self)
		if self.dropdown then
			self.dropdown:Hide()
			self.dropdown = nil
		end
	end

	local function PlayWidgetSound(self, sound)
		if self.disabled or not sound then return end
		local path = self.list and self.list[sound]
		if not path or path == sound then path = Media:Fetch("sound", sound, true) end
		if type(path) == "string" and path ~= "" then PlaySoundFile(path, "Master") end
	end

	local function ContentOnClick(this, button)
		local self = this.obj
		CloseDropDown(self)
		self:Fire("OnValueChanged", this.soundKey)
	end

	local function ContentSpeakerOnClick(this)
		PlayWidgetSound(this.row.obj, this.row.soundKey)
	end

	local function LayoutSoundRows(dropdown)
		local offset = math.floor(dropdown.slider:GetValue() + 0.5)
		local width = dropdown:GetWidth() - (#dropdown.keys > dropdown.visibleCount and 42 or 28)
		for index, row in ipairs(dropdown.rows) do
			local name = index <= dropdown.visibleCount and dropdown.keys[offset + index]
			if name then
				row.obj, row.soundKey = dropdown.obj, name
				row:SetWidth(width)
				if name == row.obj.value then row.check:Show() else row.check:Hide() end
				local text, available, cut = row.text, math.max(0, width - 38), #name
				text:SetText(name)
				while text:GetStringWidth() > available and cut > 0 do
					local first = cut
					while first > 1 and string.byte(name, first) >= 128 and string.byte(name, first) < 192 do
						first = first - 1
					end
					cut = first - 1
					text:SetText(string.sub(name, 1, cut) .. "...")
				end
				if text:GetStringWidth() > available then text:SetText("") end
				row:Show()
			else
				row:Hide()
			end
		end
	end

	local function CreateContentLine(dropdown, index)
		local frame = CreateFrame("Button", nil, dropdown)
		frame:SetHeight(18)
		frame:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 14, -13 - (index - 1) * 18)
		frame:SetHighlightTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]], "ADD")
		frame:SetScript("OnClick", ContentOnClick)
		local check = frame:CreateTexture(nil, "OVERLAY")
		check:SetWidth(16)
		check:SetHeight(16)
		check:SetPoint("LEFT", frame, "LEFT", 1, -1)
		check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
		check:Hide()
		frame.check = check

		local soundbutton = CreateFrame("Button", nil, frame)
		soundbutton:SetWidth(16)
		soundbutton:SetHeight(16)
		soundbutton:SetPoint("RIGHT", frame, "RIGHT", -1, 0)
		soundbutton:SetScript("OnClick", ContentSpeakerOnClick)
		soundbutton.row = frame
		frame.soundbutton = soundbutton

		local speaker = soundbutton:CreateTexture(nil, "OVERLAY")
		speaker:SetTexture("Interface\\Common\\VoiceChat-Speaker")
		speaker:SetAllPoints(soundbutton)
		frame.speaker = speaker
		local speakeron = soundbutton:CreateTexture(nil, "HIGHLIGHT")
		speakeron:SetTexture("Interface\\Common\\VoiceChat-On")
		speakeron:SetAllPoints(soundbutton)
		frame.speakeron = speakeron

		local text = frame:CreateFontString(nil, "OVERLAY", "GameFontWhite")
		text:SetPoint("LEFT", frame, "LEFT", 18, 0)
		text:SetHeight(18)
		text:SetJustifyH("LEFT")
		frame.text = text
		return frame
	end

	local function CreateDropDown(self)
		-- Keep preview buttons outside scroll children and update the visible rows on scroll.
		local frame = CreateFrame("Frame", nil, UIParent)
		frame:SetFrameStrata("TOOLTIP")
		frame:SetClampedToScreen(true)
		frame:EnableMouse(true)
		frame:EnableMouseWheel(true)
		frame:SetBackdrop({
			bgFile = [[Interface\DialogFrame\UI-DialogBox-Background-Dark]],
			edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
			tile = true, tileSize = 32, edgeSize = 32,
			insets = {left = 11, right = 12, top = 12, bottom = 9},
		})
		frame.rows, frame.keys, frame.obj = {}, {}, self
		local slider = CreateFrame("Slider", nil, frame)
		slider:SetOrientation("VERTICAL")
		slider:SetWidth(12)
		slider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -13)
		slider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
		slider:SetBackdrop({
			bgFile = [[Interface\Buttons\UI-SliderBar-Background]],
			edgeFile = [[Interface\Buttons\UI-SliderBar-Border]],
			tile = true, tileSize = 8, edgeSize = 8,
			insets = {left = 3, right = 3, top = 3, bottom = 3},
		})
		slider:SetThumbTexture([[Interface\Buttons\UI-SliderBar-Button-Vertical]])
		slider:SetValueStep(1)
		slider:SetScript("OnValueChanged", function() LayoutSoundRows(frame) end)
		frame.slider = slider
		frame:SetScript("OnMouseWheel", function(_, direction)
			slider:SetValue(slider:GetValue() - direction * 3)
		end)
		return frame
	end

	local function OnAcquire(self)
		self:SetHeight(44)
		self:SetWidth(200)
	end

	local function OnRelease(self)
		CloseDropDown(self)
		self:SetText("")
		self:SetLabel("")
		self:SetDisabled(false)

		self.value = nil
		self.list = nil
		self.open = nil
		self.hasClose = nil

		self.frame:ClearAllPoints()
		self.frame:Hide()
	end

	local function SetValue(self, value) -- Set the value to an item in the List.
		if self.list then
			self:SetText(value or "")
		end
		self.value = value
	end

	local function GetValue(self)
		return self.value
	end

	local function SetList(self, list) -- Set the list of values for the dropdown (key => value pairs)
		self.list = list or Media:HashTable("sound")
	end

	local function SetText(self, text) -- Set the text displayed in the box.
		self.frame.text:SetText(text or "")
	end

	local function SetLabel(self, text) -- Set the text for the label.
		self.frame.label:SetText(text or "")
	end

	local function AddItem(self, key, value) -- Add an item to the list.
		self.list = self.list or {}
		self.list[key] = value
	end
	local SetItemValue = AddItem -- Set the value of a item in the list. <<same as adding a new item>>

	local function SetMultiselect(self, flag) end -- Toggle multi-selecting. <<Dummy function to stay inline with the dropdown API>>
	local function GetMultiselect() return false end-- Query the multi-select flag. <<Dummy function to stay inline with the dropdown API>>
	local function SetItemDisabled(self, key) end-- Disable one item in the list. <<Dummy function to stay inline with the dropdown API>>

	local function SetDisabled(self, disabled) -- Disable the widget.
		self.disabled = disabled
		if disabled then
			CloseDropDown(self)
			self.frame:Disable()
			self.soundbutton:Disable()
			self.speaker:SetDesaturated(true)
			self.speakeron:SetDesaturated(true)
		else
			self.frame:Enable()
			self.soundbutton:Enable()
			self.speaker:SetDesaturated(false)
			self.speakeron:SetDesaturated(false)
		end
	end

	local function textSort(a,b)
		return string.upper(a) < string.upper(b)
	end

	local function ToggleDrop(this)
		local self = this.obj
		if self.disabled then return end
		if self.dropdown then
			CloseDropDown(self)
			AceGUI:ClearFocus()
		else
			AceGUI:SetFocus(self)
			self.dropdownFrame = self.dropdownFrame or CreateDropDown(self)
			local dropdown = self.dropdownFrame
			self.dropdown = dropdown
			dropdown:ClearAllPoints()
			dropdown:SetPoint("TOPLEFT", self.frame, "BOTTOMLEFT")
			dropdown:SetWidth(math.max(200, self.frame:GetWidth()))
			wipe(dropdown.keys)
			for key in pairs(self.list or {}) do dropdown.keys[#dropdown.keys + 1] = key end
			table.sort(dropdown.keys, textSort)
			dropdown.visibleCount = math.min(#dropdown.keys, math.max(1, math.floor((UIParent:GetHeight() * 2/5 - 25) / 18)))
			dropdown:SetHeight(dropdown.visibleCount * 18 + 25)
			for index = #dropdown.rows + 1, dropdown.visibleCount do
				dropdown.rows[index] = CreateContentLine(dropdown, index)
			end
			dropdown.slider:SetMinMaxValues(0, #dropdown.keys - dropdown.visibleCount)
			dropdown.slider:SetValue(0)
			if #dropdown.keys > dropdown.visibleCount then dropdown.slider:Show() else dropdown.slider:Hide() end
			LayoutSoundRows(dropdown)
			dropdown:Show()
		end
	end

	local function ClearFocus(self)
		CloseDropDown(self)
	end

	local function OnHide(this)
		CloseDropDown(this.obj)
	end

	local function Drop_OnEnter(this)
		this.obj:Fire("OnEnter")
	end

	local function Drop_OnLeave(this)
		this.obj:Fire("OnLeave")
	end

	local function WidgetPlaySound(this)
		PlayWidgetSound(this.obj, this.obj.value)
	end

	local function Constructor()
		local frame = AGSMW:GetBaseFrame()
		local self = {}

		self.type = widgetType
		self.frame = frame
		frame.obj = self
		frame.dropButton.obj = self
		frame.dropButton:SetScript("OnEnter", Drop_OnEnter)
		frame.dropButton:SetScript("OnLeave", Drop_OnLeave)
		frame.dropButton:SetScript("OnClick",ToggleDrop)
		frame:SetScript("OnHide", OnHide)


		local soundbutton = CreateFrame("Button", nil, frame)
			soundbutton:SetFrameLevel(frame:GetFrameLevel() + 1)
			soundbutton:SetWidth(16)
			soundbutton:SetHeight(16)
			soundbutton:SetPoint("LEFT",frame.DLeft,"LEFT",26,1)
			soundbutton:SetScript("OnClick", WidgetPlaySound)
			soundbutton.obj = self
		self.soundbutton = soundbutton
		frame.text:SetPoint("LEFT",soundbutton,"RIGHT",2,0)


		local speaker = soundbutton:CreateTexture(nil, "BACKGROUND")
			speaker:SetTexture("Interface\\Common\\VoiceChat-Speaker")
			speaker:SetAllPoints(soundbutton)
		self.speaker = speaker
		local speakeron = soundbutton:CreateTexture(nil, "HIGHLIGHT")
			speakeron:SetTexture("Interface\\Common\\VoiceChat-On")
			speakeron:SetAllPoints(soundbutton)
		self.speakeron = speakeron

		self.alignoffset = 31

		self.OnRelease = OnRelease
		self.OnAcquire = OnAcquire
		self.ClearFocus = ClearFocus
		self.SetText = SetText
		self.SetValue = SetValue
		self.GetValue = GetValue
		self.SetList = SetList
		self.SetLabel = SetLabel
		self.SetDisabled = SetDisabled
		self.AddItem = AddItem
		self.SetMultiselect = SetMultiselect
		self.GetMultiselect = GetMultiselect
		self.SetItemValue = SetItemValue
		self.SetItemDisabled = SetItemDisabled
		self.ToggleDrop = ToggleDrop

		AceGUI:RegisterAsWidget(self)
		return self
	end

	AceGUI:RegisterWidgetType(widgetType, Constructor, widgetVersion)

end
