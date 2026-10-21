-- handling for TBC on the 3.3.5 client
if GetAccountExpansionLevel() ~= 2 then return end

-- ================ HUNTER ================

local SPEC_HUNTER_BM   = 253
local SPEC_HUNTER_MM   = 254
local SPEC_HUNTER_SURV = 255

-- Distracting Shot
LCT_SpellData[20736] = {
  class = "HUNTER",
  cooldown = 8,
}
LCT_SpellData[15629] = 20736
LCT_SpellData[15630] = 20736
LCT_SpellData[15631] = 20736
LCT_SpellData[15632] = 20736
LCT_SpellData[27020] = 20736
LCT_SpellData[14274] = 20736

-- Flare
LCT_SpellData[1543] = {
  class = "HUNTER",
  cooldown = 20,
}

-- Feign Death
LCT_SpellData[5384] = {
  class = "HUNTER",
  cooldown = 30,
}

-- Disengage
LCT_SpellData[781] = {
  class = "HUNTER",
  cooldown = 25,
}
LCT_SpellData[27015] = 781
LCT_SpellData[14272] = 781
LCT_SpellData[14273] = 781

-- Scatter Shot
LCT_SpellData[19503] = {
  class = "HUNTER",
  cooldown = 30,
  talent = true,
  specID = { SPEC_HUNTER_BM, SPEC_HUNTER_MM, SPEC_HUNTER_SURV },
  talentSpecID = SPEC_HUNTER_SURV,
}

-- Dash
LCT_SpellData[61684] = {
  class = "HUNTER",
  pet = true,
  cooldown = 32,
}

-- Deterrence
LCT_SpellData[19263] = {
  class = "HUNTER",
  cooldown = 90,
}

-- Scorpid Poison
LCT_SpellData[24640] = {
  class = "HUNTER",
  cooldown = 10,
  pet = true,
}
LCT_SpellData[24583] = 24640
LCT_SpellData[24586] = 24640
LCT_SpellData[27060] = 24640
LCT_SpellData[24587] = 24640
LCT_SpellData[55728] = 24640

-- Tranquilizing Shot
LCT_SpellData[19801] = {
  class = "HUNTER",
  cooldown = 8,
}

-- Aimed Shot
LCT_SpellData[19434] = {
  class = "HUNTER",
  cooldown = 10,
  talent = true,
  talentSpecID = SPEC_HUNTER_MM,
  specID = { SPEC_HUNTER_BM, SPEC_HUNTER_MM, SPEC_HUNTER_SURV },
}
LCT_SpellData[20900] = 19434
LCT_SpellData[20902] = 19434
LCT_SpellData[20903] = 19434
LCT_SpellData[20904] = 19434
LCT_SpellData[27065] = 19434
LCT_SpellData[20901] = 19434
LCT_SpellData[49049] = 19434
LCT_SpellData[49050] = 19434

-- Dive
LCT_SpellData[23145] = {
  class = "HUNTER",
  cooldown = 32,
  pet = true,
}

-- Poison Spit
LCT_SpellData[35387] = {
  class = "HUNTER",
  cooldown = 10,
  pet = true,
}
LCT_SpellData[35389] = 35387
LCT_SpellData[35392] = 35387
LCT_SpellData[55555] = 35387
LCT_SpellData[55556] = 35387
LCT_SpellData[55557] = 35387

-- Arcane Shot
LCT_SpellData[3044] = {
  class = "HUNTER",
  cooldown = 6,
  opt_lower_cooldown = 5,
  cooldown_overload = { [SPEC_HUNTER_MM] = 5, },
}
LCT_SpellData[27019] = 3044
LCT_SpellData[14285] = 3044
LCT_SpellData[14283] = 3044
LCT_SpellData[14282] = 3044
LCT_SpellData[14281] = 3044
LCT_SpellData[14284] = 3044
LCT_SpellData[14286] = 3044
LCT_SpellData[14287] = 3044
LCT_SpellData[49044] = 3044
LCT_SpellData[49045] = 3044

-- Bestial Wrath
LCT_SpellData[19574] = {
  class = "HUNTER",
  cooldown = 120,
  talent = true,
  specID = { SPEC_HUNTER_BM, SPEC_HUNTER_MM, SPEC_HUNTER_SURV },
  talentSpecID = SPEC_HUNTER_BM,
}

