-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.10 Mangrove Coast: the reef lane's wet-side shores (2026-09-16), where
-- the Jungle comes down to the lagoon.
--
-- Mud flats at the tide line under mangroves standing on arched prop roots
-- in the shallows, their crowns a low dark-green roof; tidal channels of
-- gravel wandering through the mud, black silt in the hollows, saplings
-- out in the water, and moss on the land behind. The lagoon and the reef
-- past it are the Coral-Fringed Shallows'.
--
-- Where: the second lane's shores (the reef's band) on the humidity noise's
-- wet side, from twenty-four blocks inland to twenty out; the reef and the
-- Coastal Cliffs keep off it (`shape.off_mangrove`). Its ground is the
-- coast's, unchanged. New nodes: `mangrove_log`, `mangrove_leaves`.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local seas = tdw.seas
local n = shape.node
local ID = "mangrove_coast"

local REEF_U = { 0.30, 0.466 }                           -- the reef's lane (coral_fringed_shallows.lua)
local LAND, OUT = 24.0, 20.0                             -- blocks inland and out to sea
local SILT_FREQ, SILT_MIN = 1 / 25, 0.20
local CHANNEL_FREQ, CHANNEL_W = 1 / 70, 1.6
local TREE_CELL, TREE_SQUARES = 6, 0.55
local SAPLING_CELL, SAPLING_SQUARES = 5, 0.30

-- Positive inside the coast: the lane, the wet side, the strip either side
-- of the line. Units are mixed; only the sign is read.
function shape.mangrove_zone()
    local strip = n.min(n.sub(n.const(OUT), seas.d_map()), n.add(seas.d_map(), n.const(LAND)))
    local wet = n.mul(n.sub(n.const(0.5), shape.dry_weight()), n.const(200.0))
    local lane = n.mul(n.sub(shape.reef_band(), n.const(0.5)), n.const(200.0))
    return n.min(strip, n.min(wet, lane))
end
function shape.off_mangrove()
    return n.mul(shape.mangrove_zone(), n.const(-1.0))
end

-- For the HUD: the band, the wet side (the placement field), the strip.
function tdw.mangrove_at(x, z, d)
    local only = tdw.config.everywhere
    if only then
        return only == ID and ID or nil
    end
    local u = (x * x + z * z) * 1e-6 / (shape.R_DISC * shape.R_DISC)
    if u < REEF_U[1] or u > REEF_U[2] or d > OUT or d < -LAND then
        return nil
    end
    return tdw.placed_at(ID, x, z) and ID or nil
end

tdw.biomes[ID].ring_mode = "temperate"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.mud
tdw.biomes[ID].present = function(pos)
    if seas.class(pos) ~= "shore" then
        return false
    end
    local x, z = pos.x * 16 + 8, pos.z * 16 + 8
    local u = (x * x + z * z) * 1e-6 / (shape.R_DISC * shape.R_DISC)
    local w = shape.wobble(u) + 0.002
    return u >= REEF_U[1] - w and u <= REEF_U[2] + w
end
tdw.biomes[ID].locate = function(px, pz, seed)
    return seas.locate(px, pz, seed, -14.0, -3.0, REEF_U[1], REEF_U[2], nil, function(x, z)
        return tdw.placed_at(ID, x, z)
    end)
end

-- ------------------------------------------------------------ the trees

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "mangrove_template:" .. name)
end
local PRIORITY = { [blocks.mangrove_log] = 1 }

