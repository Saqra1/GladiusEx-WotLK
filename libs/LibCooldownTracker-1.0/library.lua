--[[
    Callbacks:
        LCT_CooldownUsed(unitid, spellid, isEnemy)
        LCT_CooldownUsedByGUID(guid, spellid, isEnemy)
		LCT_CooldownsReset(unitid)
        LCT_CooldownsResetByGUID(guid)

    Functions:
        success = lib:Subscribe(self, event, prefix)
        success = lib:Unsubscribe(self, event, prefix)
        tpu = lib:GetUnitCooldownInfo(unitid, spellid, prefix)
        tpu = lib:GetCooldownInfoByGUID(guid, spellid, prefix)
        spellid, spell_data in lib:IterateCooldowns(class, specID, race, prefix)
        spell_data = lib:GetCooldownData(spellid, prefix)
        spells_data = lib:GetCooldownsData()

    Examples:

    -- Example 1: Registering a callback and retrieving cooldown data
    local function OnCooldownUsed(event, guid, spellid, isEnemy)
        print("Cooldown used: Event =", event, "GUID =", guid, "Spell ID =", spellid, "Is Enemy =", isEnemy)
        
        -- Get the cooldown data for the spell
        local spell_data = lib:GetCooldownData(spellid, "myAddOnPrefix")
        if spell_data then
            print("Spell cooldown:", spell_data.cooldown)
            print("Class:", spell_data.class)
        end

        -- Get the current cooldown state for the unit
        local currentData = lib:GetCooldownInfoByGUID(guid, spellid, "myAddOnPrefix")
        if currentData then
            print("Current cooldown start:", currentData.cooldown_start)
            print("Current cooldown end:", currentData.cooldown_end)
        end
    end

    -- Register the callback
    local success = lib:Subscribe(self, "LCT_CooldownUsedByGUID", OnCooldownUsed, "myAddOnPrefix")
    if success then
        print("Callback registered successfully for myAddOnPrefix")
    end

    -- Example 2: Iterating over all cooldowns for a specific class and prefix
    for spellid, spell_data in lib:IterateCooldowns("MAGE", nil, nil, "myAddOnPrefix") do
        print("Spell ID:", spellid)
        print("Spell cooldown:", spell_data.cooldown)
        print("Class:", spell_data.class)
        if spell_data.specID then
            print("Spec IDs:", table.concat(spell_data.specID, ", "))
        end
    end
	
	Prefix:
	
	You only have to use prefixes if you want to add custom spells. Prefixes are used to differentiate
	different addons against one another, such that events for custom defined / updated spellIDs can be
	sent only to the correct subscriber (callback).
]]

local version = 13
local lib = LibStub:NewLibrary("LibCooldownTracker-1.0", version)

if not lib then return end

-- upvalues
local pairs, type, next, select, assert, unpack = pairs, type, next, select, assert, unpack
local tinsert, tremove = table.insert, table.remove
local GetTime, UnitGUID, IsInInstance = GetTime, UnitGUID, IsInInstance

lib.frame = lib.frame or CreateFrame("Frame")
lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)

local LibSpecDetection = LibStub("LibSpecDetection-1.0")

-- init event handler
local events = {}
do
	lib.frame:SetScript("OnEvent",
		function(self, event, ...)
			return events[event](lib, event, ...)
		end)
end

local SpellData = LCT_SpellData
LCT_SpellData = nil

do
	for spellID, spellData in pairs(SpellData) do
		if type(spellData) == "table" and not spellData.parent then

			local name, _, icon = GetSpellInfo(spellID)

			if not name then
				DEFAULT_CHAT_FRAME:AddMessage("LibCooldownTracker-1.0: bad spellid: " .. spellID)
				SpellData[spellID] = nil
			else
				spellData.name = name
				if not spellData.icon then
					spellData.icon = icon
				end
			end
		end
	end
end

-- state
lib.tracked_players = lib.tracked_players or {} --[[
	[guid][spellid] = {
		["cooldown_start"] = time,
		["cooldown_end"] = time,
		["used_start"] = time,
		["used_end"] = time,
		["detected"] = boolean,
		[EVENT] = time
	}
]]

-- Table to track event registrations by prefix
local eventPrefixSubscriptions = {}

