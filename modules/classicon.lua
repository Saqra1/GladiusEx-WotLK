local GladiusEx = _G.GladiusEx
local L = LibStub("AceLocale-3.0"):GetLocale("GladiusEx")
local fn = LibStub("LibFunctional-1.0")
local LSM = LibStub("LibSharedMedia-3.0")

-- upvalues
local strfind = string.find
local pairs, select, unpack = pairs, select, unpack
local GetTime, SetPortraitTexture, GetSpellInfo = GetTime, SetPortraitTexture, GetSpellInfo

local Spectate = GladiusEx:GetModule("Spectate", true)

local UnitClass = Spectate and Spectate.UnitClass or UnitClass
local UnitExists = Spectate and Spectate.UnitExists or UnitExists
local UnitGUID = Spectate and Spectate.UnitGUID or UnitGUID
local UnitAura = Spectate and Spectate.UnitAura or UnitAura
local UnitIsVisible = Spectate and Spectate.UnitIsVisible or UnitIsVisible
local UnitIsConnected = Spectate and Spectate.UnitIsConnected or UnitIsConnected



-- NOTE: this list can be modified from the ClassIcon module options, no need to edit it here
-- Nonetheless, if you think that we missed an important aura, please post it on the addon site at curse or wowace
local function GetDefaultImportantAuras()
    return {
        -- Exact spell ID = priority (higher = more priority). Ranks are listed separately.
        [44166] = 9.4, -- Refreshment
        [46755] = 9.4, -- Drink
        [27089] = 9.4, -- Drink
        [27827] = 9.3, -- Spirit of Redemption
        [5384] = 9.2, -- Feign Death
        [66] = 9.2, -- Invisibility
        [32612] = 9.2, -- Invisibility
        [1784] = 9.2, -- Stealth
        [5215] = 9.2, -- Prowl
        [11327] = 9.2, -- Vanish (Rank 1)
        [11329] = 9.2, -- Vanish (Rank 2)
        [26888] = 9.2, -- Vanish (Rank 3)
        [33786] = 9.1, -- Cyclone
        [20549] = 9, -- War Stomp (Racial)
        [56] = 9, -- Stun
        [25275] = 9, -- Intercept (Rank 5)
        [28271] = 9, -- Polymorph (Turtle)
        [28272] = 9, -- Polymorph (Pig)
        [28445] = 9, -- Improved Concussive Shot
        [37506] = 9, -- Scatter Shot
        [3355] = 9, -- Freezing Trap Effect (Rank 1)
        [14308] = 9, -- Freezing Trap Effect (Rank 2)
        [14309] = 9, -- Freezing Trap Effect (Rank 3)
        [13327] = 9, -- Reckless Charge
        [30216] = 9, -- Fel Iron Bomb
        [67769] = 9, -- Cobalt Frag Bomb
        [30217] = 9, -- Adamantite Grenade
        [46968] = 9, -- Shockwave
        [5246] = 9, -- Intimidating Shout
        [20253] = 9, -- Intercept (Rank 1)
        [20614] = 9, -- Intercept (Rank 2)
        [20615] = 9, -- Intercept (Rank 3)
        [25273] = 9, -- Intercept (Rank 4)
        [25274] = 9, -- Intercept (Rank 5)
        [6544] = 9, -- Heroic Leap
        [12809] = 9, -- Concussion Blow
        [12798] = 9, -- Revenge Stun (Rank 1)
        [100] = 9, -- Charge (Rank 1)
        [6178] = 9, -- Charge (Rank 2)
        [11578] = 9, -- Charge (Rank 3)
        [7922] = 9, -- Charge Stun
        [30283] = 9, -- Shadowfury (Rank 1)
        [30413] = 9, -- Shadowfury (Rank 2)
        [30414] = 9, -- Shadowfury (Rank 3)
        [47846] = 9, -- Shadowfury (Rank 4)
        [47847] = 9, -- Shadowfury (Rank 5)
        [6358] = 9, -- Seduction
        [5484] = 9, -- Howl of Terror (Rank 1)
        [17928] = 9, -- Howl of Terror (Rank 2)
        [5782] = 9, -- Fear (Rank 1)
        [6213] = 9, -- Fear (Rank 2)
        [6215] = 9, -- Fear (Rank 3)
        [54786] = 9, -- Demon Leap
        [6789] = 9, -- Death Coil (Rank 1)
        [17925] = 9, -- Death Coil (Rank 2)
        [17926] = 9, -- Death Coil (Rank 3)
        [27223] = 9, -- Death Coil (Rank 4)
        [47859] = 9, -- Death Coil (Rank 5)
        [47860] = 9, -- Death Coil (Rank 6)
        [710] = 9, -- Banish (Rank 1)
        [18647] = 9, -- Banish (Rank 2)
        [39796] = 9, -- Stoneclaw Stun
        [51514] = 9, -- Hex
        [61882] = 9, -- Earthquake (Rank 1)
        [6770] = 9, -- Sap (Rank 1)
        [2070] = 9, -- Sap (Rank 2)
        [11297] = 9, -- Sap (Rank 3)
        [51724] = 9, -- Sap (Rank 4)
        [408] = 9, -- Kidney Shot (Rank 1)
        [8643] = 9, -- Kidney Shot (Rank 2)
        [1776] = 9, -- Gouge
        [1833] = 9, -- Cheap Shot
        [2094] = 9, -- Blind
        [9484] = 9, -- Shackle Undead (Rank 1)
        [9485] = 9, -- Shackle Undead (Rank 2)
        [10955] = 9, -- Shackle Undead (Rank 3)
        [8122] = 9, -- Psychic Scream (Rank 1)
        [8124] = 9, -- Psychic Scream (Rank 2)
        [10888] = 9, -- Psychic Scream (Rank 3)
        [10890] = 9, -- Psychic Scream (Rank 4)
        [64044] = 9, -- Psychic Horror
        [605] = 9, -- Mind Control
        [10326] = 9, -- Turn Evil
        [20066] = 9, -- Repentance
        [2812] = 9, -- Holy Wrath (Rank 1)
        [10318] = 9, -- Holy Wrath (Rank 2)
        [27139] = 9, -- Holy Wrath (Rank 3)
        [48816] = 9, -- Holy Wrath (Rank 4)
        [48817] = 9, -- Holy Wrath (Rank 5)
        [853] = 9, -- Hammer of Justice (Rank 1)
        [5588] = 9, -- Hammer of Justice (Rank 2)
        [5589] = 9, -- Hammer of Justice (Rank 3)
        [10308] = 9, -- Hammer of Justice (Rank 4)
        [118] = 9, -- Polymorph (Rank 1)
        [12824] = 9, -- Polymorph (Rank 2)
        [12825] = 9, -- Polymorph (Rank 3)
        [12826] = 9, -- Polymorph (Rank 4)
        [12355] = 9, -- Impact (Rank 1)
        [31661] = 9, -- Dragon's Breath (Rank 1)
        [33041] = 9, -- Dragon's Breath (Rank 2)
        [33042] = 9, -- Dragon's Breath (Rank 3)
        [33043] = 9, -- Dragon's Breath (Rank 4)
        [42949] = 9, -- Dragon's Breath (Rank 5)
        [42950] = 9, -- Dragon's Breath (Rank 6)
        [44572] = 9, -- Deep Freeze
        [50519] = 9, -- Sonic Blast (Rank 1)
        [53564] = 9, -- Sonic Blast (Rank 2)
        [53565] = 9, -- Sonic Blast (Rank 3)
        [53566] = 9, -- Sonic Blast (Rank 4)
        [53567] = 9, -- Sonic Blast (Rank 5)
        [53568] = 9, -- Sonic Blast (Rank 6)
        [50518] = 9, -- Ravage (Rank 1)
        [53558] = 9, -- Ravage (Rank 2)
        [53559] = 9, -- Ravage (Rank 3)
        [53560] = 9, -- Ravage (Rank 4)
        [53561] = 9, -- Ravage (Rank 5)
        [53562] = 9, -- Ravage (Rank 6)
        [19386] = 9, -- Wyvern Sting (Rank 1)
        [24132] = 9, -- Wyvern Sting (Rank 2)
        [24133] = 9, -- Wyvern Sting (Rank 3)
        [27068] = 9, -- Wyvern Sting (Rank 4)
        [49011] = 9, -- Wyvern Sting (Rank 5)
        [49012] = 9, -- Wyvern Sting (Rank 6)
        [19503] = 9, -- Scatter Shot
        [1513] = 9, -- Scare Beast (Rank 1)
        [14326] = 9, -- Scare Beast (Rank 2)
        [14327] = 9, -- Scare Beast (Rank 3)
        [24394] = 9, -- Intimidation

        [60210] = 9, -- Freezing Arrow Effect (Rank 1)
        [9005] = 9, -- Pounce (Rank 1)
        [9823] = 9, -- Pounce (Rank 2)
        [9827] = 9, -- Pounce (Rank 3)
        [27006] = 9, -- Pounce (Rank 4)
        [49803] = 9, -- Pounce (Rank 5)
        [22570] = 9, -- Maim (Rank 1)
        [49802] = 9, -- Maim (Rank 2)
        [2637] = 9, -- Hibernate (Rank 1)
        [18657] = 9, -- Hibernate (Rank 2)
        [18658] = 9, -- Hibernate (Rank 3)
        [5211] = 9, -- Bash (Rank 1)
        [6798] = 9, -- Bash (Rank 2)
        [8983] = 9, -- Bash (Rank 3)
        [49203] = 9, -- Hungering Cold (Rank 1)
        [51209] = 9, -- Hungering Cold (aura)
        [47481] = 9, -- Gnaw
        [45438] = 8.9, -- Ice Block
        [642] = 8.9, -- Divine Shield
        [47585] = 8.9, -- Dispersion
        [19263] = 8.9, -- Deterrence
        [46924] = 8.9, -- Bladestorm
        [19574] = 8.9, -- Bestial Wrath
        [34692] = 8.9, -- The Beast Within
        [6940] = 8.8, -- Hand of Sacrifice
        [64205] = 8.8, -- Divine Sacrifice
        [31821] = 8.7, -- Aura Mastery
        [23920] = 8.7, -- Spell Reflection
        [8178] = 8.7, -- Grounding Totem Effect (Rank 1)
        [31224] = 8.7, -- Cloak of Shadows
        [48707] = 8.7, -- Anti-Magic Shell
        [48792] = 8.6, -- Icebound Fortitude
        [3411] = 8.6, -- Intervene
        [1022] = 8.6, -- Hand of Protection (Rank 1)
        [5599] = 8.6, -- Hand of Protection (Rank 2)
        [10278] = 8.6, -- Hand of Protection (Rank 3)
        [49039] = 8.4, -- Lichborne
        [18499] = 8.4, -- Berserker Rage
        [50334] = 8.4, -- Berserk
        [5277] = 8.2, -- Evasion (Rank 1)
        [26669] = 8.2, -- Evasion (Rank 2)
        [38031] = 8.2, -- Shield Block
        [2565] = 8.2, -- Shield Block (player)
        [20594] = 8.2, -- Stoneform (Racial)
        [55021] = 7, -- Silenced - Improved Counterspell (Rank 2)
        [18469] = 7, -- Silenced - Improved Counterspell (Rank 1)
        [25046] = 7, -- Arcane Torrent (Racial)
        [18498] = 7, -- Silenced - Gag Order
        [31117] = 7, -- Unstable Affliction
        [24259] = 7, -- Spell Lock
        [18425] = 7, -- Silenced - Improved Kick
        [1330] = 7, -- Garrote - Silence
        [15487] = 7, -- Silence
        [31935] = 7, -- Avenger's Shield (Rank 1)
        [32699] = 7, -- Avenger's Shield (Rank 2)
        [32700] = 7, -- Avenger's Shield (Rank 3)
        [48826] = 7, -- Avenger's Shield (Rank 4)
        [48827] = 7, -- Avenger's Shield (Rank 5)

        [34490] = 7, -- Silencing Shot
        [47476] = 7, -- Strangulate
        [27559] = 7, -- Silence
        [18708] = 6, -- Fel Domination
        [1044] = 5.5, -- Hand of Freedom
        [54216] = 5.5, -- Master's Call
        [16979] = 5, -- Feral Charge - Bear
        [16689] = 5, -- Nature's Grasp (Rank 1)
        [16810] = 5, -- Nature's Grasp (Rank 2)
        [16811] = 5, -- Nature's Grasp (Rank 3)
        [16812] = 5, -- Nature's Grasp (Rank 4)
        [16813] = 5, -- Nature's Grasp (Rank 5)
        [17329] = 5, -- Nature's Grasp (Rank 6)
        [27009] = 5, -- Nature's Grasp (Rank 7)
        [53312] = 5, -- Nature's Grasp (Rank 8)
        [13099] = 5, -- Net-o-Matic
        [55536] = 5, -- Frostweave Net
        [39965] = 5, -- Frost Grenade
        [23694] = 5, -- Improved Hamstring
        [58373] = 5, -- Glyph of Hamstring
        [12494] = 5, -- Frostbite
        [55080] = 5, -- Shattered Barrier
        [63685] = 5, -- Freeze
        [64695] = 5, -- Earthgrab
        [122] = 5, -- Frost Nova (Rank 1)
        [865] = 5, -- Frost Nova (Rank 2)
        [6131] = 5, -- Frost Nova (Rank 3)
        [10230] = 5, -- Frost Nova (Rank 4)
        [27088] = 5, -- Frost Nova (Rank 5)
        [42917] = 5, -- Frost Nova (Rank 6)
        [33395] = 5, -- Freeze
        [4167] = 5, -- Web (Rank 1)
        [54706] = 5, -- Venom Web Spray (Rank 1)
        [55505] = 5, -- Venom Web Spray (Rank 2)
        [55506] = 5, -- Venom Web Spray (Rank 3)
        [55507] = 5, -- Venom Web Spray (Rank 4)
        [55508] = 5, -- Venom Web Spray (Rank 5)
        [55509] = 5, -- Venom Web Spray (Rank 6)
        [50245] = 5, -- Pin (Rank 1)
        [53544] = 5, -- Pin (Rank 2)
        [53545] = 5, -- Pin (Rank 3)
        [53546] = 5, -- Pin (Rank 4)
        [53547] = 5, -- Pin (Rank 5)
        [53548] = 5, -- Pin (Rank 6)
        [19185] = 5, -- Entrapment
        [19306] = 5, -- Counterattack (Rank 1)
        [20909] = 5, -- Counterattack (Rank 2)
        [20910] = 5, -- Counterattack (Rank 3)
        [27067] = 5, -- Counterattack (Rank 4)
        [48998] = 5, -- Counterattack (Rank 5)
        [48999] = 5, -- Counterattack (Rank 6)
        [45334] = 5, -- Feral Charge Effect
        [339] = 5, -- Entangling Roots (Rank 1)
        [1062] = 5, -- Entangling Roots (Rank 2)
        [5195] = 5, -- Entangling Roots (Rank 3)
        [5196] = 5, -- Entangling Roots (Rank 4)
        [9852] = 5, -- Entangling Roots (Rank 5)
        [9853] = 5, -- Entangling Roots (Rank 6)
        [26989] = 5, -- Entangling Roots (Rank 7)
        [53308] = 5, -- Entangling Roots (Rank 8)
        [676] = 4, -- Disarm
        [53359] = 4, -- Chimera Shot - Scorpid
        [51722] = 4, -- Dismantle
        [64346] = 4, -- Fiery Payback
        [50541] = 4, -- Snatch (Rank 1)
        [53537] = 4, -- Snatch (Rank 2)
        [53538] = 4, -- Snatch (Rank 3)
        [53540] = 4, -- Snatch (Rank 4)
        [53542] = 4, -- Snatch (Rank 5)
        [53543] = 4, -- Snatch (Rank 6)
        [51271] = 3, -- Unbreakable Armor
        [12043] = 2.6, -- Presence of Mind
        [12042] = 2.5, -- Arcane Power
        [14177] = 2.6, -- Cold Blood
        [16188] = 2.6, -- Nature's Swiftness
        [17116] = 2.6, -- Nature's Swiftness
        [1719] = 2.6, -- Recklessness
        [5217] = 2.6, -- Tiger's Fury (Rank 1)
        [6793] = 2.6, -- Tiger's Fury (Rank 2)
        [9845] = 2.6, -- Tiger's Fury (Rank 3)
        [9846] = 2.6, -- Tiger's Fury (Rank 4)
        [50212] = 2.6, -- Tiger's Fury (Rank 5)
        [50213] = 2.6, -- Tiger's Fury (Rank 6)
        [29977] = 2.6, -- Combustion
        [11129] = 2.6, -- Combustion (player)
        [28682] = 2.6, -- Combustion (critical strike bonus)
        [16166] = 2.6, -- Elemental Mastery (instant cast)
        [64701] = 2.6, -- Elemental Mastery (haste)
        [20216] = 2.6, -- Divine Favor
        [12292] = 2.5, -- Death Wish
        [12472] = 2.5, -- Icy Veins
        [13750] = 2.5, -- Adrenaline Rush
        [3045] = 2.5, -- Rapid Fire
        [53201] = 2.5, -- Starfall (Rank 4)
        [48505] = 2.5, -- Starfall (Rank 1)
        [53199] = 2.5, -- Starfall (Rank 2)
        [53200] = 2.5, -- Starfall (Rank 3)
        [51713] = 2.5, -- Shadow Dance
        [30823] = 2.5, -- Shamanistic Rage
        [31884] = 2.5, -- Avenging Wrath
        [33206] = 2.5, -- Pain Suppression
        [498] = 2.5, -- Divine Protection
        [70940] = 2.5, -- Divine Guardian
        [47788] = 2.5, -- Guardian Spirit
        [47241] = 2.5, -- Metamorphosis
        [20572] = 2.5, -- Blood Fury (Racial)
        [26297] = 2.5, -- Berserking (Racial)
        [12328] = 2.4, -- Sweeping Strikes
        [13877] = 2.4, -- Blade Flurry
        [20230] = 2.4, -- Retaliation
        [32182] = 0.4, -- Heroism
        [2825] = 0.4, -- Bloodlust
        [22842] = 2.1, -- Frenzied Regeneration
        [55694] = 2.1, -- Enraged Regeneration
        [55233] = 2.1, -- Vampiric Blood
        [10060] = 2, -- Power Infusion
        [12975] = 2, -- Last Stand
        [14751] = 2, -- Inner Focus
        [27273] = 2, -- Sacrifice (Rank 7)
        [7812] = 2, -- Sacrifice (Rank 1)
        [19438] = 2, -- Sacrifice (Rank 2)
        [19440] = 2, -- Sacrifice (Rank 3)
        [19441] = 2, -- Sacrifice (Rank 4)
        [19442] = 2, -- Sacrifice (Rank 5)
        [19443] = 2, -- Sacrifice (Rank 6)
        [47985] = 2, -- Sacrifice (Rank 8)
        [47986] = 2, -- Sacrifice (Rank 9)
        [22812] = 2, -- Barkskin
        [49222] = 2, -- Bone Shield
        [61336] = 2, -- Survival Instincts
        [871] = 1.9, -- Shield Wall
        [31842] = 1.5, -- Divine Illumination
        [3034] = 1.5, -- Viper Sting
        [29166] = 1.5, -- Innervate
        [54428] = 1.5, -- Divine Plea
        [45182] = 1.5, -- Cheating Death
        [6346] = 1.4, -- Fear Ward
        [2687] = 1.1, -- Bloodrage
        [12051] = 1.1, -- Evocation
        [5118] = 1, -- Aspect of the Cheetah
        [1850] = 1, -- Dash (Rank 1)
        [9821] = 1, -- Dash (Rank 2)
        [33357] = 1, -- Dash (Rank 3)
        [2983] = 1, -- Sprint (Rank 1)
        [8696] = 1, -- Sprint (Rank 2)
        [11305] = 1, -- Sprint (Rank 3)
        [31642] = 1, -- Blazing Speed (Rank 2)
        [20578] = 0.9, -- Cannibalize
        [3043] = 0.9, -- Scorpid Sting
        [36554] = 0.9, -- Shadowstep
        [41425] = 0.9, -- Hypothermia
        [11426] = 0.8, -- Ice Barrier (Rank 1)
        [13031] = 0.8, -- Ice Barrier (Rank 2)
        [13032] = 0.8, -- Ice Barrier (Rank 3)
        [13033] = 0.8, -- Ice Barrier (Rank 4)
        [27134] = 0.8, -- Ice Barrier (Rank 5)
        [33405] = 0.8, -- Ice Barrier (Rank 6)
        [43038] = 0.8, -- Ice Barrier (Rank 7)
        [43039] = 0.8, -- Ice Barrier (Rank 8)
        [1543] = 0.8, -- Flare
        [34709] = 0.8, -- Shadow Sight
        [2645] = 0.5, -- Ghost Wolf
        -- [33891] = 0.5, -- Tree of Life (disabled)
        [9634] = 0.5, -- Dire Bear Form (Shapeshift)
        [768] = 0.5, -- Cat Form (Shapeshift)
        [783] = 0.5, -- Travel Form (Shapeshift)
        [25771] = 0.1, -- Forbearance
        [12489] = 0, -- Improved Cone of Cold (Rank 2)
        [29703] = 0, -- Dazed
        [12323] = 0, -- Piercing Howl
        [1715] = 0, -- Hamstring
        [63311] = 0, -- Glyph of Shadowflame
        [18223] = 0, -- Curse of Exhaustion
        [18118] = 0, -- Aftermath
        [8034] = 0, -- Frostbrand Attack (Rank 1)
        [8037] = 0, -- Frostbrand Attack (Rank 2)
        [10458] = 0, -- Frostbrand Attack (Rank 3)
        [16352] = 0, -- Frostbrand Attack (Rank 4)
        [16353] = 0, -- Frostbrand Attack (Rank 5)
        [25501] = 0, -- Frostbrand Attack (Rank 6)
        [58797] = 0, -- Frostbrand Attack (Rank 7)
        [58798] = 0, -- Frostbrand Attack (Rank 8)
        [58799] = 0, -- Frostbrand Attack (Rank 9)
        [8056] = 0, -- Frost Shock (Rank 1)
        [8058] = 0, -- Frost Shock (Rank 2)
        [10472] = 0, -- Frost Shock (Rank 3)
        [10473] = 0, -- Frost Shock (Rank 4)
        [25464] = 0, -- Frost Shock (Rank 5)
        [49235] = 0, -- Frost Shock (Rank 6)
        [49236] = 0, -- Frost Shock (Rank 7)
        [3600] = 0, -- Earthbind
        [26679] = 0, -- Deadly Throw (Rank 1)
        [48673] = 0, -- Deadly Throw (Rank 2)
        [48674] = 0, -- Deadly Throw (Rank 3)
        [3409] = 0, -- Crippling Poison
        [31125] = 0, -- Blade Twisting
        [15407] = 0, -- Mind Flay (Rank 1)
        [17311] = 0, -- Mind Flay (Rank 2)
        [17312] = 0, -- Mind Flay (Rank 3)
        [17313] = 0, -- Mind Flay (Rank 4)
        [17314] = 0, -- Mind Flay (Rank 5)
        [18807] = 0, -- Mind Flay (Rank 6)
        [25387] = 0, -- Mind Flay (Rank 7)
        [48155] = 0, -- Mind Flay (Rank 8)
        [48156] = 0, -- Mind Flay (Rank 9)
        [20170] = 0, -- Stun
        [63529] = 0, -- Silenced - Shield of the Templar
        [31589] = 0, -- Slow
        [44614] = 0, -- Frostfire Bolt (Rank 1)
        [47610] = 0, -- Frostfire Bolt (Rank 2)
        [116] = 0, -- Frostbolt (Rank 1)
        [205] = 0, -- Frostbolt (Rank 2)
        [837] = 0, -- Frostbolt (Rank 3)
        [7322] = 0, -- Frostbolt (Rank 4)
        [8406] = 0, -- Frostbolt (Rank 5)
        [8407] = 0, -- Frostbolt (Rank 6)
        [8408] = 0, -- Frostbolt (Rank 7)
        [10179] = 0, -- Frostbolt (Rank 8)
        [10180] = 0, -- Frostbolt (Rank 9)
        [10181] = 0, -- Frostbolt (Rank 10)
        [25304] = 0, -- Frostbolt (Rank 11)
        [27071] = 0, -- Frostbolt (Rank 12)
        [27072] = 0, -- Frostbolt (Rank 13)
        [38697] = 0, -- Frostbolt (Rank 14)
        [42841] = 0, -- Frostbolt (Rank 15)
        [42842] = 0, -- Frostbolt (Rank 16)
        [120] = 0, -- Cone of Cold (Rank 1)
        [8492] = 0, -- Cone of Cold (Rank 2)
        [10159] = 0, -- Cone of Cold (Rank 3)
        [10160] = 0, -- Cone of Cold (Rank 4)
        [10161] = 0, -- Cone of Cold (Rank 5)
        [27087] = 0, -- Cone of Cold (Rank 6)
        [42930] = 0, -- Cone of Cold (Rank 7)
        [42931] = 0, -- Cone of Cold (Rank 8)
        [6136] = 0, -- Chilled (Rank 1)
        [11113] = 0, -- Blast Wave (Rank 1)
        [13018] = 0, -- Blast Wave (Rank 2)
        [13019] = 0, -- Blast Wave (Rank 3)
        [13020] = 0, -- Blast Wave (Rank 4)
        [13021] = 0, -- Blast Wave (Rank 5)
        [27133] = 0, -- Blast Wave (Rank 6)
        [33933] = 0, -- Blast Wave (Rank 7)
        [42944] = 0, -- Blast Wave (Rank 8)
        [42945] = 0, -- Blast Wave (Rank 9)
        [50271] = 0, -- Tendon Rip (Rank 1)
        [53571] = 0, -- Tendon Rip (Rank 2)
        [53572] = 0, -- Tendon Rip (Rank 3)
        [53573] = 0, -- Tendon Rip (Rank 4)
        [53574] = 0, -- Tendon Rip (Rank 5)
        [53575] = 0, -- Tendon Rip (Rank 6)
        [54644] = 0, -- Froststorm Breath (Rank 1)
        [55488] = 0, -- Froststorm Breath (Rank 2)
        [55489] = 0, -- Froststorm Breath (Rank 3)
        [55490] = 0, -- Froststorm Breath (Rank 4)
        [55491] = 0, -- Froststorm Breath (Rank 5)
        [55492] = 0, -- Froststorm Breath (Rank 6)
        [2974] = 0, -- Wing Clip
        [61394] = 0, -- Glyph of Freezing Trap
        [13810] = 0, -- Frost Trap Aura
        [5116] = 0, -- Concussive Shot
        [35101] = 0, -- Concussive Barrage
        [61391] = 0, -- Typhoon (Rank 1)
        [53227] = 0, -- Typhoon (Rank 5)
        [61387] = 0, -- Typhoon (Rank 4)
        [61388] = 0, -- Typhoon (Rank 3)
        [61390] = 0, -- Typhoon (Rank 2)
        [58179] = 0, -- Infected Wounds
        [58180] = 0, -- Infected Wounds
        [58181] = 0, -- Infected Wounds
        [50040] = 0, -- Chilblains (Rank 1)
        [55666] = 0, -- Desecration (Rank 1)
        [45524] = 0, -- Chains of Ice
    }