-- A mangrove: a trunk that starts three blocks up, held on four to six
-- prop roots arching out and down to the mud; a crooked stem to six to
-- nine blocks; a low, wide crown of two or three flattened clumps.
local function mangrove(rng)
    schem.record_begin()
    local base = 2.5 + rng:below(3) * 0.4
    local tall = 6 + rng:below(4)
    local roots = 4 + rng:below(3)
    local first = rng:below(16)
    for i = 0, roots - 1 do
        local d = schem.DIR16[(first + i * 16 // roots) % 16 + 1]
        local reach = 2.0 + rng:below(3) * 0.4
        schem.push_path(blocks.mangrove_log, { { 0.5, base, 0.5, 0.3 },
            { 0.5 + d[1] * reach * 0.6, base + 0.6, 0.5 + d[2] * reach * 0.6, 0.22 },
            { 0.5 + d[1] * reach, -1.2, 0.5 + d[2] * reach, 0.18 } }, BLIND)
    end
    local x, z = 0.5 + (rng:below(3) - 1) * 0.3, 0.5 + (rng:below(3) - 1) * 0.3
    local trunk = { { 0.5, base - 0.5, 0.5, 0.36 }, { x, tall * 0.7, z, 0.3 }, { x + (rng:below(3) - 1) * 0.4, tall, z, 0.22 } }
    schem.push_path(blocks.mangrove_log, trunk, BLIND)
    local top = trunk[#trunk]
    schem.push_ellipsoid(blocks.mangrove_leaves, top[1], top[2] + 0.5, top[3], 3.0 + rng:below(3) * 0.4, 1.4, 3.0 + rng:below(3) * 0.4, { rough = 0.35, blind = true })
    for _ = 1, 1 + rng:below(2) do
        local d = schem.DIR16[rng:below(16) + 1]
        schem.push_ellipsoid(blocks.mangrove_leaves, top[1] + d[1] * 2.4, top[2] - 0.4, top[3] + d[2] * 2.4, 2.0, 1.0, 2.0, { rough = 0.4, blind = true })
    end
    return schem.record_schematic(PRIORITY)
end
-- A sapling in the water: a stem on three small roots, a tuft of leaves.
local function sapling(rng)
    schem.record_begin()
    local tall = 2 + rng:below(2)
    for i = 0, 2 do
        local d = schem.DIR16[(i * 5 + rng:below(2)) % 16 + 1]
        schem.push_path(blocks.mangrove_log, { { 0.5, 1.0, 0.5, 0.15 }, { 0.5 + d[1] * 0.8, -0.8, 0.5 + d[2] * 0.8, 0.1 } }, BLIND)
    end
    schem.push_path(blocks.mangrove_log, { { 0.5, 0.8, 0.5, 0.15 }, { 0.5, tall, 0.5, 0.12 } }, BLIND)
    schem.push_ellipsoid(blocks.mangrove_leaves, 0.5, tall + 0.3, 0.5, 1.0, 0.6, 1.0, { rough = 0.3, blind = true })
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { trees = {}, saplings = {} }
    if game.schematic_shapes then
        for i = 1, 8 do out.trees[i] = mangrove(rng_for("tree:" .. i)) end
        for i = 1, 4 do out.saplings[i] = sapling(rng_for("sapling:" .. i)) end
    end
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

tdw.build_biome(ID, function(ctx)
    local function ys()
        return n.mul(n.sub(n.Y(), n.const(shape.Y0)), n.const(shape.SCALE))
    end
    local function over_sea()
        return n.sub(ys(), seas.level())
    end
    local function masked(field)
        return n.min(field, shape.mangrove_zone())
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    local conditions = {
        -- 1: the mud flats.
        n.const(1.0),
        -- 2: black silt in the hollows.
        n.sub(n.noise("mg_silt", SILT_FREQ, 2, 1.0), n.const(SILT_MIN)),
        -- 3: a tidal channel's gravel.
        n.sub(n.const(CHANNEL_W), n.contour("mg_channel", CHANNEL_FREQ, 1)),
        -- 4: moss on the land behind, over the tide.
        n.sub(over_sea(), n.const(0.004)),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    code = n.mul(code, step(masked(n.const(1.0))))
    local depth = shape.compile("biome.mangrove.depth", shape.terrain(false))
    local codes = shape.compile("biome.mangrove.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 4 * km, material = blocks.mud },
        { code = 2, to = 2 * km, material = blocks.black_mud },
        { code = 2, from = 2 * km, to = 4 * km, material = blocks.mud },
        { code = 3, to = 2 * km, material = blocks.gravel },
        { code = 3, from = 2 * km, to = 4 * km, material = blocks.mud },
        { code = 4, to = 1 * km, material = blocks.moss },
        { code = 4, from = 1 * km, to = 4 * km, material = blocks.mud },
    }
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, above)
            fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                salt = salt, sink = 1, above = above, stand = shape.compile("biome.mangrove.stand_" .. name, masked(field)) }
        end
        -- The trees at the tide line, the saplings a little out.
        scatter("tree", built.trees, n.min(n.add(over_sea(), n.const(0.003)), n.sub(n.const(0.003), over_sea())), TREE_CELL, TREE_SQUARES, 291, 0.014)
        scatter("sapling", built.saplings, n.min(n.add(over_sea(), n.const(0.005)), n.sub(n.const(-0.001), over_sea())), SAPLING_CELL, SAPLING_SQUARES, 292, 0.005)
    end
    return fills
end)