--- Registers a callback for a specific event.
-- When a prefix is provided, the callback will be registered for the event with that prefix.
-- If no prefix is provided, the callback is registered for the base event.
-- @param obj The object registering the callback.
-- @param event The event name to register for (e.g., "LCT_CooldownUsedByGUID").
-- @param method The method to call when the event is fired. It can be a function or a method name.
-- @param prefix (optional) The prefix to use for the event (e.g., "myAddOnPrefix"). If provided, the event will be registered as "event_prefix".
-- @return success True if the callback was successfully registered, false otherwise.
-- @usage
-- local success = lib:Subscribe(self, "LCT_CooldownUsedByGUID", "OnCooldownUsed")
-- if success then
--     print("Callback registered successfully")
-- end
-- local success = lib:Subscribe(self, "LCT_CooldownUsedByGUID", "OnCooldownUsed", "myAddOnPrefix")
-- if success then
--     print("Callback registered for myAddOnPrefix successfully")
-- end
function lib:Subscribe(obj, event, method, prefix)
    -- Determine the event name based on the prefix
    local eventName = prefix and (prefix .. "_" .. event) or event

    -- Check if the prefix is already registered for the event
    if prefix then
        eventPrefixSubscriptions[event] = eventPrefixSubscriptions[event] or {}
        if eventPrefixSubscriptions[event][prefix] then
            -- Prefix is already registered, return false
            return false
        end
    end

    -- Register the callback
    lib.RegisterCallback(obj, eventName, method)

    -- If registration was successful and a prefix is provided, track the prefix for the event
    if prefix then
        eventPrefixSubscriptions[event][prefix] = true
    end

    return true
end

--- Unregisters a callback for a specific event.
-- When a prefix is provided, the callback will be unregistered for the event with that prefix.
-- If no prefix is provided, the callback is unregistered for the base event.
-- @param obj The object unregistering the callback.
-- @param event The event name to unregister from (e.g., "LCT_CooldownUsedByGUID").
-- @param prefix (optional) The prefix used when the callback was registered (e.g., "myAddOnPrefix"). If provided, the event will be unregistered as "event_prefix".
-- @return success True if the callback was successfully unregistered, false otherwise.
-- @usage
-- local success = lib:Unsubscribes(self, "LCT_CooldownUsedByGUID")
-- if success then
--     print("Callback unregistered successfully")
-- end
-- local success = lib:Unsubscribes(self, "LCT_CooldownUsedByGUID", "myAddOnPrefix")
-- if success then
--     print("Callback for myAddOnPrefix unregistered successfully")
-- end
function lib:Unsubscribe(obj, event, prefix)
    -- Determine the event name based on the prefix
    local eventName = prefix and (prefix .. "_" .. event) or event

    -- Precheck if there is anything subscribed with that prefix
    if prefix and (not eventPrefixSubscriptions[event] or not eventPrefixSubscriptions[event][prefix]) then
        -- If the prefix is not registered, return false
        return false
    end

    lib.UnregisterCallback(obj, eventName)

    -- If unregistration was successful and a prefix is provided, remove the prefix tracking
    if prefix and eventPrefixSubscriptions[event] then
        eventPrefixSubscriptions[event][prefix] = nil
        -- Clean up the event entry if no prefixes remain
        if not next(eventPrefixSubscriptions[event]) then
            eventPrefixSubscriptions[event] = nil
        end
    end
    return true
end

-- Stub (deprecated)
function lib:IsUnitRegistered()
	return nil
end

-- Stub (deprecated)
function lib:RegisterUnit()
end

-- Stub (deprecated)
function lib:UnregisterUnit()
end

-- simple timer used for updating number of charges
-- timers are stored ordered by their firing time so only the first
-- timer on the list is checked in the OnUpdate
local timers = {}
local timer_frame

local function Timer_OnUpdate()
	local t1 = timers[1]
	if GetTime() >= t1.time then
		tremove(timers, 1)
		t1.func(unpack(t1.args))
		if #timers == 0 then
			lib.frame:SetScript("OnUpdate", nil)
		end
	end
end