end


local defaults = {
    classIconMode = "SPEC",
    classIconGloss = false,
    classIconGlossColor = { r = 1, g = 1, b = 1, a = 0.4 },
    classIconImportantAuras = true,
    classIconCrop = true,
    classIconCooldown = true,
    classIconCooldownReverse = true,
    classIconAuras = GetDefaultImportantAuras()
}

ClassIcon = GladiusEx:NewGladiusExModule("ClassIcon",
    fn.merge(defaults, {
        classIconPosition = "LEFT",
    }),
    fn.merge(defaults, {
        classIconPosition = "RIGHT",
    }))

-- Migrate saved name overrides before AceDB fills in the new numeric defaults.
-- Keep user-created name rules and explicit IDs, including false deletion markers.
function ClassIcon:OnInitialize()
    local namespaces = GladiusEx.dbi.sv.namespaces or {}
    for _, namespace in ipairs({"ClassIcon", "party_ClassIcon"}) do
        local saved = namespaces[namespace]
        for _, profile in pairs(saved and saved.profiles or {}) do
            if not profile.classIconAurasUseIDs then
                local auras = profile.classIconAuras
                if auras then
                    for id in pairs(self.defaults_arena.classIconAuras) do
                        local name = GetSpellInfo(id)
                        if name and auras[name] ~= nil and auras[id] == nil then
                            auras[id] = auras[name]
                        end
                    end
                end
                profile.classIconAurasUseIDs = true
            end
        end
    end
    self.super.OnInitialize(self)
    self.dbi_arena.profile.classIconAurasUseIDs = true
    self.dbi_party.profile.classIconAurasUseIDs = true
