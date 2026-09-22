-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 2.5 The Dunes: the Long Shore's dry half — Goldwater's sand sea, from
-- 35.4 to 50.1 km, the widest dry band in the world.
--
-- The brief (2026-09-15):
--
--   Expansive, sweeping barchan dunes with smooth, shallow windward slopes
--   and steep slip-faces, alternating with wide, flat interdune deflation
--   basins. Elevation rises and falls in long, rhythmic sand swells with
--   vast, open sightlines.
--   Surface: deep, loose golden-tan windblown sand.
--   Trees: extremely barren; virtually zero living timber. Rare dead snags
--   or hardy grass anchor low wind-sheltered depressions.
--   Accents: very rare sun-bleached megafauna ribcages half-swallowed by
--   dune ridges, wind-carved yardang rock ribs protruding through sand
--   flats.
--
-- HOW A BARCHAN IS ASYMMETRIC. A noise is symmetric; a dune is not — it
-- climbs a long shallow windward face and drops off a short steep slip
-- face. The shape here is `min(up, down)` of two clamps on ONE stretched
-- noise: `up` opens over a wide band of the noise's range and `down` shuts
-- over a narrow one, so the ground rises over two hundred blocks and falls
-- in thirty. The noise is stretched along x (`{ x = ... }`, engine
-- 12bd662), which is the wind: the dunes come out as long crests across
-- it, marching downwind.
--
-- No new nodes. The sand is the world's `sand` (golden-tan already), the
-- deflation lag is `gravel`, the yardangs are the mesa's sandstones,
-- the snags `dead_log`, the ribs the ocean's `bone`, the hardy grass the
-- badlands' `dead_sagebrush` and a little `tall_grass`.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "dunes"

-- The shape, all in km.
local SWELL_FREQ, SWELL_AMP = 1 / 850, 0.009             -- the long rhythmic swells: nine blocks either way over kilometres
local DUNE_FREQ, DUNE_STRETCH, DUNE_H = 1 / 120, 2.6     -- the barchans: crests across the wind, stretched along it
DUNE_H = 0.024                                           -- the shape peaks at 0.55 of this: thirteen blocks of dune
local DUNE_UP, DUNE_UP_K = 0.10, 2.0                     -- the windward face: opens slowly
local DUNE_DOWN, DUNE_DOWN_K = 0.30, 8.0                 -- the slip face: shuts four times as fast
local BASIN_FREQ, BASIN_MIN, BASIN_EDGE = 1 / 620, -0.24, 5.0   -- where this is low the dunes stop: flat deflation basins, a fifth of the sand sea at most
local YARD_FREQ, YARD_W, YARD_H = 1 / 340, 7.0, 0.007    -- yardangs: rock ribs along a contour, seven blocks over the sand
local YARD_SEG_FREQ, YARD_SEG_MIN = 1 / 420, 0.34        -- in rare stretches: an accent, not a feature

-- The surface.
local LAG_FREQ, LAG_MIN = 1 / 22, 0.42                   -- the deflation lag: gravel bared in a corner of a basin
local CRUST_FREQ, CRUST_MIN = 1 / 9, 0.44                -- a wind-packed crust on it
local GRASS_FREQ, GRASS_MIN = 1.4, 0.50                  -- hardy grass, only in the sheltered hollows: one column in forty of them
local SAGE_FREQ, SAGE_MIN = 1.4, 0.50
local PATCH_FREQ, PATCH_MIN = 1 / 70, 0.42               -- and only in a few of the hollows at that: nine tenths of the sand sea is sand
local HOLLOW = 0.10                                      -- the dune weight under this is the floor between the dunes

-- The structures: cell, share of squares, salt.
local SNAG_CELL, SNAG_SQUARES = 44, 0.20
local RIB_CELL, RIB_SQUARES = 64, 0.12                   -- very rare: a sixty-four-block square, and one in eight of those
local ROCK_CELL, ROCK_SQUARES = 30, 0.25

-- ------------------------------------------------------------ the shape

local function seg(stream, freq, min, edge)
    return n.clamp(n.mul(n.sub(n.noise(stream, freq, 1, 1.0), n.const(min)), n.const(edge)), 0.0, 1.0)
