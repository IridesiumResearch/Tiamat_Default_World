<!-- SPDX-FileCopyrightText: Iridesium -->
<!-- SPDX-License-Identifier: GPL-3.0-only -->

# Exports

What Tiamat Default World (`tiamat_default_world`) deliberately offers other
mods. This is the document `LICENSE.EXCEPTION` names as "the Exports": a mod
that uses only what is listed here, the engine's scripting API and the network
protocol is an independent work. Copying or adapting this mod's code or assets
is not an export and stays under the GPL.

Keep it current. An interface the mod offers in fact is an export whether or
not this file has caught up, so a change to `mods/tiamat_default_world/exports.lua`,
to a registered identifier or to a chat command updates this file in the same
commit.

## 1. The export table

Published once with `game.export` from
`mods/tiamat_default_world/exports.lua`, read with
`game.exports("tiamat_default_world")` by a mod that lists this one in
`depends` or `optional_depends`. Version 1 of Weather's
`docs/exports-contract.md` (2026-09-17). Every function checks its arguments
and answers `nil` or `false` rather than raising.

| Field | Kind | What it is |
|---|---|---|
| `version` | integer | `1` |
| `humidity` | compiled density | The humidity field, about +/-0.5, no dither. Sample with `humidity:at(x, y, z, seed)` or `humidity:bounds(pos)`. |
| `HUMIDITY_SPLIT` | number | The wet/dry line in that field's units (`-0.05`). |
| `climate(x, z)` | function → number or nil | The ring temperature, 0..1: `T = 4t(1 - t)` with `t = r / R`, the curve biome placement follows. |
| `biome_under(x, y, z)` | function → string or nil | The id of the biome at a place (section 3), or nil. |
| `add_soil_alias(block, dry)` | function → boolean | Another mod's block (a full id string) counts as this mod's block `dry` wherever this mod compares materials: what soil is under a place, the HUD's owner table, what a plant stands on. Resolved on first use, so it may name blocks registered later. |
| `add_harmless_fluid(fluid)` | function → boolean | A fluid (a full id string) that neither breaks leaves nor quenches lava into rock. |

## 2. Registered identifiers

Content registered with the engine, namespaced `tiamat_default_world:`.

**Blocks.** acacia_leaves, acacia_log, allium, apex_stone, apple_blossom,
apple_leaves, apple_log, barnacles, birch_leaves, birch_log, black_mud,
blue_lunaria, bluebell, bone, bramble, cactus, calcite, caul, charcoal,
cherry_blossom, cherry_leaves, cherry_log, chromium_ore, clear_ice,
climbing_ivy, coal, cobbles, cold_fiber_stone, copper_ore, coral_amber,
coral_cyan, coral_magenta, crystal, dark_basalt, dark_sand, dark_sediment,
dead_coral, dead_log, dead_sagebrush, diamond, dirt, dried_mud, dry_clay, fern,
fir_log, fir_needles, flint, flowstone, glow_algae, glow_cap, glow_polyp,
gold_ore, gorse, granite, grass, gravel, heather, hot_fiber_stone, ice,
iron_ore, ironwood_leaves, ironwood_log, ironwood_planks, juniper_log,
juniper_needles, kapok_leaves, kapok_log, kapok_planks, kelp, ladys_mantle,
ladys_mantle_bloom, lava, lava_rock, lead_ore, lichen, light_sediment, magma,
magma_crust, maidenhair, mangrove_leaves, mangrove_log, marrow, metal,
monstera, morphic_rock, moss, mud, mulch, mushroom_cap, mycelium, oak_leaves,
oak_log, obsidian, ocean_moss, ochre_sandstone, orichalcum, packed_dirt,
pale_terracotta, peony, permafrost, pink_algae, pitcher_plant, poppy, pumice,
pyrite, redwood_log, redwood_needles, reeds, roman_chamomile, rose_blooms,
rose_bush, rust_red_sandstone, salt, sand, scorch, seagrass, silver_ore, slate,
snow, stone, sulfur, tall_grass, tin_ore, volcanic_ash, water, water_iris,
wet_clay, white_sand, wild_mint, willow_leaves, willow_log, willow_planks.
`docs/blocks.md` says where each is used and why.