end

function ClassIcon:OnProfileChanged(event, database)
    self.super.OnProfileChanged(self)
    if database then database.profile.classIconAurasUseIDs = true end
end

function ClassIcon:OnEnable()
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("UNIT_PORTRAIT_UPDATE", "UNIT_AURA")
    self:RegisterEvent("UNIT_MODEL_CHANGED")
    self:RegisterMessage("GLADIUSEX_SPEC_UPDATE", "UNIT_AURA")
    self:RegisterMessage("GLADIUSEX_INTERRUPT", "UNIT_AURA")

    if not self.frame then
        self.frame = {}
    end
end

function ClassIcon:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()

    for unit in pairs(self.frame) do
        self.frame[unit].priority = nil
        self.frame[unit].expires = nil
        self.frame[unit]:Hide()
    end

end

function ClassIcon:GetAttachType(unit)
    return "InFrame"
end

function ClassIcon:GetAttachPoint(unit)
    return self.db[unit].classIconPosition
end

function ClassIcon:GetAttachSize(unit)
    return GladiusEx:GetBarsHeight(unit)
end

function ClassIcon:GetModuleAttachPoints()
    return {
        ["ClassIcon"] = L["ClassIcon"],
    }
end

function ClassIcon:GetModuleAttachFrame(unit)
    if not self.frame[unit] then
        self:CreateFrame(unit)
    end

    return self.frame[unit]
