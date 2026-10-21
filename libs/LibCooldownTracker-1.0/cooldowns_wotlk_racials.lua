-- handling for TBC on the 3.3.5 client
if GetAccountExpansionLevel() ~= 2 then return end

-- Racials

-- Gift of the Naaru (Draenei)
LCT_SpellData[59547] = {
	race = "Draenei",
	heal = true,
	duration = 15,
	cooldown = 180,
}
LCT_SpellData[28880] = 59547 -- Warrior
LCT_SpellData[59542] = 59547 -- Paladin
LCT_SpellData[59543] = 59547 -- Hunter
LCT_SpellData[59544] = 59547 -- Priest
LCT_SpellData[59545] = 59547 -- Death Knight
LCT_SpellData[59548] = 59547 -- Mage

-- Will of the Forsaken (Undead)
LCT_SpellData[7744] = {
	race = "Scourge",
	cooldown = 120,
	defensive = true,
    sets_cooldowns = {
        -- PvP Trinket
		{ spellid = 42292, cooldown = 45 },
        -- Every Man for Himself
        { spellid = 59752, cooldown = 45 },
    },
}
-- Every Man for Himself (Human)
LCT_SpellData[59752] = {
    race = "Human",
    cooldown = 120,
    defensive = true,
    sets_cooldowns = {
        -- WOTF
        { spellid = 7744, cooldown = 45 },
        -- PvP Trinket
        { spellid = 42292, cooldown = 120 },
    },
}
-- Arcane Torrent (Blood Elf)
LCT_SpellData[28730] = {
	race = "BloodElf",
	cooldown = 120,
  duration = 2,
  silence = true,
}
LCT_SpellData[25046] = 28730
LCT_SpellData[50613] = 28730 -- Death Knight (runic power)

-- Blood Fury (Orc)
LCT_SpellData[20572] = {
	race = "Orc",
	offensive = true,
	duration = 15,
	cooldown = 120,
}
LCT_SpellData[33697] = 20572
LCT_SpellData[33702] = 20572
-- Cannibalize (Undead)
LCT_SpellData[20577] = {
	race = "Scourge",
	heal = true,
	duration = 10,
	cooldown = 120,
}
-- Escape Artist (Gnome)
LCT_SpellData[20589] = {
	race = "Gnome",
	defensive = true,
	cooldown = 105,
}
-- Shadowmeld (Night Elf)
LCT_SpellData[58984] = {
	race = "NightElf",
	defensive = true,
	cooldown = 120,
}
-- Stoneform (Dwarf)
LCT_SpellData[20594] = {
	race = "Dwarf",
	defensive = true,
	duration = 8,
	cooldown = 120,
}
-- War Stomp (Tauren)
LCT_SpellData[20549] = {
	race = "Tauren",
	stun = true,
	duration = 2,
	cooldown = 120,
}
-- Berserking (Troll)
LCT_SpellData[26297] = {
	race = "Troll",
	offensive = true,
	duration = 10,
	cooldown = 180
}

