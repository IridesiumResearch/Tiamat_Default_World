-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 2.1 Mossy Limestone (2026-09-18).
--
-- Vaulted domes fifteen to twenty-five blocks across and eight to fourteen
-- high, joined by gently sloping crawlspaces; walls rounded and scooped;
-- a floor of wet mud and stepped calcite rimstone basins holding still
-- water; velvety moss over half the lower surfaces, pale vines from the
-- ceiling's crevices, maidenhair micro-ferns at the drips; eroded calcite
-- boulders and gravel beds.
--
-- THE ROOMS are three storeys of them (the band is fifteen hundred blocks
-- tall; two until 2026-09-18). A storey is a footprint noise — positive where a room is, at the
-- rooms' own scale — cut by a vertical profile about the storey's centre,
-- which wanders with a slow noise so no two rooms are at one depth: the
-- footprint shrinks toward the floor and the ceiling (the vault), and a
-- fine noise scoops the walls. A crawlspace is a three-block tube along a
-- contour line at the storey's floor.
--
-- Materials: the limestone is `calcite` (pale; the "one of each" rule
-- keeps `stone` the world's rock and calcite its pale one), the floor `mud`,
-- the beds `gravel`, the moss `moss`, the vines `climbing_ivy`, the water
-- the world's. **One new plant, `maidenhair`; no new material.**

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "mossy_limestone"

-- Three storeys since 2026-09-18 ("the caves seem just a little sparse"):
-- a column through the Limestone met a room 60% of the time with two.
local STOREYS = { 0.42, 1.05, 0.74 }                    -- km under the dome, the centres' means
local STOREY_WANDER = 0.30                              -- km either way, on a slow noise
local ROOM_FREQ, ROOM_MIN, ROOM_W = 1 / 24, 0.03, 30.0  -- the footprint: blobs some twenty across; W scales it to blocks (0.06 until 2026-09-18)
local VAULT = 0.9                                       -- how much the footprint shrinks per block from the centre
local HEIGHT, HEIGHT_VARY = 11.0, 6.0                   -- blocks: 8 to 14
local SCOOP_FREQ, SCOOP = 1 / 5, 1.2                    -- the walls' scoops, blocks
local CRAWL_FREQ, CRAWL_W, CRAWL_H = 1 / 90, 1.5, 1.6   -- the tubes: a contour, half-width, half-height
local BASIN_FREQ, BASIN_MIN = 1 / 9, 0.30               -- the rimstone basins on the floor
local MOSS_FREQ, MOSS_MIN = 1 / 7, -0.10                -- moss over about half the floor
local CUSHION_CELL, CUSHION_SQUARES = 3, 0.70           -- a moss cushion every few blocks of that half
local FERN_FREQ, FERN_MIN = 1.3, 0.34                   -- maidenhair: sparse
local GRAVEL_FREQ, GRAVEL_MIN = 1 / 12, 0.36
local VINE_CELL, VINE_SQUARES = 4, 0.35
local BOULDER_CELL, BOULDER_SQUARES = 10, 0.30

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "mossy_template:" .. name)
end
-- A vine: three to seven blocks of ivy straight down from the root.
local function vine(rng)
    schem.record_begin()
    local drop = 3 + rng:below(5)
    schem.push_path(blocks.climbing_ivy, { { 0.5, 0.2, 0.5, 0.3 }, { 0.5 + (rng:below(3) - 1) * 0.3, -drop, 0.5 + (rng:below(3) - 1) * 0.3, 0.26 } }, BLIND)
    return schem.record_schematic({})
end
-- A boulder: a smooth calcite lump, two to four across, half sunk.
local function boulder(rng)
    schem.record_begin()
    local r = 1.0 + rng:below(3) * 0.5
    schem.push_ellipsoid(blocks.calcite, 0.5, r * 0.4, 0.5, r, r * 0.8, r * (0.8 + rng:below(3) * 0.15), { rough = 0.15, blind = true })
    return schem.record_schematic({})