-- Intimidation
LCT_SpellData[19577] = {
  class = "HUNTER",
  cooldown = 60,
  talent = true,
  specID = { SPEC_HUNTER_BM, SPEC_HUNTER_MM, SPEC_HUNTER_SURV },
  talentSpecID = SPEC_HUNTER_BM,
}

-- Prowl
LCT_SpellData[24450] = {
  class = "HUNTER",
  cooldown = 10,
  pet = true,
}
LCT_SpellData[24452] = 24450
LCT_SpellData[24453] = 24450

-- Raptor Strike
LCT_SpellData[2973] = {
  class = "HUNTER",
  cooldown = 6,
}
LCT_SpellData[27014] = 2973
LCT_SpellData[14266] = 2973
LCT_SpellData[14261] = 2973
LCT_SpellData[14262] = 2973
LCT_SpellData[14260] = 2973
LCT_SpellData[14263] = 2973
LCT_SpellData[14264] = 2973
LCT_SpellData[14265] = 2973
LCT_SpellData[48995] = 2973
LCT_SpellData[48996] = 2973

-- Concussive Shot
LCT_SpellData[5116] = {
  opt_lower_cooldown = 11,
  class = "HUNTER",
  cooldown = 12,
}

-- Counterattack
LCT_SpellData[19306] = {
  class = "HUNTER",
  cooldown = 5,
  talent = true,
  talentSpecID = SPEC_HUNTER_SURV,
  specID = { SPEC_HUNTER_BM, SPEC_HUNTER_MM, SPEC_HUNTER_SURV },
}
LCT_SpellData[20909] = 19306
LCT_SpellData[20910] = 19306
LCT_SpellData[27067] = 19306
LCT_SpellData[48998] = 19306
LCT_SpellData[48999] = 19306

-- Wyvern Sting
LCT_SpellData[19386] = {
  class = "HUNTER",
  cooldown = 60,
  talent = true,
  specID = { SPEC_HUNTER_BM, SPEC_HUNTER_MM, SPEC_HUNTER_SURV },
  talentSpecID = SPEC_HUNTER_SURV,
}
LCT_SpellData[24132] = 19386
LCT_SpellData[24133] = 19386
LCT_SpellData[27068] = 19386
LCT_SpellData[49011] = 19386
LCT_SpellData[49012] = 19386

-- Snake Trap
LCT_SpellData[34600] = {
  opt_lower_cooldown = 24,
  cooldown_overload = { [SPEC_HUNTER_SURV] = 24, },
  class = "HUNTER",
  cooldown = 30,
}

-- Growl
LCT_SpellData[2649] = {
  class = "HUNTER",
  cooldown = 5,
  pet = true,
}
LCT_SpellData[14918] = 2649
LCT_SpellData[14919] = 2649
LCT_SpellData[14921] = 2649
LCT_SpellData[14916] = 2649
LCT_SpellData[14917] = 2649
LCT_SpellData[27047] = 2649
LCT_SpellData[14920] = 2649
LCT_SpellData[61676] = 2649

-- Misdirection
LCT_SpellData[34477] = {
  class = "HUNTER",
  cooldown = 30,
}

-- Fire Breath
LCT_SpellData[34889] = {
  class = "HUNTER",
  cooldown = 10,
  pet = true,
}
LCT_SpellData[35323] = 34889
LCT_SpellData[55482] = 34889
LCT_SpellData[55483] = 34889
LCT_SpellData[55484] = 34889
LCT_SpellData[55485] = 34889

-- Warp
LCT_SpellData[35346] = {
  class = "HUNTER",
  cooldown = 15,
  pet = true,
}

-- Readiness
LCT_SpellData[23989] = {
  class = "HUNTER",
  cooldown = 180,
  talent = true,
  resets = { 5116, 34026, 53271, 1513, 3044, 20736, 1543, 53351, 2643, 3045, 19801, 3034, 19263, 781, 13813, 5384, 60192, 1499, 13809, 13795, 34477, 1495, 2973, 34600, 19434, 53209, 34490, 19503 },
  specID = { SPEC_HUNTER_BM, SPEC_HUNTER_MM, SPEC_HUNTER_SURV },
  talentSpecID = SPEC_HUNTER_MM,
}

-- Silencing Shot
LCT_SpellData[34490] = {
  class = "HUNTER",
  cooldown = 20,
  talent = true,
  specID = { SPEC_HUNTER_MM },
}

