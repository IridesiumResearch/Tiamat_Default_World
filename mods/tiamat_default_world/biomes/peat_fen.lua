-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.13 Peat Fen: a quarter of the Temperate Woodlands' province in the
-- temperate ring (2026-09-16).
--
-- Flat wet ground: a carpet of sphagnum moss over black peat, open pools of
-- dark water in every low place ringed with reed beds, cotton grass on the
-- drier hummocks, and bog oaks — black, dead, thousands of years in the
-- peat — lying half sunk or standing as broken stumps.
--
-- WHERE: the Woodlands' province side "a" past a split of -0.383 of the
-- province noise (its 12.5th percentile), in the temperate ring; the
-- Redwood Stands take the same share on the Long Shore. A dressing biome:
-- the mild rings' programs are at 999. The pools are the wet side's gully
-- floors, filled wider than a brook. New node: `reeds`.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "peat_fen"
local WATER = "tiamat_default_world:water"

local POOL_AT = 0.42                                    -- the gully depth the water reaches: wide, shallow pools
local REED_BAND = { 0.20, 0.46 }                        -- the gully depth band the reeds stand in
local PEAT_FREQ, PEAT_MIN = 1 / 30, 0.25
local COTTON_FREQ, COTTON_MIN = 1.4, 0.30
local REED_THIN_FREQ, REED_THIN_MIN = 1.3, -0.20
local STUMP_CELL, STUMP_SQUARES = 30, 0.30
local LOG_CELL, LOG_SQUARES = 40, 0.35

tdw.biomes[ID].ring_mode = "temperate"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.black_mud

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "fen_template:" .. name)
end
local PRIORITY = { [blocks.dead_log] = 1 }

-- A bog oak's stump: a thick black stub two to four blocks, split.
local function stump(rng)
    schem.record_begin()
    local tall = 2 + rng:below(3)
    schem.push_path(blocks.dead_log, { { 0.5, -1.5, 0.5, 0.9 }, { 0.5, tall, 0.5, 0.6 } }, { rough = 0.4, blind = true })
    for _ = 1, 2 do
        local d = schem.DIR16[rng:below(16) + 1]
        schem.push_path(blocks.dead_log, { { 0.5, -0.8, 0.5, 0.35 }, { 0.5 + d[1] * 1.8, -0.6, 0.5 + d[2] * 1.8, 0.2 } }, BLIND)
    end
    return schem.record_schematic(PRIORITY)
end
-- A bog oak lying half sunk: eight to fourteen blocks of black trunk.
local function log(rng)
    schem.record_begin()
    local length = 8 + rng:below(7)
    local d = schem.DIR16[rng:below(16) + 1]
    local half = length / 2
    schem.push_path(blocks.dead_log, { { 0.5 - d[1] * half, -0.2, 0.5 - d[2] * half, 0.8 }, { 0.5 + d[1] * half, -0.4, 0.5 + d[2] * half, 0.55 } }, BLIND)
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { stumps = {}, logs = {} }
    if game.schematic_shapes then
        for i = 1, 4 do out.stumps[i] = stump(rng_for("stump:" .. i)) end
        for i = 1, 4 do out.logs[i] = log(rng_for("log:" .. i)) end
    end
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