**Items.** rose.

**Fluids.** water, brine, lava.

**Sounds.** step_hard, step_soft, cave, underworld, canopy, wind, undersea,
crickets, frogs, ember, echo_dark, peel, portal.

**Textures and sounds as files.** The files under
`mods/tiamat_default_world/textures/` and `mods/tiamat_default_world/sounds/`
are served to clients by the engine as the content of the identifiers above.
Referring to them by identifier is an export; copying the files is not.

**HUD script.** `hud.lua`, pushed to every player.

## 3. Biome and area ids

What `biome_under` answers, and what `/where` and `/tp` name.

**Areas.** surface, normal_caves, dark_caves, abyss, magma_shell, hot_magical,
slime_border, cold_magical, hollow_ring, hollow, tail, below_apex.

**Biomes.** Every `id` in `mods/tiamat_default_world/biomes/catalogue.lua`,
which is the authoritative list; as of this writing: temperate_woodlands,
rolling_grasslands, alpine_highlands, frozen_wastes, coastal_cliffs,
sandy_shores, dunes, flower_forest, heather_moor, river_valleys, jungle,
arid_mesa, badlands, taiga, icefall, silverwood, salt_pan, volcanic_foothills,
obsidian_barrens, geyser_basin, cinder_coast, deep_ocean,
coral_fringed_shallows, frostpine_coast, rime_tundra, rime_wall, kelp_forest,
pack_ice, abyssal_trench, mangrove_coast, savanna, karst_towers, peat_fen,
redwood_stands, mossy_limestone, crystal_seam, underground_river,
fungal_grove_chambers, mineral_vein_tunnels, stalactite_forests,
stone_labyrinth, echoing_black_marble, shadow_pool_chambers,
blind_fish_grottoes, whispering_crevasse, phosphorescent_fungi_pockets,
pressure_crushed_depths, silent_vertical_shafts, abyssal_mud_flats,
crush_zone_mineral_beds, black_water_reservoirs, fossil_embedded_walls,
magma_crust_above, lava_caves, magma_crust_below, living_flame_corridors,
mana_lava_tubes, molten_crystal_gardens, fire_spirit_nests,
arcane_forge_caverns, viscous_gel_chambers, amorphous_ooze_pools,
bouncing_gel_pillars, semi_living_slime_reefs, frozen_mana_crystal_halls,
stilled_time_chambers, forest_spirit_sanctums, ice_spider_nests,
mushroom_forest, gravity_warped_forests, echoing_void_tunnels,
fragmented_stone_arches, residual_magic_shells, silent_observatory_chambers,
empty_cathedral_voids, floating_island_clusters, memory_eating_islands,
dead_mushroom_yard, weightless_dust_seas, poison_root_stones,
forgotten_forest_fragments, pyre_stillness_domes, twisted_bone_corridors,
old_bone_fields, living_shadow_mazes, wind_hollow_shafts, wall_of_eyes_caves,
impossible_geometry_vaults, living_rooms, body_changer_pools,
anti_light_cathedrals, nightmare_tunnels.

## 4. Chat commands

Accepted from players, in any mod's world that loads this one:

| Command | What it does |
|---|---|
| `/help` | Lists these commands. |
| `/where` | The biome, the ring, and the depth under the dome. |
| `/tp` | Travel to a biome, a ring, spawn or coordinates; `/tp list` gives the names. |
| `/crevasse` | Cracks a crevasse open under the player. |
| `/roses` | Goes to the first rose bush that grew this session. |
| `/stats` | Writes the woodland's growth figures to the server log. |

## 5. Data it stores

`game.storage` key `pos:<player uuid>`: the player's last position as three
numbers, `"x y z"`, two decimals each. Private to this mod; listed because it
is written into the world's save.
