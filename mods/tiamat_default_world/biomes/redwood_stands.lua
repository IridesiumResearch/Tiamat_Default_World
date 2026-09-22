-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.14 Redwood Stands: a quarter of the Temperate Woodlands' province on
-- the Long Shore (2026-09-16).
--
-- Giants: redwoods 108 to 162 blocks tall (forty to sixty until 2026-09-17,
-- "about 3 times that big around and about 4.5 times that tall. with more
-- needles"; the whole tree taken to 60% of that on 2026-09-18, `SIZE`) on
-- buttressed feet, bare
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
-- Every length in a tree, a fallen trunk and the spacing, against the
-- 2026-09-17 giants (2026-09-18: "reduce the size of the redwoods to 60%").
local SIZE = 0.6
local GIANT_CELL, GIANT_SQUARES = 22, 0.55              -- 14 until the giants were made three times as thick, 36 until SIZE
local YOUNG_CELL, YOUNG_SQUARES = 11, 0.40              -- 18 until SIZE
local FALLEN_CELL, FALLEN_SQUARES = 36, 0.35            -- 60 until SIZE
local GIANT_ABOVE, YOUNG_ABOVE = 0.290 * SIZE, 0.140 * SIZE   -- km: the tallest of each, and their crowns' tips

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
    local tall = math.floor((big and (180 + rng:below(91)) or (81 + rng:below(46))) * SIZE)
    local r0 = (big and (4.8 + rng:below(4) * 0.75) or (2.4 + rng:below(3) * 0.45)) * SIZE
    schem.push_path(blocks.redwood_log, { { 0.5, -3.0 * SIZE, 0.5, r0 * 1.35 }, { 0.5, 4.0 * SIZE, 0.5, r0 }, { 0.5, tall * 0.7, 0.5, r0 * 0.6 }, { 0.5, tall, 0.5, 0.5 } }, BLIND)
    -- The buttresses: five to seven flaring out and down into the ground.
    local roots = big and (5 + rng:below(3)) or 3
    for i = 0, roots - 1 do
        local d = schem.DIR16[(i * 16 // roots + rng:below(2)) % 16 + 1]
        schem.push_path(blocks.redwood_log, { { 0.5, 7.0 * SIZE, 0.5, r0 * 0.5 }, { 0.5 + d[1] * r0 * 1.6, 1.0 * SIZE, 0.5 + d[2] * r0 * 1.6, r0 * 0.3 },
            { 0.5 + d[1] * r0 * 2.2, -2.0 * SIZE, 0.5 + d[2] * r0 * 2.2, 1.0 * SIZE } }, BLIND)
    end
    -- The crown: dense tiers of needles over the top third, each on a ring
    -- of limbs with a clump at every limb's end.
    local from = math.floor(tall * (big and 0.62 or 0.45))
    local step = big and 3 or 2                           -- 4 and 3 until SIZE: the tiers keep their count
    for h = from, tall - 1, step do
        local t = (h - from) / math.max(1, tall - from)
        local r = ((big and 11.0 or 5.5) * (1.0 - t) + 2.0) * SIZE
        schem.push_ellipsoid(blocks.redwood_needles, 0.5, h + 0.5, 0.5, r, 2.2 * SIZE + 0.4, r, { rough = 0.4, jitter = rng, blind = true })
        local limbs = big and 3 or 2
        local first = rng:below(16)
        for k = 0, limbs - 1 do
            local d = schem.DIR16[(first + k * 16 // limbs + rng:below(3)) % 16 + 1]
            local reach = r * 1.15
            schem.push_path(blocks.redwood_log, { { 0.5, h, 0.5, big and 0.6 or 0.4 }, { 0.5 + d[1] * reach, h + 1.0, 0.5 + d[2] * reach, 0.3 } }, BLIND)
            schem.push_ellipsoid(blocks.redwood_needles, 0.5 + d[1] * reach, h + 1.2, 0.5 + d[2] * reach, (r * 0.45 + 1.0) * SIZE + 0.4, 1.6 * SIZE + 0.3, (r * 0.45 + 1.0) * SIZE + 0.4, { rough = 0.4, jitter = rng, blind = true })
        end
    end
    schem.push_ellipsoid(blocks.redwood_needles, 0.5, tall + 1.0, 0.5, 2.4 * SIZE, 4.8 * SIZE, 2.4 * SIZE, { rough = 0.25, blind = true })
    return schem.record_schematic(PRIORITY)
end
-- A fallen giant: twenty to thirty blocks of trunk on its side, moss along
-- its top.
local function fallen(rng)
    schem.record_begin()
    local length = (40 + rng:below(21)) * SIZE             -- the fallen giants grew with the standing ones (2026-09-17), and shrank with them
    local d = schem.DIR16[rng:below(16) + 1]
    local half = length / 2
    local r = (3.2 + rng:below(3) * 0.6) * SIZE
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
        scatter("giant", built.giants, GIANT_CELL, GIANT_SQUARES, 331, GIANT_ABOVE)
        scatter("young", built.young, YOUNG_CELL, YOUNG_SQUARES, 332, YOUNG_ABOVE)
        scatter("fallen", built.fallen, FALLEN_CELL, FALLEN_SQUARES, 333, 0.010)
    end
    return fills
end)