end
local function tent(stream, freq, w)
    return n.clamp(n.add(n.mul(n.contour(stream, freq, 2), n.const(-1.0 / w)), n.const(1.0)), 0.0, 1.0)
end
-- The dune field's own noise, stretched along the wind.
local function dune_noise()
    return n.noise("dn_dune", DUNE_FREQ, 2, 1.0, { x = DUNE_STRETCH })
end
-- 0 to 1 over a barchan: the windward ramp against the slip face, times
-- the basin gate — in a deflation basin there is no dune at all.
local function dune_w()
    local up = n.clamp(n.mul(n.add(dune_noise(), n.const(DUNE_UP)), n.const(DUNE_UP_K)), 0.0, 1.0)
    local down = n.clamp(n.mul(n.sub(n.const(DUNE_DOWN), dune_noise()), n.const(DUNE_DOWN_K)), 0.0, 1.0)
    return n.mul(n.min(up, down), seg("dn_basin", BASIN_FREQ, BASIN_MIN, BASIN_EDGE))
end
local function yardang()
    return n.mul(tent("dn_yard", YARD_FREQ, YARD_W), seg("dn_yard_seg", YARD_SEG_FREQ, YARD_SEG_MIN, 6.0))
end

-- The Dunes' terms of the terrain, km, added to the depth. Deepest first:
-- the swell, then the dunes on it, then the rock ribs through them.
function shape.dune_terms()
    local acc = n.add(n.noise("dn_swell", SWELL_FREQ, 2, SWELL_AMP), n.mul(dune_w(), n.const(DUNE_H)))
    return n.add(acc, n.mul(yardang(), n.const(YARD_H)))
end
-- Where they stand: the Long Shore's dry half, faded in over the ring's
-- edge and across the humidity split, which is the same pair of weights
-- every biome on half a ring uses.
function shape.dune_weight()
    if tdw.config.everywhere == ID then
        return n.const(1.0)
    end
    -- The Long Shore (the Hem too until 2026-09-16, when the rim went
    -- cold), the dry side, and the province the sand takes: the barchans
    -- are thirteen blocks tall and nothing else on the dry side wants them,
    -- so the terms stop exactly where the Rolling Grasslands' turf starts.
    local first, last = tdw.layers.ring_by_id.shore, tdw.layers.ring_by_id.shore
    local band = n.mul(n.clamp(n.mul(shape.ring(first.u[1], last.u[2]), n.const(1.0 / 0.010)), 0.0, 1.0), shape.dry_weight())
    return n.mul(band, shape.province_weight("b"))
end

tdw.biomes[ID].ring_mode = "temperate"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.sand

-- Whether (x, z) is the Dunes', by its placement field, cached by
-- eight-block square as the cold biomes' tests are: the HUD asks, because
-- everything the sand sea is made of belongs to somebody else — the
-- coast's sand, the mesa's sandstone, the badlands' sagebrush.
local FIELD = nil
local cache, cached = {}, 0
function tdw.dunes_at(x, z)
    local only = tdw.config.everywhere
    if only then
        return only == ID
    end
    local u = (x * x + z * z) * 1e-6 / (shape.R_DISC * shape.R_DISC)
    local ring = tdw.layers.ring_by_id.shore
    if u < ring.u[1] - shape.wobble(u) or u > ring.u[2] + shape.wobble(u) then
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
        FIELD = FIELD or shape.compile("dunes.at", tdw.biome_mask(n, ID))
        local y = shape.Y0 + 1000 * shape.dome_at(u)
        hit = FIELD:at(x + 0.5, y + 0.5, z + 0.5, seed) > 0
        cache[key] = hit
        cached = cached + 1
    end
    return hit
end

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local ROUGH = { rough = 0.35, blind = true }
local FULL = game.OCCUPANCY_FULL
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "dunes_template:" .. name)
end

