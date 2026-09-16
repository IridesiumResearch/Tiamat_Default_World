-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 2.8 Silverwood: Firwold's other half (2026-09-16) — "I need a second
-- biome in taiga too".
--
-- Where the Taiga is a dark wall of spruce over peat, this is the same
-- country gone pale and open: birch and aspen in loose stands, white
-- trunks, small bright leaves, and a floor of lichen with mulch under the
-- stands and moss on the ridge crests. The basins are still peat and
-- black water, since the ground is the Taiga's.
--
-- **No terms of its own.** It stands on `shape.taiga_terms` and reads the
-- Taiga's feature fields (`shape.taiga_feature`): the uplands roll the
-- same way, the ridges are where the Taiga's are, the basins hold the same
-- pools. A dressing biome, for the same reason as the Icefall.
--
-- New node: `lichen`, the floor. The trunks are the woodland's birch log,
-- the leaves the Flower Forest's birch leaves.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "silverwood"

local MULCH_FREQ, MULCH_MIN = 1 / 12, 0.24               -- mulch under the stands
local STAND_FREQ, STAND_MIN = 1 / 55, 0.02               -- the stands: a slow noise, most of the ground
local BIRCH_CELL, BIRCH_SQUARES = 4, 0.55                -- close in a stand
local ASPEN_CELL, ASPEN_SQUARES = 6, 0.40
local LOG_CELL, LOG_SQUARES = 34, 0.30
local BOULDER_CELL, BOULDER_SQUARES = 26, 0.30
local GRASS_FREQ, GRASS_MIN = 1.4, 0.36                  -- the Taiga's rust grass, sparser than there
local BASIN_OFF = 0.2                                    -- nothing of the trees where the basin weight is over this

tdw.biomes[ID].ring_mode = "rim"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.dirt

-- ------------------------------------------------------------ the trees

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "silverwood_template:" .. name)
end
local PRIORITY = { [blocks.birch_log] = 1, [blocks.granite] = 1 }