end

function ClassIcon:UNIT_AURA(event, unit)
    if not self.frame[unit] or not self.frame[unit]:IsShown() then  return end
    -- important auras
    self:UpdateAura(unit)

end

function ClassIcon:UNIT_MODEL_CHANGED(event,unit)
    if not self.frame[unit] then return end

    -- force model update
    if self.frame[unit].portrait3d then
        self.frame[unit].portrait3d.guid = false
    end

    self:UpdateAura(unit)
end

function ClassIcon:handle_aura(unit, name, best_priority, spellid)
    local prio = self:GetImportantAura(unit, name, spellid)
        
    if prio and prio > 0 and prio >= best_priority then
        return true, prio
    else
        return false, nil
    end
end

function ClassIcon:ScanAuras(unit)
    local best_priority = 0
    local best_name, best_icon, best_duration, best_expires
    local t = GetTime()

    -- debuffs
    for index = 1, 40 do
        local name,_, icon, _, _, duration, expires, _, _, _, spellid = UnitAura(unit, index, "HARMFUL")
        if not name then break end
        local prio = self:GetImportantAura(unit, name, spellid)
        if prio and prio > best_priority or (prio == best_priority and best_expires and expires > best_expires) then
            best_name, best_icon, best_duration, best_expires, best_priority = name, icon, duration, expires, prio
        end
    end

    -- buffs
    for index = 1, 40 do
        local name,_, icon, _, _, duration, expires, _, _, _, spellid = UnitAura(unit, index, "HELPFUL")
        if not name then break end
        local prio = self:GetImportantAura(unit, name, spellid)
        -- V: make sure we have a best_expires before comparing it
        if prio and prio > best_priority or (prio == best_priority and best_expires and expires > best_expires) then
            best_name, best_icon, best_duration, best_expires, best_priority = name, icon, duration, expires, prio
        end
    end
    
    -- interrupts
    local interrupt = GladiusEx:GetModule("InterruptsEx", true)
    if interrupt then
        local name, icon, duration, expires, prio = interrupt:GetInterruptFor(unit)
        if name then
            if prio and prio > best_priority or (prio == best_priority and best_expires and expires > best_expires) then
                best_name, best_icon, best_duration, best_expires, best_priority = name, icon, duration, expires, prio
            end
        end
    end
    
    return best_name, best_icon, best_duration, best_expires
