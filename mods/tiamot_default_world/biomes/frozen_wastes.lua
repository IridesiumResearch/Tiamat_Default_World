-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 1.9 Frozen Wastes: Frostmoor, the frost ring's dry half.
--
-- The brief (2026-09-14):
--
--   Topography: expansive windswept permafrost plains interrupted by jagged
--   pressure ridges, sudden glacial crevasses, and towering serac ice spires
--   (10 to 25 blocks high). Rolling snow dunes with wind-sculpted sastrugi —
--   sharp, wave-like frozen ridges aligned with the prevailing blizzards.
--   Surface: snow, dense translucent blue glacial ice, and permafrost
--   polygons (frozen soil and frost-heaved gravel in geometric patterns).
--   Trees: nearly absent; solitary frozen snags or miniature copses, no
--   needles at all. No grass at all.
--   Ice: frozen cryo-lakes of deep clear ice* with blue ice below; sheer
--   vertical crevasses 15 to 30 blocks deep with slick blue ice walls.
--   Accents: wind-hollowed ice caves tunnelled beneath glaciers, massive
--   erratic boulders, and localised whiteout blizzards that pile snow
--   against windward structures.
--
-- PLACEMENT is the designer's choice (2026-09-14): Frostmoor, the frost
-- ring's dry half, taken from the alpine, which keeps the Crown and the
-- frost ring's wet half. The ground is `shape.frozen_terms`, cross-faded
-- into the alpine's mountains by `cold_terms` in shape.lua — wide, so the
-- range comes down to the plain over a kilometre or two.
--
-- THE WIND blows toward +x everywhere. The dunes are drawn out along it and
-- the sastrugi are ridges of a noise stretched six times along it, so they
-- run with the wind; a blizzard's drifts pile on the side of an obstacle the
-- wind comes from.
--
-- The engine has no friction per block, so the crevasses' ice walls are no
-- slicker than stone (engine-asks 27), and no particles for the whiteout
-- itself (item 20).

local blocks = tdw.blocks
local shape = tdw.shape
local n = shape.node
local schem = tdw.schem
local edits = tdw.edits

local ID = "frozen_wastes"

