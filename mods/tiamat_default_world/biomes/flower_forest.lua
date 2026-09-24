-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 2.6 Flower Forest: the Long Shore's wet half, 35.4 to 50.1 km — open
-- parkland of apple, cherry and birch over carpets of flowers.
--
-- The brief (2026-09-15):
--
--   Soft, rolling hills and sun-drenched knolls terracing down into gentle
--   meadow hollows. Slopes are mild and navigable, opening into wide
--   sunlit clearings framed by loose groves.
--   Surface: lush emerald grass, small patches of rich dark mulch, and
--   smooth, moss-dusted stones half-buried in the ground.
--   Trees: moderate to open parkland density; small picturesque clusters
--   of 6 to 14, leaving little sunlit meadows between them. Bearing apple
--   trees*, wild cherries*, and birches.
--   Erosion: mild runoff feeding narrow, rare, shallow crystal-clear
--   brooks with smooth pebble beds; no steep gullies or shear cuts, just
--   soft grassy banks and quiet spring seeps pooling in low hollows.
--   Accents: dense, vibrant carpets of single- and two-block flowers
--   (alliums*, peonies*, poppies*, bluebells*) growing in sweeping
--   wave-like colour gradients; fallen rotting blossom logs.
--
-- WHAT IT ADDS TO THE TERRAIN: almost nothing, on purpose. The wet half of
-- the mild rings is already soft relief with shallow gullies in it
-- (`wet_terms`), which is the brief's mild slopes and its runoff; the only
-- new term is a slow knoll noise, six blocks either way, so the ground
-- rolls a little more openly here than in the woodland. The brooks are the
-- gullies' own floors with water in them, laid by the terraced fluid fill
-- the rivers use — no channel of its own to cut, which is what "no steep
-- gullies or shear cuts" asks for.
--
-- THE COLOUR GRADIENTS. The four flowers are four cover fills that share
-- one slow wave noise: each takes a band of it, and the bands overlap at
-- their edges, so a walk across the meadow goes allium to poppy to peony
-- to bluebell and back, in sweeps a hundred blocks wide, with the colours
-- mixing where two bands meet. Each takes the columns the GRASS does not
-- (the same trick the meadow flowers use, biomes.lua): the engine's cover
-- fill would stack a second run on the first inside a block.
--
-- New nodes: apple and cherry wood, leaves and blossom*, birch leaves, and
-- the four flowers*. The birch's log is the woodland's; the mulch is the
-- Taiga's; the stones are `stone` under `moss`.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "flower_forest"
local WATER = "tiamat_default_world:water"

-- The shape.
local KNOLL_FREQ, KNOLL_AMP = 1 / 180, 0.006             -- the knolls: six blocks either way, over a couple of hundred
local BROOK_AT = 0.74                                    -- the gully depth a brook's water reaches: the deepest quarter of it
local BROOK_BED = 0.66                                   -- and the pebble bed under and beside it
local SEEP_FREQ, SEEP_MIN = 1 / 30, 0.30                 -- spring seeps pooling in the low hollows

-- The surface.
local MULCH_FREQ, MULCH_MIN = 1 / 11, 0.30               -- small patches of rich dark mulch
local STONE_FREQ, STONE_MIN = 1 / 13, 0.38               -- moss-dusted stones half-buried in the ground
local GRASS_FREQ, GRASS_MIN = 1.5, 0.26                  -- the grass takes the high side of this noise: 60% fewer columns than the first cut (2026-09-16)
local FLOWER_MIN = 0.20                                  -- and the flowers the low fifth of it
local THIN_FREQ, THIN_MIN = 1.3, 0.28                    -- thinned by a second, independent noise to 40% of that: 60% fewer than the first cut (2026-09-16).
                                                         -- A threshold alone could not do it: one octave of a fine noise sits AT the clamp an eighth of the time, so
                                                         -- raising the cut from 0.20 to 0.35 took only a third of the flowers away, not the three fifths asked for.
local WAVE_FREQ = 1 / 110                                -- the colour gradient's own wave
-- Each flower's band of the wave, overlapping at the edges so the colours
-- mix where two meet.
local BANDS = {
    allium   = { -0.60, -0.20 },
    poppy    = { -0.26, -0.01 },
    peony    = { -0.06,  0.21 },
    bluebell = {  0.16,  0.60 },
}

