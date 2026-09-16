-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- Spindle: the default world. This file only decides the load order.
--
-- Every file below is loaded exactly once and hangs what it exports off the
-- `tdw` global, which the sandbox shares between a mod's own files. The
-- engine's `require` is confined to this directory and does not cache — so a
-- file required twice would run twice, which is why nothing but this file
-- calls it.
--
-- Order matters: blocks first (everything else needs their ids), then the
-- shape (the density programs), the layer table, the biome registry, the
-- biomes themselves, and only then the generator and the player hooks that
-- read all of it.

tdw = {}

-- Development switches. `everywhere` names a built surface biome and puts it
-- over the WHOLE surface, ignoring its ring and humidity, so one biome can be
-- looked at on its own while it is being made. Set it to nil for the world.
tdw.config = {
    everywhere = nil,
    -- **What no biome has claimed is WHITE.** Four surface biomes are built
    -- and every other area in the catalogue — the three cave bands, the five
    -- shells, the tail below the apex — has a registered biome and no code
    -- behind it, and until now the generator filled all of it with the
    -- layer table's stand-in rock, which looks like rock and reads as
    -- finished work. White reads as what it is: unclaimed. Everything below
    -- the surface band (a hundred blocks down, layers.DEPTH) takes it. Set
    -- this to false for a world that looks like a world.
    white_unbuilt = true,
    -- Which biome a NEW player starts in, by id, or nil for the fixed spawn
    -- in the woodlands. The landing hunts for it: it drops them on one
    -- azimuth of that biome's ring, reads the ground, and goes round again
    -- if the humidity put something else there (whereami.lua).
    spawn_biome = nil,
}

-- The host reports a failed load as "errored in init.lua" and nothing more,
-- so say which file and what the error was before letting it through.
local function load(name)
    local ok, result = pcall(require, name)
    if not ok then
        game.log(string.format("tiamot_default_world: %s.lua failed: %s", name, tostring(result)))
        error(result, 0)
    end
    return result
end

tdw.blocks = load("blocks")
tdw.shape = load("shape")
tdw.layers = load("layers")
load("hooks")                   -- one tick and one chat hook, many subscribers
tdw.edits = load("edits")   -- the paced runtime edit queue
load("rocks")                   -- boulders and clusters, for any biome: tdw.rocks
load("schem")                   -- ellipsoids written and carved, for any biome: tdw.schem
load("seas")                    -- where the seas are and each pool's level: tdw.seas, shape.sea_exclude
load("biomes")             -- registry: tdw.register_area / register_biome
load("biomes.catalogue")   -- every area and every biome, as data
load("biomes.temperate_woodlands")   -- 1.1, the first one built
load("biomes.rolling_grasslands")    -- 1.2, the dry half of the same ring
load("biomes.alpine_highlands")      -- 1.3, the frost ring's dry half
load("biomes.coastal_cliffs")        -- 1.4, the steep stretches of the Long Shore
load("biomes.river_valleys")         -- 1.6, the troughs and their rivers, cut across every ring they cross
load("biomes.jungle")                -- 1.7, the Verdant Belt's wet half: karst under megatrees (the Dense Rainforest Canopy until 2026-09-15)
load("biomes.deep_ocean")            -- 1.8, abyssal plains under a flat sea (not placed)
load("biomes.frozen_wastes")         -- 1.9, the Crown's ice cap (Frostmoor until 2026-09-16)
load("biomes.icefall")               -- 2.7, the Crown's other half: the ice cap broken
load("biomes.arid_mesa")             -- 2.0, the Glass Waste's dry half: benches and canyons
load("biomes.badlands")              -- 2.1, the Glass Waste's wet half: fins, rills and gullies
load("biomes.salt_pan")              -- 2.9, a third of the Glass Waste: the flat white crust
load("biomes.taiga")                 -- 2.2, Firwold: spruce uplands and peat basins
load("biomes.silverwood")            -- 2.8, Firwold's other half: birch on lichen
load("biomes.volcanic_foothills")    -- 2.3, the Ember Ridge: basalt terraces, cinder cones, fissures
load("biomes.coral_fringed_shallows") -- 2.4, the second lane's sea: lagoon flats behind a barrier reef
load("biomes.dunes")                 -- 2.5, Goldwater: barchan dunes and deflation basins
load("biomes.flower_forest")         -- 2.6, the Long Shore's wet half: parkland groves and flower carpets
load("whereami")                     -- the biome you are in, on the HUD and from chat

-- The HUD script runs on the CLIENT, once a frame, and sees only what
-- `game.set_hud` sent that player. It draws the biome's name; whereami.lua
-- decides what the name is and how long it stays up.
game.register_hud_script("hud.lua")
load("generate")
load("player")
load("rules")             -- leaves and water, and other rules of the whole world

game.log(string.format("tiamot_default_world ready: %d areas, %d biomes (%d built)",
    #tdw.area_list, #tdw.biome_list, tdw.built_count()))