-- A birch: a slim white trunk eight to fourteen blocks with a little
-- wander, a few short limbs high up, and a narrow crown.
local function birch(rng)
    schem.record_begin()
    local tall = 8 + rng:below(7)
    local trunk = { { 0.5, -1.5, 0.5, 0.48 } }
    local x, z = 0.5, 0.5
    for i = 1, 3 do
        local t = i / 3
        x = x + (rng:below(3) - 1) * 0.18
        z = z + (rng:below(3) - 1) * 0.18
        trunk[#trunk + 1] = { x, t * tall, z, 0.42 - 0.2 * t }
    end
    schem.push_path(blocks.birch_log, trunk, BLIND)
    local top = trunk[#trunk]
    for _ = 1, 2 + rng:below(3) do
        local d = schem.DIR16[rng:below(16) + 1]
        local h = tall * (0.55 + rng:below(35) / 100)
        local bx, by, bz = schem.path_point(trunk, h)
        local reach = 1.2 + rng:below(3) * 0.4
        schem.push_path(blocks.birch_log, { { bx, by, bz, 0.2 },
            { bx + d[1] * reach, by + 1.0 + rng:below(3) * 0.3, bz + d[2] * reach, 0.13 } }, BLIND)
        schem.push_ellipsoid(blocks.birch_leaves, bx + d[1] * reach, by + 1.5, bz + d[2] * reach,
            1.4 + rng:below(3) * 0.25, 1.2, 1.4 + rng:below(3) * 0.25, { rough = 0.4, blind = true })
    end
    schem.push_ellipsoid(blocks.birch_leaves, top[1], top[2] + 0.9, top[3],
        1.8 + rng:below(3) * 0.3, 2.2, 1.8 + rng:below(3) * 0.3, { rough = 0.35, blind = true })
    return schem.record_schematic(PRIORITY)
end

-- An aspen: taller and straighter, its crown a rounded head near the top
-- and nothing below it — the trunk stands bare for most of its height.
local function aspen(rng)
    schem.record_begin()
    local tall = 11 + rng:below(7)
    schem.push_path(blocks.birch_log, { { 0.5, -1.5, 0.5, 0.5 }, { 0.5, tall * 0.5, 0.5, 0.4 }, { 0.5, tall, 0.5, 0.24 } }, BLIND)
    local r = 2.0 + rng:below(3) * 0.35
    schem.push_ellipsoid(blocks.birch_leaves, 0.5, tall - r * 0.4, 0.5, r, r * 1.3, r, { rough = 0.35, blind = true })
    for _ = 1, 2 do
        local d = schem.DIR16[rng:below(16) + 1]
        schem.push_ellipsoid(blocks.birch_leaves, 0.5 + d[1] * r * 0.6, tall - r * 0.8 + rng:below(3) * 0.4, 0.5 + d[2] * r * 0.6,
            r * 0.6, r * 0.7, r * 0.6, { rough = 0.4, blind = true })
    end
    return schem.record_schematic(PRIORITY)
end

-- A fallen birch, lichened along its top.
local function fallen_birch(rng)
    schem.record_begin()
    local length = 5 + rng:below(6)
    local d = schem.DIR16[rng:below(16) + 1]
    local half = length / 2
    schem.push_path(blocks.birch_log, { { 0.5 - d[1] * half, 0.3, 0.5 - d[2] * half, 0.55 }, { 0.5 + d[1] * half, 0.15, 0.5 + d[2] * half, 0.42 } }, BLIND)
    schem.push_path(blocks.lichen, { { 0.5 - d[1] * half, 0.8, 0.5 - d[2] * half, 0.42 }, { 0.5 + d[1] * half, 0.6, 0.5 + d[2] * half, 0.34 } }, { rough = 0.5, blind = true })
    return schem.record_schematic(PRIORITY)
end

-- A granite boulder with lichen over its top.
local function boulder(rng)
    schem.record_begin()
    local r = 1.2 + rng:below(4) * 0.35
    schem.push_ellipsoid(blocks.granite, 0.5, r * 0.3, 0.5, r, r * 0.8, r * (0.8 + rng:below(3) * 0.1), { rough = 0.3, blind = true })
    schem.push_ellipsoid(blocks.lichen, 0.5, r * 0.3 + r * 0.55, 0.5, r * 0.75, r * 0.35, r * 0.7, { rough = 0.5, blind = true })
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { birches = {}, aspens = {}, logs = {}, boulders = {} }
    if game.schematic_shapes then
        for i = 1, 6 do out.birches[i] = birch(rng_for("birch:" .. i)) end
        for i = 1, 4 do out.aspens[i] = aspen(rng_for("aspen:" .. i)) end
        for i = 1, 4 do out.logs[i] = fallen_birch(rng_for("log:" .. i)) end
        for i = 1, 4 do out.boulders[i] = boulder(rng_for("boulder:" .. i)) end
    end
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

tdw.build_biome(ID, function(ctx)
    local T = shape.taiga_feature
    local function masked(field)
        local mask = tdw.biome_mask(n, ID)
        return mask and n.min(field, mask) or field
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    local function stands()
        return n.sub(n.noise("sw_stand", STAND_FREQ, 2, 1.0), n.const(STAND_MIN))
    end
    local conditions = {
        -- 1: the lichen floor, everywhere.
        n.const(1.0),
        -- 2: mulch under the stands.
        n.min(stands(), n.sub(n.noise("sw_mulch", MULCH_FREQ, 2, 1.0), n.const(MULCH_MIN))),
        -- 3: moss on the ridge crests.
        n.sub(T.ridge(), n.const(0.6)),
        -- 4: the basins: the Taiga's peat and black water.
        n.sub(T.basin(), n.const(0.5)),
        -- 5: the channels through them: wet gravel.
        n.min(n.sub(T.channel(), n.const(0.5)), n.sub(T.basin(), n.const(0.5))),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    local mask = tdw.biome_mask(n, ID)
    if mask then
        code = n.mul(code, step(mask))
    end
    local depth = shape.compile("biome.silverwood.depth", shape.terrain(false))
    local codes = shape.compile("biome.silverwood.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 1 * km, material = blocks.lichen },
        { code = 1, from = 1 * km, to = 4 * km, material = blocks.dirt },
        { code = 2, to = 1 * km, material = blocks.mulch },
        { code = 2, from = 1 * km, to = 4 * km, material = blocks.dirt },
        { code = 3, to = 1 * km, material = blocks.moss },
        { code = 3, from = 1 * km, to = 3 * km, material = blocks.granite },
        { code = 4, to = 3 * km, material = blocks.black_mud },
        { code = 4, from = 3 * km, to = 6 * km, material = blocks.mud },
        { code = 5, to = 1 * km, material = blocks.creek_bed },
        { code = 5, from = 1 * km, to = 4 * km, material = blocks.mud },
    }
    local grass = shape.compile("biome.silverwood.grass", masked(n.min(n.sub(n.const(BASIN_OFF), T.basin()),
        n.sub(n.noise("sw_grass", GRASS_FREQ, 1, 1.0), n.const(GRASS_MIN)))))
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
        { cover = blocks.rust_grass, cells = 2, take = grass },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt)
            if #list > 0 then
                fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                    salt = salt, sink = 1, stand = shape.compile("biome.silverwood.stand_" .. name, masked(field)) }
            end
        end
        local firm = n.sub(n.const(BASIN_OFF), T.basin())
        scatter("birch", built.birches, n.min(firm, stands()), BIRCH_CELL, BIRCH_SQUARES, 181)
        scatter("aspen", built.aspens, n.min(firm, n.sub(stands(), n.const(0.12))), ASPEN_CELL, ASPEN_SQUARES, 182)
        scatter("log", built.logs, firm, LOG_CELL, LOG_SQUARES, 183)
        scatter("boulder", built.boulders, n.min(firm, n.sub(T.ridge(), n.const(0.3))), BOULDER_CELL, BOULDER_SQUARES, 184)
    end
    return fills
end)