-- Cower
LCT_SpellData[1742] = {
  class = "HUNTER",
  cooldown = 45,
  pet = true,
}

-- Shell Shield
LCT_SpellData[26064] = {
  class = "HUNTER",
  cooldown = 60,
  duration = 12,
  defensive = true,
  pet = true,
}

-- Mongoose Bite
LCT_SpellData[1495] = {
  class = "HUNTER",
  cooldown = 5,
}
LCT_SpellData[14269] = 1495
LCT_SpellData[14270] = 1495
LCT_SpellData[14271] = 1495
LCT_SpellData[36916] = 1495
LCT_SpellData[53339] = 1495

-- Viper Sting
LCT_SpellData[3034] = {
  class = "HUNTER",
  cooldown = 15,
}

-- Freezing Trap
LCT_SpellData[1499] = {
    opt_lower_cooldown = 24,
    cooldown_overload = { [SPEC_HUNTER_SURV] = 24, },
	class = "HUNTER",
    cooldown = 30,
    sets_cooldowns = {
        -- Freezing Arrow
        { spellid = 60192, cooldown = 30 },
        -- Frost Trap
        { spellid = 13809, cooldown = 30 },
    }
}
LCT_SpellData[14310] = 1499
LCT_SpellData[14311] = 1499

-- Pummel
LCT_SpellData[26090] = {
  class = "HUNTER",
  cooldown = 30,
  pet = true,
}

-- Immolation Trap
LCT_SpellData[13795] = {
  opt_lower_cooldown = 24,
  cooldown_overload = { [SPEC_HUNTER_SURV] = 24, },
  class = "HUNTER",
  cooldown = 30,
}
LCT_SpellData[27023] = 13795
LCT_SpellData[14302] = 13795
LCT_SpellData[14303] = 13795
LCT_SpellData[14304] = 13795
LCT_SpellData[14305] = 13795
LCT_SpellData[49055] = 13795
LCT_SpellData[49056] = 13795

-- Rapid Fire
LCT_SpellData[3045] = {
  opt_lower_cooldown = 180, -- AQ set
  class = "HUNTER",
  cooldown = 300,
}
-- Volley
LCT_SpellData[1510] = {
  class = "HUNTER",
  cooldown = 60,
}
LCT_SpellData[27022] = 1510
LCT_SpellData[14294] = 1510
LCT_SpellData[14295] = 1510
LCT_SpellData[58431] = 1510
LCT_SpellData[58434] = 1510

-- Scare Beast
LCT_SpellData[1513] = {
  class = "HUNTER",
  cooldown = 30,
}
LCT_SpellData[14326] = 1513
LCT_SpellData[14327] = 1513

-- Kill Command
LCT_SpellData[34026] = {
  class = "HUNTER",
  cooldown = 60,
}

-- Furious Howl
LCT_SpellData[24604] = {
  class = "HUNTER",
  cooldown = 40,
  pet = true,
}
LCT_SpellData[64491] = 24604
LCT_SpellData[64492] = 24604
LCT_SpellData[64493] = 24604
LCT_SpellData[64494] = 24604
LCT_SpellData[64495] = 24604

-- Frost Trap
LCT_SpellData[13809] = {
  opt_lower_cooldown = 24,
  cooldown_overload = { [SPEC_HUNTER_SURV] = 24, },
  class = "HUNTER",
  cooldown = 30,
	sets_cooldowns = {
        -- Freezing Trap
        { spellid = 1499, cooldown = 30 },
        -- Freezing Arrow
        { spellid = 60192, cooldown = 30 },
	}
}

-- Explosive Trap
LCT_SpellData[13813] = {
  opt_lower_cooldown = 24,
  cooldown_overload = { [SPEC_HUNTER_SURV] = 24, },
  class = "HUNTER",
  cooldown = 30,
}
LCT_SpellData[27025] = 13813
LCT_SpellData[14316] = 13813
LCT_SpellData[14317] = 13813
LCT_SpellData[49066] = 13813
LCT_SpellData[49067] = 13813

-- Multi-Shot
LCT_SpellData[2643] = {
  class = "HUNTER",
  cooldown = 10,
}
LCT_SpellData[27021] = 2643
LCT_SpellData[25294] = 2643
LCT_SpellData[14288] = 2643
LCT_SpellData[14289] = 2643
LCT_SpellData[14290] = 2643 
LCT_SpellData[49047] = 2643 
LCT_SpellData[49048] = 2643 