tdw.build_biome(ID, function(ctx)
    local function masked(field)
        local mask = tdw.biome_mask(n, ID)
        field = mask and n.min(field, mask) or field
        return shape.sea_exclude and shape.sea_exclude(field, 20.0) or field
    end
    local function off_river(field)
        return shape.river_exclude and shape.river_exclude(field, (shape.RIVER_BAR or 0) + 4) or field
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    local function gully()
        return n.add(shape.gully_floor(), n.const(0.6))
    end
    local conditions = {
        -- 1: sphagnum over peat.
        n.const(1.0),
        -- 2: bare black peat.
        n.sub(n.noise("pf_peat", PEAT_FREQ, 2, 1.0), n.const(PEAT_MIN)),
        -- 3: the pools' margins and beds: soft mud.
        n.sub(gully(), n.const(REED_BAND[1])),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    code = n.mul(code, step(masked(n.const(1.0))))
    local depth = shape.compile("biome.fen.depth", shape.terrain(false))
    local codes = shape.compile("biome.fen.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 1 * km, material = blocks.moss },
        { code = 1, from = 1 * km, to = 6 * km, material = blocks.black_mud },
        { code = 2, to = 6 * km, material = blocks.black_mud },
        { code = 3, to = 2 * km, material = blocks.mud },
        { code = 3, from = 2 * km, to = 6 * km, material = blocks.black_mud },
    }
    local reeds = shape.compile("biome.fen.reeds", masked(off_river(n.min(n.min(n.sub(gully(), n.const(REED_BAND[1])),
        n.sub(n.const(REED_BAND[2]), gully())), n.sub(n.noise("pf_reed_thin", REED_THIN_FREQ, 1, 1.0), n.const(REED_THIN_MIN))))))
    local cotton = shape.compile("biome.fen.cotton", masked(off_river(n.min(n.sub(n.const(REED_BAND[1] - 0.03), gully()),
        n.sub(n.noise("pf_cotton", COTTON_FREQ, 1, 1.0), n.const(COTTON_MIN))))))
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
        { cover = blocks.reeds, cells = 3, take = reeds },
        { cover = blocks.tall_grass, cells = 2, take = cotton },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, above)
            fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                salt = salt, sink = 1, above = above, stand = shape.compile("biome.fen.stand_" .. name, masked(off_river(field))) }
        end
        scatter("stump", built.stumps, n.sub(n.const(REED_BAND[1]), gully()), STUMP_CELL, STUMP_SQUARES, 321, 0.005)
        scatter("log", built.logs, n.sub(n.const(0.5), gully()), LOG_CELL, LOG_SQUARES, 322, 0.002)
    end
    -- The pools: dark water over the gullies' floors, wider than a brook,
    -- on the ground beside them as the brooks are (shape.lua).
    --
    -- **`within` reads no height** (2026-09-23), the river's treatment
    -- (river_valleys.lua). The engine reads a terraced fill's fields on the
    -- one plane y = 0.5 for the whole world, and since engine ask 35 a
    -- `within` whose bounds disagree between that plane and the chunk's
    -- slab is an ERROR — the guard (hooks.lua) takes it as "no water
    -- here", and a fen chunk skipped dry. The gully term was the worst
    -- kind of reader: the gully noise is 3D and unstretched, so tens of
    -- thousands of blocks down on that plane it draws a DIFFERENT set of lines
    -- than the ground carries, and a pool held water only where the two
    -- patterns happened to cross. It is dropped, and exactly: the level is
    -- the ground plus GULLY_DEPTH * (gully - POOL_AT)
    -- (`shape.gully_water_level`), so there is room under it precisely
    -- where the gully the TERRAIN carries is deeper than POOL_AT — the
    -- trough bounds its own water by construction, and the within's copy
    -- of that test only ever said it again, at the wrong altitude. (The
    -- 0.02 slack goes with it: a fiftieth of a 2.5-block groove, under a
    -- cell.)
    --
    -- "The terrain carries the gully" is that proof's whole load, and
    -- two grounds do NOT carry it, so the within takes a flat term for
    -- each. In a river valley the terrain is min'd with the trough — the
    -- smooth height less the valley's depth, no gully term — yet the
    -- level still restores the full cut, so along every gully line
    -- crossing a valley slope the water stood up to GULLY_DEPTH * (1 -
    -- POOL_AT), 1.45 blocks, proud of ground that has no channel: mostly
    -- PARTIAL blocks, spills by the fluid contract, woken on load and
    -- running downhill — the exact fault `gully_water_level` was built
    -- to end. The course is kept out to the rim (its contour reads x and
    -- z alone), as the reeds and the cotton already keep off it. And
    -- within the coast's reach the shore programs lift low ground to the
    -- water's plane (`seas.floor`), erasing channels the level then
    -- re-cuts, so in a "_shore" program the pools stop over the floor
    -- clamp's whole reach (PLAIN_W + FADE) rather than the 20-block hem
    -- — the sea map reads x and z alone too.
    --
    -- What stays reads x and z alone, or the flat-stretched hair the
    -- volcanic lava keeps (volcanic_foothills.lua): the band on the TRUE
    -- radius, the smooth humidity, the province noise and the sea map. The
    -- band is the temperate ring's (the catalogue's span), wide of the
    -- ember side by the wobble's whole reach — u_biome = u * (1 ± SHARE),
    -- and the ember programs carry the temperate pair at full strength
    -- under the ridge's terms, so a pool past the line still sits in a
    -- real channel — and sure of the frost side, where the pair fades
    -- under the cold terms (shape.lua, "all") and a channel the terrain no
    -- longer cuts would stand its water proud on the tundra. The humidity
    -- is the smooth field at the bare split, in place of `humidity_mask`,
    -- whose dither is an UNSTRETCHED noise — at the slice it was speckle
    -- from nowhere. At the split the wet terms still stand at half
    -- strength, so a full-depth pool is at most 0.2 blocks proud there:
    -- under a cell. The residue, named as the lava names its own: where
    -- the split, the frost fade and a deep gully all meet, a film up to
    -- most of a block can perch — the river's trade, and the opposite
    -- fault to a dry fen.
    local level = shape.gully_water_level(POOL_AT)
    local within
    if tdw.config.everywhere then
        within = n.const(1.0)
    else
        local SHARE = shape.RING_WOBBLE_SHARE
        local ring = tdw.layers.ring_by_id.temperate
        local ring_lo, ring_hi = ring.u[1] / (1.0 - SHARE), ring.u[2] / (1.0 - SHARE)
        local ring_mid, ring_half = (ring_lo + ring_hi) / 2, (ring_hi - ring_lo) / 2
        within = n.sub(n.const(ring_half), n.abs(n.sub(shape.sub.u(), n.const(ring_mid))))
        within = n.min(within, n.sub(shape.humidity(), n.const(shape.HUMIDITY_SPLIT)))
        within = n.min(within, shape.province_mask("a", -0.383))
    end
    if shape.river_exclude then
        within = shape.river_exclude(within, (shape.RIVER_RIM or 150) + 4)
    end
    if shape.sea_exclude then
        local inset = 20.0
        if tdw.seas and tdw.seas.on() and shape.terrain_mode and shape.terrain_mode:find("_shore", 1, true) then
            inset = (tdw.seas.PLAIN_W or 130.0) + (tdw.seas.FADE or 900.0)
        end
        within = shape.sea_exclude(within, inset)
    end
    fills[#fills + 1] = {
        fluid = WATER,
        level = shape.compile("biome.fen.pool_level", level),
        within = shape.compile("biome.fen.pool_within", within),
    }
    return fills
end)
