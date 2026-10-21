-- Original 3.3.5a racial SkillLineAbility/Spell data, including class variants.
-- ID = {race token, race ID, cooldown, duration or false, cast variants}
-- Stoneform/Cannibalize durations come from their triggered effects.
return {
    [7744] = {"Scourge", 5, 120, false, {7744}}, -- Will of the Forsaken
    [20549] = {"Tauren", 6, 120, 2, {20549}}, -- War Stomp
    [20572] = {"Orc", 2, 120, 15, {20572, 33697, 33702}}, -- Blood Fury
    [20577] = {"Scourge", 5, 120, 10, {20577}}, -- Cannibalize
    [20589] = {"Gnome", 7, 105, false, {20589}}, -- Escape Artist
    [20594] = {"Dwarf", 3, 120, 8, {20594}}, -- Stoneform
    [26297] = {"Troll", 8, 180, 10, {26297}}, -- Berserking
    [28730] = {"BloodElf", 10, 120, 2, {28730, 25046, 50613}}, -- Arcane Torrent
    [58984] = {"NightElf", 4, 120, false, {58984}}, -- Shadowmeld
    [59547] = {"Draenei", 11, 180, 15, {59547, 28880, 59542, 59543, 59544, 59545, 59548}}, -- Gift of the Naaru
    [59752] = {"Human", 1, 120, false, {59752}}, -- Every Man for Himself
}
