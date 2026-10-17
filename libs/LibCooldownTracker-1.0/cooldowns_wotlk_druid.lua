-- handling for TBC on the 3.3.5 client
if GetAccountExpansionLevel() ~= 2 then return end

-- ================ DRUID ================

local SPEC_DRUID_BALANCE  = 102
local SPEC_DRUID_FERAL    = 103
local SPEC_DRUID_RESTO    = 105

-- Barkskin
LCT_SpellData[22812] = {
  class = "DRUID",
  cooldown = 60,
  duration = 12,
}

-- Cower
LCT_SpellData[8998] = {
  class = "DRUID",
  cooldown = 10,
}
LCT_SpellData[9000] = 8998
LCT_SpellData[9892] = 8998
LCT_SpellData[27004] = 8998
LCT_SpellData[31709] = 8998
LCT_SpellData[48575] = 8998

-- Force of Nature
LCT_SpellData[33831] = {
  class = "DRUID",
  cooldown = 180,
  talent = true,
  duration = 30,
  specID = { SPEC_DRUID_BALANCE },
}

-- Nature's Grasp
LCT_SpellData[16689] = {
  class = "DRUID",
  cooldown = 60,
}
LCT_SpellData[16810] = 16689
LCT_SpellData[16811] = 16689
LCT_SpellData[16812] = 16689
LCT_SpellData[16813] = 16689
LCT_SpellData[17329] = 16689
LCT_SpellData[27009] = 16689
LCT_SpellData[53312] = 16689

-- Frenzied Regeneration
LCT_SpellData[22842] = {
  class = "DRUID",
  cooldown = 180,
  duration = 10,
}

-- Challenging Roar
LCT_SpellData[5209] = {
  class = "DRUID",
  cooldown = 180,
  duration = 6,
}

-- Bash
LCT_SpellData[5211] = {
  class = "DRUID",
  cooldown = 60,
}
LCT_SpellData[6798] = 5211
LCT_SpellData[8983] = 5211

-- Prowl
LCT_SpellData[5215] = {
  class = "DRUID",
  cooldown = 10,
  cooldown_starts_on_aura_fade = true,
}
LCT_SpellData[6783] = 5215
LCT_SpellData[9913] = 5215
LCT_SpellData[48932] = 5215

-- Enrage
LCT_SpellData[5229] = {
  class = "DRUID",
  cooldown = 60,
  duration = 10,
}

-- Swiftmend
LCT_SpellData[18562] = {
  class = "DRUID",
  cooldown = 15,
  talent = true,
  specID = { SPEC_DRUID_RESTO },
}

-- Growl
LCT_SpellData[6795] = {
  class = "DRUID",
  cooldown = 10,
}

-- Dash
LCT_SpellData[1850] = {
  class = "DRUID",
  cooldown = 180,
}
LCT_SpellData[9821] = 1850
LCT_SpellData[33357] = 1850

-- Feral Charge (Bear)
LCT_SpellData[16979] = {
  class = "DRUID",
  cooldown = 15,
  talent = true,
  specID = { SPEC_DRUID_FERAL },
  sets_cooldowns = {
	{ spellid = 49376, cooldown = 15 }
  }
}

-- Feral Charge (Cat)
LCT_SpellData[49376] = {
  class = "DRUID",
  cooldown = 30,
  talent = true,
  specID = { SPEC_DRUID_FERAL },
  sets_cooldowns = {
	{ spellid = 16979, cooldown = 15 }
  }
}

-- Rebirth
LCT_SpellData[20484] = {
  class = "DRUID",
  cooldown = 600,
}
LCT_SpellData[20739] = 20484
LCT_SpellData[20742] = 20484
LCT_SpellData[20747] = 20484
LCT_SpellData[20748] = 20484
LCT_SpellData[26994] = 20484
LCT_SpellData[48477] = 20484

-- Mangle (Bear Form)
LCT_SpellData[33878] = {
  class = "DRUID",
  cooldown = 6,
  talent = true,
  specID = { SPEC_DRUID_FERAL },
}
LCT_SpellData[33986] = 33878
LCT_SpellData[33987] = 33878
LCT_SpellData[48563] = 33878
LCT_SpellData[48564] = 33878

-- Faerie Fire (Feral)
LCT_SpellData[16857] = {
  class = "DRUID",
  cooldown = 6,
  specID = { SPEC_DRUID_FERAL },
  resets = { 5215 },
}

-- Nature's Swiftness
LCT_SpellData[17116] = {
  class = "DRUID",
  cooldown = 180,
  talent = true,
  cooldown_starts_on_dispel = true,
  cooldown_starts_on_aura_fade = true,
  specID = { SPEC_DRUID_RESTO },
}

-- Tranquility
LCT_SpellData[740] = {
  class = "DRUID",
  cooldown = 480,
}
LCT_SpellData[8918] = 740
LCT_SpellData[9862] = 740
LCT_SpellData[9863] = 740
LCT_SpellData[26983] = 740
LCT_SpellData[44203] = 740
LCT_SpellData[44205] = 740
LCT_SpellData[44206] = 740
LCT_SpellData[44207] = 740
LCT_SpellData[44208] = 740
LCT_SpellData[48446] = 740
LCT_SpellData[48447] = 740

-- Innervate
LCT_SpellData[29166] = {
  class = "DRUID",
  cooldown = 180,
}

-- Wild Growth
LCT_SpellData[48438] = {
  class = "DRUID",
  cooldown = 8,
  talent = true,
  specID = { SPEC_DRUID_RESTO },
}

-- Berserk
LCT_SpellData[50334] = {
  class = "DRUID",
  cooldown = 180,
  specID = { SPEC_DRUID_FERAL },
}

-- Survival Instincts
LCT_SpellData[61336] = {
  class = "DRUID",
  cooldown = 180,
  duration = 12,
  specID = { SPEC_DRUID_FERAL },
}

-- Starfall
LCT_SpellData[48505] = {
  class = "DRUID",
  cooldown = 60,
  -- opt_lower_cooldown = 60 Note: Assume everyone runs with the glyph
  talent = true,
  duration = 10,
  specID = { SPEC_DRUID_BALANCE },
}

-- Tiger's Fury
LCT_SpellData[5217] = {
	class = "DRUID",
	cooldown = 30,
}
LCT_SpellData[6793] = 5217
LCT_SpellData[9845] = 5217
LCT_SpellData[50212] = 5217
LCT_SpellData[50213] = 5217
