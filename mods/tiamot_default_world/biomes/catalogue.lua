-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- Every area of the Spindle and every biome in it, as data.
--
-- This is the designer's list, top to bottom. A biome listed here is
-- REGISTERED: it has an id, an area, and a first guess at where it goes. It
-- is BUILT only when a file under biomes/ calls `tdw.build_biome` for it
-- — one at a time, in order, so each one gets looked at on its own.
--
-- `ring`, `humidity` and `note` on the surface biomes are placement
-- proposals, to be argued with when each is built. Humidity is the value of
-- the slow "humidity" noise, which runs about -0.42 .. +0.42.

local area, biome = tdw.register_area, tdw.register_biome

-- 1. The surface --------------------------------------------------------------
area{ id = "surface", name = "Surface", kind = "surface",
    note = "Rings by distance from the axis, split by humidity and altitude." }
-- **Where the built biomes stand, until the unbuilt ones take their rings
-- back.** Five are placed and seven rings are part-empty, so each built biome
-- holds every ring its temperature suits (2026-09-14): the alpine has the
-- cold core, and the woodland and the grassland share everything outside
-- it by humidity — whose split moves toward dry as the world warms
-- (shape.WARM_DRY_PUSH), so the hot rings in the middle are grassland and
-- the mild ones are mostly woodland. Every edge wanders: the ring span by
-- shape.RING_WOBBLE, the wet/dry line by the humidity noise, which is a
-- blob field and never a circle.
biome{ id = "temperate_woodlands", name = "Temperate Woodlands", area = "surface",
    spans = { { "temperate", "temperate", "wet", "a" }, { "shore", "hem", "wet", "a" } },
    humidity = { -0.05, 0.42 },
    note = "1.1 — oak woodland, the first biome built. The wet half of the mild rings: the temperate ring, the Long Shore and the Hem. It skips the two hot rings, which are all grassland, and the Verdant Belt, whose wet half is the rainforest." }
biome{ id = "rolling_grasslands", name = "Rolling Grasslands", area = "surface",
    spans = { { "temperate", "temperate", "dry" }, { "verdant", "verdant", "dry" }, { "shore", "hem", "dry", "a" } },
    humidity = { -0.42, -0.05 },
    note = "The dry half of every ring outside the cold core, AND the whole width of the Ember Ridge and the Glass Waste: the dry band round the middle of the world, which is what the driest biome there is stands in for until there is a desert." }
biome{ id = "alpine_highlands", name = "Alpine Highlands", area = "surface",
    spans = { { "crown", "crown" } },
    note = "1.3 — the cold core, both halves of it: the Crown and Frostmoor. Its terrain is a MAP, so it reaches exactly as far as that map does — see the map constants in its own file." }
biome{ id = "frozen_wastes", name = "Frozen Wastes", area = "surface",
    spans = { { "frost", "frost", "dry" } },
    note = "1.9 — Frostmoor, the frost ring's dry half (2026-09-14, the designer's choice): permafrost plains, pressure ridges, crevasses, glaciers with ice caves, seracs, cryo-lakes. Its terrain is cross-faded into the alpine's mountains (shape.lua, cold_terms)." }
biome{ id = "coastal_cliffs", name = "Coastal Cliffs", area = "surface",
    spans = { { "temperate", "hem" } },
    ring = "shore",
    note = "1.4 and the shelf: every shore of every sea (seas.lua), from the temperate ring out. Its `present` is the sea map's: the shore band, the face and the shelf." }
biome{ id = "sandy_shores", name = "Sandy Shores", area = "surface",
    ring = "shore", note = "Gentle stretches of the Long Shore." }
biome{ id = "dunes", name = "The Dunes", area = "surface",
    spans = { { "shore", "hem", "dry", "b" } },
    ring = "shore", humidity = { -0.42, -0.05 },
    note = "2.5 — Goldwater: the dry half of the Long Shore and the Hem, in the provinces the Rolling Grasslands do not take (2026-09-16) — barchan dunes with steep slip faces, flat deflation basins, yardang rock ribs, megafauna ribcages." }