local function SetTimer(time, func, ...)
	local pos = 1
	while pos <= #timers do
		if timers[pos].time >= time then
			break
		end
		pos = pos + 1
	end

	tinsert(timers, pos, { time = time, func = func, args = { ... } })

	if #timers == 1 then
		lib.frame:SetScript("OnUpdate", Timer_OnUpdate)
	end

	return pos
end

local function ClearTimers()
	lib.frame:SetScript("OnUpdate", nil)
	timers = {}
end

local function GetCooldownTime(spellid, guid, prefix)
    -- Get the spell data based on the prefix or fallback to the base configuration
    local spelldata = lib:GetCooldownData(spellid, prefix) or lib:GetCooldownData(spellid)
    if not spelldata then return nil end

    -- Get the base cooldown time
    local time = spelldata.cooldown

    if spelldata.cooldown_overload then
        local overloads = spelldata.cooldown_overload
		
		local specID = LibSpecDetection and LibSpecDetection:GetSpecID(guid)

		if specID and overloads[specID] then
            return overloads[specID]
        end

        -- Get the class from the GUID using GetPlayerInfoByGUID
        local _, class = GetPlayerInfoByGUID(guid)
        if class and overloads[class] then
            return overloads[class]
        end
    end

    return time
end


local function AddCharge(guid, spellid, prefix)
	prefix = prefix and prefix or "base"
	local tps = lib.tracked_players[guid][spellid][prefix]
	tps.charges = tps.charges + 1

	FireCooldownEvent("LCT_CooldownUsed", guid, spellid, prefix)
	
	-- schedule another timer if there are more charges in cooldown
	if tps.charges < tps.max_charges then
		local now = GetTime()
		local spelldata = SpellData[spellid]
		tps.cooldown_start = now
		tps.cooldown_end = now + GetCooldownTime(spellid, guid, prefix)
		tps.charge_timer = SetTimer(tps.cooldown_end, AddCharge, guid, spellid)
	else
		tps.charge_timer = false
	end
end
-- Helper function to fire cooldown events based on prefix availability
local function FireCooldownEvent(event, guid, spellid, isEnemy, prefix)

	local isPrefixed = prefix and prefix ~= "base"
    local eventName = isPrefixed and (prefix .. "_" .. event .. "ByGUID") or event .. "ByGUID"

    -- Fire the event for the specified prefix or base
    lib.callbacks:Fire(eventName, guid, spellid, isEnemy)
	
    -- Fire unitID events for the GUID
	local unitIDs = lib:FindUnitIDs(guid)
	if unitIDs then
		for _, unitID in pairs(unitIDs) do
			lib.callbacks:Fire(event, unitID, spellid, isEnemy)
		end
	end

    local spelldata = lib:GetCooldownData(spellid, prefix)
    -- If it's a base event, check for subscribed prefixes not in the spelldata.prefixes
    if not isPrefixed then
        if eventPrefixSubscriptions[eventName] then
            for registeredPrefix, _ in pairs(eventPrefixSubscriptions[eventName]) do
                -- Check if the registered prefix is NOT in the spell's prefixes list
                if not (spelldata and spelldata.prefixes and spelldata.prefixes[registeredPrefix]) then
                    -- Fire the prefixed event explicitly
                    local prefixedEventName = registeredPrefix .. "_" .. eventName 
                    
					lib.callbacks:Fire(prefixedEventName, guid, spellid, isEnemy)

                    -- Also fire unit-based events for the specific prefix
					local unitIDs = lib:FindUnitIDs(guid)
					if unitIDs then
						for _, unitID in pairs(unitIDs) do
							local unitEventName = registeredPrefix .. "_" .. event 
							lib.callbacks:Fire(unitEventName, unitID, spellid, isEnemy)
						end
					end
                end
            end
        end
    end
end