-- The trees: cell, share of squares, salt. The groves are a slow noise;
-- inside one the cells are dense, outside it there are no trees at all,
-- which is what leaves the sunlit clearings between them.
local GROVE_FREQ, GROVE_MIN = 1 / 95, 0.15               -- the groves are the same size and further apart: the sunlit gaps between them are about three quarters wider (2026-09-16)
local APPLE_CELL, APPLE_SQUARES = 6, 0.42
local CHERRY_CELL, CHERRY_SQUARES = 7, 0.38
local BIRCH_CELL, BIRCH_SQUARES = 6, 0.40
local LOG_CELL, LOG_SQUARES = 34, 0.30

-- ------------------------------------------------------------ the shape

-- The knolls, and where this biome stands: the Long Shore's wet half.
function shape.knoll_terms()
    return n.noise("ff_knoll", KNOLL_FREQ, 2, KNOLL_AMP)
end
-- **Not gated by the province**, unlike the Dunes' terms: a knoll is six
-- blocks of gentle roll over two hundred, and the Temperate Woodlands on
-- the other side of the line reads no differently for having them. That
-- saves the six operations the gate costs in the world's deepest program
-- (`temperate_shore`, 991 of 1,024 with the Dunes' gate in it).
function shape.knoll_weight()
    if tdw.config.everywhere == ID then
        return n.const(1.0)
    end
    local first, last = tdw.layers.ring_by_id.temperate, tdw.layers.ring_by_id.shore
    return n.mul(n.clamp(n.mul(shape.ring(first.u[1], last.u[2]), n.const(1.0 / 0.010)), 0.0, 1.0),
        n.sub(n.const(1.0), shape.dry_weight()))
end

tdw.biomes[ID].ring_mode = "temperate"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.dirt

-- ------------------------------------------------------------ the trees

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "flower_forest_template:" .. name)
end
local PRIORITY = {
    [blocks.apple_log] = 1, [blocks.cherry_log] = 1, [blocks.birch_log] = 1, [blocks.moss] = 1,
}

-- A crown: a rough ball of leaves with blossom thrown through it — two or
-- three smaller blobs of blossom off the same centre, so the flower is in
-- the canopy rather than a shell round it.
local function crown(rng, leaves, blossom, x, y, z, r, flat)
    schem.push_ellipsoid(leaves, x, y, z, r, r * flat, r, { rough = 0.3, blind = true })
    for _ = 1, 2 + rng:below(2) do
        local d = schem.DIR16[rng:below(16) + 1]
        local off = r * (0.35 + rng:below(4) * 0.12)
        schem.push_ellipsoid(blossom, x + d[1] * off, y + (rng:below(5) - 2) * 0.3 * r * flat, z + d[2] * off,
            r * 0.5, r * flat * 0.55, r * 0.5, { rough = 0.45, blind = true })
    end
end

