-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.14 Redwood Stands: a quarter of the Temperate Woodlands' province on
-- the Long Shore (2026-09-16).
--
-- Giants: redwoods forty to sixty blocks tall on buttressed feet, bare
-- red trunks for two thirds of their height and narrow spires of needles
-- above, with younger trees between; a floor of needle mulch and moss
-- under dense ferns, and fallen giants lying across it, mossed along their
-- tops. The light is dim and green.
--
-- WHERE: the Woodlands' province side "a" past a split of -0.383 on the
-- Long Shore; the Peat Fen takes the same share in the temperate ring. A
-- dressing biome. New nodes: `redwood_log`, `redwood_needles`.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "redwood_stands"

local MOSS_FREQ, MOSS_MIN = 1 / 18, 0.20
local FERN_FREQ, FERN_MIN = 1.4, -0.12                   -- ferns over most of the floor
local FERN_PATCH_FREQ, FERN_PATCH_MIN = 1 / 30, -0.20
local GIANT_CELL, GIANT_SQUARES = 14, 0.55
local YOUNG_CELL, YOUNG_SQUARES = 8, 0.40
local FALLEN_CELL, FALLEN_SQUARES = 48, 0.35

tdw.biomes[ID].ring_mode = "temperate"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.dirt

-- ------------------------------------------------------------ the trees

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "redwood_template:" .. name)
end
local PRIORITY = { [blocks.redwood_log] = 1 }

-- A redwood: a buttressed foot, a straight trunk tapering to a spire, short
-- limbs only in the top third, and narrow tiers of needles there.
local function redwood(rng, big)
    schem.record_begin()
    local tall = big and (40 + rng:below(21)) or (18 + rng:below(11))
    local r0 = big and (1.6 + rng:below(4) * 0.25) or (0.8 + rng:below(3) * 0.15)
    schem.push_path(blocks.redwood_log, { { 0.5, -2.0, 0.5, r0 * 1.35 }, { 0.5, 2.0, 0.5, r0 }, { 0.5, tall * 0.7, 0.5, r0 * 0.6 }, { 0.5, tall, 0.5, 0.2 } }, BLIND)
    if big then
        for i = 0, 3 do
            local d = schem.DIR16[(i * 4 + rng:below(3)) % 16 + 1]
            schem.push_path(blocks.redwood_log, { { 0.5, 2.5, 0.5, r0 * 0.5 }, { 0.5 + d[1] * r0 * 2.0, -1.0, 0.5 + d[2] * r0 * 2.0, 0.35 } }, BLIND)
        end
    end
    local from = math.floor(tall * (big and 0.62 or 0.4))
    for h = from, tall - 1, big and 3 or 2 do
        local t = (h - from) / math.max(1, tall - from)
        local r = (big and 4.2 or 2.6) * (1.0 - t) + 0.8
        schem.push_ellipsoid(blocks.redwood_needles, 0.5, h + 0.5, 0.5, r, 1.2, r, { rough = 0.35, jitter = rng, blind = true })
        if big and rng:below(2) == 0 then
            local d = schem.DIR16[rng:below(16) + 1]
            schem.push_path(blocks.redwood_log, { { 0.5, h, 0.5, 0.35 }, { 0.5 + d[1] * r, h + 0.8, 0.5 + d[2] * r, 0.18 } }, BLIND)
        end
    end
    schem.push_ellipsoid(blocks.redwood_needles, 0.5, tall + 0.6, 0.5, 0.8, 1.6, 0.8, { rough = 0.2, blind = true })
    return schem.record_schematic(PRIORITY)
end
-- A fallen giant: twenty to thirty blocks of trunk on its side, moss along
-- its top.
local function fallen(rng)
    schem.record_begin()
    local length = 20 + rng:below(11)
    local d = schem.DIR16[rng:below(16) + 1]
    local half = length / 2
    local r = 1.3 + rng:below(3) * 0.25
    schem.push_path(blocks.redwood_log, { { 0.5 - d[1] * half, r * 0.6, 0.5 - d[2] * half, r }, { 0.5 + d[1] * half, r * 0.4, 0.5 + d[2] * half, r * 0.6 } }, BLIND)
    schem.push_path(blocks.moss, { { 0.5 - d[1] * half, r * 1.5, 0.5 - d[2] * half, r * 0.6 }, { 0.5 + d[1] * half, r * 1.0, 0.5 + d[2] * half, r * 0.4 } }, { rough = 0.5, blind = true })
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { giants = {}, young = {}, fallen = {} }
    if game.schematic_shapes then
        for i = 1, 6 do out.giants[i] = redwood(rng_for("giant:" .. i), true) end
        for i = 1, 5 do out.young[i] = redwood(rng_for("young:" .. i), false) end
        for i = 1, 4 do out.fallen[i] = fallen(rng_for("fallen:" .. i)) end
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
    local conditions = {
        -- 1: needle mulch over loam.
        n.const(1.0),
        -- 2: moss.
        n.sub(n.noise("rw_moss", MOSS_FREQ, 2, 1.0), n.const(MOSS_MIN)),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    code = n.mul(code, step(masked(n.const(1.0))))
    local depth = shape.compile("biome.redwood.depth", shape.terrain(false))
    local codes = shape.compile("biome.redwood.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 1 * km, material = blocks.mulch },
        { code = 1, from = 1 * km, to = 5 * km, material = blocks.dirt },
        { code = 2, to = 1 * km, material = blocks.moss },
        { code = 2, from = 1 * km, to = 5 * km, material = blocks.dirt },
    }
    local ferns = shape.compile("biome.redwood.ferns", masked(off_river(n.min(n.sub(n.noise("rw_fern", FERN_FREQ, 1, 1.0), n.const(FERN_MIN)),
        n.sub(n.noise("rw_fern_patch", FERN_PATCH_FREQ, 2, 1.0), n.const(FERN_PATCH_MIN))))))
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
        { cover = blocks.fern, cells = 3, take = ferns },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, cell, chance, salt, above)
            fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                salt = salt, sink = 2, above = above, stand = shape.compile("biome.redwood.stand_" .. name, masked(off_river(n.const(1.0)))) }
        end
        scatter("giant", built.giants, GIANT_CELL, GIANT_SQUARES, 331, 0.064)
        scatter("young", built.young, YOUNG_CELL, YOUNG_SQUARES, 332, 0.032)
        scatter("fallen", built.fallen, FALLEN_CELL, FALLEN_SQUARES, 333, 0.004)
    end
    return fills
end)
