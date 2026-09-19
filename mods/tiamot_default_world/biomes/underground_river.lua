-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 2.3 Underground River (2026-09-18).
--
-- Long meandering tubes ten to eighteen wide and six to ten high, cut by
-- water: an undercut outer bank and a sloping inner shelf; polished grey
-- bedrock along the base, coarse gravel and rounded cobbles, dark silt on
-- the banks; a flowing channel one to three deep down the middle; glowing
-- algae films at the waterline, aquatic moss pads in the current, bleached
-- roots hanging from the ceiling, driftwood snags at the choke points.
--
-- THE TUBE follows a two-octave contour line (the meander); its floor is
-- at a depth that wanders slowly, so the river runs downhill in stretches
-- (the terraced fluid fill holds it in pools with lips where it does). The
-- inner shelf: on the bend's inner side (the signed contour times a bend
-- noise) the floor rises toward the wall, so one bank is a shelf and the
-- other a wall.
--
-- Materials: the bedrock is `stone`, the gravel `gravel`, the silt
-- `black_mud`, the moss pads `ocean_moss`, the roots and snags `dead_log`,
-- the water the world's. **One new material, `cobbles`; one new plant,
-- `glow_algae`.**

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "underground_river"

-- Two rivers since 2026-09-18 ("a little sparse": a column through this
-- ground met a river 7% of the time): the first where it was, a second
-- shallower on its own course. The meanders closer together too.
local RIVERS = {
    { floor = 0.80, wander = 0.25, course = "ur_course", floor_stream = "ur_floor", bend = "ur_bend" },
    { floor = 0.42, wander = 0.15, course = "ur_course2", floor_stream = "ur_floor2", bend = "ur_bend2" },
}
local FLOOR_FREQ = 1 / 1400                              -- the bed's fall: a quarter-kilometre over a kilometre and a half, a block in six at the steepest
local COURSE_FREQ = 1 / 260                             -- the meander (1/420 until 2026-09-18)
local HALF, HALF_VARY = 7.0, 2.0                        -- half-width: 10 to 18 across
local TALL, TALL_VARY = 8.0, 2.0                        -- 6 to 10 high
local SHELF = 0.45                                      -- the inner shelf's rise per block toward its wall
local BEND_FREQ = 1 / 300
local CHANNEL = 0.55                                    -- the channel is this share of the half-width
local WATER_DEEP = 2.6                                  -- blocks over the channel's floor (its air begins half a block under the level's zero)
local SILT_FREQ, SILT_MIN = 1 / 10, 0.15
local COBBLE_FREQ, COBBLE_MIN = 1 / 5, 0.25
local ALGAE_FREQ, ALGAE_MIN = 1 / 3, 0.05
local PAD_FREQ, PAD_MIN = 1.2, 0.30
local ROOT_CELL, ROOT_SQUARES = 6, 0.30
local SNAG_CELL, SNAG_SQUARES = 14, 0.35

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "river_cave_template:" .. name)
end
-- A root: down from the ceiling two to six blocks, forking once.
local function root(rng)
    schem.record_begin()
    local drop = 2 + rng:below(5)
    local d = schem.DIR16[rng:below(16) + 1]
    schem.push_path(blocks.dead_log, { { 0.5, 0.3, 0.5, 0.4 }, { 0.5 + d[1] * 0.8, -drop, 0.5 + d[2] * 0.8, 0.2 } }, BLIND)
    if rng:below(2) == 0 then
        local e = schem.DIR16[rng:below(16) + 1]
        schem.push_path(blocks.dead_log, { { 0.5, -drop * 0.4, 0.5, 0.3 }, { 0.5 + e[1] * 1.5, -drop * 0.8, 0.5 + e[2] * 1.5, 0.15 } }, BLIND)
    end
    return schem.record_schematic({})
end
-- A snag: a trunk four to eight long lying across the floor.
local function snag(rng)
    schem.record_begin()
    local len = 4 + rng:below(5)
    local d = schem.DIR16[rng:below(16) + 1]
    schem.push_path(blocks.dead_log, { { 0.5 - d[1] * len / 2, 0.3, 0.5 - d[2] * len / 2, 0.5 }, { 0.5 + d[1] * len / 2, 0.6, 0.5 + d[2] * len / 2, 0.35 } }, BLIND)
    return schem.record_schematic({})
end
local BUILT = nil
local function structures()
    if BUILT then return BUILT end
    BUILT = { roots = {}, snags = {} }
    if game.schematic_shapes then
        for i = 1, 4 do BUILT.roots[i] = root(rng_for("root:" .. i)) end
        for i = 1, 4 do BUILT.snags[i] = snag(rng_for("snag:" .. i)) end
    end
    return BUILT
end

-- ------------------------------------------------------------ the fields