-- A dead snag: a bare bleached trunk, split at the top, with one or two
-- stubs of branch left on it. Sunk two blocks: the sand has taken it.
local function snag(rng)
    schem.record_begin()
    local tall = 3 + rng:below(4)
    local d = schem.DIR16[rng:below(16) + 1]
    local lean = 0.3 + rng:below(3) * 0.25
    schem.push_path(blocks.dead_log, {
        { 0.5, -2.5, 0.5, 0.62 },
        { 0.5 + d[1] * lean * 0.4, tall * 0.5, 0.5 + d[2] * lean * 0.4, 0.45 },
        { 0.5 + d[1] * lean, tall, 0.5 + d[2] * lean, 0.28 },
    }, BLIND)
    for _ = 1, 1 + rng:below(2) do
        local w = schem.DIR16[rng:below(16) + 1]
        local h = tall * (0.45 + rng:below(40) / 100)
        schem.push_path(blocks.dead_log, {
            { 0.5, h, 0.5, 0.3 },
            { 0.5 + w[1] * (1.2 + rng:below(3) * 0.4), h + 0.6 + rng:below(3) * 0.3, 0.5 + w[2] * (1.2 + rng:below(3) * 0.4), 0.16 },
        }, BLIND)
    end
    return schem.record_schematic({ [blocks.dead_log] = 1 })
end

-- A megafauna ribcage: a spine along the ground and six to nine pairs of
-- ribs arching off it, thinning to their tips, the whole thing sunk so
-- the sand has swallowed the lower half — what is left is a row of arcs
-- standing out of a dune's flank.
local function ribcage(rng)
    schem.record_begin()
    local d = schem.DIR16[rng:below(16) + 1]
    local side = schem.DIR16[(rng:below(16) + 4) % 16 + 1]
    local pairs_n = 6 + rng:below(4)
    local step = 1.6 + rng:below(3) * 0.2
    local half = pairs_n * step / 2
    local ax, az = 0.5 - d[1] * half, 0.5 - d[2] * half
    schem.push_path(blocks.bone, {
        { ax, 0.2, az, 0.55 },
        { 0.5, 0.6, 0.5, 0.62 },
        { 0.5 + d[1] * half, 0.1, 0.5 + d[2] * half, 0.5 },
    }, BLIND)
    for i = 0, pairs_n - 1 do
        local t = -half + i * step
        local x, z = 0.5 + d[1] * t, 0.5 + d[2] * t
        local reach = 2.2 + rng:below(4) * 0.35
        local rise = 2.6 + rng:below(4) * 0.4
        -- Both ribs of the pair: out, up and over, closing toward the top.
        for _, s in ipairs({ 1, -1 }) do
            schem.push_path(blocks.bone, {
                { x, 0.4, z, 0.42 },
                { x + side[1] * reach * s, rise * 0.55, z + side[2] * reach * s, 0.32 },
                { x + side[1] * reach * 0.75 * s, rise, z + side[2] * reach * 0.75 * s, 0.22 },
            }, BLIND)
        end
    end
    -- The skull, at one end, half under.
    schem.push_ellipsoid(blocks.bone, ax - d[1] * 2.4, 0.4, az - d[2] * 2.4, 1.5, 1.1, 1.2, ROUGH)
    return schem.record_schematic({ [blocks.bone] = 1 })
end