biome{ id = "flower_forest", name = "Flower Forest", area = "surface",
    spans = { { "temperate", "temperate", "wet", "b" }, { "shore", "hem", "wet", "b" } },
    ring = "shore", humidity = { -0.05, 0.42 },
    note = "2.6 — the wet half of the mild rings, in the provinces the woodland does not take (2026-09-16): parkland groves of apple, cherry and birch over carpets of allium, peony, poppy and bluebell in sweeping bands, with brooks in the gully floors." }
biome{ id = "river_valleys", name = "River Valleys", area = "surface",
    ring = "temperate",
    note = "1.6 — troughs cut across every ring they cross, from the temperate one outward. Its spans and its `present` are set in its own file: a river is a LINE, not a band, so it answers for the chunks its course runs near and no others." }
biome{ id = "jungle", name = "Jungle", area = "surface",
    spans = { { "verdant", "verdant", "wet" } },
    ring = "verdant", humidity = { 0.05, 0.42 }, note = "1.7 — the wet half of the Verdant Belt: karst, ravines and sinkholes under megatrees. The Dense Rainforest Canopy until 2026-09-15." }
biome{ id = "arid_mesa", name = "Arid Mesa", area = "surface",
    spans = { { "glass", "glass", "dry" } },
    ring = "glass", humidity = { -0.42, 0.0 }, note = "2.0 — the Glass Waste's dry half: benches, box canyons, buttes, arches, hoodoos." }
biome{ id = "badlands", name = "Badlands", area = "surface",
    spans = { { "glass", "glass", "wet" } },
    ring = "glass", humidity = { 0.0, 0.42 }, note = "2.1 — the Glass Waste's wet half: fins, rills, gullies, piping voids, banded ash and clay." }
biome{ id = "taiga", name = "Taiga", area = "surface",
    spans = { { "frost", "frost", "wet" } },
    ring = "frost", humidity = { -0.05, 0.42 },
    note = "2.2 — Firwold, the frost ring's wet half: rolling uplands and glacial ridges, peat basins with stagnant pools, a wall of spruce, ancient pines, fallen logs, fog. Its terrain is cross-faded into the alpine's mountains and the Frozen Wastes' plains (shape.lua, cold_terms)." }
biome{ id = "volcanic_foothills", name = "Volcanic Foothills", area = "surface",
    spans = { { "ember", "ember" } },
    ring = "ember", note = "2.3 — the Ember Ridge, the only surface sign of the magma shell: stepped basalt ridges, cinder cones, lava levees, gouges, ash gullies, thermal fissures venting steam." }
biome{ id = "deep_ocean", name = "Deep Ocean", area = "surface",
    spans = { { "temperate", "hem" } },
    ring = "hem",
    note = "1.8 — abyssal plains under a hundred blocks of sea: guyots, pillow ridges, trenches, basalt pillars, vents, whale bones, brine pools. Every sea's floor past the coast's shelf (seas.lua)." }
biome{ id = "coral_fringed_shallows", name = "Coral-Fringed Shallows", area = "surface",
    spans = { { "verdant", "shore" } },
    ring = "shore",
    note = "2.4 — the second sea lane (34.1 to 39.5 km), the warm water off the Goldwater dunes: sunlit lagoon flats one to five blocks deep behind a barrier reef crest that drops into open water, surge channels, corals, bomboras, anemone walls. Its `present` is the sea map's class and its own lane; every other shore is the Coastal Cliffs." }

