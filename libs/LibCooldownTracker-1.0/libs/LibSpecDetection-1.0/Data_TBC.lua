-- RCE Cross-Expansion handling
if GetAccountExpansionLevel() ~= 1 then return end -- not TBC

local addonName, ns = ...

ns.isTBC = true

-- Spec mapping table for class and specialization detection
ns.SpecMapping = {
    WARRIOR = { [1] = 71, [2] = 72, [3] = 73 },             -- Arms, Fury, Protection
    PALADIN = { [1] = 65, [2] = 66, [3] = 70 },             -- Holy, Protection, Retribution
    HUNTER = { [1] = 253, [2] = 254, [3] = 255 },           -- Beast Mastery, Marksmanship, Survival
    ROGUE = { [1] = 259, [2] = 260, [3] = 261 },            -- Assassination, Combat, Subtlety
    PRIEST = { [1] = 256, [2] = 257, [3] = 258 },           -- Discipline, Holy, Shadow
    DEATHKNIGHT = { [1] = 250, [2] = 251, [3] = 252 },      -- Blood, Frost, Unholy
    SHAMAN = { [1] = 262, [2] = 263, [3] = 264 },           -- Elemental, Enhancement, Restoration
    MAGE = { [1] = 62, [2] = 63, [3] = 64 },                -- Arcane, Fire, Frost
    WARLOCK = { [1] = 265, [2] = 266, [3] = 267 },          -- Affliction, Demonology, Destruction
    DRUID = { [1] = 102, [2] = 103, [3] = 105 }             -- Balance, Feral, Restoration
}

-- Mana thresholds for spec detection 
-- Note: Not useful in TBC as healers and DPS specs have almost the same mana (especially when having to compare S1 to S4 gear)
ns.ManaThreshold = {
}