local function CooldownEvent(event, guid, spellid, isEnemy)

	-- Get the top parent cooldown data without considering prefixes
    local spelldata, tmpSpellID = lib:GetCooldownData(spellid)
    if not spelldata then return end

	if tmpSpellID then
		spellid = tmpSpellID
	end

    -- Initialize tracking for the player if it doesn't exist
    if not lib.tracked_players[guid] then
        lib.tracked_players[guid] = {}
    end
    local tpu = lib.tracked_players[guid]

    -- Get current time
    local now = GetTime()

    -- Check if the same spell cast was detected recently (margin check)
    local margin = 1
    if tpu[spellid] then
        local events = tpu[spellid].events or {}
        if event == "UNIT_SPELLCAST_SUCCEEDED" or event == "SPELL_CAST_SUCCESS" or event == "SPELL_AURA_APPLIED" then
            if (event ~= "UNIT_SPELLCAST_SUCCEEDED" and events["UNIT_SPELLCAST_SUCCEEDED"] and (events["UNIT_SPELLCAST_SUCCEEDED"] + margin) > now) or
               (event ~= "SPELL_AURA_APPLIED"       and events["SPELL_AURA_APPLIED"]       and (events["SPELL_AURA_APPLIED"]       + margin) > now) or
               (event ~= "SPELL_CAST_SUCCESS"       and events["SPELL_CAST_SUCCESS"]       and (events["SPELL_CAST_SUCCESS"]       + margin) > now) then
                return -- Exit early if the margin check fails
            end
        end
    end

    -- Initialize tracking for the spell if it doesn't exist
    if not tpu[spellid] then
        tpu[spellid] = {}
    end

    -- Register event time
    if not tpu[spellid].events then
        tpu[spellid].events = {}
    end
    tpu[spellid].events[event] = now

    -- Handle cooldown tracking for each prefix
    local prefixes = spelldata.prefixes or {}
    local prefixList = {}

    -- Add "base" to the list if it has a cooldown defined
    if spelldata.cooldown then
        table.insert(prefixList, "base")
    end

    -- Add existing prefixes to the list
    for prefix, _ in pairs(prefixes) do
        table.insert(prefixList, prefix)
    end

    for _, currentPrefix in ipairs(prefixList) do

        local currentSpellData = (currentPrefix == "base") and spelldata or prefixes[currentPrefix]
        local prefixEntry = tpu[spellid][currentPrefix]

        -- Initialize tracking for this prefix if it doesn't exist
        if not prefixEntry then
            tpu[spellid][currentPrefix] = {
                detected = true,
            }
            prefixEntry = tpu[spellid][currentPrefix]
        end

        -- Determine actions based on the event
        local used_start, used_end, cooldown_start
        if currentSpellData.cooldown_starts_on_dispel then
            if event == "SPELL_DISPEL" then
                used_start = true
                cooldown_start = true
            end
        elseif currentSpellData.cooldown_starts_on_aura_fade then
            if event == "UNIT_SPELLCAST_SUCCEEDED" or event == "SPELL_CAST_SUCCESS" or event == "SPELL_AURA_APPLIED" then
                used_start = true
            elseif event == "SPELL_AURA_REMOVED" then
                cooldown_start = true
            end
        else
            if event == "UNIT_SPELLCAST_SUCCEEDED" or event == "SPELL_CAST_SUCCESS" or event == "SPELL_AURA_APPLIED" then
                used_start = true
                cooldown_start = true
            elseif event == "SPELL_AURA_REMOVED" then
                used_end = true
            end
        end

        -- Apply the determined actions
        if used_start then
            prefixEntry.used_start = now
            prefixEntry.used_end = currentSpellData.duration and (now + currentSpellData.duration)

            -- Handle charges
            if prefixEntry.charges then
                prefixEntry.charges = prefixEntry.charges - 1
                if not prefixEntry.charges_detected and prefixEntry.cooldown_end and (prefixEntry.cooldown_end - 2) > now then
                    prefixEntry.charges_detected = true
                    if currentSpellData.opt_charges_linked then
                        for i = 1, #currentSpellData.opt_charges_linked do
                            local lspellid = currentSpellData.opt_charges_linked[i]
                            local lspelldata = SpellData[lspellid]
                            if not tpu[lspellid] then
                                tpu[lspellid] = {}
                            end
                            if not tpu[lspellid][currentPrefix] then
                                tpu[lspellid][currentPrefix] = {
                                    charges = lspelldata.opt_charges,
                                    max_charges = lspelldata.opt_charges,
                                }
                            end
                            tpu[lspellid][currentPrefix].charges_detected = true
                        end
                    end
                end
            end

            -- Reset other cooldowns for the same prefix
            if currentSpellData.resets then
                for i = 1, #currentSpellData.resets do
                    local rspellid = currentSpellData.resets[i]
                    if not tpu[rspellid] then
                        tpu[rspellid] = {}
                    end
                    if not tpu[rspellid][currentPrefix] then
                        tpu[rspellid][currentPrefix] = {}
                    end
                    tpu[rspellid][currentPrefix].cooldown_start = 0
                    tpu[rspellid][currentPrefix].cooldown_end = 0
                end
            end
        end

        if used_end then
            prefixEntry.used_end = now
        end

        if cooldown_start then
            if not prefixEntry.charges or not prefixEntry.cooldown_end or prefixEntry.cooldown_end <= now then
                local duration = GetCooldownTime(spellid, guid, currentPrefix)
				prefixEntry.cooldown_start = duration and now
                prefixEntry.cooldown_end = duration and (now + duration)

                if prefixEntry.charges and not prefixEntry.charge_timer then
                    prefixEntry.charge_timer = SetTimer(prefixEntry.cooldown_end, AddCharge, guid, spellid)
                end

                -- Handle linked cooldowns for the same prefix
                local sets_cooldowns = currentSpellData.sets_cooldowns or currentSpellData.sets_cooldown and { currentSpellData.sets_cooldown } or {}
                for i = 1, #sets_cooldowns do
                    local cd = sets_cooldowns[i]
                    local cspellid = cd.spellid
                    if not tpu[cspellid] then
                        tpu[cspellid] = {}
                    end
                    if not tpu[cspellid][currentPrefix] then
                        tpu[cspellid][currentPrefix] = {}
                    end

                    local cprefixEntry = tpu[cspellid][currentPrefix]
                    if not cprefixEntry.cooldown_end or (cprefixEntry.cooldown_end < (now + cd.cooldown)) then
                        cprefixEntry.cooldown_start = now
                        cprefixEntry.cooldown_end = now + cd.cooldown
                        cprefixEntry.used_start = cprefixEntry.used_start or 0
                        cprefixEntry.used_end = cprefixEntry.used_end or 0
						--FireCooldownEvent("LCT_CooldownUsed", guid, cspellid, isEnemy, currentPrefix)
                    end
                end
            end
            -- Fire the event for the current prefix and base if needed
            FireCooldownEvent("LCT_CooldownUsed", guid, spellid, isEnemy, currentPrefix)
        end
    end
