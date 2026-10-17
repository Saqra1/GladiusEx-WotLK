--[[
    Callbacks:
        SPEC_DETECTED(unitID, guid, specID, isEnemy)
        SPEC_LOST(guid)
        SPEC_RESET()

    Functions:
        specID = lib:GetSpecID(guid)
        isEnemy = lib:IsEnemy(guid)

    Example:

    -- Fetching the library, registering a callback, and handling a detected spec
    local LSD = LibStub("LibSpecDetection-1.0")
    if not LSD then
        print("LibSpecDetection library not found!")
        return
    end

    -- Define the callback function for the SPEC_DETECTED event
    local function OnSpecDetected(event, unitID, guid, specID, isEnemy)
        print("Spec detected: Event =", event, "Unit ID =", unitID or "N/A", "GUID =", guid, "Spec ID =", specID, "Is Enemy =", isEnemy)
        
        -- Get the spec ID for the GUID
        local currentSpecID = LSD:GetSpecID(guid)
        if currentSpecID then
            ("Current spec ID:", currentSpecID)
        end

        -- Check if the detected spec belongs to an enemy
        local enemyStatus = LSD:IsEnemy(guid)
        print("Is Enemy:", enemyStatus)
    end

    -- Register the SPEC_DETECTED callback
    LSD.callbacks:RegisterCallback("SPEC_DETECTED", OnSpecDetected)

    -- Description:

    LibSpecDetection is a library that tracks and identifies the specializations of units. 
    
    The library supports the following callback events:
    - "SPEC_DETECTED": Fired when a spec is detected for a unit. Note that unitID can be nil if no known unitID is associated with the GUID.
    - "SPEC_LOST": Fired when a detected spec expires or is reset.
    - "SPEC_RESET": Fired when all detected specs are cleared (e.g., upon entering the world or a loading screen).
    
    The library provides functions to retrieve spec information and interact with the tracked specs of units.

    -- Notes:
    - The library automatically manages timers to forget detected specs after 60 minutes.
    - It integrates with LibGroupTalents/LibGroupInSpecT to update specs based on talent inspections, primarily for friendly units.
	- It supports MoP, Cata, WotLK and TBC (TBC only via the RCE exploit on the WotLK 3.3.5 client)
]]

-- Define the library and dependencies
local MAJOR, MINOR = "LibSpecDetection-1.0", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end -- already loaded

local CallbackHandler = LibStub("CallbackHandler-1.0")
local LGT = LibStub("LibGroupTalents-1.0", true)
local LGI = LibStub("LibGroupInSpecT-1.0", true)

LibStub("AceTimer-3.0"):Embed(lib)

-- Load data tables from the Data folder into the addon namespace
local _, data = ...

-- Access SPEC_MAPPING, MANA_THRESHOLD, and AURA_MAPPING from the data tables
local SPEC_MAPPING = data.SpecMapping
local MANA_THRESHOLD = data.ManaThreshold
local AURA_MAPPING = data.AuraMapping

-- Define the duration to forget the GUID
local SPEC_FORGET_TIME = 3600 -- 60 minutes in seconds

-- Set up CallbackHandler directly
lib.callbacks = CallbackHandler:New(lib)

-- Local tables for detected specs and timers
local detectedSpecs = {}
local timers = {}
local arenaSpecs = {} -- Store specs for arena units

-- Frame setup for event handling
local frame = CreateFrame("Frame")

-- Exposed functions
function lib:GetSpecID(guid)
    if not guid or not detectedSpecs[guid] then return end
    return detectedSpecs[guid].specID
end

function lib:IsEnemy(guid)
    if not guid or not detectedSpecs[guid] then return end
    return detectedSpecs[guid].isEnemy
end

-- Local helper functions
local function SetDetectedSpec(guid, specID, isEnemy, unitID)
	
	-- Allow setting spec by unitID alone when guid is not available (for arena prep in MoP and beyond only)
    if not guid and not unitID then return end
    
    lib.callbacks:Fire("SPEC_DETECTED", unitID, guid, specID, isEnemy)

    if not guid then return end

    detectedSpecs[guid] = { specID = specID, isEnemy = isEnemy }
    if timers[guid] then
        lib:CancelTimer(timers[guid])
        timers[guid] = nil
    end

    timers[guid] = lib:ScheduleTimer(function()
        detectedSpecs[guid] = nil
        timers[guid] = nil
        lib.callbacks:Fire("SPEC_LOST", guid)
    end, SPEC_FORGET_TIME)
end

