-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 1.8 Deep Ocean: abyssal plains under a hundred blocks of sea.
--
-- The brief (2026-09-14):
--
--   Topography: expansive abyssal plains 60 to 120+ blocks below sea level,
--   broken by sudden submarine trenches that drop into near-bottomless
--   chasms, solitary volcanic guyots (flat-topped seamounts), and rolling
--   pillow-lava ridges.
--   Seafloor: sand, white sand, mud, dark basalt crusts, rippled deep-sea
--   gravel drifts, and dense pockets of fine dark sand around tectonic
--   cracks with magma in them.
--   Flora: completely absent across the deep muddy plains (total light
--   extinction), except around vents and rock chimneys, where all kinds of
--   sea growth flourish.
--   Accents: sunken whale skeletons broken across basalt reefs, underwater
--   brine pools, and towering basalt pillars that rise from the abyss to
--   within a few blocks of the surface. New material: Bone.
--
-- THE SEA is the world's (seas.lua, 2026-09-15): every sea's floor past the
-- coast's shelf is this biome's. Its floor is `shape.ocean_floor`, km over
-- the POOL'S level — the coast's `shape.sea_deep` blends the shelf's foot
-- into it and stands it on the level the sea map gives. Nothing here knows
-- the dome any more.
--
-- THE FLOOR, in km over the sea (negative is under it): a plain 60 to 120
-- blocks down wandering on a slow noise; guyots rising 55 blocks to flat
-- tops where a slower noise saturates; pillow-lava ridges along a contour,
-- lumpy with pillows; trenches 350 blocks deep with three-block walls along
-- another contour, in stretches; rare basalt pillars where two noises are
-- both high, whose tops stand four blocks under the surface; brine pools
-- four blocks deep; tectonic cracks a block and a half wide with magma in
-- their floors; and gravel drifts rippled into low ridges. The materials
-- read the same weights back.
--
-- THE BRINE is a second fluid, `brine`. The engine's fluids do not mix — a
-- block holding one accepts none of another — so a pool of brine laid in a
-- hollow under the sea stays a pool, with the sea over it.
--
-- Stand-ins until the designer names nodes: the white sand is `stone`
-- (and the salt crust round a brine pool), the fine dark sand `black_mud`.
-- The brine is drawn as the `water` block.

local blocks = tdw.blocks
local shape = tdw.shape
local seas = tdw.seas
local n = shape.node
local schem = tdw.schem

local ID = "deep_ocean"