-- Chimera Shot
LCT_SpellData[53209] = {
  class = "HUNTER",
  cooldown = 10,
  talent = true,
  specID = { SPEC_HUNTER_MM },
}

-- Black Arrow
LCT_SpellData[3674] = {
  class = "HUNTER",
  cooldown = 30,
  talent = true,
  specID = { SPEC_HUNTER_SURV },
}

-- Explosive Shot
LCT_SpellData[53301] = {
  class = "HUNTER",
  cooldown = 6,
  talent = true,
  detects = { 3674 },
  specID = { SPEC_HUNTER_SURV },
}

-- Master's Call
LCT_SpellData[53271] = {
  class = "HUNTER",
  cooldown = 60,
}

-- Freezing Arrow
LCT_SpellData[60192] = {
  class = "HUNTER",
  cooldown = 30,
	sets_cooldowns = {
        -- Freezing Trap
        { spellid = 1499, cooldown = 30 },
        -- Frost Trap
        { spellid = 13809, cooldown = 30 },
	}
}

-- Roar of Sacrifice
LCT_SpellData[53480] = {
  class = "HUNTER",
  cooldown = 60,
  pet = true,
}

-- Bullheaded
LCT_SpellData[53490] = {
  class = "HUNTER",
  cooldown = 180,
  pet = true,
}

-- Intervene
LCT_SpellData[53476] = {
  class = "HUNTER",
  cooldown = 30,
  -- opt_cooldown = 21 Note: This is only applicable for BM, and BM doesn't use Intervene
  pet = true,
}

-- Additional pet cooldowns (original 3.3.5a Spell/SkillLineAbility data).

-- Acid Spit
LCT_SpellData[55749] = {
  class = "HUNTER",
  cooldown = 10,
  pet = true,
  duration = 30,
  specID = { SPEC_HUNTER_BM },
}
LCT_SpellData[55750] = 55749
LCT_SpellData[55751] = 55749
LCT_SpellData[55752] = 55749
LCT_SpellData[55753] = 55749
LCT_SpellData[55754] = 55749

-- Bad Attitude
LCT_SpellData[50433] = {
  class = "HUNTER",
  cooldown = 120,
  pet = true,
  duration = 45,
  offensive = true,
}
LCT_SpellData[52395] = 50433
LCT_SpellData[52396] = 50433
LCT_SpellData[52397] = 50433
LCT_SpellData[52398] = 50433
LCT_SpellData[52399] = 50433

-- Call of the Wild
LCT_SpellData[53434] = {
  class = "HUNTER",
  cooldown = 300,
  pet = true,
  duration = 20,
  offensive = true,
}

-- Carrion Feeder
LCT_SpellData[54044] = {
  class = "HUNTER",
  cooldown = 30,
  pet = true,
  heal = true,
}

-- Charge
LCT_SpellData[61685] = {
  class = "HUNTER",
  cooldown = 25,
  pet = true,
  duration = 1,
}

-- Demoralizing Screech
LCT_SpellData[24423] = {
  class = "HUNTER",
  cooldown = 10,
  pet = true,
  duration = 10,
}
LCT_SpellData[24577] = 24423
LCT_SpellData[24578] = 24423
LCT_SpellData[24579] = 24423
LCT_SpellData[27051] = 24423
LCT_SpellData[55487] = 24423

-- Dust Cloud
LCT_SpellData[50285] = {
  class = "HUNTER",
  cooldown = 40,
  pet = true,
  duration = 8,
}

-- Froststorm Breath
LCT_SpellData[54644] = {
  class = "HUNTER",
  cooldown = 10,
  pet = true,
  duration = 5,
  specID = { SPEC_HUNTER_BM },
}
LCT_SpellData[55488] = 54644
LCT_SpellData[55489] = 54644
LCT_SpellData[55490] = 54644
LCT_SpellData[55491] = 54644
LCT_SpellData[55492] = 54644

-- Gore
LCT_SpellData[35290] = {
  class = "HUNTER",
  cooldown = 10,
  pet = true,
}
LCT_SpellData[35291] = 35290
LCT_SpellData[35292] = 35290
LCT_SpellData[35293] = 35290
LCT_SpellData[35294] = 35290
LCT_SpellData[35295] = 35290