local function GetSpecByAura(spellID)
    return AURA_MAPPING[spellID]
end

local function CheckAuras(unitID)

    local guid = UnitGUID(unitID)
    if not guid or detectedSpecs[guid] then return end

	local i = 1
    while true do
        local srcUnit, spellID
        if data.isCata or data.isMoP then
            _, _, _, _, _, _, _, srcUnit, _, spellID = UnitAura(unitID, i, "HELPFUL")
        else -- WotLK/TBC
            _, _, _, _, _, _, _, srcUnit, _, _, spellID = UnitAura(unitID, i, "HELPFUL")
        end
        if not spellID then break end

        local auraData = GetSpecByAura(spellID)
        local specID, checkSource
        
        if auraData and type(auraData) == "table" then
            specID = auraData.specID
            checkSource = auraData.checkSource
        elseif auraData then
            specID = auraData
            checkSource = false
        end
		
        if specID and (not checkSource or srcUnit) then
			local targetUnit = checkSource and srcUnit or unitID
            if checkSource then
                guid = UnitGUID(targetUnit)
            end
            local isEnemy = not UnitIsFriend("player", targetUnit)
			
			if guid and not detectedSpecs[guid] then
				SetDetectedSpec(guid, specID, isEnemy, targetUnit)
			end
            return
        end
        i = i + 1
    end
end

local function GetPrimaryTalentTabIndex()
    local maxPoints, primaryTabIndex = 0, nil
    for i = 1, 3 do
		local pointsSpent
		if data.isCata then
			_, _, _, _, pointsSpent = GetTalentTabInfo(i)
        else
			_, _, pointsSpent = GetTalentTabInfo(i)
		end
		if pointsSpent and maxPoints and pointsSpent > maxPoints then
            maxPoints = pointsSpent
            primaryTabIndex = i
        end
    end
    return primaryTabIndex
end

local function CheckPlayerSpec()
    local specIndex = GetSpecialization and GetSpecialization() or GetPrimaryTalentTabIndex()
    if specIndex then
        local _, playerClass = UnitClass("player")
        local playerGUID = UnitGUID("player")

        if not playerGUID then return end

        local specID = SPEC_MAPPING[playerClass] and SPEC_MAPPING[playerClass][specIndex]

        if specID and (not detectedSpecs[playerGUID] or detectedSpecs[playerGUID].specID ~= specID) then
			SetDetectedSpec(playerGUID, specID, false, "player")
        end
    end
end

local function CheckMana(unitID)
    local guid = UnitGUID(unitID)
    if not guid or detectedSpecs[guid] then return false end

    local _, class = UnitClass(unitID)
    local manaMax = UnitPowerMax(unitID, 0)
    local manaConfig = MANA_THRESHOLD[class]

    if manaConfig and manaMax then
        if (manaConfig.greater and manaMax > manaConfig.threshold) or 
			(not manaConfig.greater and manaMax < manaConfig.threshold) then

			local isEnemy = not UnitIsFriend("player", unitID)
            SetDetectedSpec(guid, manaConfig.specID, isEnemy, unitID)
            return true
        end
    end
    return false
end

-- Event handler for talent updates
local function OnPlayerTalentUpdate()
    CheckPlayerSpec()
end


-- Attempt spec detection
local function AttemptSpecDetection(unitID)
    if CheckMana(unitID) then return end
    CheckAuras(unitID)
end

-- Event handler for UNIT_AURA events, checking for auras
local function OnUnitAura(unit)
    if not unit then return end
    AttemptSpecDetection(unit)
end

-- Arena opponent updates
local function OnArenaOpponentUpdate(unitID, status)
    if not unitID:find("pet") and status == "seen" and not detectedSpecs[UnitGUID(unitID)] then
        if arenaSpecs[unitID] then -- MoP and onwards only
            SetDetectedSpec(UnitGUID(unitID), arenaSpecs[unitID], true, unitID)
        else
            AttemptSpecDetection(unitID)
        end
    end
end

local function OnNameplateAdded(unitID)
	if not C_NamePlate then return end
	
	if UnitIsPlayer(unitID) and not detectedSpecs[UnitGUID(unitID)] then
		AttemptSpecDetection(unitID)
	end
end

local function CheckAllNameplates()
	if not C_NamePlate then return end
	
	for _, plate in pairs(C_NamePlate.GetNamePlates()) do
		local unitID = plate.namePlateUnitToken
		
		OnNameplateAdded(unitID)
	end
end