end


local function enable()
	lib.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	lib.frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	lib.frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

	lib.tracked_players = {}
end

local function disable()
	lib.frame:UnregisterAllEvents()
end

function lib.callbacks:OnUsed(target, event)
	if event == "LCT_CooldownUsed" or event == "LCT_CooldownUsedByGUID" then
		enable()
	end
end

function lib.callbacks:OnUnused(target, event)
	if event == "LCT_CooldownUsed" or event == "LCT_CooldownUsedByGUID" then
		disable()
	end
end

--- Returns a table with the state of a unit's cooldown, or nil if there is no state stored about it.
-- @param unitid The unit unitid.
-- @param spellid The cooldown spellid.
-- @usage
-- local tracked = lib:GetUnitCooldownInfo(unitid, spellid)
-- if tracked then
--     print(tracked.cooldown_start) -- times are based on GetTime()
--     print(tracked.cooldown_end)
--     print(tracked.used_start)
--     print(tracked.used_end)
--     print(tracked.detected) -- use this to check if the unit has used this spell before (useful for detecting talents/glyphs)
-- end
function lib:GetUnitCooldownInfo(unitid, spellid, prefix)
	if not unitid then return end

	local guid = UnitGUID(unitid)

	if not guid then return end

	local tpu = lib.tracked_players[guid]

	if not tpu then return end

	if not tpu[spellid] then return end
	
	if prefix then return tpu[spellid][prefix] end

	return tpu[spellid].base and tpu[spellid].base or tpu[spellid]
end