-- Heart of the Phoenix
LCT_SpellData[55709] = {
  class = "HUNTER",
  cooldown = 480,
  pet = true,
  heal = true,
}

-- Last Stand
LCT_SpellData[53478] = {
  class = "HUNTER",
  cooldown = 360,
  pet = true,
  duration = 20,
  defensive = true,
}

-- Lava Breath
LCT_SpellData[58604] = {
  class = "HUNTER",
  cooldown = 10,
  pet = true,
  duration = 10,
  specID = { SPEC_HUNTER_BM },
}
LCT_SpellData[58607] = 58604
LCT_SpellData[58608] = 58604
LCT_SpellData[58609] = 58604
LCT_SpellData[58610] = 58604
LCT_SpellData[58611] = 58604

-- Lick Your Wounds
LCT_SpellData[53426] = {
  class = "HUNTER",
  cooldown = 180,
  pet = true,
  duration = 5,
  heal = true,
}

-- Lightning Breath
LCT_SpellData[24844] = {
  class = "HUNTER",
  cooldown = 10,
  pet = true,
}
LCT_SpellData[25008] = 24844
LCT_SpellData[25009] = 24844
LCT_SpellData[25010] = 24844
LCT_SpellData[25011] = 24844
LCT_SpellData[25012] = 24844

-- Monstrous Bite
LCT_SpellData[54680] = {
  class = "HUNTER",
  cooldown = 10,
  pet = true,
  specID = { SPEC_HUNTER_BM },
}
LCT_SpellData[55495] = 54680
LCT_SpellData[55496] = 54680
LCT_SpellData[55497] = 54680
LCT_SpellData[55498] = 54680
LCT_SpellData[55499] = 54680

-- Nether Shock
LCT_SpellData[50479] = {
  class = "HUNTER",
  cooldown = 40,
  duration = 2,
  interrupt = true,
  pet = true,
}
LCT_SpellData[53584] = 50479
LCT_SpellData[53586] = 50479
LCT_SpellData[53587] = 50479
LCT_SpellData[53588] = 50479
LCT_SpellData[53589] = 50479

-- Pin
LCT_SpellData[50245] = {
  class = "HUNTER",
  cooldown = 40,
  pet = true,
  duration = 4,
  cc = true,
}
LCT_SpellData[53544] = 50245
LCT_SpellData[53545] = 50245
LCT_SpellData[53546] = 50245
LCT_SpellData[53547] = 50245
LCT_SpellData[53548] = 50245

-- Rabid
LCT_SpellData[53401] = {
  class = "HUNTER",
  cooldown = 45,
  pet = true,
  duration = 20,
  offensive = true,
}

-- Rake
LCT_SpellData[59881] = {
  class = "HUNTER",
  cooldown = 10,
  pet = true,
  duration = 9,
}
LCT_SpellData[59882] = 59881
LCT_SpellData[59883] = 59881
LCT_SpellData[59884] = 59881
LCT_SpellData[59885] = 59881
LCT_SpellData[59886] = 59881

-- Ravage
LCT_SpellData[50518] = {
  class = "HUNTER",
  cooldown = 40,
  pet = true,
  duration = 2,
  stun = true,
}
LCT_SpellData[53558] = 50518
LCT_SpellData[53559] = 50518
LCT_SpellData[53560] = 50518
LCT_SpellData[53561] = 50518
LCT_SpellData[53562] = 50518

-- Roar of Recovery
LCT_SpellData[53517] = {
  class = "HUNTER",
  cooldown = 180,
  pet = true,
  duration = 9,
  defensive = true,
}

-- Savage Rend
LCT_SpellData[50498] = {
  class = "HUNTER",
  cooldown = 60,
  pet = true,
  duration = 15,
}
LCT_SpellData[53578] = 50498
LCT_SpellData[53579] = 50498
LCT_SpellData[53580] = 50498
LCT_SpellData[53581] = 50498
LCT_SpellData[53582] = 50498

-- Serenity Dust
LCT_SpellData[50318] = {
  class = "HUNTER",
  cooldown = 60,
  pet = true,
  duration = 15,
  offensive = true,
}
LCT_SpellData[52012] = 50318
LCT_SpellData[52013] = 50318
LCT_SpellData[52014] = 50318
LCT_SpellData[52015] = 50318
LCT_SpellData[52016] = 50318