-- A bearing apple: a short crooked bole that forks low into three or four
-- limbs, each ending in its own lump of crown — the shape of an orchard
-- tree left to itself.
local function apple(rng)
    schem.record_begin()
    local tall = 2.4 + rng:below(4) * 0.35
    local lean = schem.DIR16[rng:below(16) + 1]
    local bole = {
        { 0.5, -1.5, 0.5, 0.72 },
        { 0.5 + lean[1] * 0.2, tall * 0.5, 0.5 + lean[2] * 0.2, 0.55 },
        { 0.5 + lean[1] * 0.35, tall, 0.5 + lean[2] * 0.35, 0.48 },
    }
    schem.push_path(blocks.apple_log, bole, BLIND)
    local top = bole[#bole]
    local limbs = 3 + rng:below(2)
    local first = rng:below(16)
    for i = 0, limbs - 1 do
        local d = schem.DIR16[(first + i * 16 // limbs + rng:below(2)) % 16 + 1]
        local reach = 1.6 + rng:below(4) * 0.35
        local rise = 1.8 + rng:below(4) * 0.4
        local tip = { top[1] + d[1] * reach, top[2] + rise, top[3] + d[2] * reach, 0.24 }
        schem.push_path(blocks.apple_log, { { top[1], top[2], top[3], 0.4 },
            { top[1] + d[1] * reach * 0.5, top[2] + rise * 0.6, top[3] + d[2] * reach * 0.5, 0.32 }, tip }, BLIND)
        crown(rng, blocks.apple_leaves, blocks.apple_blossom, tip[1], tip[2] + 0.8, tip[3], 2.0 + rng:below(3) * 0.35, 0.8)
    end
    return schem.record_schematic(PRIORITY)
end

-- A wild cherry: taller, leaning toward the light, its crown high and
-- spreading, with a heavier load of blossom than the apple.
local function cherry(rng)
    schem.record_begin()
    local tall = 5 + rng:below(4)
    local lean = schem.DIR16[rng:below(16) + 1]
    local over = 0.8 + rng:below(3) * 0.4
    local trunk = {
        { 0.5, -1.5, 0.5, 0.66 },
        { 0.5 + lean[1] * over * 0.3, tall * 0.45, 0.5 + lean[2] * over * 0.3, 0.5 },
        { 0.5 + lean[1] * over, tall, 0.5 + lean[2] * over, 0.36 },
    }
    schem.push_path(blocks.cherry_log, trunk, BLIND)
    local top = trunk[#trunk]
    local limbs = 3 + rng:below(3)
    local first = rng:below(16)
    for i = 0, limbs - 1 do
        local d = schem.DIR16[(first + i * 16 // limbs + rng:below(2)) % 16 + 1]
        local reach = 2.0 + rng:below(4) * 0.4
        local tip = { top[1] + d[1] * reach, top[2] + 1.2 + rng:below(3) * 0.4, top[3] + d[2] * reach, 0.22 }
        schem.push_path(blocks.cherry_log, { { top[1], top[2], top[3], 0.34 }, tip }, BLIND)
        crown(rng, blocks.cherry_leaves, blocks.cherry_blossom, tip[1], tip[2] + 0.7, tip[3], 2.2 + rng:below(3) * 0.35, 0.75)
    end
    crown(rng, blocks.cherry_leaves, blocks.cherry_blossom, top[1], top[2] + 1.6, top[3], 2.4 + rng:below(3) * 0.3, 0.7)
    return schem.record_schematic(PRIORITY)
end

-- A birch: slim, straight, pale, with a narrow crown high up and a few
-- short limbs under it.
local function birch(rng)
    schem.record_begin()
    local tall = 7 + rng:below(5)
    local trunk = { { 0.5, -1.5, 0.5, 0.5 } }
    local x, z = 0.5, 0.5
    for i = 1, 3 do
        local t = i / 3
        x = x + (rng:below(3) - 1) * 0.15
        z = z + (rng:below(3) - 1) * 0.15
        trunk[#trunk + 1] = { x, t * tall, z, 0.44 - 0.2 * t }
    end
    schem.push_path(blocks.birch_log, trunk, BLIND)
    local top = trunk[#trunk]
    for i = 1, 2 + rng:below(2) do
        local d = schem.DIR16[rng:below(16) + 1]
        local h = tall * (0.55 + rng:below(35) / 100)
        local bx, by, bz = schem.path_point(trunk, h)
        local reach = 1.2 + rng:below(3) * 0.4
        schem.push_path(blocks.birch_log, { { bx, by, bz, 0.22 },
            { bx + d[1] * reach, by + 1.0 + rng:below(3) * 0.3, bz + d[2] * reach, 0.14 } }, BLIND)
        schem.push_ellipsoid(blocks.birch_leaves, bx + d[1] * reach, by + 1.6, bz + d[2] * reach,
            1.5 + rng:below(3) * 0.25, 1.3, 1.5 + rng:below(3) * 0.25, { rough = 0.35, blind = true })
    end
    schem.push_ellipsoid(blocks.birch_leaves, top[1], top[2] + 1.0, top[3],
        2.0 + rng:below(3) * 0.3, 2.4, 2.0 + rng:below(3) * 0.3, { rough = 0.3, blind = true })
    return schem.record_schematic(PRIORITY)
end

-- A fallen rotting blossom log: a bole lying half sunk, mossed along its
-- top, with blossom fallen over it and a stub of branch at one end.
local function fallen_log(rng)
    schem.record_begin()
    local length = 4 + rng:below(5)
    local d = schem.DIR16[rng:below(16) + 1]
    local half = length / 2
    local wood = rng:below(2) == 0 and blocks.apple_log or blocks.cherry_log
    local blossom = wood == blocks.apple_log and blocks.apple_blossom or blocks.cherry_blossom
    local ax, az = 0.5 - d[1] * half, 0.5 - d[2] * half
    local bx, bz = 0.5 + d[1] * half, 0.5 + d[2] * half
    schem.push_path(wood, { { ax, 0.3, az, 0.85 }, { bx, 0.15, bz, 0.7 } }, BLIND)
    schem.push_path(blocks.moss, { { ax, 0.95, az, 0.7 }, { bx, 0.75, bz, 0.6 } }, { rough = 0.4, blind = true })
    for _ = 1, 2 + rng:below(3) do
        local t = (rng:below(9) - 4) / 8
        schem.push_ellipsoid(blossom, 0.5 + d[1] * half * t * 2, 0.9, 0.5 + d[2] * half * t * 2,
            0.9, 0.5, 0.9, { rough = 0.5, blind = true })
    end
    local s = schem.DIR16[rng:below(16) + 1]
    schem.push_path(wood, { { bx, 0.4, bz, 0.4 }, { bx + s[1] * 1.6, 1.4, bz + s[2] * 1.6, 0.2 } }, BLIND)
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { apples = {}, cherries = {}, birches = {}, logs = {} }
    if not game.schematic_shapes then
        BUILT = out
        return out
    end
    for i = 1, 5 do out.apples[i] = apple(rng_for("apple:" .. i)) end
    for i = 1, 5 do out.cherries[i] = cherry(rng_for("cherry:" .. i)) end
    for i = 1, 5 do out.birches[i] = birch(rng_for("birch:" .. i)) end
    for i = 1, 4 do out.logs[i] = fallen_log(rng_for("log:" .. i)) end
    local parts = {}
    for key, list in pairs(out) do
        local sum = 0
        for _, one in ipairs(list) do sum = sum + one:len() end
        parts[#parts + 1] = string.format("%d %s (%d blocks)", #list, key, sum)
    end
    game.log("tiamat_default_world flower forest: cut " .. table.concat(parts, ", "))
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
    -- The gully's own depth, 0 on the flat and 1 on a floor: the brooks
    -- and their beds are bands of it. `shape.gully_floor` is that, less
    -- 0.6, so the depth back is one addition.
    local function gully()
        return n.add(shape.gully_floor(), n.const(0.6))
    end
    local conditions = {
        -- 1: lush grass over loam.
        n.const(1.0),
        -- 2: small patches of rich dark mulch.
        n.sub(n.noise("ff_mulch", MULCH_FREQ, 2, 1.0), n.const(MULCH_MIN)),
        -- 3: a smooth stone half-buried, under a dusting of moss.
        n.sub(n.noise("ff_stone", STONE_FREQ, 2, 1.0), n.const(STONE_MIN)),
        -- 4: a brook's pebble bed, and the wet gravel of its banks.
        n.sub(gully(), n.const(BROOK_BED)),
        -- 5: a spring seep pooling in a low hollow: wet ground, no channel.
        n.min(n.sub(gully(), n.const(0.35)), n.sub(n.noise("ff_seep", SEEP_FREQ, 2, 1.0), n.const(SEEP_MIN))),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    local mask = tdw.biome_mask(n, ID)
    if mask then
        code = n.mul(code, step(mask))
    end
    if shape.sea_exclude then
        -- Not on a seabed (2026-09-16), as the woodland and the grassland.
        code = n.mul(code, step(shape.sea_exclude(n.const(1.0), 20.0)))
    end
    local depth = shape.compile("biome.flowers.depth", shape.terrain(false))
    local codes = shape.compile("biome.flowers.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = shape.SKIN_TOP, material = blocks.grass },
        { code = 1, from = shape.SKIN_TOP, to = 4 * km, material = blocks.dirt },
        { code = 2, to = shape.SKIN_TOP, material = blocks.mulch },
        { code = 2, from = shape.SKIN_TOP, to = 4 * km, material = blocks.dirt },
        { code = 3, to = 1 * km, material = blocks.moss },
        { code = 3, from = 1 * km, to = 4 * km, material = blocks.stone },
        { code = 4, to = 2 * km, material = blocks.gravel },
        { code = 4, from = 2 * km, to = 4 * km, material = blocks.dirt },
        { code = 5, to = 1 * km, material = blocks.mud },
        { code = 5, from = 1 * km, to = 4 * km, material = blocks.dirt },
    }
    -- The grass takes the high side of its own noise; the flowers take the
    -- low side, split between them by the wave. Neither stands on a brook's
    -- bed or in a seep.
    local function dry_ground(field)
        return n.min(field, n.sub(n.const(BROOK_BED - 0.04), gully()))
    end
    -- The grass is thinned by its own second noise, as the flowers are:
    -- both are 40% of what they were (2026-09-16, "reduce the amount of
    -- flowers and grass in the flower forest by 60%").
    local grass = shape.compile("biome.flowers.grass", masked(off_river(dry_ground(
        n.min(n.sub(n.noise("ff_grass", GRASS_FREQ, 1, 1.0), n.const(GRASS_MIN)),
            n.sub(n.noise("ff_grass_thin", THIN_FREQ, 1, 1.0), n.const(THIN_MIN)))))))
    local function off_grass()
        return n.min(n.sub(n.mul(n.noise("ff_grass", GRASS_FREQ, 1, 1.0), n.const(-1.0)), n.const(FLOWER_MIN)),
            n.sub(n.noise("ff_thin", THIN_FREQ, 1, 1.0), n.const(THIN_MIN)))
    end
    local function flower(name)
        local band = BANDS[name]
        local wave = n.noise("ff_wave", WAVE_FREQ, 2, 1.0)
        return shape.compile("biome.flowers." .. name, masked(off_river(dry_ground(n.min(off_grass(),
            n.min(n.sub(wave, n.const(band[1])), n.sub(n.const(band[2]), n.noise("ff_wave", WAVE_FREQ, 2, 1.0))))))))
    end
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
        { cover = blocks.tall_grass, cells = 2, take = grass },
        { cover = blocks.allium, cells = 3, take = flower("allium") },
        { cover = blocks.peony, cells = 3, take = flower("peony") },
        { cover = blocks.poppy, cells = 2, take = flower("poppy") },
        { cover = blocks.bluebell, cells = 2, take = flower("bluebell") },
    }
    if game.schematic_shapes then
        local built = structures()
        local function grove()
            return n.sub(n.noise("ff_grove", GROVE_FREQ, 2, 1.0), n.const(GROVE_MIN))
        end
        local function scatter(name, list, field, cell, chance, salt)
            if #list > 0 then
                fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                    salt = salt, sink = 1,
                    stand = shape.compile("biome.flowers.stand_" .. name, masked(off_river(dry_ground(field)))) }
            end
        end
        -- The groves: apples and cherries together in them, birches on
        -- their edges, where the grove noise is only just positive.
        scatter("apple", built.apples, n.sub(grove(), n.const(0.06)), APPLE_CELL, APPLE_SQUARES, 161)
        scatter("cherry", built.cherries, n.sub(grove(), n.const(0.10)), CHERRY_CELL, CHERRY_SQUARES, 162)
        scatter("birch", built.birches, n.min(grove(), n.sub(n.const(0.12), grove())), BIRCH_CELL, BIRCH_SQUARES, 163)
        scatter("log", built.logs, grove(), LOG_CELL, LOG_SQUARES, 164)
    end
    -- The brooks: water in the deepest quarter of the gullies, most of the
    -- gully's depth under the ground's own height beside it
    -- (`shape.gully_water_level`: on the smooth ground until 2026-09-18,
    -- and it poured out where the detail dipped). The bed under it is the
    -- pebbles of code 4, and the banks are grass — no channel is cut for
    -- it, which is the brief's "no shear cuts".
    --
    -- **`within` reads no height** (2026-09-23), the river's treatment
    -- (river_valleys.lua). The engine reads a terraced fill's fields on the
    -- one plane y = 0.5 for the whole world, and since engine ask 35 a
    -- `within` whose bounds disagree between that plane and the chunk's
    -- slab is an ERROR — the guard (hooks.lua) takes it as "no water
    -- here", and a brook chunk skipped dry. The gully term was the worst
    -- reader of the lot: the gully noise is 3D and unstretched, so tens of
    -- thousands of blocks down on that plane it draws a DIFFERENT set of lines
    -- than the ground carries, and a brook held water only where the two
    -- patterns happened to cross. It is dropped, and exactly: the level is
    -- the ground plus GULLY_DEPTH * (gully - BROOK_AT), so there is room
    -- under it precisely where the gully the TERRAIN carries is deeper
    -- than BROOK_AT — the channel bounds its own water by construction,
    -- and the within's copy of that test only ever said it again, at the
    -- wrong altitude.
    --
    -- "The terrain carries the gully" is that proof's whole load, and
    -- two grounds do NOT carry it, so the within takes a flat term for
    -- each. In a river valley the terrain is min'd with the trough — the
    -- smooth height less the valley's depth, no gully term — yet the
    -- level still restores the full cut, so along every gully line
    -- crossing a valley slope the brook stood up to GULLY_DEPTH * (1 -
    -- BROOK_AT), 0.65 blocks, proud of ground that has no channel:
    -- partial blocks, spills by the fluid contract, woken on load and
    -- running downhill — the exact fault `gully_water_level` was built
    -- to end. The course is kept out to the rim (its contour reads x and
    -- z alone), as the cover and the stands already keep off it. And
    -- within the coast's reach the shore programs lift low ground to the
    -- water's plane (`seas.floor`), erasing channels the level then
    -- re-cuts, so in a "_shore" program the brooks stop over the floor
    -- clamp's whole reach (PLAIN_W + FADE) rather than the 20-block hem
    -- — the sea map reads x and z alone too.
    --
    -- What stays reads x and z alone, or the flat-stretched hair the
    -- volcanic lava keeps (volcanic_foothills.lua): bands on the TRUE
    -- radius for the catalogue's two spans, the smooth humidity, the
    -- province noise and the sea map. Each band takes the wobble's whole
    -- reach (u_biome = u * (1 ± SHARE)) on the side whose programs carry
    -- the temperate pair at full strength — the ember side of the
    -- temperate ring, the verdant side of the Long Shore — since a brook
    -- past the line there still runs in a real channel; and stops where
    -- the ring surely begins on the side the pair fades out — under the
    -- cold terms at the frost edge, under the tundra's across the Hem's
    -- blend — where a channel the terrain no longer cuts would stand its
    -- water proud. The humidity is the smooth field at the bare split, in
    -- place of `humidity_mask`, whose dither is an UNSTRETCHED noise — at
    -- the slice it was speckle from nowhere. A brook proud of its banks
    -- needs the pair under 0.26 of full strength (gully * (1 - pair) >
    -- BROOK_AT), and at the bare split the pair still stands at half:
    -- nothing perches.
    local level = shape.gully_water_level(BROOK_AT)
    local within
    if tdw.config.everywhere then
        within = n.const(1.0)
    else
        local SHARE = shape.RING_WOBBLE_SHARE
        local function flat_band(lo, hi)
            local mid, half = (lo + hi) / 2, (hi - lo) / 2
            return n.sub(n.const(half), n.abs(n.sub(shape.sub.u(), n.const(mid))))
        end
        local t, sh = tdw.layers.ring_by_id.temperate, tdw.layers.ring_by_id.shore
        within = n.max(flat_band(t.u[1] / (1.0 - SHARE), t.u[2] / (1.0 - SHARE)),
            flat_band(sh.u[1] / (1.0 + SHARE), sh.u[2] / (1.0 + SHARE)))
        within = n.min(within, n.sub(shape.humidity(), n.const(shape.HUMIDITY_SPLIT)))
        within = n.min(within, shape.province_mask("b", 0.383))
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
        level = shape.compile("biome.flowers.brook_level", level),
        within = shape.compile("biome.flowers.brook_within", within),
    }
    return fills
end)