end

function ClassIcon:UpdateAura(unit)
    if not self.frame[unit] or not self.db[unit].classIconImportantAuras then return end

    local name, icon, duration, expires = self:ScanAuras(unit)
    
    if name then
        self:SetAura(unit, name, icon, duration, expires)
    else
        self:SetClassIcon(nil, unit)
    end
end

function ClassIcon:SetAura(unit, name, icon, duration, expires)
    -- don't display the aura if we're already showing the same icon / expiration / duration (this causes a brief "glitch" to appear)
    if self.frame[unit].icon and self.frame[unit].icon == icon and
        ((not self.frame[unit].duration and not duration) or (self.frame[unit].duration and duration and self.frame[unit].duration == duration)) and
        ((not self.frame[unit].expires and not expires) or (self.frame[unit].expires and expires and self.frame[unit].expires == expires)) then
       return 
    end
    
    self.frame[unit].icon = icon
    self.frame[unit].duration = duration
    self.frame[unit].expires = expires
    
    self:SetTexture(unit, icon, true, 0, 1, 0, 1)

    -- display aura
    if self.db[unit].classIconCooldown and duration ~= 0 then
        self.frame[unit].cooldown:SetCooldown(expires - duration, duration)
        self.frame[unit].cooldown:Show()
    else
        self.frame[unit].cooldown:Hide()
    end