--- Returns a table with the state of a unit's cooldown, or nil if there is no state stored about it.
-- @param guid The unit guid.
-- @param spellid The cooldown spellid.
-- @usage
-- local tracked = lib:GetCooldownInfoByGUID(guid, spellid)
-- if tracked then
--     print(tracked.cooldown_start) -- times are based on GetTime()
--     print(tracked.cooldown_end)
--     print(tracked.used_start)
--     print(tracked.used_end)
--     print(tracked.detected) -- use this to check if the unit has used this spell before (useful for detecting talents/glyphs)
-- end
function lib:GetCooldownInfoByGUID(guid, spellID, prefix)
    local trackedPlayer = lib.tracked_players[guid]

    if not trackedPlayer or not trackedPlayer[spellID] then return end

    -- Check if the prefix is valid for this spellID
    local spellData = lib:GetCooldownData(spellID, nil, false)

	if prefix and spellData and type(spellData) == "table" and spellData.prefixes and spellData.prefixes[prefix] then
		if trackedPlayer[spellID][prefix] then
			return trackedPlayer[spellID][prefix]
		else
			return
		end
	end
	
    -- Fallback to base if no valid prefix data was found
    return trackedPlayer[spellID].base
end

--- Returns the raw data of all the cooldowns. See the cooldowns_*.lua data files for more details about its structure.
function lib:GetCooldownsData()
	return SpellData
end

function lib:AddCustomSpell(spellID, info, prefix)

    local name, _, icon = GetSpellInfo(spellID)
    if not name then
        DEFAULT_CHAT_FRAME:AddMessage("LibCooldownTracker-1.0: bad spellid: " .. spellID)
        return
    end

    if not prefix or not spellID or not info or type(info) ~= "table" then return end

    if info.reduce and info.reduce.spellid and info.reduce.all then
        print("Invalid spellData for spellID " .. spellID .. ": cannot indicate both that all should be reduced, and at the same time only a selection of spellids.")
    elseif info.reduce and (not info.reduce.duration or (not info.reduce.all and not info.reduce.spellid)) then
        print("Invalid spellData for spellID " .. spellID .. ": missing reduction information.")
    elseif not info.cooldown and not info.parent then
        print("Invalid spellData for spellID " .. spellID .. ": must either point to a parent or provide a cooldown.")
    end

	info.name = name
	info.icon = info.icon or icon

    -- Handle adding to SpellData
    if SpellData[spellID] and type(SpellData[spellID]) == "number" then
        SpellData[spellID] = { parent = SpellData[spellID], prefixes = { [prefix] = info } }
    elseif not SpellData[spellID] or (SpellData[spellID] and type(SpellData[spellID]) == "table") then
        SpellData[spellID] = SpellData[spellID] or { prefixes = {} }
        SpellData[spellID].prefixes[prefix] = info
    end
end

function lib:RemoveCustomSpell(spellID, prefix)
    if not prefix or not spellID or not SpellData[spellID] or not type(SpellData[spellID]) == "table" or not SpellData[spellID].prefixes then return end

    -- Remove from SpellData
    SpellData[spellID].prefixes[prefix] = nil

    -- If no prefixes remain, remove the spell entirely
    if not SpellData[spellID].cooldown and next(SpellData[spellID].prefixes) == nil then
        SpellData[spellID] = nil
    end
end


--- Returns the raw data of a specified cooldown spellid.
-- @param spellid The cooldown spellid.
-- @param the prefix used for custom configs
function lib:GetCooldownData(spellid, prefix, iterateParents)

	if iterateParents == nil then
		iterateParents = true
	end

    local data = SpellData[spellid]
    if not data then
        return nil
    end

    -- If prefix is provided, prioritize checking it
    if prefix and type(data) == "table" and data.prefixes and data.prefixes[prefix] then
        data = data.prefixes[prefix]
		
		if type(data) == "table" and data.parent then
			data = data.parent
		end
    end

    if iterateParents then
		-- Resolve nested parent/child relationships or number references
		while type(data) == "number" or (type(data) == "table" and data.parent) do
			if type(data) == "number" then
				spellid = data
				data = SpellData[data]
			elseif type(data) == "table" then
				spellid = data.parent
				data = SpellData[data.parent]
			end

			-- If the resolved data is nil, break the loop
			if not data then
				return nil
			end
		end
	end

    return data, spellid
end