-- 2. Normal caves ----------------------------------------------------------------
area{ id = "normal_caves", name = "Normal Caves", kind = "depth", note = "100 to 1,600 blocks down." }
biome{ id = "mossy_limestone", name = "Mossy Limestone", area = "normal_caves" }
biome{ id = "crystal_seam", name = "Crystal Seam", area = "normal_caves" }
biome{ id = "underground_river", name = "Underground River", area = "normal_caves", note = "Needs generated water." }
biome{ id = "fungal_grove_chambers", name = "Fungal Grove Chambers", area = "normal_caves" }
biome{ id = "mineral_vein_tunnels", name = "Mineral Vein Tunnels", area = "normal_caves" }
biome{ id = "stalactite_forests", name = "Stalactite Forests", area = "normal_caves" }

-- 3. Dark caves ------------------------------------------------------------------
area{ id = "dark_caves", name = "Dark Caves", kind = "depth", note = "1,600 to 4,000 blocks down: the Gloam." }
biome{ id = "stone_labyrinth", name = "Stone Labyrinth", area = "dark_caves" }
biome{ id = "echoing_black_marble", name = "Echoing Black Marble", area = "dark_caves" }
biome{ id = "shadow_pool_chambers", name = "Shadow Pool Chambers", area = "dark_caves" }
biome{ id = "blind_fish_grottoes", name = "Blind Fish Grottoes", area = "dark_caves" }
biome{ id = "whispering_crevasse", name = "Whispering Crevasse", area = "dark_caves" }
biome{ id = "phosphorescent_fungi_pockets", name = "Phosphorescent Fungi Pockets", area = "dark_caves", note = "Rare." }

-- 4. The abyss -------------------------------------------------------------------
area{ id = "abyss", name = "Abyss Below", kind = "depth", note = "More than 4,000 blocks down." }
biome{ id = "pressure_crushed_depths", name = "Pressure-Crushed Depths", area = "abyss" }
biome{ id = "silent_vertical_shafts", name = "Silent Vertical Shafts", area = "abyss" }
biome{ id = "abyssal_mud_flats", name = "Abyssal Mud Flats", area = "abyss" }
biome{ id = "crush_zone_mineral_beds", name = "Crush-Zone Mineral Beds", area = "abyss" }
biome{ id = "black_water_reservoirs", name = "Black Water Reservoirs", area = "abyss", note = "Needs generated water." }
biome{ id = "fossil_embedded_walls", name = "Fossil-Embedded Walls", area = "abyss" }

-- 5. The magma shell -------------------------------------------------------------
area{ id = "magma_shell", name = "Magma Shell", kind = "shell",
    note = "Bleeds 50 blocks into the layers above and below; 25 blocks of lava caves in the middle." }
biome{ id = "magma_crust_above", name = "Cooked Crust (above)", area = "magma_shell" }
biome{ id = "lava_caves", name = "Lava Caves", area = "magma_shell", note = "The 25-block core. Lava is a look-alike solid until fluid can be generated here." }
biome{ id = "magma_crust_below", name = "Cooked Crust (below)", area = "magma_shell" }

-- 6. Hot magical caves -----------------------------------------------------------
area{ id = "hot_magical", name = "Hot Magical Caves", kind = "shell" }
biome{ id = "living_flame_corridors", name = "Living Flame Corridors", area = "hot_magical" }
biome{ id = "mana_lava_tubes", name = "Mana Lava Tubes", area = "hot_magical" }
biome{ id = "molten_crystal_gardens", name = "Molten Crystal Gardens", area = "hot_magical" }
biome{ id = "fire_spirit_nests", name = "Fire Spirit Nests", area = "hot_magical" }
biome{ id = "arcane_forge_caverns", name = "Arcane Forge Caverns", area = "hot_magical" }

-- 7. The slime border ------------------------------------------------------------
area{ id = "slime_border", name = "Slime Border", kind = "shell", note = "The Caul." }
biome{ id = "viscous_gel_chambers", name = "Viscous Gel Chambers", area = "slime_border" }
biome{ id = "amorphous_ooze_pools", name = "Amorphous Ooze Pools", area = "slime_border" }
biome{ id = "bouncing_gel_pillars", name = "Bouncing Gel Pillars", area = "slime_border" }
biome{ id = "semi_living_slime_reefs", name = "Semi-Living Slime Reefs", area = "slime_border" }