end

function ClassIcon:SetTexture(unit, texture, needs_crop, left, right, top, bottom)
    -- so the user wants a border, but the borders in the blizzard icons are
    -- messed up in random ways (some are missing the alpha at the corners, some contain
    -- random blocks of colored pixels there)
    -- so instead of using the border already present in the icons, we crop them and add
    -- our own (this would have been a lot easier if wow allowed alpha mask textures)
    local needs_border = needs_crop and not self.db[unit].classIconCrop
    local size = self:GetAttachSize(unit)
    if needs_border then
        self.frame[unit].texture:ClearAllPoints()
        self.frame[unit].texture:SetPoint("CENTER")
        self.frame[unit].texture:SetWidth(size * (1 - 6 / 64))
        self.frame[unit].texture:SetHeight(size * (1 - 6 / 64))
        self.frame[unit].texture_border:Show()
    else
        self.frame[unit].texture:ClearAllPoints()
        self.frame[unit].texture:SetPoint("CENTER")
        self.frame[unit].texture:SetWidth(size)
        self.frame[unit].texture:SetHeight(size)
        self.frame[unit].texture_border:Hide()
    end


    if needs_crop then
        local n
        if self.db[unit].classIconCrop then n = 5 else n = 3 end
        left = left + (right - left) * (n / 64)
        right = right - (right - left) * (n / 64)
        top = top + (bottom - top) * (n / 64)
        bottom = bottom - (bottom - top) * (n / 64)
    end

    -- set texture
    self.frame[unit].texture:SetTexture(texture)
    self.frame[unit].texture:SetTexCoord(left, right, top, bottom)

    -- hide portrait
    if self.frame[unit].portrait3d then
        self.frame[unit].portrait3d:Hide()
    end
    if self.frame[unit].portrait2d then
        self.frame[unit].portrait2d:Hide()
    end
end