end
-- A moss cushion (2026-09-18: "Moss should not be on cards it should be a
-- decoration like thin bushes except soft light green"): three to six
-- rough lumps huddled on the floor, a block to two across and half a block
-- to a block high, the lower half of each pressed into the rock. The floor's moss was
-- a cover one cell thick, which read as flat cards laid on the mud.
local function cushion(rng)
    schem.record_begin()
    for _ = 1, 3 + rng:below(4) do
        local d = schem.DIR16[rng:below(16) + 1]
        local off = rng:below(4) * 0.35
        local r = 0.45 + rng:below(4) * 0.15
        local h = 0.5 + rng:below(4) * 0.17
        schem.push_ellipsoid(blocks.moss, 0.5 + d[1] * off, 1.0, 0.5 + d[2] * off, r, h, r * (0.8 + rng:below(3) * 0.15), { rough = 0.5, blind = true })
    end
    return schem.record_schematic({})
end
local BUILT = nil
local function structures()
    if BUILT then return BUILT end
    BUILT = { vines = {}, boulders = {}, cushions = {} }
    if game.schematic_shapes then
        for i = 1, 4 do BUILT.vines[i] = vine(rng_for("vine:" .. i)) end
        for i = 1, 4 do BUILT.boulders[i] = boulder(rng_for("boulder:" .. i)) end
        for i = 1, 6 do BUILT.cushions[i] = cushion(rng_for("cushion:" .. i)) end
    end
    return BUILT
end

-- ------------------------------------------------------------ the fields

tdw.cave_biome(ID, { -0.30, 0.14 }, function(ctx)     -- -0.12 until 2026-09-18, when the Crystal Seam shrank
    local caves = ctx.caves
    -- A storey's centre, km under the dome, and the height of its rooms.
    local function centre(k)
        return n.add(n.noise("ml_storey" .. k, 1 / 900, 1, 2.0 * STOREY_WANDER, shape.HUMIDITY_STRETCH), n.const(STOREYS[k]))   -- slow: at 1/300 a storey climbed a block a block and its floors were ramps
    end
    local function height(k)
        return n.add(n.noise("ml_height" .. k, 1 / 50, 1, HEIGHT_VARY, shape.HUMIDITY_STRETCH), n.const(HEIGHT))
    end
    -- Blocks from the storey's centre, either way: |D - centre| * 1000.
    local function off(k)
        return n.abs(n.mul(n.sub(caves.D(), centre(k)), n.const(1000.0)))
    end
    local function footprint(k)
        return n.mul(n.sub(n.noise("ml_room" .. k, ROOM_FREQ, 2, 1.0, shape.HUMIDITY_STRETCH), n.const(ROOM_MIN)), n.const(ROOM_W))
    end
    -- The room: the lesser of the footprint and the half-height, less the
    -- distance from the centre — the footprint shrinks a block per block
    -- toward the floor and the ceiling, the vault — and the scoops on it.
    -- The distance read ONCE (it carries the dome's polynomial).
    local function room(k)
        local box = n.min(footprint(k), n.mul(height(k), n.const(0.5)))
        return n.add(n.sub(box, off(k)), n.noise("ml_scoop", SCOOP_FREQ, 1, SCOOP))
    end
    -- The crawlspace at the storey's floor: within CRAWL_W of the line and
    -- CRAWL_H of the floor, which is half the height under the centre.
    local function crawl(k)
        local floor_off = n.sub(n.mul(n.sub(caves.D(), centre(k)), n.const(1000.0)), n.mul(height(k), n.const(0.5)))
        return n.min(n.sub(n.const(CRAWL_W), n.contour("ml_crawl" .. k, CRAWL_FREQ, 2)),
            n.sub(n.const(CRAWL_H), n.abs(floor_off)))
    end
    local void = nil
    for k = 1, #STOREYS do
        local storey = n.max(room(k), crawl(k))
        void = void and n.max(void, storey) or storey
    end
    void = ctx.mine(void)
    local carve = ctx.compile("carve", void)
    -- Into the rock from the void: the linings by a code. The floor is the
    -- lower part of a room (off > 0.3 height): mud, basins, gravel; the
    -- rest calcite, two blocks in.
    local function step(f) return n.clamp(n.mul(f, n.const(1e4)), 0.0, 1.0) end
    local function lower(k)
        return n.sub(n.sub(caves.D(), centre(k)), n.mul(height(k), n.const(0.0003)))   -- positive under 0.3 h below the centre
    end
    local floorish = nil
    for k = 1, #STOREYS do
        local f = n.min(lower(k), n.sub(footprint(k), n.const(1.0)))
        floorish = floorish and n.max(floorish, f) or f
    end
    local conditions = {
        n.const(1.0),                                                                             -- 1 calcite
        floorish,                                                                                 -- 2 the floor: mud
        n.min(floorish, n.sub(n.noise("ml_gravel", GRAVEL_FREQ, 1, 1.0), n.const(GRAVEL_MIN))),   -- 3 gravel beds
        n.min(floorish, n.sub(n.noise("ml_basin", BASIN_FREQ, 2, 1.0), n.const(BASIN_MIN))),      -- 4 rimstone: calcite
    }
    local code = n.const(0.0)
    for k, c in ipairs(conditions) do
        code = n.max(code, n.mul(step(c), n.const(k)))
    end
    local depth = ctx.compile("depth", n.mul(void, n.const(-1.0)))
    local codes = ctx.compile("codes", code)
    local entries = {
        { code = 1, to = 2.5, material = blocks.calcite },
        { code = 2, to = 1.2, material = blocks.mud },
        { code = 2, from = 1.2, to = 3.0, material = blocks.calcite },
        { code = 3, to = 1.2, material = blocks.gravel },
        { code = 3, from = 1.2, to = 3.0, material = blocks.calcite },
        { code = 4, to = 3.0, material = blocks.calcite },
    }
    -- The covers stand where air sits on rock, which in a chunk that is
    -- rock throughout is a cave floor: the take needs the province and the
    -- noise, not the void again (five hundred operations a cell).
    local function on_floor(f)
        return ctx.mine(f)
    end
    local moss = ctx.compile("moss", on_floor(n.min(n.sub(n.noise("ml_moss", MOSS_FREQ, 2, 1.0), n.const(MOSS_MIN)), n.sub(n.const(0.5), n.noise("ml_basin", BASIN_FREQ, 2, 1.0)))))
    local fern = ctx.compile("fern", on_floor(n.sub(n.noise("ml_fern", FERN_FREQ, 1, 1.0), n.const(FERN_MIN))))
    local fills = {
        { carve = carve },
        { layers = true, depth = depth, code = codes, entries = entries },
        ctx.caves.vein_fill(ctx, void, 0.0),          -- the crystal veins through the rock (caves.lua)
        { cover = blocks.maidenhair, cells = 3, take = fern },
    }
    if game.schematic_shapes then
        local built = structures()
        -- The vines hang from the ceiling: the depth positive in the VOID,
        -- so the crossing the engine stamps at is rock over air.
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.vines, cell = VINE_CELL, chance = VINE_SQUARES, salt = 401, sink = 0,
            stand = ctx.compile("stand_vine", ctx.mine(n.sub(n.noise("ml_crevice", 1 / 6, 1, 1.0), n.const(0.15)))) }
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.boulders, cell = BOULDER_CELL, chance = BOULDER_SQUARES, salt = 402, sink = 1,
            stand = ctx.compile("stand_boulder", ctx.mine(n.sub(n.noise("ml_boulder", 1 / 15, 1, 1.0), n.const(0.1)))) }
        -- The moss: cushions where the flat cover was (the same field).
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.cushions, cell = CUSHION_CELL, chance = CUSHION_SQUARES, salt = 403, sink = 1,
            stand = moss }
    end
    -- The basins' water: a block deep over the floor, where the basin noise
    -- says, in a room. The level is the storey floor in world y, per storey.
    for k = 1, #STOREYS do
        local floor_y = n.sub(n.add(n.mul(n.sub(shape.dome_node(), centre(k)), n.const(1000.0)), n.const(shape.Y0)),
            n.mul(height(k), n.const(0.5)))
        fills[#fills + 1] = {
            fluid = "tiamot_default_world:water",
            lip = blocks.calcite,
            -- The floor's top block is the vault's plus the scoop: the level
            -- three over the formula's floor is one or two blocks of water.
            level = ctx.compile("pool_level" .. k, n.add(floor_y, n.const(3.0))),
            within = ctx.compile("pool_within" .. k, ctx.mine_flat(n.min(n.sub(footprint(k), n.const(3.0)),
                n.sub(n.noise("ml_basin", BASIN_FREQ, 2, 1.0), n.const(BASIN_MIN))))),
        }
    end
    return fills
end)