local function CooldownIterator(state, spellid)
	while true do
		spellid = next(state.data_source, spellid)
		if spellid == nil then
			return
		end
		local spelldata = state.data_source[spellid]

		-- handle prefixes
		if state.prefix and type(spelldata) ~= "number" and spelldata.prefixes and spelldata.prefixes[prefix] then
			spelldata = spelldata.prefixes[prefix]
		end

		-- iterate through parents
		spelldata = lib:GetCooldownData(spellid, state.prefix)

		-- ignore references to other spells
		if type(spelldata) ~= "number" then
			if state.class and state.class == spelldata.class then
				if state.specID and spelldata.specID then
					for _, intSpecID in pairs(spelldata.specID) do
						if intSpecID == state.specID then
							-- add spec
							return spellid, spelldata
						end
					end
				elseif not spelldata.specID then
					-- add base
					return spellid, spelldata
				end
			end

			if state.race and state.race == spelldata.race then
				-- return racial
				return spellid, spelldata
			end

			if spelldata.item then
				-- return item
				return spellid, spelldata
			end
		end
	end
end

-- Define the list of common unitIDs to check
local commonUnitIDs = {
	"player", "target", "focus", "mouseover",
	"party1", "party2", "party3", "party4",
	"arena1", "arena2", "arena3", "arena4", "arena5"
}

function lib:FindUnitIDs(guid)

    local unitIDs = {}
	local found = false
    -- Iterate through the list and check if the GUID matches
    for _, unitID in ipairs(commonUnitIDs) do
        if UnitGUID(unitID) == guid then
            table.insert(unitIDs, unitID)
			found = true
        end
    end

	if not found then return end

    return unitIDs -- Return all matching unitIDs for the given guid
end

--[[
-- uses lookup tables
local function FastCooldownIterator(state, spellid)
	local spelldata
	-- class
	if state.class then
		if state.data_source then
			spellid, spelldata = CooldownIterator(state, spellid)
		end

		if spellid then
			return spellid, spelldata
		else
			-- do race next
			state.data_source = race_spelldata[state.race]
			state.class = nil
			spellid = nil
		end
	end

	-- race
	if state.race then
		if state.data_source then
			spellid, spelldata = CooldownIterator(state, spellid)
		end

		if spellid then
			return spellid, spelldata
		else
			-- do items next
			state.data_source = item_spelldata
			state.race = nil
			spellid = nil
		end
	end

	-- item
	if state.item and state.data_source then
		spellid, spelldata = CooldownIterator(state, spellid)
		return spellid, spelldata
	end
end
--]]

--- Iterates over the cooldowns that apply to a unit of the specified //class//, //specID// and //race//.
-- @param class The unit class. Can be nil.
-- @param specID The unit talent spec ID. Can be nil.
-- @param race The unit race. Can be nil.
function lib:IterateCooldowns(class, specID, race, prefix)
	local state = {}
	state.class = class
	state.specID = specID
	state.race = race or ""
	state.item = true
	state.prefix = prefix

	state.data_source = SpellData
	return CooldownIterator, state
end

function events:PLAYER_ENTERING_WORLD()
	local instanceType = select(2, IsInInstance())

	-- reset cooldowns when joining an arena
	if instanceType == "arena" then
		ClearTimers()
		for guid in pairs(lib.tracked_players) do
			lib.tracked_players[guid] = nil
			FireCooldownEvent("LCT_CooldownsReset", guid)
		end
	end
end

function events:UNIT_SPELLCAST_SUCCEEDED(event, unit, spellName, rank, lineID, spellId)
    local isEnemy = not UnitIsFriend("player", unit)
	
	--CooldownEvent(event, UnitGUID(unit), spellId, isEnemy)
end

function events:COMBAT_LOG_EVENT_UNFILTERED(_, _, event, sourceGUID, e, sourceFlags, d, _, _, spellId)
    
	local isEnemy = false
	local b = bit.band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE)
	isEnemy = b == COMBATLOG_OBJECT_REACTION_HOSTILE
	
	local spelldata = SpellData[spellId]
	if not spelldata then return end
	
	if event == "SPELL_DISPEL" or
	   event == "SPELL_AURA_REMOVED" or
	   event == "SPELL_AURA_APPLIED" or
	   event == "SPELL_CAST_SUCCESS" then
	   
		CooldownEvent(event, sourceGUID, spellId, isEnemy)
	end
end