function ClassIcon:SetClassIcon(_, unit)
    if not self.frame[unit] then return end

    -- hide cooldown frame
    self.frame[unit].cooldown:Hide()

    if self.db[unit].classIconMode == "PORTRAIT2D" and (GladiusEx:IsArenaUnit(unit) or not self:IsSpectating()) then
        -- portrait2d
        if not self.frame[unit].portrait2d then
            self.frame[unit].portrait2d = self.frame[unit]:CreateTexture(nil, "OVERLAY")
            self.frame[unit].portrait2d:SetAllPoints()
            local n = 9 / 64
            self.frame[unit].portrait2d:SetTexCoord(n, 1 - n, n, 1 - n)
        end
        if not UnitIsVisible(unit) or not UnitIsConnected(unit) then
            self.frame[unit].portrait2d:Hide()
        else
            SetPortraitTexture(self.frame[unit].portrait2d, unit)
            self.frame[unit].portrait2d:Show()
            if self.frame[unit].portrait3d then
                self.frame[unit].portrait3d:Hide()
            end
            self.frame[unit].texture:SetTexture(0, 0, 0, 1)
            return
        end
    elseif self.db[unit].classIconMode == "PORTRAIT3D" and (GladiusEx:IsArenaUnit(unit) or not self:IsSpectating()) then
        -- portrait3d
        local zoom = 1.0
        if not self.frame[unit].portrait3d then
            self.frame[unit].portrait3d = CreateFrame("PlayerModel", nil, self.frame[unit])
            self.frame[unit].portrait3d:SetAllPoints()
            self.frame[unit].portrait3d:SetScript("OnShow", function(f) f:SetPortraitZoom(zoom) end)
            self.frame[unit].portrait3d:SetScript("OnHide", function(f) f.guid = nil end)
        end
        if not UnitIsVisible(unit) or not UnitIsConnected(unit) then
            self.frame[unit].portrait3d:Hide()
        else
            local guid = UnitGUID(unit)
            if self.frame[unit].portrait3d.guid ~= guid then
                self.frame[unit].portrait3d.guid = guid
                self.frame[unit].portrait3d:SetUnit(unit)
                self.frame[unit].portrait3d:SetPortraitZoom(zoom)
                self.frame[unit].portrait3d:SetPosition(0, 0, 0)
            end
            self.frame[unit].portrait3d:Show()
            self.frame[unit].texture:SetTexture(0, 0, 0, 1)
            if self.frame[unit].portrait2d then
                self.frame[unit].portrait2d:Hide()
            end
            return
        end
    end

    -- get unit class
    local class, specID

    if not GladiusEx:IsTesting(unit) or GladiusEx:IsSpectating() then
        class = UnitExists(unit) and select(2, UnitClass(unit)) or nil
        
        -- check for arena prep info
        if not class then
            class = GladiusEx.buttons[unit].class
        end
        specID = GladiusEx.buttons[unit].specID
    else
        class = GladiusEx.testing[unit].unitClass
        specID = GladiusEx.testing[unit].specID
    end

    local texture
    local left, right, top, bottom
    local needs_crop

    if not class then
        texture = [[Interface\Icons\INV_Misc_QuestionMark]]
        left, right, top, bottom = 0, 1, 0, 1
        needs_crop = true
    elseif self.db[unit].classIconMode == "SPEC" and specID then
        texture = GladiusEx.Data.SPECIALIZATION_ICONS[specID]
        left, right, top, bottom = 0, 1, 0, 1
        needs_crop = true
    else
        texture = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
        left, right, top, bottom = unpack(CLASS_BUTTONS[class])
        needs_crop = true
    end

    self:SetTexture(unit, texture, needs_crop, left, right, top, bottom)
end

function ClassIcon:CreateFrame(unit)
    local button = GladiusEx.buttons[unit]
    if (not button) then return end

    -- create frame
    self.frame[unit] = CreateFrame("CheckButton", "GladiusEx" .. self:GetName() .. "Frame" .. unit, button, "ActionButtonTemplate")
    self.frame[unit]:EnableMouse(false)
    self.frame[unit].texture = _G[self.frame[unit]:GetName().."Icon"]
    self.frame[unit].normalTexture = _G[self.frame[unit]:GetName().."NormalTexture"]
    self.frame[unit].cooldown = _G[self.frame[unit]:GetName().."Cooldown"]
    self.frame[unit].texture_border = self.frame[unit]:CreateTexture(nil, "BACKGROUND", nil, -1)
    self.frame[unit].texture_border:SetTexture([[Interface\AddOns\GladiusEx\media\icon_border]])
    self.frame[unit].texture_border:SetAllPoints()
end

function ClassIcon:Update(unit)
    -- create frame
    if not self.frame[unit] then
        self:CreateFrame(unit)
    end

    -- style action button
    self.frame[unit].normalTexture:SetHeight(self.frame[unit]:GetHeight() + self.frame[unit]:GetHeight() * 0.4)
    self.frame[unit].normalTexture:SetWidth(self.frame[unit]:GetWidth() + self.frame[unit]:GetWidth() * 0.4)

    self.frame[unit].normalTexture:ClearAllPoints()
    self.frame[unit].normalTexture:SetPoint("CENTER")
    self.frame[unit]:SetNormalTexture([[Interface\AddOns\GladiusEx\media\gloss]])

    self.frame[unit].texture:ClearAllPoints()
    self.frame[unit].texture:SetPoint("TOPLEFT", self.frame[unit], "TOPLEFT")
    self.frame[unit].texture:SetPoint("BOTTOMRIGHT", self.frame[unit], "BOTTOMRIGHT")

    self.frame[unit].normalTexture:SetVertexColor(self.db[unit].classIconGlossColor.r, self.db[unit].classIconGlossColor.g,
        self.db[unit].classIconGlossColor.b, self.db[unit].classIconGloss and self.db[unit].classIconGlossColor.a or 0)

    self.frame[unit].cooldown:SetReverse(self.db[unit].classIconCooldownReverse)

    -- hide
    self.frame[unit]:Hide()
end

function ClassIcon:Refresh(unit)
    self:UpdateAura(unit)