-- K: Credit for the list goes to Gladdy (Classic) team
ns.AuraMapping = {
	
	-- AURAS (BUFFS / DEBUFFS)

    -- DRUID
    [45283] = {specID = 105, checkSource = false, }, -- Natural Perfection
    [16880] = {specID = 105, checkSource = false, }, -- Nature's Grace; Dreamstate spec in TBC equals Restoration
    [24858] = {specID = 102, checkSource = false, }, -- Moonkin Form; Dreamstate spec in TBC equals Restoration
    [17007] = {specID = 103, checkSource = true, }, -- Leader of the Pack
    [16188] = {specID = 105, checkSource = false, }, -- Nature's Swiftness
    [33891] = {specID = 105, checkSource = false, }, -- Tree of Life

    -- HUNTER
    [34471] = {specID = 253, checkSource = false, }, -- The Beast Within
    [20895] = {specID = 253, checkSource = false, }, -- Spirit Bond
    [34455] = {specID = 253, checkSource = false, }, -- Ferocious Inspiration
    [27066] = {specID = 254, checkSource = false, }, -- Trueshot Aura
    [34501] = {specID = 255, checkSource = false, }, -- Expose Weakness

    -- MAGE
    [33405] = {specID = 64, checkSource = false, }, -- Ice Barrier
    [11129] = {specID = 63, checkSource = false, }, -- Combustion
    [12042] = {specID = 62, checkSource = false, }, -- Arcane Power
    [12043] = {specID = 62, checkSource = false, }, -- Presence of Mind
    [31589] = {specID = 62, checkSource = true, }, -- Slow
    [12472] = {specID = 64, checkSource = false, }, -- Icy Veins
    [46989] = {specID = 62, checkSource = false, }, -- Improved Blink

    -- PALADIN
    [31836] = {specID = 65, checkSource = false, }, -- Light's Grace
    [31842] = {specID = 65, checkSource = false, }, -- Divine Illumination
    [20216] = {specID = 65, checkSource = false, }, -- Divine Favor
    [20375] = {specID = 70, checkSource = false, }, -- Seal of Command
    [20049] = {specID = 70, checkSource = false, }, -- Vengeance
    [20218] = {specID = 70, checkSource = false, }, -- Sanctity Aura
    [26018] = {specID = 70, checkSource = false, }, -- Vindication
    [27179] = {specID = 66, checkSource = false, }, -- Holy Shield

    -- PRIEST
    [15473] = {specID = 258, checkSource = false, }, -- Shadowform
    [15286] = {specID = 258, checkSource = false, }, -- Vampiric Embrace
    [45234] = {specID = 256, checkSource = false, }, -- Focused Will
    [27811] = {specID = 256, checkSource = false, }, -- Blessed Recovery
    [33142] = {specID = 257, checkSource = false, }, -- Blessed Resilience
    [14752] = {specID = 256, checkSource = true, }, -- Divine Spirit
    [27681] = {specID = 256, checkSource = true, }, -- Prayer of Spirit
    [10060] = {specID = 256, checkSource = true, }, -- Power Infusion
    [33206] = {specID = 256, checkSource = true, }, -- Pain Suppression
    [14893] = {specID = 256, checkSource = false, }, -- Inspiration

    -- ROGUE
    [36554] = {specID = 261, checkSource = false, }, -- Shadowstep
    [44373] = {specID = 261, checkSource = false, }, -- Shadowstep Speed
    [36563] = {specID = 261, checkSource = false, }, -- Shadowstep DMG
    [14278] = {specID = 261, checkSource = false, }, -- Ghostly Strike
    [31233] = {specID = 259, checkSource = false, }, -- Find Weakness
    [13877] = {specID = 260, checkSource = false, }, -- Blade Flurry

    -- SHAMAN
    [30807] = {specID = 263, checkSource = false, }, -- Unleashed Rage
    [16280] = {specID = 263, checkSource = false, }, -- Flurry
    [30823] = {specID = 263, checkSource = false, }, -- Shamanistic Rage
    [16190] = {specID = 264, checkSource = true, }, -- Mana Tide Totem
    [32594] = {specID = 264, checkSource = true, }, -- Earth Shield
    [29202] = {specID = 264, checkSource = true, }, -- Healing Way

    -- WARLOCK
    [19028] = {specID = 267, checkSource = false, }, -- Soul Link
    [23759] = {specID = 267, checkSource = false, }, -- Master Demonologist
    [35696] = {specID = 267, checkSource = false, }, -- Demonic Knowledge
    [30300] = {specID = 266, checkSource = false, }, -- Nether Protection
    [34936] = {specID = 266, checkSource = false, }, -- Backlash

    -- WARRIOR
    [29838] = {specID = 71, checkSource = false, }, -- Second Wind
    [12292] = {specID = 71, checkSource = false, }, -- Death Wish

	-- SPELLS / ABILITIES

    -- DRUID
    [33831] = {specID = 102, checkSource = false, }, -- Force of Nature
    [33983] = {specID = 103, checkSource = false, }, -- Mangle (Cat)
    [33987] = {specID = 103, checkSource = false, }, -- Mangle (Bear)
    [18562] = {specID = 105, checkSource = false, }, -- Swiftmend
    [17116] = {specID = 105, checkSource = false, }, -- Nature's Swiftness
    [33891] = {specID = 105, checkSource = false, }, -- Tree of Life

    -- HUNTER
    [19577] = {specID = 253, checkSource = false, }, -- Intimidation
    [34490] = {specID = 254, checkSource = false, }, -- Silencing Shot
    [27068] = {specID = 255, checkSource = false, }, -- Wyvern Sting
    [19306] = {specID = 255, checkSource = false, }, -- Counterattack
    [27066] = {specID = 254, checkSource = false, }, -- Trueshot Aura

    -- MAGE
    [12042] = {specID = 62, checkSource = false, }, -- Arcane Power
    [33043] = {specID = 63, checkSource = false, }, -- Dragon's Breath
    [33933] = {specID = 63, checkSource = false, }, -- Blast Wave
    [33405] = {specID = 64, checkSource = false, }, -- Ice Barrier
    [31687] = {specID = 64, checkSource = false, }, -- Summon Water Elemental
    [12472] = {specID = 64, checkSource = false, }, -- Icy Veins
    [11958] = {specID = 64, checkSource = false, }, -- Cold Snap

    -- PALADIN
    [33072] = {specID = 65, checkSource = false, }, -- Holy Shock
    [20216] = {specID = 65, checkSource = false, }, -- Divine Favor
    [31842] = {specID = 65, checkSource = false, }, -- Divine Illumination
    [32700] = {specID = 66, checkSource = false, }, -- Avenger's Shield
    [27170] = {specID = 70, checkSource = false, }, -- Seal of Command
    [35395] = {specID = 70, checkSource = false, }, -- Crusader Strike
    [20066] = {specID = 70, checkSource = false, }, -- Repentance
    [20218] = {specID = 70, checkSource = false, }, -- Sanctity Aura

    -- PRIEST
    [10060] = {specID = 256, checkSource = false, }, -- Power Infusion
    [33206] = {specID = 256, checkSource = false, }, -- Pain Suppression
    [14752] = {specID = 256, checkSource = false, }, -- Divine Spirit
    [33143] = {specID = 257, checkSource = false, }, -- Blessed Resilience
    [34861] = {specID = 257, checkSource = false, }, -- Circle of Healing
    [15473] = {specID = 258, checkSource = false, }, -- Shadowform
    [34917] = {specID = 258, checkSource = false, }, -- Vampiric Touch
    [15286] = {specID = 258, checkSource = false, }, -- Vampiric Embrace

    -- ROGUE
    [34413] = {specID = 259, checkSource = false, }, -- Mutilate
    [14177] = {specID = 259, checkSource = false, }, -- Cold Blood
    [13750] = {specID = 260, checkSource = false, }, -- Adrenaline Rush
    [13877] = {specID = 260, checkSource = false, }, -- Blade Flurry
    [14185] = {specID = 261, checkSource = false, }, -- Preparation
    [16511] = {specID = 261, checkSource = false, }, -- Hemorrhage
    [36554] = {specID = 261, checkSource = false, }, -- Shadowstep
    [14278] = {specID = 261, checkSource = false, }, -- Ghostly Strike
    [14183] = {specID = 261, checkSource = false, }, -- Premeditation

    -- SHAMAN
    [16166] = {specID = 262, checkSource = false, }, -- Elemental Mastery
    [30706] = {specID = 262, checkSource = false, }, -- Totem of Wrath
    [30823] = {specID = 263, checkSource = false, }, -- Shamanistic Rage
    [17364] = {specID = 263, checkSource = false, }, -- Stormstrike
    [16190] = {specID = 264, checkSource = false, }, -- Mana Tide Totem
    [32594] = {specID = 264, checkSource = false, }, -- Earth Shield
    [16188] = {specID = 264, checkSource = false, }, -- Nature's Swiftness

    -- WARLOCK
    [30405] = {specID = 265, checkSource = false, }, -- Unstable Affliction
    [18220] = {specID = 265, checkSource = false, }, -- Dark Pact
    [30414] = {specID = 266, checkSource = false, }, -- Shadowfury
    [30912] = {specID = 266, checkSource = false, }, -- Conflagrate
    [18708] = {specID = 267, checkSource = false, }, -- Fel Domination

    -- WARRIOR
    [30330] = {specID = 71, checkSource = false, }, -- Mortal Strike
    [12292] = {specID = 71, checkSource = false, }, -- Death Wish
    [30335] = {specID = 72, checkSource = false, }, -- Bloodthirst
    [12809] = {specID = 73, checkSource = false, }, -- Concussion Blow
    [30022] = {specID = 73, checkSource = false, }, -- Devastation
    [30356] = {specID = 73, checkSource = false, }, -- Shield Slam
}