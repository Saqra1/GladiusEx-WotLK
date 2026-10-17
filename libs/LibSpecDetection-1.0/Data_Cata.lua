-- RCE Cross-Expansion handling
if GetAccountExpansionLevel() ~= 3 then return end -- not Cata

-- The MoP file is a WORK IN PROGRESS - I've just set it up as a stub using the Cata data for now

local addonName, ns = ...

ns.isCata = true

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
ns.ManaThreshold = {
    SHAMAN = { greater = false, specID = 263, threshold = 40000 },
    PALADIN = { greater = true, specID = 65, threshold = 40000 },
    DRUID = { greater = false, specID = 103, threshold = 40000 }
}

ns.AuraMapping = {
    -- BUFFS
    
    -- WARRIOR
    [46924] = {specID = 71, checkSource = true, }, -- Bladestorm (Arms Warrior)
    [56638] = {specID = 71, checkSource = true, }, -- Taste for Blood
    [65156] = {specID = 71, checkSource = true, }, -- Juggernaut
    [29801] = {specID = 72, checkSource = true, }, -- Rampage (Fury Warrior)
    [46913] = {specID = 72, checkSource = true, }, -- Bloodsurge R1
    [46914] = {specID = 72, checkSource = true, }, -- Bloodsurge R2
    [46915] = {specID = 72, checkSource = true, }, -- Bloodsurge R3
    [50227] = {specID = 73, checkSource = true, }, -- Sword and Board (Protection Warrior)
    
    -- PALADIN
    [54149] = {specID = 65, checkSource = true, }, -- Infusion of Light (Holy Paladin)
    
    -- ROGUE
    [51690] = {specID = 260, checkSource = true, }, -- Killing Spree (Outlaw Rogue)
    [13877] = {specID = 260, checkSource = true, }, -- Blade Flurry
    [13750] = {specID = 260, checkSource = true, }, -- Adrenaline Rush
    [36554] = {specID = 261, checkSource = true, }, -- Shadowstep (Subtlety Rogue)
    [31223] = {specID = 261, checkSource = true, }, -- Master of Subtlety
    [51713] = {specID = 261, checkSource = true, }, -- Shadow Dance
    [51698] = {specID = 261, checkSource = true, }, -- Honor Among Thieves R1
    [51700] = {specID = 261, checkSource = true, }, -- Honor Among Thieves R2
    [51701] = {specID = 261, checkSource = true, }, -- Honor Among Thieves R3
    
    -- PRIEST
    [10060] = {specID = 256, checkSource = true, }, -- Power Infusion (Discipline Priest)
    [33206] = {specID = 256, checkSource = true, }, -- Pain Suppression
    [52795] = {specID = 256, checkSource = true, }, -- Borrowed Time
    [57472] = {specID = 256, checkSource = true, }, -- Renewed Hope
    [47517] = {specID = 256, checkSource = true, }, -- Grace
    [14751] = {specID = 257, checkSource = true, }, -- Chakra (Holy Priest)
    [47788] = {specID = 257, checkSource = true, }, -- Guardian Spirit
    [15473] = {specID = 258, checkSource = true, }, -- Shadowform (Shadow Priest)
    [15286] = {specID = 258, checkSource = true, }, -- Vampiric Embrace
    
    -- DEATHKNIGHT
    [49222] = {specID = 250, checkSource = true, }, -- Bone Shield (Blood Death Knight)
    [53138] = {specID = 250, checkSource = true, }, -- Abomination's Might
    [55610] = {specID = 251, checkSource = true, }, -- Imp. Icy Talons (Frost Death Knight)
    [51052] = {specID = 252, checkSource = true, }, -- Anti-Magic Zone (Unholy Death Knight)
    [49016] = {specID = 252, checkSource = true, }, -- Unholy Frenzy
    
    -- MAGE      
    [11426] = {specID = 64, checkSource = true, }, -- Ice Barrier (Frost Mage)
    
    -- WARLOCK   
    [59672] = {specID = 266, checkSource = true, }, -- Metamorphosis (Demonology Warlock)
    [30299] = {specID = 267, checkSource = true, }, -- Nether Protection (Destruction Warlock)
    
    -- SHAMAN
    [16166] = {specID = 262, checkSource = true, }, -- Elemental Mastery (Elemental Shaman)
    [51470] = {specID = 262, checkSource = true, }, -- Elemental Oath
    [30802] = {specID = 263, checkSource = true, }, -- Unleashed Rage (Enhancement Shaman)
    [30823] = {specID = 263, checkSource = true, }, -- Shamanistic Rage
    [61295] = {specID = 264, checkSource = true, }, -- Riptide (Restoration Shaman)
    [974]   = {specID = 264, checkSource = true, }, -- Earth Shield
    
    -- HUNTER
    [20895] = {specID = 253, checkSource = true, }, -- Spirit Bond (Beast Mastery Hunter)
    [75447] = {specID = 253, checkSource = true, }, -- Ferocious Inspiration
    [19506] = {specID = 254, checkSource = true, }, -- Trueshot Aura (Marksmanship Hunter)
    
    -- DRUID
    [48505] = {specID = 102, checkSource = true, }, -- Starfall (Balance Druid)
    [50516] = {specID = 102, checkSource = true, }, -- Typhoon
    [24907] = {specID = 102, checkSource = true, }, -- Moonkin Form
    [24932] = {specID = 103, checkSource = true, }, -- Leader of the Pack (Feral Druid)
    [18562] = {specID = 105, checkSource = true, }, -- Swiftmend (Restoration Druid)
    [48438] = {specID = 105, checkSource = true, }, -- Wild Growth
    [33891] = {specID = 105, checkSource = true, }, -- Tree of Life
    
    -- ABILITIES / SPELLS
    
    -- WARRIOR
    [12294] = {specID = 71, checkSource = true, }, -- Mortal Strike (Arms Warrior)
    [46924] = {specID = 71, checkSource = true, }, -- Bladestorm
    [23881] = {specID = 72, checkSource = true, }, -- Bloodthirst (Fury Warrior)
    [12809] = {specID = 73, checkSource = true, }, -- Concussion Blow (Protection Warrior)
    [46968] = {specID = 73, checkSource = true, }, -- Shockwave
    [23922] = {specID = 66, checkSource = true, }, -- Shield Slam (Protection Paladin)
    [50720] = {specID = 73, checkSource = true, }, -- Vigilance
    
    -- PALADIN
    [31935] = {specID = 66, checkSource = true, }, -- Avenger's Shield
    [20473] = {specID = 65, checkSource = true, }, -- Holy Shock (Holy Paladin)
    [53563] = {specID = 65, checkSource = true, }, -- Beacon of Light
    [68020] = {specID = 70, checkSource = true, }, -- Seal of Command (Retribution Paladin)
    [35395] = {specID = 70, checkSource = true, }, -- Crusader Strike
    [53385] = {specID = 70, checkSource = true, }, -- Divine Storm
    [20066] = {specID = 70, checkSource = true, }, -- Repentance
    
    -- ROGUE
    [1329] = {specID = 259, checkSource = true, }, -- Mutilate (Assassination Rogue)
    [14177] = {specID = 259, checkSource = true, }, -- Cold Blood
    [51690] = {specID = 260, checkSource = true, }, -- Killing Spree (Outlaw Rogue)
    [13877] = {specID = 260, checkSource = true, }, -- Blade Flurry
    [13750] = {specID = 260, checkSource = true, }, -- Adrenaline Rush
    [36554] = {specID = 261, checkSource = true, }, -- Shadowstep (Subtlety Rogue)
    [16511] = {specID = 261, checkSource = true, }, -- Hemorrhage
    
    -- PRIEST
    [47540] = {specID = 256, checkSource = true, }, -- Penance (Discipline Priest)
    [10060] = {specID = 256, checkSource = true, }, -- Power Infusion
    [33206] = {specID = 256, checkSource = true, }, -- Pain Suppression
    [34861] = {specID = 257, checkSource = true, }, -- Circle of Healing (Holy Priest)
    [15487] = {specID = 258, checkSource = true, }, -- Silence (Shadow Priest)
    [34914] = {specID = 258, checkSource = true, }, -- Vampiric Touch
    
    -- DEATHKNIGHT
    [55050] = {specID = 250, checkSource = true, }, -- Heart Strike (Blood Death Knight)
    [49222] = {specID = 250, checkSource = true, }, -- Bone Shield
    [53138] = {specID = 250, checkSource = true, }, -- Abomination's Might
    [49203] = {specID = 251, checkSource = true, }, -- Hungering Cold (Frost Death Knight)
    [49143] = {specID = 251, checkSource = true, }, -- Frost Strike
    [49184] = {specID = 251, checkSource = true, }, -- Howling Blast
    [55610] = {specID = 251, checkSource = true, }, -- Improved Icy Talons
    [55090] = {specID = 252, checkSource = true, }, -- Scourge Strike (Unholy Death Knight)
    [49206] = {specID = 252, checkSource = true, }, -- Summon Gargoyle
    [51052] = {specID = 252, checkSource = true, }, -- Anti-Magic Zone
    [49194] = {specID = 252, checkSource = true, }, -- Unholy Blight
    [49016] = {specID = 252, checkSource = true, }, -- Unholy Frenzy
    
    -- MAGE
    [44425] = {specID = 62, checkSource = true, }, -- Arcane Barrage (Arcane Mage)
    [31589] = {specID = 62, checkSource = true, }, -- Slow
    [44457] = {specID = 63, checkSource = true, }, -- Living Bomb (Fire Mage)
    [31661] = {specID = 63, checkSource = true, }, -- Dragon's Breath
    [11366] = {specID = 63, checkSource = true, }, -- Pyroblast
    [11129] = {specID = 63, checkSource = true, }, -- Combustion
    [44572] = {specID = 64, checkSource = true, }, -- Deep Freeze (Frost Mage)
    [31687] = {specID = 64, checkSource = true, }, -- Summon Water Elemental
    [11426] = {specID = 64, checkSource = true, }, -- Ice Barrier
    
    -- WARLOCK
    [48181] = {specID = 265, checkSource = true, }, -- Haunt (Affliction Warlock)
    [30108] = {specID = 265, checkSource = true, }, -- Unstable Affliction
    [17962] = {specID = 267, checkSource = true, }, -- Conflagrate (Destruction Warlock)
    [59672] = {specID = 266, checkSource = true, }, -- Metamorphosis (Demonology Warlock)
    
    -- SHAMAN
    [51533] = {specID = 263, checkSource = true, }, -- Feral Spirit (Enhancement Shaman)
    [16166] = {specID = 262, checkSource = true, }, -- Elemental Mastery (Elemental Shaman)
    [51490] = {specID = 262, checkSource = true, }, -- Thunderstorm
    [51470] = {specID = 262, checkSource = true, }, -- Elemental Oath
    [30802] = {specID = 263, checkSource = true, }, -- Unleashed Rage
    [30823] = {specID = 263, checkSource = true, }, -- Shamanistic Rage
    [61295] = {specID = 264, checkSource = true, }, -- Riptide (Restoration Shaman)
    
    -- HUNTER
    [53209] = {specID = 253, checkSource = true, }, -- Chimera Shot (Beast Mastery Hunter)
    [20895] = {specID = 253, checkSource = true, }, -- Spirit Bond
    [75447] = {specID = 253, checkSource = true, }, -- Ferocious Inspiration
    [19506] = {specID = 254, checkSource = true, }, -- Trueshot Aura (Marksmanship Hunter)
    [34490] = {specID = 254, checkSource = true, }, -- Silencing Shot
    [19386] = {specID = 254, checkSource = true, }, -- Wyvern Sting
    [19434] = {specID = 254, checkSource = true, }, -- Aimed Shot
    [53301] = {specID = 255, checkSource = true, }, -- Explosive Shot (Survival Hunter)
    
    -- DRUID
    [48505] = {specID = 102, checkSource = true, }, -- Starfall (Balance Druid)
    [50516] = {specID = 102, checkSource = true, }, -- Typhoon
    [48517] = {specID = 102, checkSource = true, }, -- Eclipse (Solar)
    [48518] = {specID = 102, checkSource = true, }, -- Eclipse (Lunar)
    [33831] = {specID = 102, checkSource = true, }, -- Force of Nature
    [24858] = {specID = 102, checkSource = true, }, -- Moonkin Form
    [33878] = {specID = 103, checkSource = true, }, -- Mangle (Bear) (Feral Druid)
    [33876] = {specID = 103, checkSource = true, }, -- Mangle (Cat)
    [49376] = {specID = 103, checkSource = true, }, -- Feral Charge (Cat)
    [22570] = {specID = 103, checkSource = true, }, -- Maim
    [33891] = {specID = 105, checkSource = true, }, -- Tree of Life (Restoration Druid)
    [18562] = {specID = 105, checkSource = true, }, -- Swiftmend
}