end

function ClassIcon:Show(unit)
    -- show frame
    self.frame[unit]:Show()

    -- set class icon
    self:UpdateAura(unit)
end

function ClassIcon:Reset(unit)
    if not self.frame[unit] then return end

    -- hide
    self.frame[unit].priority = nil
    self.frame[unit].expires = nil
    self.frame[unit]:Hide() 
end

function ClassIcon:Test(unit)
end

function ClassIcon:GetImportantAura(unit, name, spellid)
    local auras = self.db[unit].classIconAuras
    local priority = spellid and auras[spellid]
    -- Exact IDs override names, including priority 0. A deleted ID rule (false)
    -- falls back to the name; keep false values in the profile for AceDB.
    if type(priority) == "number" then return priority end
    return auras[name]
end

local function AuraOptionKey(aura)
    -- AceConfig requires string keys; keep numeric IDs distinct from saved names
    -- and from the newAura controls, without changing the profile's keys.
    return GladiusEx:SpellRuleKey(aura)
end

function ClassIcon:GetOptions(unit)
    local options
    options = {
        general = {
            type = "group",
            name = L["General"],
            order = 1,
            args = {
                widget = {
                    type = "group",
                    name = L["Widget"],
                    desc = L["Widget settings"],
                    inline = true,
                    order = 1,
                    args = {
                        classIconMode = {
                            type = "select",
                            name = L["Show"],
                            values = {
                                ["CLASS"] = L["Class"],
                                ["SPEC"] = L["Spec"],
                                ["PORTRAIT2D"] = L["Portrait 2D"],
                                ["PORTRAIT3D"] = L["Portrait 3D"],
                            },
                            desc = L["When available, show specialization instead of class icons"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 3,
                        },
                        sep = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 4,
                        },
                        classIconImportantAuras = {
                            type = "toggle",
                            name = L["Important auras"],
                            desc = L["Show important auras instead of the class icon"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 5,
                        },
                        classIconCrop = {
                            type = "toggle",
                            name = L["Crop borders"],
                            desc = L["Toggle if the icon borders should be cropped or not"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 6,
                        },
                        sep2 = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 7,
                        },
                        classIconCooldown = {
                            type = "toggle",
                            name = L["Cooldown spiral"],
                            desc = L["Display the cooldown spiral for the important auras"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 10,
                        },
                        classIconCooldownReverse = {
                            type = "toggle",
                            name = L["Cooldown reverse"],
                            desc = L["Invert the dark/bright part of the cooldown spiral"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 15,
                        },
                        sep3 = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 17,
                        },
                        classIconGloss = {
                            type = "toggle",
                            name = L["Gloss"],
                            desc = L["Toggle gloss on the icon"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 20,
                        },
                        classIconGlossColor = {
                            type = "color",
                            name = L["Gloss color"],
                            desc = L["Color of the gloss"],
                            get = function(info) return GladiusEx:GetColorOption(self.db[unit], info) end,
                            set = function(info, r, g, b, a) return GladiusEx:SetColorOption(self.db[unit], info, r, g, b, a) end,
                            hasAlpha = true,
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 25,
                        },
                    },
                },
                position = {
                    type = "group",
                    name = L["Position"],
                    desc = L["Position settings"],
                    inline = true,
                    order = 3,
                    args = {
                        classIconPosition = {
                            type = "select",
                            name = L["Position"],
                            desc = L["Position of the frame"],
                            values = { ["LEFT"] = L["Left"], ["RIGHT"] = L["Right"] },
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 1,
                        },
                    },
                },
            },
        },
        auraList = {
            type = "group",
            name = L["Important auras"],
            childGroups = "tree",
            order = 3,
            args = {
                matching = {
                    type = "description",
                    name = L["Names match all ranks and effects with that name. Numeric IDs match only that exact spell and override name rules. Priority 0 hides the matching aura. Deleting an ID rule restores name matching."],
                    order = 0,
                },
                newAura = {
                    type = "group",
                    name = L["New aura"],
                    desc = L["New aura"],
                    inline = true,
                    order = 1,
                    args = {
                        priority = {
                            type= "range",
                            name = L["Priority"],
                            desc = L["Select what priority the aura should have - higher equals more priority"],
                            get = function() return self.newAuraPriority or "" end,
                            set = function(info, value) self.newAuraPriority = value end,
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            min = 0,
                            max = 10,
                            step = 0.1,
                            order = 2,
                        },
                        add = {
                            type = "execute",
                            name = L["Add new aura"],
                            order = 3,
                        },
                    },
                },
            },
        },
    }

    -- set some initial value for the auras priority
    self.newAuraPriority = 5

    -- setup auras
    for aura, priority in pairs(self.db[unit].classIconAuras) do
        if priority then
            options.auraList.args[AuraOptionKey(aura)] = self:SetupAuraOptions(options, unit, aura)
        end
    end

    GladiusEx:ConfigureNewSpellRule(self, unit, "classIconAuras", options.auraList.args,
        options.auraList.args.newAura.args,
        function() return self.newAuraPriority end,
        function(aura) return self:SetupAuraOptions(options, unit, aura) end,
        function() return not self:IsUnitEnabled(unit) end)
    return options
end

function ClassIcon:SetupAuraOptions(options, unit, aura)
    local group = {
        type = "group", name = tostring(aura),
        disabled = function() return not self:IsUnitEnabled(unit) end,
        args = {
            priority = {
                type = "range", name = L["Priority"],
                desc = L["Select what priority the aura should have - higher equals more priority"],
                min = 0, softMax = 10, step = 0.1, order = 2,
                get = function() return self.db[unit].classIconAuras[aura] end,
                set = function(info, value)
                    self.db[unit].classIconAuras[aura] = value
                    GladiusEx:UpdateFrames()
                end,
            },
            delete = {type = "execute", name = L["Delete"], order = 3},
        },
    }
    return GladiusEx:ConfigureSpellRule(self, unit, "classIconAuras", options.auraList.args,
        aura, group, function(key) return self:SetupAuraOptions(options, unit, key) end,
        function() return not self:IsUnitEnabled(unit) end)
end
