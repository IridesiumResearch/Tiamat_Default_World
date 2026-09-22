-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.0 Frostpine Coast: the Hem's inner band (2026-09-16), where the cold
-- rim begins.
--
-- Snowbound fir forest in stands with open snowfields between them, on the
-- Rime Tundra's ground (`shape.tundra_terms`, the Hem's everywhere): the
-- roll, the hummocks, the frozen tarns. The fourth sea lane runs through
-- this band, so most of its shores are the Coastal Cliffs' behind firs.
-- Turf and bare permafrost under the stands, snow over half the ground,
-- dead firs standing grey at the stands' edges, erratics.
--
-- A dressing biome: no terms of its own. No new nodes: the alpine's firs.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "frostpine_coast"
local BAND = shape.RIM.coast

local STAND_FREQ, STAND_MIN = 1 / 90, -0.02              -- the stands: a little over half the ground
local FIR_CELL, FIR_SQUARES = 5, 0.50
local SNAG_CELL, SNAG_SQUARES = 18, 0.30
local ERRATIC_CELL, ERRATIC_SQUARES = 44, 0.30
local SNOW_FREQ, SNOW_MIN = 1 / 45, -0.02                -- snow over about half the ground, and under the stands less of it
local BARE_FREQ, BARE_MIN = 1 / 30, 0.25
local TUFT_FREQ, TUFT_MIN = 1.5, 0.22

tdw.biomes[ID].ring_mode = "hem"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.dirt
tdw.biomes[ID].present = shape.rim_present(BAND)
tdw.biomes[ID].locate = shape.rim_locate((BAND[1] + BAND[2]) / 2)

-- ------------------------------------------------------------ the trees

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "frostpine_template:" .. name)
end
local PRIORITY = { [blocks.fir_log] = 1, [blocks.dead_log] = 1, [blocks.granite] = 1 }

-- A frostpine: a straight fir nine to sixteen blocks, its tiers of needles
-- narrowing up the trunk, each tier with a cap of snow on it.
local function fir(rng)
    schem.record_begin()
    local tall = 9 + rng:below(8)
    schem.push_path(blocks.fir_log, { { 0.5, -1.5, 0.5, 0.45 }, { 0.5, tall, 0.5, 0.2 } }, BLIND)
    local base_r = 2.2 + rng:below(4) * 0.25
    local first = 2 + rng:below(2)
    for h = first, tall - 1, 2 do
        local t = (h - first) / math.max(1, tall - first)
        local r = base_r * (1.0 - t) + 0.45
        schem.push_ellipsoid(blocks.fir_needles, 0.5, h + 0.3, 0.5, r, 0.7, r, { rough = 0.3, jitter = rng, blind = true })
        schem.push_ellipsoid(blocks.snow, 0.5, h + 0.95, 0.5, r * 0.8, 0.28, r * 0.8, { rough = 0.4, blind = true })
    end
    schem.push_ellipsoid(blocks.snow, 0.5, tall + 0.4, 0.5, 0.45, 0.6, 0.45, { rough = 0.2, blind = true })
    return schem.record_schematic(PRIORITY)
end

-- A dead fir: a grey trunk with a few stubs of branch, leaning a little.
local function snag(rng)
    schem.record_begin()
    local tall = 5 + rng:below(6)
    local d = schem.DIR16[rng:below(16) + 1]
    local trunk = { { 0.5, -1.5, 0.5, 0.4 }, { 0.5 + d[1] * 0.6, tall, 0.5 + d[2] * 0.6, 0.18 } }
    schem.push_path(blocks.dead_log, trunk, BLIND)
    for _ = 1, 2 + rng:below(3) do
        local e = schem.DIR16[rng:below(16) + 1]
        local bx, by, bz = schem.path_point(trunk, tall * (0.4 + rng:below(50) / 100))
        schem.push_path(blocks.dead_log, { { bx, by, bz, 0.15 }, { bx + e[1] * 1.3, by - 0.4, bz + e[2] * 1.3, 0.1 } }, BLIND)
    end
    return schem.record_schematic(PRIORITY)