-- Thresholds are against the noise as measured (see the rainforest's file):
-- two octaves are over 0.2 on 27% of the ground, 0.3 on 18%, 0.35 on 14%,
-- and at the +0.5 clamp on 6%. Rare things are two noises both high.
local PLAIN_KM, PLAIN_VARY, PLAIN_FREQ = -0.090, 0.060, 1 / 2000   -- 60 to 120 blocks down
local UNDULATE_FREQ, UNDULATE_AMP = 1 / 300, 0.008                  -- about four blocks either way
local GUYOT_FREQ, GUYOT_MIN, GUYOT_EDGE, GUYOT_H = 1 / 700, 0.30, 5.0, 0.055
local RIDGE_FREQ, RIDGE_W, RIDGE_H = 1 / 520, 26.0, 0.016
local PILLOW_FREQ, PILLOW_AMP = 1 / 4, 0.005
local TRENCH_FREQ, TRENCH_W, TRENCH_WALL, TRENCH_D = 1 / 1400, 16.0, 3.0, 0.350
local TRENCH_SEG_FREQ, TRENCH_SEG_MIN = 1 / 1800, 0.05
local PILLAR_FREQ, PILLAR_MIN, PILLAR_EDGE, PILLAR_TOP = 1 / 160, 0.33, 40.0, -0.004
local CRACK_FREQ, CRACK_W, CRACK_D = 1 / 240, 1.3, 0.005
local CRACK_SEG_FREQ, CRACK_SEG_MIN = 1 / 300, 0.15
local POOL_FREQ, POOL_MIN, POOL_EDGE, POOL_D = 1 / 110, 0.33, 10.0, 0.004
local DRIFT_FREQ, DRIFT_MIN, RIPPLE_FREQ, RIPPLE_H = 1 / 45, 0.35, 1 / 7, 0.0008
local SAND_FREQ, SAND_MIN = 1 / 60, 0.35
local REEF_FREQ, REEF_MIN = 1 / 80, 0.42                 -- two octaves: a tenth of the floor
local SHALLOW = 0.020                                   -- km: a pillar's top this near the surface has sea growth
-- The structures: cell, share of squares, salt.
local VENT_CELL, VENT_SQUARES, VENT_SALT = 26, 0.9, 81
local WHALE_CELL, WHALE_SQUARES, WHALE_SALT = 64, 0.25, 82     -- one a square of 64 in four: the most cell the scatter takes
local KELP_CELL, KELP_SQUARES, KELP_SALT = 4, 0.4, 83

-- ------------------------------------------------------------ the floor

local function ys()
    return n.mul(n.sub(n.Y(), n.const(shape.Y0)), n.const(shape.SCALE))
end
-- y over the pool's level, km.
local function over_sea()
    return n.sub(ys(), seas.level())
end
local function gate(stream, freq, min, edge)
    return n.clamp(n.mul(n.sub(n.noise(stream, freq, 1, 1.0), n.const(min)), n.const(edge)), 0.0, 1.0)
end
-- Two noises both over `min`: rare, round-ish, steep-sided.
local function both(stream, freq, min, edge)
    return n.clamp(n.mul(n.min(n.sub(n.noise(stream, freq, 2, 1.0), n.const(min)),
        n.sub(n.noise(stream .. "_b", freq, 2, 1.0), n.const(min))), n.const(edge)), 0.0, 1.0)
end
local function guyot_w()
    return n.clamp(n.mul(n.sub(n.noise("oc_guyot", GUYOT_FREQ, 2, 1.0), n.const(GUYOT_MIN)), n.const(GUYOT_EDGE)), 0.0, 1.0)
end
local function ridge_w()
    return n.clamp(n.mul(n.add(n.contour("oc_ridge", RIDGE_FREQ, 2), n.const(-RIDGE_W)), n.const(-1.4 / RIDGE_W)), 0.0, 1.0)
end
local function trench_w()
    local line = n.clamp(n.mul(n.add(n.contour("oc_trench", TRENCH_FREQ, 2), n.const(-TRENCH_W)), n.const(-1.0 / TRENCH_WALL)), 0.0, 1.0)
    return n.mul(line, gate("oc_trench_seg", TRENCH_SEG_FREQ, TRENCH_SEG_MIN, 6.0))
end
local function pillar_w()
    return both("oc_pillar", PILLAR_FREQ, PILLAR_MIN, PILLAR_EDGE)
end
local function pool_w()
    return both("oc_pool", POOL_FREQ, POOL_MIN, POOL_EDGE)
end
-- The distance to a crack's line, blocks, and whether this stretch of it is live.
local function crack_d()
    return n.contour("oc_crack", CRACK_FREQ, 2)
end
local function crack_live()
    return gate("oc_crack_seg", CRACK_SEG_FREQ, CRACK_SEG_MIN, 8.0)
end
-- Positive within `blocks` of a live crack.
local function near_crack(blocks_in, live_min)
    return n.min(n.add(n.mul(crack_d(), n.const(-1.0)), n.const(blocks_in)), n.sub(crack_live(), n.const(live_min)))
end
local function drift_w()
    return gate("oc_drift", DRIFT_FREQ, DRIFT_MIN, 6.0)
end
-- The plain's own height, km over the sea: the level a brine pool's
-- surface is read from as well as the floor.
local function plain()
    return n.add(n.noise("oc_plain", PLAIN_FREQ, 2, PLAIN_VARY), n.const(PLAIN_KM))
end

-- The ocean's floor, km over the pool's level (negative). The coast's
-- `shape.sea_deep` stands it on the level.
function shape.ocean_floor()
    local floor = n.add(plain(), n.noise("oc_undulate", UNDULATE_FREQ, 2, UNDULATE_AMP))
    floor = n.add(floor, n.mul(guyot_w(), n.const(GUYOT_H)))
    floor = n.add(floor, n.mul(ridge_w(), n.const(RIDGE_H)))
    floor = n.add(floor, n.mul(n.noise("oc_pillow", PILLOW_FREQ, 1, PILLOW_AMP), ridge_w()))
    floor = n.add(floor, n.mul(n.mul(n.clamp(n.sub(n.const(1.0), n.mul(n.abs(n.noise("oc_ripple", RIPPLE_FREQ, 1, 1.0)), n.const(4.0))), 0.0, 1.0),
        drift_w()), n.const(RIPPLE_H)))
    floor = n.sub(floor, n.mul(trench_w(), n.const(TRENCH_D)))
    floor = n.sub(floor, n.mul(pool_w(), n.const(POOL_D)))
    floor = n.sub(floor, n.mul(n.mul(n.clamp(n.mul(n.add(crack_d(), n.const(-CRACK_W)), n.const(-2.0)), 0.0, 1.0), crack_live()),
        n.const(CRACK_D)))
    -- A pillar: the floor pulled up to PILLAR_TOP where its weight is 1, as
    -- `floor * (1 - w) + TOP * w`, so the floor is evaluated once.
    local w = pillar_w()
    return n.add(n.mul(floor, n.add(n.mul(w, n.const(-1.0)), n.const(1.0))), n.mul(pillar_w(), n.const(PILLAR_TOP)))
end

tdw.biomes[ID].ring_mode = "temperate"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.mud
-- Where this biome is: past the shelf of any sea (seas.lua).
tdw.biomes[ID].present = function(pos)
    return seas.reaches(pos, seas.SHELF_END)
end
tdw.biomes[ID].locate = function(px, pz, seed)
    -- Not in the Abyssal Trench's province (3.9).
    return seas.locate(px, pz, seed, seas.DEEP_FROM + 20.0, seas.DIST_FAR, nil, nil, nil, function(x, z)
        return not (tdw.abyss_zone and tdw.abyss_zone(x, z))
    end)
end

-- ------------------------------------------------------------ the structures

local FULL = game.OCCUPANCY_FULL
local BLIND = { blind = true }

-- A vent: one to three rock chimneys eight to eighteen blocks tall, leaning a
-- little, each with a hot mouth of magma, crusted with barnacles and moss up
-- their flanks, and a garden of kelp and seagrass round their feet.
local function vent(rng)
    schem.record_begin()
    local count = 1 + rng:below(3)
    for i = 1, count do
        local ox, oz = 0.5, 0.5
        if i > 1 then
            ox, oz = 0.5 + rng:below(7) - 3, 0.5 + rng:below(7) - 3
        end
        local tall = 8 + rng:below(11)
        local d = schem.DIR16[rng:below(16) + 1]
        local chimney = {
            { ox, -1.5, oz, 1.7 },
            { ox + d[1] * 0.4, tall * 0.45, oz + d[2] * 0.4, 1.15 },
            { ox + d[1] * 0.9, tall, oz + d[2] * 0.9, 0.55 },
        }
        schem.push_path(blocks.dark_basalt, chimney, BLIND)
        local top = chimney[3]
        schem.push_path(blocks.magma, { { top[1], tall - 3.0, top[3], 0.4 }, { top[1], tall + 0.1, top[3], 0.35 } }, BLIND)
        for _ = 1, 4 + rng:below(3) do
            local px, py, pz, pr = schem.path_point(chimney, rng:below(tall))
            local w = schem.DIR16[rng:below(16) + 1]
            local crust = rng:below(2) == 0 and blocks.barnacles or blocks.ocean_moss
            schem.push_ellipsoid(crust, px + w[1] * pr, py, pz + w[2] * pr, 1.1, 1.4, 1.1, { rough = 0.3, blind = true })
        end
    end
    for _ = 1, 10 + rng:below(9) do
        local w = schem.DIR16[rng:below(16) + 1]
        local r = 2.5 + rng:below(5)
        local x, z = 0.5 + w[1] * r, 0.5 + w[2] * r
        if rng:below(3) == 0 then
            schem.push_path(blocks.kelp, { { x, 0.15, z, 0.28 }, { x, 3.0 + rng:below(8), z, 0.24 } }, BLIND)
        else
            schem.push_path(blocks.seagrass, { { x, 0.15, z, 0.28 }, { x, 1.0 + rng:below(2), z, 0.24 } }, BLIND)
        end
    end
    return schem.record_schematic({ [blocks.dark_basalt] = 1, [blocks.magma] = 2 })
end

-- A whale skeleton, broken across a basalt reef: a spine in three pieces,
-- the middle one knocked aside; ribs up the front half, some missing and
-- some collapsed flat; a skull; the jaws fallen apart; and reef boulders
-- half sunk round it. Everything lies at the floor, half in the sand.
local function whale(rng)
    schem.record_begin()
    local length = 24 + rng:below(11)
    local heading = rng:below(16)
    local d, side = schem.DIR16[heading + 1], schem.DIR16[(heading + 4) % 16 + 1]
    local function at(t, s, y)
        return 0.5 + d[1] * (t - length / 2) + side[1] * s, y, 0.5 + d[2] * (t - length / 2) + side[2] * s
    end
    local breaks = { 0, length * 0.3 + rng:below(4), length * 0.62 + rng:below(4), length }
    for b = 1, #breaks - 1 do
        local shift = b == 2 and (rng:below(2) * 2 - 1) * (1.0 + rng:below(3) * 0.4) or 0.0
        local x0, y0, z0 = at(breaks[b] + 0.6, shift, 0.35)
        local x1, y1, z1 = at(breaks[b + 1] - 0.6, shift * 0.5 + (rng:below(3) - 1) * 0.6, 0.45)
        schem.push_path(blocks.bone, { { x0, y0, z0, 0.55 }, { x1, y1, z1, 0.6 } }, BLIND)
    end
    local t = length * 0.35
    while t < length * 0.85 do
        for s = -1, 1, 2 do
            local roll = rng:below(10)
            if roll >= 3 then
                local collapsed = roll < 5
                local bx, by, bz = at(t, 0, 0.5)
                local mx, my, mz = at(t + 0.3, s * 2.3, collapsed and 0.4 or 2.2 + rng:below(3) * 0.3)
                local tx, ty, tz = at(t + 0.6, s * (collapsed and 3.6 or 3.2), collapsed and 0.1 or -0.4)
                schem.push_path(blocks.bone, { { bx, by, bz, 0.3 }, { mx, my, mz, 0.28 }, { tx, ty, tz, 0.22 } }, BLIND)
            end
        end
        t = t + 1.6
    end
    local sx, sy, sz = at(length + 0.5, 0, 0.7)
    local ex, ey, ez = at(length + 4.5, 0, 0.5)
    schem.push_path(blocks.bone, { { sx, sy, sz, 1.5 }, { ex, ey, ez, 0.9 } }, BLIND)
    for s = -1, 1, 2 do
        local ax, ay, az = at(length + 1.0, s * 1.2, 0.2)
        local bx, by, bz = at(length + 8 + rng:below(2), s * (2.2 + rng:below(3) * 0.5), 0.1)
        schem.push_path(blocks.bone, { { ax, ay, az, 0.45 }, { bx, by, bz, 0.35 } }, BLIND)
    end
    for _ = 1, 4 + rng:below(4) do
        local x, y, z = at(rng:below(length + 6), (rng:below(9) - 4) * 1.2, -0.2)
        schem.push_ellipsoid(blocks.dark_basalt, x, y, z, 1.2 + rng:below(3) * 0.4, 0.9, 1.2 + rng:below(3) * 0.4, { rough = 0.3, blind = true })
    end
    return schem.record_schematic({ [blocks.bone] = 1 })
end

-- A stand of kelp: one column, its height the list's.
local function kelp(tall)
    local list = {}
    for dy = 0, tall - 1 do
        list[#list + 1] = { 0, dy, 0, blocks.kelp, (1 << 4) | (1 << 13) | (1 << 22) }
    end
    return game.schematic(list)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { vents = {}, whales = {}, kelp = {} }
    if not game.schematic_shapes then
        game.log("tiamot_default_world deep ocean: no game.schematic_shapes in this engine; no structures")
        BUILT = out
        return out
    end
    local function rng_for(name)
        return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "ocean_template:" .. name)
    end
    for i = 1, 6 do out.vents[i] = vent(rng_for("vent:" .. i)) end
    for i = 1, 4 do out.whales[i] = whale(rng_for("whale:" .. i)) end
    for i, tall in ipairs({ 5, 8, 11, 14 }) do out.kelp[i] = kelp(tall) end
    local parts = {}
    for _, key in ipairs({ "vents", "whales", "kelp" }) do
        local total = 0
        for _, one in ipairs(out[key]) do total = total + one:len() end
        parts[#parts + 1] = string.format("%d %s (%d blocks)", #out[key], key, total)
    end
    game.log("tiamot_default_world deep ocean: cut " .. table.concat(parts, ", "))
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

tdw.build_biome(ID, function(ctx)
    -- This biome's floor: past the coast's shelf.
    local function zone()
        local band = n.sub(seas.d_map(), n.const(seas.SHELF_END))
        -- Not the Abyssal Trench's province (3.9).
        return shape.off_abyss and n.min(band, n.mul(shape.off_abyss(), n.const(1000.0))) or band
    end
    local function masked(field)
        return n.min(field, zone())
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    -- A pillar's top near the surface, where there is light for sea growth.
    local function shallow_pillar()
        return n.min(n.sub(pillar_w(), n.const(0.5)), n.add(over_sea(), n.const(SHALLOW)))
    end
    local conditions = {
        -- 1: the plains: mud.
        n.const(1.0),
        -- 2: patches of sand.
        n.sub(n.noise("oc_sand", SAND_FREQ, 2, 1.0), n.const(SAND_MIN)),
        -- 3: rippled gravel drifts.
        n.sub(drift_w(), n.const(0.05)),
        -- 4: basalt crusts: the pillow ridges, the reefs, the guyots' flanks,
        -- the trenches' walls and the pillars.
        n.max(n.max(n.max(n.sub(ridge_w(), n.const(0.15)), n.sub(n.noise("oc_reef", REEF_FREQ, 2, 1.0), n.const(REEF_MIN))),
            n.max(n.sub(guyot_w(), n.const(0.3)), n.sub(trench_w(), n.const(0.05)))), n.sub(pillar_w(), n.const(0.2))),
        -- 5: white sand on a guyot's flat top.
        n.sub(guyot_w(), n.const(0.9)),
        -- 6: fine dark sand in dense pockets round a live crack.
        near_crack(14.0, 0.2),
        -- 7: the salt crust round a brine pool.
        n.min(n.sub(pool_w(), n.const(0.02)), n.sub(n.const(0.6), pool_w())),
        -- 8: the vent garden's crust near a crack: moss over basalt.
        near_crack(8.0, 0.4),
        -- 9: magma in the crack's floor.
        near_crack(CRACK_W + 0.6, 0.3),
        -- 10: barnacles on a pillar's top near the light.
        shallow_pillar(),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    code = n.mul(code, step(zone()))
    local depth = shape.compile("biome.ocean.depth", shape.terrain(false))
    local codes = shape.compile("biome.ocean.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 3 * km, material = blocks.mud },
        { code = 2, to = 3 * km, material = blocks.sand },
        { code = 3, to = 2 * km, material = blocks.gravel },
        { code = 3, from = 2 * km, to = 4 * km, material = blocks.mud },
        -- The basalt reaches far down: a pillar's sides, a trench's walls and a
        -- guyot's steep flanks are hundreds of blocks under the column's top.
        -- As far as the deepest of them, the trenches' 350, and twenty more
        -- (400 until 2026-09-18: no further into the ground than it shows).
        { code = 4, to = 370 * km, material = blocks.dark_basalt },
        { code = 5, to = 3 * km, material = blocks.stone },
        { code = 5, from = 3 * km, to = 370 * km, material = blocks.dark_basalt },
        { code = 6, to = 2 * km, material = blocks.black_mud },
        { code = 6, from = 2 * km, to = 5 * km, material = blocks.dark_basalt },
        { code = 7, to = 1 * km, material = blocks.stone },
        { code = 7, from = 1 * km, to = 3 * km, material = blocks.mud },
        { code = 8, to = 1 * km, material = blocks.ocean_moss },
        { code = 8, from = 1 * km, to = 5 * km, material = blocks.dark_basalt },
        { code = 9, to = 3 * km, material = blocks.magma },
        { code = 9, from = 3 * km, to = 8 * km, material = blocks.dark_basalt },
        { code = 10, to = 1 * km, material = blocks.barnacles },
        { code = 10, from = 1 * km, to = 370 * km, material = blocks.dark_basalt },
    }
    -- Seagrass only where there is growth: round a live crack's vents, and
    -- on a pillar's top near the light.
    local grass = shape.compile("biome.ocean.seagrass", masked(n.min(
        n.max(near_crack(18.0, 0.3), shallow_pillar()),
        n.sub(n.noise("oc_seagrass", 1.5, 1, 1.0), n.const(0.2)))))
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries },
        { cover = blocks.seagrass, cells = 3, take = grass },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, above)
            fills[#fills + 1] = { scatter = true, depth = depth, stand = shape.compile("biome.ocean.stand_" .. name, masked(field)),
                schematics = list, cell = cell, chance = chance, salt = salt, sink = 1, above = above }
        end
        scatter("vent", built.vents, near_crack(6.0, 0.4), VENT_CELL, VENT_SQUARES, VENT_SALT, 0.022)
        -- A whale on a reef, on the plain: not on a guyot's slope, in a
        -- trench or on a pillar.
        scatter("whale", built.whales, n.min(n.sub(n.noise("oc_reef", REEF_FREQ, 2, 1.0), n.const(REEF_MIN)),
            n.sub(n.const(0.05), n.max(n.max(guyot_w(), trench_w()), pillar_w()))), WHALE_CELL, WHALE_SQUARES, WHALE_SALT, 0.006)
        scatter("kelp", built.kelp, n.max(near_crack(12.0, 0.4), shallow_pillar()), KELP_CELL, KELP_SQUARES, KELP_SALT, 0.016)
    end
    -- The brine pools: a second fluid, laid per column a block and a bit
    -- under the plain's surface, inside the pool and nowhere a trench runs.
    -- After the sea, whose water it takes the place of.
    fills[#fills + 1] = {
        fluid = "tiamot_default_world:brine",
        level = shape.compile("biome.ocean.brine_level", n.add(n.mul(n.add(n.add(plain(), n.noise("oc_undulate", UNDULATE_FREQ, 2, UNDULATE_AMP)),
            seas.level()), n.const(1000.0)), n.const(shape.Y0 - 1.2))),
        within = shape.compile("biome.ocean.brine_within", masked(n.min(n.sub(pool_w(), n.const(0.05)), n.sub(n.const(0.05), trench_w())))),
    }
    return fills
end)