-- Arena spec prep update
local function OnArenaPrepOpponentSpecializations()
    for i = 1, 5 do
        local unit = "arena" .. i
        if not arenaSpecs[unit] then
            local specID = GetArenaOpponentSpec and GetArenaOpponentSpec(i) or nil
            if specID then
                arenaSpecs[unit] = specID
                SetDetectedSpec(UnitGUID(unit), specID, true, unit)
            end
        end
    end
end

-- Player target and focus changes
local function OnPlayerTargetChanged()
    if UnitExists("target") and not detectedSpecs[UnitGUID("target")] then
        AttemptSpecDetection("target")
    end
end

local function OnPlayerFocusChanged()
    if UnitExists("focus") and not detectedSpecs[UnitGUID("focus")] then
        AttemptSpecDetection("focus")
    end
end

-- Combat log event for spec detection and respec tracking
local function OnCombatLogEventUnfiltered(...)
    local subEvent, srcGUID, srcFlags, spellID

    if data.isMoP or data.isCata then
        _, subEvent, _, srcGUID, srcFlags, _, _, _, _, _, _, spellID = ...
    else
        _, subEvent, srcGUID, srcFlags, _, _, _, _, spellID = ...
    end

    if subEvent == "SPELL_CAST_SUCCESS" then
		if not detectedSpecs[srcGUID] and AURA_MAPPING[spellID] then
            local specID = AURA_MAPPING[spellID]
			
			if type(specID) == "table" then
				specID = specID.specID
			end

            local isEnemy = not CombatLog_Object_IsA(srcFlags, COMBATLOG_FILTER_FRIENDLY_UNITS)
            SetDetectedSpec(srcGUID, specID, isEnemy, nil)
        end
    end
end

local function OnPlayerEnteringWorld()
	
	for guid, timerID in pairs(timers) do
        lib:CancelTimer(timerID)
        timers[guid] = nil
    end

    detectedSpecs = {}
    arenaSpecs = {}
    lib.callbacks:Fire("SPEC_RESET")

    -- Initialize player and arena specs
    lib:ScheduleTimer(CheckPlayerSpec, 1) -- K: This needs to be delayed because spec data doesn't load immediately after leaving arena/bgs or similar
    OnArenaPrepOpponentSpecializations()
	CheckAllNameplates()
end

-- Event handler for LibGroupTalents updates
local function OnLibGroupTalentsUpdate(event, guid, unit, newSpec, n1, n2, n3)
    if unit and UnitIsFriend("player", unit) then
        local _, class = UnitClass(unit)
        local specID = SPEC_MAPPING[class] and SPEC_MAPPING[class][newSpec]
        if specID and (not detectedSpecs[guid] or detectedSpecs[guid].specID ~= specID) then
            SetDetectedSpec(guid, specID, false, unit)
        end
    end
end

-- Event handler for GroupInSpecT updates
local function OnLibGroupInSpecTUpdate(event, guid, unit, info)
    if unit and UnitIsFriend("player", unit) then
        local _, class = UnitClass(unit)
        local specID = info.global_spec_id
        if specID and (not detectedSpecs[guid] or detectedSpecs[guid].specID ~= specID) then
            SetDetectedSpec(guid, specID, false, unit)
        end
    end
end

-- Register the events and set event handlers
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("ARENA_OPPONENT_UPDATE")
if GetArenaOpponentSpec then
    frame:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
end
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

if C_NamePlate then
	frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        OnPlayerEnteringWorld(...)
    elseif event == "PLAYER_TALENT_UPDATE" then
        OnPlayerTalentUpdate(...)
    elseif event == "UNIT_AURA" then
        OnUnitAura(...)
    elseif event == "ARENA_OPPONENT_UPDATE" then
        OnArenaOpponentUpdate(...)
    elseif event == "ARENA_PREP_OPPONENT_SPECIALIZATIONS" then
        OnArenaPrepOpponentSpecializations(...)
    elseif event == "PLAYER_TARGET_CHANGED" then
        OnPlayerTargetChanged(...)
    elseif event == "PLAYER_FOCUS_CHANGED" then
        OnPlayerFocusChanged(...)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEventUnfiltered(...)
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		OnNameplateAdded(...)
    end
end)

-- Register callback for Inspect updates
if LGT then
    LGT.RegisterCallback(lib, "LibGroupTalents_Update", OnLibGroupTalentsUpdate)
elseif LGI then
    LGI.RegisterCallback(lib, "GroupInSpecT_Update", OnLibGroupInSpecTUpdate)
end

return lib