-- 8. Cold magical caves ----------------------------------------------------------
area{ id = "cold_magical", name = "Cold Magical Caves", kind = "shell" }
biome{ id = "frozen_mana_crystal_halls", name = "Frozen Mana Crystal Halls", area = "cold_magical" }
biome{ id = "stilled_time_chambers", name = "Stilled Time Chambers", area = "cold_magical" }
biome{ id = "forest_spirit_sanctums", name = "Forest Spirit Sanctums", area = "cold_magical" }
biome{ id = "ice_spider_nests", name = "Ice Spider Nests", area = "cold_magical" }
biome{ id = "mushroom_forest", name = "Mushroom Forest", area = "cold_magical" }

-- 9. The hollow ring -------------------------------------------------------------
area{ id = "hollow_ring", name = "The Hollow Ring", kind = "shell", note = "The rind around the void." }
biome{ id = "gravity_warped_forests", name = "Gravity-Warped Forests", area = "hollow_ring" }
biome{ id = "echoing_void_tunnels", name = "Echoing Void Tunnels", area = "hollow_ring" }
biome{ id = "fragmented_stone_arches", name = "Fragmented Stone Arches", area = "hollow_ring" }
biome{ id = "residual_magic_shells", name = "Residual Magic Shells", area = "hollow_ring" }
biome{ id = "silent_observatory_chambers", name = "Silent Observatory Chambers", area = "hollow_ring" }

-- 10. The hollow -----------------------------------------------------------------
area{ id = "hollow", name = "The Hollow", kind = "shell", note = "The void itself: 74 km across, 20 km high." }
biome{ id = "empty_cathedral_voids", name = "Empty Cathedral Voids", area = "hollow" }
biome{ id = "floating_island_clusters", name = "Floating Island Clusters", area = "hollow" }
biome{ id = "memory_eating_islands", name = "Memory-Eating Islands", area = "hollow" }
biome{ id = "dead_mushroom_yard", name = "Dead Mushroom Yard", area = "hollow" }
biome{ id = "weightless_dust_seas", name = "Weightless Dust Seas", area = "hollow" }
biome{ id = "poison_root_stones", name = "Poison Root Stones", area = "hollow" }
biome{ id = "forgotten_forest_fragments", name = "Forgotten Forest Fragments", area = "hollow" }
biome{ id = "pyre_stillness_domes", name = "Pyre Stillness Domes", area = "hollow" }

-- 11. The tail -------------------------------------------------------------------
area{ id = "tail", name = "The Tail", kind = "tail", note = "Extremely eerie and monstrous. Y -37 km to -63 km." }
biome{ id = "twisted_bone_corridors", name = "Twisted Bone Corridors", area = "tail" }
biome{ id = "old_bone_fields", name = "Old Bone Fields", area = "tail" }
biome{ id = "living_shadow_mazes", name = "Living Shadow Mazes", area = "tail" }
biome{ id = "wind_hollow_shafts", name = "Wind Hollow Shafts", area = "tail" }
biome{ id = "wall_of_eyes_caves", name = "Wall of Eyes Caves", area = "tail" }

-- 12. Below the apex -------------------------------------------------------------
area{ id = "below_apex", name = "The Below Apex", kind = "tail", note = "Truly horrifying. Y -63 km to the point." }
biome{ id = "impossible_geometry_vaults", name = "Impossible Geometry Vaults", area = "below_apex" }
biome{ id = "living_rooms", name = "Living Rooms", area = "below_apex" }
biome{ id = "body_changer_pools", name = "Body-Changer Pools", area = "below_apex" }
biome{ id = "anti_light_cathedrals", name = "Anti-Light Cathedrals", area = "below_apex" }
biome{ id = "nightmare_tunnels", name = "Nightmare Tunnels", area = "below_apex" }