end

-- A granite erratic, snow on its top.
local function erratic(rng)
    schem.record_begin()
    local r = 1.2 + rng:below(4) * 0.4
    schem.push_ellipsoid(blocks.granite, 0.5, r * 0.3, 0.5, r, r * 0.8, r * 0.8, { rough = 0.35, blind = true })
    schem.push_ellipsoid(blocks.snow, 0.5, r * 1.0, 0.5, r * 0.65, r * 0.25, r * 0.6, { rough = 0.5, blind = true })
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { firs = {}, snags = {}, erratics = {} }
    if game.schematic_shapes then
        for i = 1, 8 do out.firs[i] = fir(rng_for("fir:" .. i)) end
        for i = 1, 4 do out.snags[i] = snag(rng_for("snag:" .. i)) end
        for i = 1, 4 do out.erratics[i] = erratic(rng_for("erratic:" .. i)) end
    end
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

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
    local function stands()
        return n.sub(n.noise("fp_stand", STAND_FREQ, 2, 1.0), n.const(STAND_MIN))
    end
    local function snow()
        -- Less under the stands: the snow's cut raised where a stand is.
        return n.sub(n.sub(n.noise("fp_snow", SNOW_FREQ, 2, 1.0), n.const(SNOW_MIN)), n.mul(n.clamp(n.mul(stands(), n.const(4.0)), 0.0, 1.0), n.const(0.25)))
    end
    local conditions = {
        -- 1: cold turf.
        n.const(1.0),
        -- 2: bare permafrost.
        n.sub(n.noise("fp_bare", BARE_FREQ, 1, 1.0), n.const(BARE_MIN)),
        -- 3: snow.
        snow(),
        -- 4: a frozen tarn.
        n.sub(F.tarn(), n.const(0.6)),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    code = n.mul(code, step(masked(n.const(1.0))))
    local depth = shape.compile("biome.frostpine.depth", shape.terrain(false))
    local codes = shape.compile("biome.frostpine.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 1 * km, material = blocks.dirt },
        { code = 1, from = 1 * km, to = 5 * km, material = blocks.dirt },
        { code = 2, to = 5 * km, material = blocks.permafrost },
        { code = 3, to = 2 * km, material = blocks.snow },
        { code = 3, from = 2 * km, to = 5 * km, material = blocks.dirt },
        { code = 4, to = 2 * km, material = blocks.clear_ice },
        { code = 4, from = 2 * km, to = 5 * km, material = blocks.ice },
    }
    local tufts = shape.compile("biome.frostpine.tufts", masked(n.min(n.mul(snow(), n.const(-1.0)),
        n.sub(n.noise("fp_tuft", TUFT_FREQ, 1, 1.0), n.const(TUFT_MIN)))))
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
        { cover = blocks.tall_grass, cells = 2, take = tufts },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, above)
            fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                salt = salt, sink = 1, above = above, stand = shape.compile("biome.frostpine.stand_" .. name, masked(field)) }
        end
        local firm = n.sub(n.const(0.15), F.tarn())
        scatter("fir", built.firs, n.min(firm, stands()), FIR_CELL, FIR_SQUARES, 211, 0.018)
        scatter("snag", built.snags, n.min(firm, n.sub(n.const(0.06), n.abs(stands()))), SNAG_CELL, SNAG_SQUARES, 212, 0.012)
        scatter("erratic", built.erratics, firm, ERRATIC_CELL, ERRATIC_SQUARES, 213, 0.006)
    end
    return fills
end)

-- The colour of its grass, dirt and lichen (2026-09-16): the chunk tint, on
-- its band of the Hem.
tdw.biome_tint("frostpine_coast", { 0.82, 0.94, 1.0 }, function()
    return shape.node.min(tdw.biome_mask(shape.node, "frostpine_coast"), shape.rim_band(shape.RIM.coast))
end)
