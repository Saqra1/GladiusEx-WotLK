-- RCE Cross-Expansion handling
if GetAccountExpansionLevel() ~= 2 then return end -- not Wrath

local addonName, ns = ...

ns.isWotLK = true

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
-- Note: There's a small risk that a very ungeared healer may be interpreted as DPS spec
ns.ManaThreshold = {
	SHAMAN = { greater = false, specID = 263, threshold = 11000 },
    PALADIN = { greater = true, specID = 65, threshold = 11000 },
    DRUID = { greater = false, specID = 103, threshold = 11000 }
}

ns.AuraMapping = {
    -- BUFFS
    
    -- WARRIOR

    [56638] = {specID = 71, checkSource = false, }, -- Taste for Blood
    [64976] = {specID = 71, checkSource = false, }, -- Juggernaut
    [57522] = {specID = 71, checkSource = false, }, -- Enrage
    [52437] = {specID = 71, checkSource = false, }, -- Sudden Death
    [56112] = {specID = 72, checkSource = false, }, -- Furious Attacks
    [29801] = {specID = 72, checkSource = true, }, -- Rampage
    [46916] = {specID = 72, checkSource = false, }, -- Slam!
    [50227] = {specID = 73, checkSource = false, }, -- Sword and Board

    -- PALADIN  

    [20375] = {specID = 70, checkSource = false, }, -- Seal of Command
    [59578] = {specID = 70, checkSource = false, }, -- The Art of War
    [31836] = {specID = 65, checkSource = false, }, -- Light's Grace
    [54149] = {specID = 65, checkSource = false, }, -- Infusion of Light

    -- ROGUE

    [36554] = {specID = 261, checkSource = false, }, -- Shadowstep
    [44373] = {specID = 261, checkSource = false, }, -- Shadowstep Speed
    [36563] = {specID = 261, checkSource = false, }, -- Shadowstep DMG
    [51713] = {specID = 261, checkSource = false, }, -- Shadow Dance
    [31665] = {specID = 261, checkSource = false, }, -- Master of Subtlety
    [14278] = {specID = 261, checkSource = false, }, -- Ghostly Strike
    [51690] = {specID = 260, checkSource = false, }, -- Killing Spree
    [13877] = {specID = 260, checkSource = false, }, -- Blade Flurry
    [13750] = {specID = 260, checkSource = false, }, -- Adrenaline Rush
    [14177] = {specID = 259, checkSource = false, }, -- Cold Blood

    -- PRIEST

	[47540]	= {specID = 256, checkSource = true, }, -- Penance
	[10060]	= {specID = 256, checkSource = true, }, -- Power Infusion
	[33206]	= {specID = 256, checkSource = true, }, -- Pain Suppression
	[47517]	= {specID = 256, checkSource = true, }, -- Grace
	[34861]	= {specID = 257, checkSource = true, }, -- Circle of Healing
	[14751]	= {specID = 257, checkSource = false, }, -- Chakra
	[47788]	= {specID = 257, checkSource = true, }, -- Guardian Spirit
	[15487]	= {specID = 258, checkSource = true, }, -- Silence
	[34914]	= {specID = 258, checkSource = true, }, -- Vampiric Touch	
	[15407]	= {specID = 258, checkSource = true, }, -- Mind Flay		
	[15473]	= {specID = 258, checkSource = false, }, -- Shadowform
	[15286]	= {specID = 258, checkSource = true, }, -- Vampiric Embrace

    -- DEATHKNIGHT

    [49222] = {specID = 252, checkSource = false, }, -- Bone Shield

    -- MAGE

    [43039] = {specID = 64, checkSource = false, }, -- Ice Barrier
    [74396] = {specID = 64, checkSource = false, }, -- Fingers of Frost
    [57761] = {specID = 64, checkSource = false, }, -- Fireball!
    [11129] = {specID = 63, checkSource = false, }, -- Combustion
    [64346] = {specID = 63, checkSource = false, }, -- Fiery Payback
    [48108] = {specID = 63, checkSource = false, }, -- Hot Streak
    [54741] = {specID = 63, checkSource = false, }, -- Firestarter
    [55360] = {specID = 63, checkSource = true, }, -- Living Bomb
    [31583] = {specID = 62, checkSource = true, }, -- Arcane Empowerment
    [44413] = {specID = 62, checkSource = false, }, -- Incanter's Absorption

    -- WARLOCK

    [30302] = {specID = 267, checkSource = false, }, -- Nether Protection
    [63244] = {specID = 267, checkSource = false, }, -- Pyroclasm
    [54277] = {specID = 267, checkSource = false, }, -- Backdraft
    [47283] = {specID = 267, checkSource = false, }, -- Empowered Imp
    [34936] = {specID = 267, checkSource = false, }, -- Backlash
    [47193] = {specID = 266, checkSource = false, }, -- Demonic Empowerment
    [64371] = {specID = 265, checkSource = false, }, -- Eradication

    -- SHAMAN

    [65264] = {specID = 262, checkSource = false, }, -- Lava Flows
    [51470] = {specID = 262, checkSource = true, }, -- Elemental Oath
    [52179] = {specID = 262, checkSource = false, }, -- Astral Shift
    [53390] = {specID = 264, checkSource = true, }, -- Tidal Waves
	[49284] = {specID = 264, checkSource = true, }, -- Earth Shield
    [30809] = {specID = 263, checkSource = true, }, -- Unleashed Rage
    [53817] = {specID = 263, checkSource = false, }, -- Maelstrom Weapon

    -- HUNTER

    [20895] = {specID = 253, checkSource = false, }, -- Spirit Bond
    [34471] = {specID = 253, checkSource = false, }, -- The Beast Within
    [75447] = {specID = 253, checkSource = true, }, -- Ferocious Inspiration
    [19506] = {specID = 254, checkSource = true, }, -- Trueshot Aura
    [64420] = {specID = 255, checkSource = false, }, -- Sniper Training

    -- DRUID

    [16975] = {specID = 103, checkSource = false, }, -- Predatory Strikes
    [50334] = {specID = 103, checkSource = false, }, -- Berserk
    [24858] = {specID = 102, checkSource = false, }, -- Moonkin Form
    [45283] = {specID = 105, checkSource = false, }, -- Natural Perfection
    [16188] = {specID = 105, checkSource = false, }, -- Nature's Swiftness
    [33891] = {specID = 105, checkSource = false, }, -- Tree of Life
	[17007] = {specID = 103, checkSource = true, }, -- Leader of the Pack
    
    -- ABILITIES / SPELLS
    
	-- WARRIOR

    [47486] = {specID = 71, checkSource = true, }, -- Mortal Strike
    [46924] = {specID = 71, checkSource = true, }, -- Bladestorm
    [23881] = {specID = 72, checkSource = true, }, -- Bloodthirst
    [12809] = {specID = 73, checkSource = true, }, -- Concussion Blow
    [47498] = {specID = 73, checkSource = true, }, -- Devastate
    [46968] = {specID = 73, checkSource = true, }, -- Shockwave
    [50720] = {specID = 73, checkSource = true, }, -- Vigilance

    -- PALADIN

    [48827] = {specID = 66, checkSource = true, }, -- Avenger's Shield
    [48825] = {specID = 65, checkSource = true, }, -- Holy Shock
    [53563] = {specID = 65, checkSource = true, }, -- Beacon of Light
    [35395] = {specID = 70, checkSource = true, }, -- Crusader Strike
    [66006] = {specID = 70, checkSource = true, }, -- Divine Storm
    [20066] = {specID = 70, checkSource = true, }, -- Repentance

    -- ROGUE

    [48666] = {specID = 259, checkSource = true, }, -- Mutilate
    [14177] = {specID = 259, checkSource = true, }, -- Cold Blood
    [51690] = {specID = 260, checkSource = true, }, -- Killing Spree
    [13877] = {specID = 260, checkSource = true, }, -- Blade Flurry
    [13750] = {specID = 260, checkSource = true, }, -- Adrenaline Rush
    [36554] = {specID = 261, checkSource = true, }, -- Shadowstep
    [48660] = {specID = 261, checkSource = true, }, -- Hemorrhage
    [51713] = {specID = 261, checkSource = true, }, -- Shadow Dance

    -- PRIEST

    [52985] = {specID = 256, checkSource = true, }, -- Penance
    [10060] = {specID = 256, checkSource = true, }, -- Power Infusion
    [33206] = {specID = 256, checkSource = true, }, -- Pain Suppression
    [34861] = {specID = 257, checkSource = true, }, -- Circle of Healing
    [15487] = {specID = 258, checkSource = true, }, -- Silence
    [48160] = {specID = 258, checkSource = true, }, -- Vampiric Touch

    -- DEATHKNIGHT

    [55262] = {specID = 250, checkSource = true, }, -- Heart Strike
    [49203] = {specID = 251, checkSource = true, }, -- Hungering Cold
    [55268] = {specID = 251, checkSource = true, }, -- Frost Strike
    [51411] = {specID = 251, checkSource = true, }, -- Howling Blast
    [55271] = {specID = 252, checkSource = true, }, -- Scourge Strike

    -- MAGE

    [44781] = {specID = 62, checkSource = true, }, -- Arcane Barrage
    [55360] = {specID = 63, checkSource = true, }, -- Living Bomb
    [42950] = {specID = 63, checkSource = true, }, -- Dragon's Breath
    [42945] = {specID = 63, checkSource = true, }, -- Blast Wave
    [44572] = {specID = 64, checkSource = true, }, -- Deep Freeze

    -- WARLOCK

    [59164] = {specID = 265, checkSource = true, }, -- Haunt
    [47843] = {specID = 265, checkSource = true, }, -- Unstable Affliction
    [59672] = {specID = 266, checkSource = true, }, -- Metamorphosis
    [47193] = {specID = 266, checkSource = true, }, -- Demonic Empowerment
    [47996] = {specID = 266, checkSource = true, }, -- Intercept Felguard
    [59172] = {specID = 267, checkSource = true, }, -- Chaos Bolt
    [47847] = {specID = 267, checkSource = true, }, -- Shadowfury

    -- SHAMAN

    [59159] = {specID = 262, checkSource = true, }, -- Thunderstorm
    [16166] = {specID = 262, checkSource = true, }, -- Elemental Mastery
    [51533] = {specID = 263, checkSource = true, }, -- Feral Spirit
    [30823] = {specID = 263, checkSource = true, }, -- Shamanistic Rage
    [17364] = {specID = 263, checkSource = true, }, -- Stormstrike
    [61301] = {specID = 264, checkSource = true, }, -- Riptide
    [51886] = {specID = 264, checkSource = true, }, -- Cleanse Spirit

    -- HUNTER

    [19577] = {specID = 253, checkSource = true, }, -- Intimidation
    [34490] = {specID = 254, checkSource = true, }, -- Silencing Shot
    [53209] = {specID = 254, checkSource = true, }, -- Chimera Shot
    [60053] = {specID = 255, checkSource = true, }, -- Explosive Shot
    [49012] = {specID = 255, checkSource = true, }, -- Wyvern Sting

    -- DRUID

    [53201] = {specID = 102, checkSource = true, }, -- Starfall
    [61384] = {specID = 102, checkSource = true, }, -- Typhoon
    [24858] = {specID = 102, checkSource = true, }, -- Moonkin Form
    [48566] = {specID = 103, checkSource = true, }, -- Mangle (Cat)
    [48564] = {specID = 103, checkSource = true, }, -- Mangle (Bear)
    [50334] = {specID = 103, checkSource = true, }, -- Berserk
    [18562] = {specID = 105, checkSource = true, }, -- Swiftmend
    [17116] = {specID = 105, checkSource = true, }, -- Nature's Swiftness
    [33891] = {specID = 105, checkSource = true, }, -- Tree of Life
    [53251] = {specID = 105, checkSource = true, }, -- Wild Growth
}