-- Snatch
LCT_SpellData[50541] = {
  class = "HUNTER",
  cooldown = 60,
  pet = true,
  duration = 6,
}
LCT_SpellData[53537] = 50541
LCT_SpellData[53538] = 50541
LCT_SpellData[53540] = 50541
LCT_SpellData[53542] = 50541
LCT_SpellData[53543] = 50541

-- Sonic Blast
LCT_SpellData[50519] = {
  class = "HUNTER",
  cooldown = 60,
  pet = true,
  duration = 2,
  stun = true,
}
LCT_SpellData[53564] = 50519
LCT_SpellData[53565] = 50519
LCT_SpellData[53566] = 50519
LCT_SpellData[53567] = 50519
LCT_SpellData[53568] = 50519

-- Spirit Strike
LCT_SpellData[61193] = {
  class = "HUNTER",
  cooldown = 10,
  pet = true,
  duration = 6,
  specID = { SPEC_HUNTER_BM },
}
LCT_SpellData[61194] = 61193
LCT_SpellData[61195] = 61193
LCT_SpellData[61196] = 61193
LCT_SpellData[61197] = 61193
LCT_SpellData[61198] = 61193

-- Spore Cloud
LCT_SpellData[50274] = {
  class = "HUNTER",
  cooldown = 10,
  pet = true,
  duration = 9,
}
LCT_SpellData[53593] = 50274
LCT_SpellData[53594] = 50274
LCT_SpellData[53596] = 50274
LCT_SpellData[53597] = 50274
LCT_SpellData[53598] = 50274

-- Stampede
LCT_SpellData[57386] = {
  class = "HUNTER",
  cooldown = 60,
  pet = true,
  duration = 60,
  specID = { SPEC_HUNTER_BM },
}
LCT_SpellData[57389] = 57386
LCT_SpellData[57390] = 57386
LCT_SpellData[57391] = 57386
LCT_SpellData[57392] = 57386
LCT_SpellData[57393] = 57386

-- Sting
LCT_SpellData[56626] = {
  class = "HUNTER",
  cooldown = 6,
  pet = true,
  duration = 20,
}
LCT_SpellData[56627] = 56626
LCT_SpellData[56628] = 56626
LCT_SpellData[56629] = 56626
LCT_SpellData[56630] = 56626
LCT_SpellData[56631] = 56626

-- Swipe
LCT_SpellData[50256] = {
  class = "HUNTER",
  cooldown = 5,
  pet = true,
}
LCT_SpellData[53526] = 50256
LCT_SpellData[53528] = 50256
LCT_SpellData[53529] = 50256
LCT_SpellData[53532] = 50256
LCT_SpellData[53533] = 50256

-- Swoop
LCT_SpellData[52825] = {
  class = "HUNTER",
  cooldown = 25,
  pet = true,
  duration = 1,
}

-- Taunt
LCT_SpellData[53477] = {
  class = "HUNTER",
  cooldown = 180,
  pet = true,
  duration = 3,
}

-- Tendon Rip
LCT_SpellData[50271] = {
  class = "HUNTER",
  cooldown = 20,
  pet = true,
  duration = 6,
}
LCT_SpellData[53571] = 50271
LCT_SpellData[53572] = 50271
LCT_SpellData[53573] = 50271
LCT_SpellData[53574] = 50271
LCT_SpellData[53575] = 50271

-- Thunderstomp
LCT_SpellData[63900] = {
  class = "HUNTER",
  cooldown = 10,
  pet = true,
}

-- Venom Web Spray
LCT_SpellData[54706] = {
  class = "HUNTER",
  cooldown = 40,
  pet = true,
  duration = 4,
  cc = true,
  specID = { SPEC_HUNTER_BM },
}
LCT_SpellData[55505] = 54706
LCT_SpellData[55506] = 54706
LCT_SpellData[55507] = 54706
LCT_SpellData[55508] = 54706
LCT_SpellData[55509] = 54706

-- Web
LCT_SpellData[4167] = {
  class = "HUNTER",
  cooldown = 40,
  pet = true,
  duration = 4,
  cc = true,
}

-- Wolverine Bite
LCT_SpellData[53508] = {
  class = "HUNTER",
  cooldown = 10,
  pet = true,
}