tdw.cave_biome(ID, { 0.14, 1 }, function(ctx)
    local caves = ctx.caves
    local function floor_d(k)
        local river = RIVERS[k]
        return n.add(n.noise(river.floor_stream, FLOOR_FREQ, 1, 2.0 * river.wander, shape.HUMIDITY_STRETCH), n.const(river.floor))
    end
    local function across_of(k)
        return n.contour(RIVERS[k].course, COURSE_FREQ, 2)
    end
    local function signed(k)
        return n.contour(RIVERS[k].course, COURSE_FREQ, 2, true)
    end
    -- The nearer of the two courses, for the linings and the covers: they
    -- paint only rock within a block or two of a void, so the course they
    -- belong to is the one that void is.
    local function across()
        return n.min(across_of(1), across_of(2))
    end
    local function half()
        return n.add(n.noise("ur_half", 1 / 60, 1, HALF_VARY, shape.HUMIDITY_STRETCH), n.const(HALF))
    end
    local function tall()
        return n.add(n.noise("ur_tall", 1 / 40, 1, TALL_VARY, shape.HUMIDITY_STRETCH), n.const(TALL))
    end
    -- The inner shelf: blocks past the channel's edge on the bend's inner
    -- side (the signed contour times a bend noise says which side), and
    -- nothing in the channel — the first cut raised the channel's own floor
    -- on that side and left the water level under it.
    local function inner(k)
        local side = n.clamp(n.mul(n.mul(signed(k), n.noise(RIVERS[k].bend, BEND_FREQ, 1, 1.0)), n.const(10.0)), 0.0, 1.0)
        return n.mul(n.clamp(n.sub(across_of(k), n.mul(half(), n.const(CHANNEL))), 0.0, 40.0), side)
    end
    -- Blocks above a river's local floor, the floor rising over the shelf.
    local function up(k)
        return n.sub(n.mul(n.sub(floor_d(k), caves.D()), n.const(1000.0)), n.mul(inner(k), n.const(SHELF)))
    end
    local function tube(k)
        local h = up(k)
        return n.min(n.min(n.add(h, n.const(0.5)), n.sub(tall(), up(k))), n.sub(half(), across_of(k)))
    end
    local void = ctx.mine(n.max(tube(1), tube(2)))
    local carve = ctx.compile("carve", void)
    local function step(f) return n.clamp(n.mul(f, n.const(1e4)), 0.0, 1.0) end
    -- Linings, by distance from the course: the channel's bed cobbles and
    -- gravel, the banks silt and gravel, the walls stone (the rock itself).
    local in_channel = n.sub(n.mul(half(), n.const(CHANNEL)), across())
    local conditions = {
        n.const(1.0),                                                                                   -- 1 stone: the walls
        n.sub(n.mul(half(), n.const(0.85)), across()),                                                   -- 2 the banks: gravel
        n.min(n.sub(n.mul(half(), n.const(0.85)), across()), n.sub(n.noise("ur_silt", SILT_FREQ, 1, 1.0), n.const(SILT_MIN))),  -- 3 silt flats
        in_channel,                                                                                     -- 4 the bed: gravel
        n.min(in_channel, n.sub(n.noise("ur_cobble", COBBLE_FREQ, 1, 1.0), n.const(COBBLE_MIN))),        -- 5 cobbles
    }
    local code = n.const(0.0)
    for k, c in ipairs(conditions) do
        code = n.max(code, n.mul(step(c), n.const(k)))
    end
    local depth = ctx.compile("depth", n.mul(void, n.const(-1.0)))
    local codes = ctx.compile("codes", code)
    local entries = {
        { code = 2, to = 1.2, material = blocks.gravel },
        { code = 3, to = 1.2, material = blocks.black_mud },
        { code = 4, to = 1.5, material = blocks.gravel },
        { code = 5, to = 1.5, material = blocks.cobbles },
    }
    -- A cover stands where air sits on rock: a cave floor, in these chunks.
    local function on_floor(f)
        return ctx.mine(f)
    end
    -- Algae at the waterline: on the floor just outside the channel; moss
    -- pads in the channel.
    local algae = ctx.compile("algae", on_floor(n.min(n.min(n.sub(across(), n.mul(half(), n.const(CHANNEL - 0.05))), n.sub(n.mul(half(), n.const(0.8)), across())),
        n.sub(n.noise("ur_algae", ALGAE_FREQ, 1, 1.0), n.const(ALGAE_MIN)))))
    local pads = ctx.compile("pads", on_floor(n.min(in_channel, n.sub(n.noise("ur_pad", PAD_FREQ, 1, 1.0), n.const(PAD_MIN)))))
    local fills = {
        { carve = carve },
        { layers = true, depth = depth, code = codes, entries = entries },
        caves.vein_fill(ctx, void, 0.0),              -- the crystal veins through the rock (caves.lua)
        { cover = blocks.glow_algae, cells = 1, take = algae },
        { cover = blocks.ocean_moss, cells = 1, take = pads },
    }
    if game.schematic_shapes then
        local built = structures()
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.roots, cell = ROOT_CELL, chance = ROOT_SQUARES, salt = 421, sink = 0,
            stand = ctx.compile("stand_root", ctx.mine(n.sub(n.noise("ur_roots", 1 / 20, 1, 1.0), n.const(0.1)))) }
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.snags, cell = SNAG_CELL, chance = SNAG_SQUARES, salt = 422, sink = 1,
            stand = ctx.compile("stand_snag", ctx.mine(n.min(in_channel, n.sub(n.const(HALF - 0.8), half())))) }
    end
    -- Each river: WATER_DEEP over its channel's floor, in world y. The floor
    -- is the tube's, without the shelf (the channel is the middle).
    for k = 1, #RIVERS do
        local floor_y = n.sub(n.mul(n.sub(shape.dome_node(), floor_d(k)), n.const(1000.0)), n.const(-shape.Y0))
        fills[#fills + 1] = {
            fluid = "tiamot_default_world:water",
            lip = blocks.stone,
            level = ctx.compile("river_level" .. k, n.add(floor_y, n.const(WATER_DEEP))),
            -- `mine_flat`, not `mine`: a fluid fill's fields are read on the
            -- slice at y = 0.5 (caves.lua).
            within = ctx.compile("river_within" .. k, ctx.mine_flat(n.sub(n.mul(half(), n.const(CHANNEL)), across_of(k)))),
        }
    end
    return fills
end)