-- The ground, km over the dome. Thresholds against the measured noise: two
-- octaves over 0.3 on 18% of the ground, at the +0.5 clamp on 6%.
-- Smoothed by half and more on 2026-09-15 ("smooth out everything in
-- frozen wastes quite a bit"): the plain, the dunes, the sastrugi, the
-- ridges' height and their jag, the polygons' heave.
local PLAIN_FREQ, PLAIN_AMP = 1 / 1500, 0.011                        -- five or six blocks either way over kilometres
local DUNE_FREQ, DUNE_AMP, DUNE_STRETCH = 1 / 60, 0.0035, 3.0         -- under two blocks either way, three times as long downwind
local SNOW_FREQ, SNOW_MIN = 1 / 140, -0.05                           -- snowfields over a little more than half; the rest scoured bare
local SASTRUGI_FREQ, SASTRUGI_H, SASTRUGI_STRETCH = 1 / 8, 0.0005, 6.0
local RIDGE_FREQ, RIDGE_W, RIDGE_H = 1 / 480, 12.0, 0.005
local JAG_FREQ, JAG_AMP = 1 / 3, 0.003
local CREVASSE_FREQ, CREVASSE_W, CREVASSE_D, CREVASSE_VARY = 1 / 260, 1.6, 0.015, 0.015   -- 15 to 30 deep
local CREVASSE_SEG_FREQ, CREVASSE_SEG_MIN = 1 / 350, 0.10
local GLACIER_FREQ, GLACIER_MIN, GLACIER_EDGE, GLACIER_H = 1 / 420, 0.30, 6.0, 0.012
local CAVE_FREQ, CAVE_W, CAVE_LO, CAVE_HI, CAVE_CUT = 1 / 90, 2.6, 0.001, 0.0055, 0.03
local LAKE_FREQ, LAKE_MIN, LAKE_EDGE, LAKE_DROP = 1 / 380, 0.30, 10.0, 0.002
local POLY_FREQ, POLY_W, POLY_HEAVE = 1 / 11, 0.9, 0.00025
-- The structures: cell, share of squares, salt, reach over the ground (km).
local SERAC_CELL, SERAC_SQUARES, SERAC_SALT = 20, 0.12, 91          -- 0.5 until "cut down on the number of ice spikes" (2026-09-16)
local ERRATIC_CELL, ERRATIC_SQUARES, ERRATIC_SALT = 48, 0.35, 92
local SNAG_CELL, SNAG_SQUARES, SNAG_SALT = 40, 0.045, 93            -- 0.15 until "decrease the trees down to 15%", then "twice the trees again" (2026-09-15)
local TUFT_FREQ, TUFT_MIN = 1.5, 0.30                                -- a LITTLE grass on the bare ground: two octaves, since one sits at the clamp an eighth of the time
local TUFT_PATCH_FREQ, TUFT_PATCH_MIN = 1 / 40, 0.20                 -- and only in patches (0.40 at one octave covered a third of Frostmoor, 2026-09-16)
-- The whiteout (2026-09-15: "a thick white/blue gray fog here"): thick, at
-- every height, thinner where the Wastes only partly cover a chunk.
local WHITEOUT = { r = 0.86, g = 0.90, b = 0.95 }
local WHITEOUT_VISIBILITY, WHITEOUT_EDGE_VISIBILITY = 78, 210       -- a third of the strength of 26/70 (2026-09-15)
-- The blizzards: a square of BLIZZARD_CELL blocks is in one for
-- BLIZZARD_TICKS ticks, one square in BLIZZARD_ONE_IN; a drift stops
-- DRIFT_MAX blocks up a face.
local BLIZZARD_CELL, BLIZZARD_TICKS, BLIZZARD_ONE_IN, DRIFT_MAX = 192, 12000, 4, 3

-- ------------------------------------------------------------ the ground

local function ys()
    return n.mul(n.sub(n.Y(), n.const(shape.Y0)), n.const(shape.SCALE))
end
local WIND = { x = DUNE_STRETCH }
local function plain()
    return n.noise("fw_plain", PLAIN_FREQ, 2, PLAIN_AMP)
end
local function snow_w()
    return n.clamp(n.mul(n.sub(n.noise("fw_snow", SNOW_FREQ, 2, 1.0), n.const(SNOW_MIN)), n.const(8.0)), 0.0, 1.0)
end
local function ridge_w()
    return n.clamp(n.mul(n.add(n.contour("fw_ridge", RIDGE_FREQ, 2), n.const(-RIDGE_W)), n.const(-1.5 / RIDGE_W)), 0.0, 1.0)
end
local function crevasse_d()
    return n.contour("fw_crevasse", CREVASSE_FREQ, 2)
end
local function crevasse_w()
    local line = n.clamp(n.mul(n.add(crevasse_d(), n.const(-CREVASSE_W)), n.const(-3.0)), 0.0, 1.0)
    return n.mul(line, n.clamp(n.mul(n.sub(n.noise("fw_crevasse_seg", CREVASSE_SEG_FREQ, 1, 1.0), n.const(CREVASSE_SEG_MIN)), n.const(8.0)), 0.0, 1.0))
end
local function glacier_w()
    return n.clamp(n.mul(n.sub(n.noise("fw_glacier", GLACIER_FREQ, 2, 1.0), n.const(GLACIER_MIN)), n.const(GLACIER_EDGE)), 0.0, 1.0)
end
local function lake_w()
    return n.clamp(n.mul(n.min(n.sub(n.noise("fw_lake", LAKE_FREQ, 2, 1.0), n.const(LAKE_MIN)),
        n.sub(n.noise("fw_lake_b", LAKE_FREQ, 2, 1.0), n.const(LAKE_MIN))), n.const(LAKE_EDGE)), 0.0, 1.0)
end
-- The polygons' gravel borders: where either of two fine contours runs.
local function polygon_w()
    local a = n.clamp(n.mul(n.add(n.contour("fw_poly_a", POLY_FREQ, 1), n.const(-POLY_W)), n.const(-2.0)), 0.0, 1.0)
    return n.max(a, n.clamp(n.mul(n.add(n.contour("fw_poly_b", POLY_FREQ * 1.3, 1), n.const(-POLY_W)), n.const(-2.0)), 0.0, 1.0))
end

-- The Frozen Wastes' terms of the terrain, km, added to the depth.
function shape.frozen_terms()
    local acc = n.add(plain(), n.noise("fw_dune", DUNE_FREQ, 2, DUNE_AMP, WIND))
    -- Sastrugi: sharp ridges where a wind-stretched noise crosses zero, on
    -- the snowfields.
    local sastrugi = n.clamp(n.sub(n.const(1.0), n.mul(n.abs(n.noise("fw_sastrugi", SASTRUGI_FREQ, 1, 1.0, { x = SASTRUGI_STRETCH })),
        n.const(5.0))), 0.0, 1.0)
    acc = n.add(acc, n.mul(n.mul(sastrugi, snow_w()), n.const(SASTRUGI_H)))
    -- Pressure ridges, jagged along their crests.
    acc = n.add(acc, n.mul(ridge_w(), n.add(n.noise("fw_jag", JAG_FREQ, 1, JAG_AMP), n.const(RIDGE_H))))
    -- The polygons' borders heave a little over the bare ground.
    acc = n.add(acc, n.mul(n.mul(polygon_w(), n.add(n.mul(snow_w(), n.const(-1.0)), n.const(1.0))), n.const(POLY_HEAVE)))
    -- The glaciers: a sheet of ice twelve blocks thick with a steep front.
    acc = n.add(acc, n.mul(glacier_w(), n.const(GLACIER_H)))
    -- Crevasses, sheer, fifteen to thirty deep.
    local depth = n.add(n.mul(n.add(n.noise("fw_crevasse_depth", 1 / 120, 1, 1.0), n.const(0.5)), n.const(CREVASSE_VARY)), n.const(CREVASSE_D))
    acc = n.sub(acc, n.mul(crevasse_w(), depth))
    -- The ice caves: a tunnel along a contour, CAVE_LO to CAVE_HI over the
    -- plain, inside a glacier's thick middle.
    local rel = n.sub(n.sub(n.sub(ys(), shape.dome_node()), plain()), n.const((CAVE_LO + CAVE_HI) / 2))
    local band = n.clamp(n.mul(n.sub(n.abs(rel), n.const((CAVE_HI - CAVE_LO) / 2)), n.const(-2000.0)), 0.0, 1.0)
    local tunnel = n.clamp(n.mul(n.add(n.contour("fw_cave", CAVE_FREQ, 2), n.const(-CAVE_W)), n.const(-1.0)), 0.0, 1.0)
    local deep_ice = n.clamp(n.mul(n.sub(glacier_w(), n.const(0.85)), n.const(20.0)), 0.0, 1.0)
    acc = n.sub(acc, n.mul(n.mul(n.mul(band, tunnel), deep_ice), n.const(CAVE_CUT)))
    -- The cryo-lakes: the ground pulled down to two blocks under the plain,
    -- flat, as `acc * (1 - w) + (plain - drop) * w`.
    local w = lake_w()
    return n.add(n.mul(acc, n.add(n.mul(w, n.const(-1.0)), n.const(1.0))),
        n.mul(n.add(plain(), n.const(-LAKE_DROP)), lake_w()))
end

tdw.biomes[ID].ring_mode = "alpine"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.permafrost

-- ------------------------------------------------------------ where it is

-- Whether (x, z) is the Frozen Wastes', by its placement field and the
-- world's seed, cached by eight-block square: the alpine's random tick asks
-- this of every block it is offered, and so do the drifts.
local FIELD = nil
local cache, cached = {}, 0
function tdw.frozen_at(x, z)
    local only = tdw.config.everywhere
    if only then
        return only == ID
    end
    local u = (x * x + z * z) * 1e-6 / (shape.R_DISC * shape.R_DISC)
    local frost = tdw.layers.ring_by_id.frost
    if u < frost.u[1] - shape.RING_WOBBLE or u > frost.u[2] + shape.RING_WOBBLE then
        return false
    end
    local seed = game.world_seed or tdw.seed
    if seed == nil then
        return false
    end
    local key = (x // 8) * 65536 + (z // 8)
    local hit = cache[key]
    if hit == nil then
        if cached > 20000 then
            cache, cached = {}, 0
        end
        FIELD = FIELD or shape.compile("frozen.at", tdw.biome_mask(n, ID))
        local y = shape.Y0 + 1000 * shape.dome_at(u)
        hit = FIELD:at(x + 0.5, y + 0.5, z + 0.5, seed) > 0
        cache[key] = hit
        cached = cached + 1
    end
    return hit
end

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }

-- A cluster of seracs: two to six ice spires ten to twenty-five blocks tall,
-- leaning, rough-sided and needle-topped, with broken shards at their feet.
local function seracs(rng)
    schem.record_begin()
    for i = 1, 2 + rng:below(5) do
        local ox, oz = 0.5, 0.5
        if i > 1 then
            ox, oz = 0.5 + rng:below(11) - 5, 0.5 + rng:below(11) - 5
        end
        local tall = 10 + rng:below(16)
        local lean = schem.DIR16[rng:below(16) + 1]
        local r = 1.8 + rng:below(5) * 0.2
        local tilt = 0.08 + rng:below(4) * 0.03
        schem.push_path(blocks.ice, {
            { ox, -3.0, oz, r },
            { ox + lean[1] * tall * tilt * 0.5, tall * 0.5, oz + lean[2] * tall * tilt * 0.5, r * 0.6 },
            { ox + lean[1] * tall * tilt, tall, oz + lean[2] * tall * tilt, 0.25 },
        }, { rough = 0.25, blind = true })
    end
    for _ = 1, 1 + rng:below(3) do
        local d = schem.DIR16[rng:below(16) + 1]
        local x, z = 0.5 + d[1] * (3 + rng:below(4)), 0.5 + d[2] * (3 + rng:below(4))
        local len = 3 + rng:below(3)
        schem.push_path(blocks.ice, { { x, 0.2, z, 0.7 }, { x + d[1] * len, 0.2 + rng:below(3) * 0.8, z + d[2] * len, 0.4 } },
            { rough = 0.3, blind = true })
    end
    return schem.record_schematic({})
end

-- An erratic: one to three great granite boulders dropped together, half
-- sunk in the ground, with snow lying on their tops.
local function erratic(rng)
    schem.record_begin()
    for i = 1, 1 + rng:below(3) do
        local r = 2.5 + rng:below(5) * 0.5
        local x, z = 0.5, 0.5
        if i > 1 then
            local d = schem.DIR16[rng:below(16) + 1]
            x, z = 0.5 + d[1] * (r + 1.5), 0.5 + d[2] * (r + 1.5)
            r = r * 0.7
        end
        local rx, ry, rz = r * (0.9 + rng:below(3) * 0.1), r * 0.75, r * (0.9 + rng:below(3) * 0.1)
        schem.push_ellipsoid(blocks.granite, x, ry * 0.4, z, rx, ry, rz, { rough = 0.3, blind = true })
        schem.push_ellipsoid(blocks.snow, x, ry * 0.4 + ry * 0.85, z, rx * 0.7, 0.8, rz * 0.7, { rough = 0.3, blind = true })
    end
    return schem.record_schematic({ [blocks.granite] = 1 })
end

-- A frozen snag, or a copse of two to four: dead trunks three to seven tall
-- with broken tops and a stub or two, snow on the stubs. No needles.
local function snags(rng)
    schem.record_begin()
    for i = 1, (rng:below(3) == 0) and (2 + rng:below(3)) or 1 do
        local ox, oz = 0.5, 0.5
        if i > 1 then
            ox, oz = 0.5 + rng:below(7) - 3, 0.5 + rng:below(7) - 3
        end
        local tall = 3 + rng:below(5)
        local lean = schem.DIR16[rng:below(16) + 1]
        local trunk = {
            { ox, -1.0, oz, 0.45 },
            { ox + lean[1] * 0.3, tall * 0.6, oz + lean[2] * 0.3, 0.33 },
            { ox + lean[1] * 0.7, tall, oz + lean[2] * 0.7, 0.22 },
        }
        schem.push_path(blocks.dead_wood, trunk, BLIND)
        for _ = 1, rng:below(3) do
            local px, py, pz = schem.path_point(trunk, tall * (0.4 + rng:below(4) * 0.12))
            local d = schem.DIR16[rng:below(16) + 1]
            local tip = { px + d[1] * 1.6, py + 0.8, pz + d[2] * 1.6, 0.14 }
            schem.push_path(blocks.dead_wood, { { px, py, pz, 0.2 }, tip }, BLIND)
            schem.push_ellipsoid(blocks.snow, tip[1], tip[2] + 0.35, tip[3], 0.45, 0.25, 0.45, BLIND)
        end
        local top = trunk[3]
        schem.push_ellipsoid(blocks.snow, top[1], top[2] + 0.35, top[3], 0.4, 0.3, 0.4, BLIND)
    end
    return schem.record_schematic({ [blocks.dead_wood] = 1 })
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { seracs = {}, erratics = {}, snags = {} }
    if not game.schematic_shapes then
        BUILT = out
        return out
    end
    local function rng_for(name)
        return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "frozen_template:" .. name)
    end
    for i = 1, 6 do out.seracs[i] = seracs(rng_for("serac:" .. i)) end
    for i = 1, 5 do out.erratics[i] = erratic(rng_for("erratic:" .. i)) end
    for i = 1, 6 do out.snags[i] = snags(rng_for("snag:" .. i)) end
    local parts = {}
    for _, key in ipairs({ "seracs", "erratics", "snags" }) do
        local total = 0
        for _, one in ipairs(out[key]) do total = total + one:len() end
        parts[#parts + 1] = string.format("%d %s (%d blocks)", #out[key], key, total)
    end
    game.log("tiamot_default_world frozen wastes: cut " .. table.concat(parts, ", "))
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

tdw.build_biome(ID, function(ctx)
    local function masked(field)
        local mask = tdw.biome_mask(n, ID)
        return mask and n.min(field, mask) or field
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    local conditions = {
        -- 1: the wind-scoured plain: permafrost.
        n.const(1.0),
        -- 2: the snowfields.
        n.sub(snow_w(), n.const(0.3)),
        -- 3: the polygons' frost-heaved gravel, on the bare ground only.
        n.min(n.sub(polygon_w(), n.const(0.3)), n.sub(n.const(0.3), snow_w())),
        -- 4: a pressure ridge: ice.
        n.sub(ridge_w(), n.const(0.15)),
        -- 5: a glacier: ice under a skin of snow, all the way down its front
        -- and round its caves.
        n.sub(glacier_w(), n.const(0.05)),
        -- 6: a crevasse's walls: blue ice.
        n.min(n.add(n.mul(crevasse_d(), n.const(-1.0)), n.const(CREVASSE_W + 1.5)),
            n.sub(n.noise("fw_crevasse_seg", CREVASSE_SEG_FREQ, 1, 1.0), n.const(CREVASSE_SEG_MIN + 0.02))),
        -- 7: a cryo-lake: clear ice, blue ice under it.
        n.sub(lake_w(), n.const(0.4)),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    local mask = tdw.biome_mask(n, ID)
    if mask then
        code = n.mul(code, step(mask))
    end
    local depth = shape.compile("biome.frozen.depth", shape.terrain(false))
    local codes = shape.compile("biome.frozen.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 5 * km, material = blocks.permafrost },
        { code = 2, to = 2 * km, material = blocks.snow },
        { code = 2, from = 2 * km, to = 5 * km, material = blocks.permafrost },
        { code = 3, to = 1 * km, material = blocks.creek_bed },
        { code = 3, from = 1 * km, to = 5 * km, material = blocks.permafrost },
        { code = 4, to = 14 * km, material = blocks.ice },
        { code = 5, to = 1 * km, material = blocks.snow },
        { code = 5, from = 1 * km, to = 40 * km, material = blocks.ice },
        { code = 6, to = 45 * km, material = blocks.ice },
        { code = 7, to = 3 * km, material = blocks.clear_ice },
        { code = 7, from = 3 * km, to = 14 * km, material = blocks.ice },
    }
    -- A little grass (2026-09-15, "a bit of grass here and there on the
    -- dirt up there"): the alpine's tufts, sparse, on the bare permafrost
    -- between the snowfields, off the ice, the lakes and the crevasses.
    local tufts = shape.compile("biome.frozen.tufts", masked(n.min(n.min(n.sub(n.const(0.3), snow_w()),
        n.sub(n.const(0.05), n.max(n.max(glacier_w(), lake_w()), crevasse_w()))),
        n.min(n.sub(n.noise("fw_tuft", TUFT_FREQ, 2, 1.0), n.const(TUFT_MIN)),
            n.sub(n.noise("fw_tuft_patch", TUFT_PATCH_FREQ, 2, 1.0), n.const(TUFT_PATCH_MIN))))))
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
        { cover = blocks.alpine_grass, cells = 2, take = tufts },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, above)
            fills[#fills + 1] = { scatter = true, depth = depth, stand = shape.compile("biome.frozen.stand_" .. name, masked(field)),
                schematics = list, cell = cell, chance = chance, salt = salt, sink = 1, above = above }
        end
        -- Off the ice, the lakes and the crevasses: the plain.
        local function plain_ground()
            return n.sub(n.const(0.05), n.max(n.max(glacier_w(), lake_w()), crevasse_w()))
        end
        scatter("serac", built.seracs, n.min(n.sub(glacier_w(), n.const(0.7)), n.sub(n.const(0.05), crevasse_w())),
            SERAC_CELL, SERAC_SQUARES, SERAC_SALT, 0.03)
        scatter("erratic", built.erratics, plain_ground(), ERRATIC_CELL, ERRATIC_SQUARES, ERRATIC_SALT, 0.012)
        scatter("snag", built.snags, plain_ground(), SNAG_CELL, SNAG_SQUARES, SNAG_SALT, 0.012)
    end
    return fills
end)

-- ------------------------------------------------------------ the whiteout

if tdw.on_chunk_fog then
    tdw.on_chunk_fog(function(pos)
        local only = tdw.config.everywhere
        if only then
            if only ~= ID then
                return nil
            end
            return { r = WHITEOUT.r, g = WHITEOUT.g, b = WHITEOUT.b, visibility = WHITEOUT_VISIBILITY }
        end
        FIELD = FIELD or shape.compile("frozen.at", tdw.biome_mask(n, ID))
        local b = FIELD:bounds(pos)
        if b.high <= 0 then
            return nil
        end
        return { r = WHITEOUT.r, g = WHITEOUT.g, b = WHITEOUT.b,
            visibility = b.low > 0 and WHITEOUT_VISIBILITY or WHITEOUT_EDGE_VISIBILITY }
    end)
end

-- ------------------------------------------------------------ the blizzards

-- A whiteout drifts snow against whatever stands in the wind. A square of
-- BLIZZARD_CELL blocks is in a blizzard for BLIZZARD_TICKS ticks at a time,
-- one square in BLIZZARD_ONE_IN, by a hash of the square and the time; in
-- one, a random tick on a snow surface whose next block downwind (+x) holds
-- something that is not snow — a boulder, a snag, a serac, a wall somebody
-- built — lays a layer of snow cells in the air over it, against that face,
-- until the drift stands DRIFT_MAX blocks deep. So the snow piles on the
-- windward side of things, and only while the blizzard lasts.
local now = 0
tdw.on_tick(function(dt_ticks)
    now = now + dt_ticks
end)
local FULL = game.OCCUPANCY_FULL
local LAYERS = {}
for cy = 0, 2 do
    local mask = 0
    for cz = 0, 2 do
        for cx = 0, 2 do
            mask = mask | schem.bit(cx, cy, cz)
        end
    end
    LAYERS[cy + 1] = mask
end
local SNOW = "tiamot_default_world:snow"
local stats = { drifts = 0 }

tdw.on_random_tick(blocks.snow, function(x, y, z)
    if not tdw.frozen_at(x, z) then
        return false
    end
    if schem.hash(x // BLIZZARD_CELL, now // BLIZZARD_TICKS, z // BLIZZARD_CELL) % BLIZZARD_ONE_IN ~= 0 then
        return true
    end
    local above = schem.at(x, y + 1, z)
    if above == nil or above.occupancy == FULL or (above.occupancy ~= 0 and above.material ~= blocks.snow) then
        return true
    end
    local face = schem.at(x + 1, y + 1, z)
    if face == nil or face.occupancy == 0 or face.material == blocks.snow then
        return true
    end
    -- How deep the drift is already: snow blocks under the tick's block.
    local deep = 0
    for k = 1, DRIFT_MAX do
        local b = schem.at(x, y - k + 1, z)
        if b and b.material == blocks.snow and b.occupancy == FULL then
            deep = deep + 1
        else
            break
        end
    end
    if deep >= DRIFT_MAX or not edits.room() then
        return true
    end
    for _, layer in ipairs(LAYERS) do
        if above.occupancy & layer ~= layer then
            edits.begin()
            edits.push({ x = x, y = y + 1, z = z }, SNOW, layer & ~above.occupancy, true)
            if edits.commit() then
                stats.drifts = stats.drifts + 1
            end
            break
        end
    end
    return true
end)