-- A wind-carved rock: a low lump of sandstone standing out of the sand,
-- undercut on one side, for the yardang flats.
local function rock(rng)
    schem.record_begin()
    local material = rng:below(2) == 0 and blocks.ochre_sandstone or blocks.rust_red_sandstone
    local r = 1.4 + rng:below(4) * 0.4
    schem.push_ellipsoid(material, 0.5, 0.2, 0.5, r, 0.8 + rng:below(3) * 0.3, r * (0.7 + rng:below(4) * 0.12), ROUGH)
    local d = schem.DIR16[rng:below(16) + 1]
    schem.push_ellipsoid(game.AIR, 0.5 + d[1] * r, -0.3, 0.5 + d[2] * r, 0.8, 0.5, 0.8, BLIND)
    return schem.record_schematic({ [material] = 1, [game.AIR] = 2 })
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { snags = {}, ribs = {}, rocks = {} }
    if not game.schematic_shapes then
        BUILT = out
        return out
    end
    for i = 1, 5 do out.snags[i] = snag(rng_for("snag:" .. i)) end
    for i = 1, 3 do out.ribs[i] = ribcage(rng_for("rib:" .. i)) end
    for i = 1, 5 do out.rocks[i] = rock(rng_for("rock:" .. i)) end
    local parts = {}
    for key, list in pairs(out) do
        local sum = 0
        for _, one in ipairs(list) do sum = sum + one:len() end
        parts[#parts + 1] = string.format("%d %s (%d blocks)", #list, key, sum)
    end
    game.log("tiamat_default_world dunes: cut " .. table.concat(parts, ", "))
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
    -- The basins: where the dune FIELD's own gate is low there are no
    -- dunes at all, and the ground is a flat floor of deflation lag rather
    -- than loose sand. (Measured against the dune weight instead, this was
    -- most of the biome: the barchan shape is zero between the crests as
    -- well as in the basins, and the sand sea came up half covered in
    -- sagebrush.)
    local function basin()
        return n.sub(n.const(0.08), seg("dn_basin", BASIN_FREQ, BASIN_MIN, BASIN_EDGE))
    end
    local conditions = {
        -- 1: deep loose sand, everywhere.
        n.const(1.0),
        -- 2: the lag in the basins: coarse gravel the wind cannot lift.
        n.min(basin(), n.sub(n.noise("dn_lag", LAG_FREQ, 2, 1.0), n.const(LAG_MIN))),
        -- 3: and the wind-packed crust between the patches of it.
        n.min(basin(), n.sub(n.noise("dn_crust", CRUST_FREQ, 1, 1.0), n.const(CRUST_MIN))),
        -- 4: the yardangs: rock, standing out of the sand — the rib's
        -- spine alone, so the sand runs up to it rather than round a
        -- shelf of stone ("90% of materials in the desert is sand").
        n.sub(yardang(), n.const(0.72)),
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
    local depth = shape.compile("biome.dunes.depth", shape.terrain(false))
    local codes = shape.compile("biome.dunes.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 20 * km, material = blocks.sand },
        { code = 2, to = 1 * km, material = blocks.gravel },
        { code = 2, from = 1 * km, to = 20 * km, material = blocks.sand },
        { code = 3, to = 1 * km, material = blocks.packed_dirt },
        { code = 3, from = 1 * km, to = 20 * km, material = blocks.sand },
        { code = 4, to = 3 * km, material = blocks.ochre_sandstone },
        { code = 4, from = 3 * km, to = 20 * km, material = blocks.rust_red_sandstone },
    }
    -- What grows: nothing on a dune. In the hollows between them, sparse
    -- sagebrush and a little hardy grass, and not on the bare rock.
    local function sheltered(freq, min, name)
        return shape.compile("biome.dunes." .. name, masked(off_river(n.min(n.min(n.min(
            n.sub(n.const(HOLLOW), dune_w()), n.sub(n.const(0.35), yardang())),
            n.sub(n.noise("dn_patch", PATCH_FREQ, 2, 1.0), n.const(PATCH_MIN))),
            n.sub(n.noise("dn_" .. name, freq, 1, 1.0), n.const(min))))))
    end
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
        { cover = blocks.dead_sagebrush, cells = 2, take = sheltered(SAGE_FREQ, SAGE_MIN, "sage") },
        { cover = blocks.tall_grass, cells = 2, take = sheltered(GRASS_FREQ, GRASS_MIN, "grass") },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, sink)
            if #list > 0 then
                fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                    salt = salt, sink = sink,
                    stand = shape.compile("biome.dunes.stand_" .. name, masked(off_river(field))) }
            end
        end
        -- The snags stand in the hollows, the ribcages half-swallowed on a
        -- dune's flank, the rocks out on the yardang flats.
        scatter("snag", built.snags, n.min(n.sub(n.const(HOLLOW), dune_w()),
            n.sub(n.noise("dn_patch", PATCH_FREQ, 2, 1.0), n.const(PATCH_MIN))), SNAG_CELL, SNAG_SQUARES, 151, 2)
        scatter("rib", built.ribs, n.min(n.sub(dune_w(), n.const(0.30)), n.sub(n.const(0.75), dune_w())), RIB_CELL, RIB_SQUARES, 152, 2)
        scatter("rock", built.rocks, n.min(n.sub(yardang(), n.const(0.12)), n.sub(n.const(0.5), yardang())), ROCK_CELL, ROCK_SQUARES, 153, 1)
    end
    return fills
end)
