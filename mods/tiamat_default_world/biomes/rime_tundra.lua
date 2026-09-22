-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.1 Rime Tundra: the Hem's ground, and its middle band (2026-09-16).
--
-- The designer's ask: "the world needs to get colder as it nears the edge
-- again until an ice wall is hit right at the last couple hundred blocks of
-- the edge". So the Hem, the outermost ring, is the cold rim, in three
-- bands of the wobbled radius, colder outward:
--
--   50.1 to 53.7 km   Frostpine Coast (3.0): snowbound fir forest
--   53.7 km to 200 blocks from the edge   Rime Tundra (this): open ground
--   the last 200 blocks   The Rime Wall (3.2): drifts, then a wall of ice
--
-- (The edge is at `shape.EDGE_U` of the wobbled radius, 57.45 to 59.8 km:
-- inside the engine's world, which is a square 60,000 blocks either way.)
--
-- The ground is this file's everywhere in the Hem (`shape.tundra_terms`):
-- a long roll, hummocks, frost polygons pressed into the permafrost, pingos
-- standing out of it with their tops fallen in, and flat frozen tarns. The
-- Frostpine Coast dresses the same ground with trees; the wall stands on it.
-- The "hem" programs fade the mild rings' terrain out under it across the
-- Hem's inner edge, the "edge" programs carry it alone (shape.lua).
--
-- Colder outward: the snow's share climbs from a fifth of the ground at the
-- band's inner edge to nine tenths at the wall's foot, and the turf and its
-- tufts give out.
--
-- No new nodes: permafrost, snow, ice, clear ice, turf, gravel and granite.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "rime_tundra"

-- ------------------------------------------------------------ the bands

-- The rim's bands on the wobbled radius, shared by the three rim biomes.
local EDGE_BLOCKS_PER_U = shape.R_DISC * 1000 / 2     -- blocks of radius per unit of u at the rim: dr = du * R^2 / 2r
shape.RIM = {
    coast = { shape.HEM_U, (53.7 / 59.0) ^ 2 },
    tundra = { (53.7 / 59.0) ^ 2, shape.EDGE_U - 200 / EDGE_BLOCKS_PER_U },
    wall = { shape.EDGE_U - 200 / EDGE_BLOCKS_PER_U, shape.EDGE_U + 0.05 },
    blocks_per_u = EDGE_BLOCKS_PER_U,
}
local BAND = shape.RIM.tundra

-- Positive inside [lo, hi] of the wobbled radius, in u.
function shape.rim_band(band)
    return shape.ring(band[1], band[2])
end
-- 0 at the tundra's inner edge, 1 at the wall's foot: how cold it is.
function shape.rim_outward()
    return n.clamp(n.mul(n.add(shape.u_biome_node(), n.const(-BAND[1])), n.const(1.0 / (BAND[2] - BAND[1]))), 0.0, 1.0)
end

-- Whether a chunk can hold any of a band: its centre's u, widened by the
-- chunk's own reach and the wobble.
-- Not past a shelf: a land biome's fills on an ocean floor paint turf on
-- it (the Frostpine Coast did, under the fourth lane).
function shape.rim_present(band)
    return function(pos)
        if tdw.seas and tdw.seas.on() and tdw.seas.class(pos) == "deep" then
            return false
        end
        local x, z = pos.x * 16 + 8, pos.z * 16 + 8
        local r = math.sqrt(x * x + z * z) * 0.001
        local R2 = shape.R_DISC * shape.R_DISC
        local u = r * r / R2
        local reach = 2.0 * r * 0.024 / R2 + shape.wobble(u)
        return u + reach >= band[1] and u - reach <= band[2]
    end
end

-- `/tp` into a band of the rim: the generic search steps across a span in
-- shares of it, and the wall is two hundred blocks of a Hem nine
-- kilometres deep. Along sixteen bearings from the player's own, the radius
-- where the wobbled radius is `target` is found by halving (the wobble is a
-- slow noise, so along a bearing the wobbled radius only grows), and the
-- first on dry land is the landing.
local U_LOCATE = nil
function shape.rim_locate(target)
    return function(px, pz, seed)
        U_LOCATE = U_LOCATE or shape.compile("rim.u_locate", shape.u_biome_node())
        local R = shape.R_DISC * 1000
        local base = math.atan(pz, px)
        for i = 0, 15 do
            local a = base + (i % 2 == 0 and 1 or -1) * math.floor((i + 1) / 2) * (math.pi / 8)
            local cx, cz = math.cos(a), math.sin(a)
            local lo = R * math.sqrt(target / (1.0 + shape.RING_WOBBLE_SHARE))
            local hi = R * math.sqrt(target / (1.0 - shape.RING_WOBBLE_SHARE))
            for _ = 1, 24 do
                local r = (lo + hi) / 2
                local x, z = cx * r, cz * r
                local u = (x * x + z * z) * 1e-6 / (shape.R_DISC * shape.R_DISC)
                local y = shape.Y0 + 1000 * shape.dome_at(u)
                if U_LOCATE:at(x + 0.5, y + 0.5, z + 0.5, seed) < target then lo = r else hi = r end
            end
            local x, z = cx * lo, cz * lo
            if not tdw.seas or not tdw.seas.on() or tdw.seas.at(x, z, seed) < -60 then
                return math.floor(x), math.floor(z)
            end
        end
        return nil
    end
end

-- Which of the rim's biomes (x, z) is, for the HUD, or nil: the wobbled
-- radius sampled at the base dome, cached by eight-block square.
local U_FIELD = nil
local cache, cached = {}, 0
function tdw.rim_at(x, z)
    local only = tdw.config.everywhere
    if only then
        return (only == "frostpine_coast" or only == "rime_tundra" or only == "rime_wall") and only or nil
    end
    local u = (x * x + z * z) * 1e-6 / (shape.R_DISC * shape.R_DISC)
    if u < shape.HEM_U - shape.wobble(shape.HEM_U) then
        return nil
    end
    local seed = game.world_seed or tdw.seed
    if seed == nil then
        return nil
    end
    local key = (x // 8) * 65536 + (z // 8)
    local hit = cache[key]
    if hit == nil then
        if cached > 20000 then
            cache, cached = {}, 0
        end
        U_FIELD = U_FIELD or shape.compile("rim.u", shape.u_biome_node())
        local y = shape.Y0 + 1000 * shape.dome_at(u)
        local ub = U_FIELD:at(x + 0.5, y + 0.5, z + 0.5, seed)
        if ub < shape.RIM.coast[1] then
            hit = false
        elseif ub < shape.RIM.coast[2] then
            hit = "frostpine_coast"
        elseif ub < shape.RIM.tundra[2] then
            hit = "rime_tundra"
        else
            hit = "rime_wall"
        end
        cache[key] = hit
        cached = cached + 1
    end
    return hit or nil
end

-- ------------------------------------------------------------ the ground

local ROLL_FREQ, ROLL_AMP = 1 / 700, 0.016                -- the long roll: eight blocks either way
local HUMMOCK_FREQ, HUMMOCK_AMP = 1 / 7, 0.0018          -- a block of hummock either way
local POLY_FREQ, POLY_W, POLY_D = 1 / 22, 1.4, 0.0012    -- frost polygons: troughs a block deep along a contour, twenty blocks across
local PINGO_FREQ, PINGO_MIN, PINGO_EDGE, PINGO_H = 1 / 260, 0.36, 7.0, 0.018
local PINGO_THIN_FREQ, PINGO_THIN_MIN = 1 / 900, 0.10    -- a second noise: one pingo field in three or so
local PINGO_PIT_MIN, PINGO_PIT_D = 0.47, 0.006           -- the collapsed tops
local TARN_FREQ, TARN_MIN, TARN_EDGE, TARN_DROP = 1 / 350, 0.26, 8.0, 0.004

local function roll()
    return n.noise("rt_roll", ROLL_FREQ, 2, ROLL_AMP)
end
local function polygon_w()
    return n.clamp(n.add(n.mul(n.contour("rt_poly", POLY_FREQ, 1), n.const(-1.0 / POLY_W)), n.const(1.0)), 0.0, 1.0)
end
local function pingo_n()
    return n.min(n.noise("rt_pingo", PINGO_FREQ, 1, 1.0),
        n.add(n.noise("rt_pingo_thin", PINGO_THIN_FREQ, 1, 1.0), n.const(PINGO_MIN - PINGO_THIN_MIN)))
end
local function pingo_w()
    return n.clamp(n.mul(n.sub(pingo_n(), n.const(PINGO_MIN)), n.const(PINGO_EDGE)), 0.0, 1.0)
end
local function pingo_pit()
    return n.clamp(n.mul(n.sub(pingo_n(), n.const(PINGO_PIT_MIN)), n.const(40.0)), 0.0, 1.0)
end
local function tarn_w()
    return n.clamp(n.mul(n.sub(n.noise("rt_tarn", TARN_FREQ, 2, 1.0), n.const(TARN_MIN)), n.const(TARN_EDGE)), 0.0, 1.0)
end
shape.tundra_feature = { roll = roll, polygon = polygon_w, pingo = pingo_w, tarn = tarn_w }

-- The Hem's terms, km. The pingos first, the deepest; the tarns pull the
-- ground down to a flat floor as the Taiga's basins do, `acc * (1 - w) +
-- floor * w`.
function shape.tundra_terms()
    local acc = n.sub(n.mul(pingo_w(), n.const(PINGO_H)), n.mul(pingo_pit(), n.const(PINGO_PIT_D)))
    acc = n.add(acc, n.add(roll(), n.noise("rt_hummock", HUMMOCK_FREQ, 1, HUMMOCK_AMP)))
    acc = n.sub(acc, n.mul(polygon_w(), n.const(POLY_D)))
    local w = tarn_w()
    return n.add(n.mul(acc, n.add(n.mul(w, n.const(-1.0)), n.const(1.0))),
        n.mul(n.sub(roll(), n.const(TARN_DROP)), tarn_w()))
end

tdw.biomes[ID].ring_mode = "hem"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.permafrost
tdw.biomes[ID].present = shape.rim_present(BAND)
tdw.biomes[ID].locate = shape.rim_locate((BAND[1] + BAND[2]) / 2)

-- ------------------------------------------------------------ the structures

local ROUGH = { rough = 0.35, blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "rime_tundra_template:" .. name)
end
local PRIORITY = { [blocks.granite] = 1, [blocks.slate] = 1 }

-- An erratic: a granite boulder dropped by the ice, snow on its top.
local function erratic(rng)
    schem.record_begin()
    local r = 1.3 + rng:below(5) * 0.4
    schem.push_ellipsoid(blocks.granite, 0.5, r * 0.35, 0.5, r, r * 0.8, r * (0.7 + rng:below(4) * 0.1), ROUGH)
    schem.push_ellipsoid(blocks.snow, 0.5, r * 1.05, 0.5, r * 0.7, r * 0.25, r * 0.6, { rough = 0.5, blind = true })
    return schem.record_schematic(PRIORITY)
end
-- A slab of slate the frost has heaved up on edge.
local function heave(rng)
    schem.record_begin()
    local d = schem.DIR16[rng:below(16) + 1]
    local long = 1.2 + rng:below(3) * 0.4
    schem.push_ellipsoid(blocks.slate, 0.5, 0.6, 0.5, 0.35 + math.abs(d[1]) * long, 1.1 + rng:below(3) * 0.3, 0.35 + math.abs(d[2]) * long, ROUGH)
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { erratics = {}, heaves = {} }
    if game.schematic_shapes then
        for i = 1, 5 do out.erratics[i] = erratic(rng_for("erratic:" .. i)) end
        for i = 1, 4 do out.heaves[i] = heave(rng_for("heave:" .. i)) end
    end
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

local SNOW_FREQ, SNOW_IN, SNOW_OUT = 1 / 55, 0.28, -0.40 -- the snow noise over this: from the inner edge's value to the wall's
local MAT_FREQ, MAT_MIN = 1 / 25, 0.05                   -- the turf mats between the snow, fewer outward
local TUFT_FREQ, TUFT_MIN = 1.5, 0.30

tdw.build_biome(ID, function(ctx)
    local F = shape.tundra_feature
    local function masked(field)
        local mask = tdw.biome_mask(n, ID)
        field = mask and n.min(field, mask) or field
        field = n.min(field, shape.rim_band(BAND))
        return shape.sea_exclude and shape.sea_exclude(field, 20.0) or field
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    local function snow()
        return n.add(n.sub(n.noise("rt_snow", SNOW_FREQ, 2, 1.0), n.const(SNOW_IN)), n.mul(shape.rim_outward(), n.const(SNOW_IN - SNOW_OUT)))
    end
    local function mat()
        return n.sub(n.sub(n.noise("rt_mat", MAT_FREQ, 2, 1.0), n.const(MAT_MIN)), n.mul(shape.rim_outward(), n.const(0.5)))
    end
    local conditions = {
        -- 1: bare permafrost.
        n.const(1.0),
        -- 2: turf mats, thinning outward.
        mat(),
        -- 3: the polygons' troughs: frost-sorted gravel.
        n.sub(F.polygon(), n.const(0.5)),
        -- 4: snow, more of it outward.
        snow(),
        -- 5: a frozen tarn: clear ice over glacier ice.
        n.sub(F.tarn(), n.const(0.6)),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    code = n.mul(code, step(masked(n.const(1.0))))
    local depth = shape.compile("biome.rime_tundra.depth", shape.terrain(false))
    local codes = shape.compile("biome.rime_tundra.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 6 * km, material = blocks.permafrost },
        { code = 2, to = 1 * km, material = blocks.dirt },
        { code = 2, from = 1 * km, to = 6 * km, material = blocks.permafrost },
        { code = 3, to = 1 * km, material = blocks.gravel },
        { code = 3, from = 1 * km, to = 6 * km, material = blocks.permafrost },
        { code = 4, to = 2 * km, material = blocks.snow },
        { code = 4, from = 2 * km, to = 6 * km, material = blocks.permafrost },
        { code = 5, to = 2 * km, material = blocks.clear_ice },
        { code = 5, from = 2 * km, to = 6 * km, material = blocks.ice },
    }
    local tufts = shape.compile("biome.rime_tundra.tufts", masked(n.min(n.min(mat(), n.mul(snow(), n.const(-1.0))),
        n.sub(n.noise("rt_tuft", TUFT_FREQ, 1, 1.0), n.const(TUFT_MIN)))))
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
        { cover = blocks.tall_grass, cells = 2, take = tufts },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt)
            fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                salt = salt, sink = 1, above = 0.006, stand = shape.compile("biome.rime_tundra.stand_" .. name, masked(field)) }
        end
        local firm = n.sub(n.const(0.2), F.tarn())
        scatter("erratic", built.erratics, firm, 40, 0.35, 201)
        scatter("heave", built.heaves, n.min(firm, n.sub(F.polygon(), n.const(0.3))), 16, 0.20, 202)
    end
    return fills
end)

-- ------------------------------------------------------------ the haze

local HAZE = { r = 0.84, g = 0.88, b = 0.93 }
if tdw.on_chunk_fog then
    local place = nil
    tdw.on_chunk_fog(function(pos)
        local only = tdw.config.everywhere
        if only then
            return only == ID and { r = HAZE.r, g = HAZE.g, b = HAZE.b, visibility = 320 } or nil
        end
        if not tdw.biomes[ID].present(pos) then
            return nil
        end
        place = place or shape.compile("rime_tundra.place", shape.rim_band(BAND))
        local b = place:bounds(pos)
        if b.high <= 0 then
            return nil
        end
        return { r = HAZE.r, g = HAZE.g, b = HAZE.b, visibility = b.low > 0 and 320 or 640 }
    end)
end

-- The colour of its grass, dirt and lichen (2026-09-16): the chunk tint, on
-- its band of the Hem.
tdw.biome_tint("rime_tundra", { 0.82, 0.94, 1.0 }, function()
    return shape.node.min(tdw.biome_mask(shape.node, "rime_tundra"), shape.rim_band(shape.RIM.tundra))
end)
