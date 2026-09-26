-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.3 Shadow Pool Chambers (2026-09-26).
--
-- Broad, low caverns twenty to thirty-five blocks across and only four to
-- seven high, the ceiling undulating so close over the floor that it dips
-- into the water in places. Most of the floor is a reservoir of ink-black
-- water a block to three deep, dead still; mud shelves stand out of it,
-- and stepping stones. Wet charcoal shale; slick black mud. Pale weed
-- ribbons standing in the water, black biofilm along the shores, pale
-- sponges on the submerged rock. Drips from the hollows in the ceiling.
--
-- THE CHAMBERS: a footprint noise, flat in y, for the plan, and a water
-- level at each storey's wandering centre. The floor is one to three
-- blocks under the water, lifted a little over it where a shelf noise or a
-- fine stepping-stone noise says. The ceiling is a two-octave noise over
-- the water, from half a block UNDER it (a flooded crawl) to six over, and
-- three more in the drip hollows.
--
-- THE WATER is `still_water` (blocks.lua): the water block's surface,
-- near-opaque, black from inside, and three levels of light lost a block.
-- Laid full to each storey's level, so every reservoir is a body at rest —
-- mirror-flat, no ripple — until somebody wades in.
--
-- Materials: `charcoal` for the shale, `black_mud` for the shelves, the
-- floors and the biofilm, `seagrass` for the weed ribbons and `pumice` for
-- the sponges. **No new block.**

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "shadow_pool_chambers"
local FLAT = tdw.caves.DEEP_FLAT                     -- flat in y, all the way to y = 0.5 (caves.lua)

local STOREYS = { 1.90, 2.60, 3.35 }                    -- km under the dome
local STOREY_WANDER, WANDER_FREQ = 0.015, 1 / 4000   -- the water lies level: a storey barely tilts
local ROOM_FREQ, ROOM_MIN, ROOM_K = 1 / 55, 0.05, 34.0  -- twenty to thirty-five across
local BED_FREQ, BED_TOP, BED_FALL = 1 / 18, 1.2, 1.4    -- the floor 1.2 to 2.6 under the water
local SHELF_FREQ, SHELF_MIN = 1 / 24, 0.12
local STONE_FREQ, STONE_MIN = 1 / 4, 0.30
local DRY = 0.6                                         -- a shelf or a stone stands this far out of the water
local CEIL_FREQ, CEIL_LOW, CEIL_SPAN = 1 / 14, -0.5, 6.5
local HOLLOW_FREQ, HOLLOW_MIN, HOLLOW_H = 1 / 8, 0.35, 3.0
local WEED_FREQ, WEED_MIN, WEED_DEEP = 1 / 9, 0.05, 1.6   -- only in the deeper water, and short enough to stay under it
local SPONGE_CELL, SPONGE_SQUARES = 6, 0.20

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "shadow_pool_template:" .. name)
end
-- A shelf-sponge: one to three pale rubbery lobes, half a block to a block
-- wide, on the rock at the foot of the water.
local function sponge(rng)
    schem.record_begin()
    for i = 1, 1 + rng:below(3) do
        local d = schem.DIR16[rng:below(16) + 1]
        local off = (i - 1) * 0.45
        local r = 0.25 + rng:below(3) * 0.1
        schem.push_ellipsoid(blocks.pumice, 0.5 + d[1] * off, 1.1 + (i - 1) * 0.2, 0.5 + d[2] * off, r, r * 0.55, r, BLIND)
    end
    return schem.record_schematic({})
end
local BUILT = nil
local function structures()
    if BUILT then return BUILT end
    BUILT = { sponges = {} }
    if game.schematic_shapes then
        for i = 1, 5 do BUILT.sponges[i] = sponge(rng_for("sponge:" .. i)) end
    end
    return BUILT
end

-- ------------------------------------------------------------ the fields

local function centre(k)
    return n.add(n.noise("spc_storey" .. k, WANDER_FREQ, 1, 2.0 * STOREY_WANDER, FLAT), n.const(STOREYS[k]))
end

tdw.cave_biome(ID, { 0.15, 1 }, function(ctx)
    local caves = ctx.caves
    -- Blocks above the water: the depth FIRST.
    local function up(k)
        return n.mul(n.sub(centre(k), caves.D()), n.const(1000.0))
    end
    local function footprint(k)
        return n.mul(n.sub(n.noise("spc_room" .. k, ROOM_FREQ, 2, 1.0, FLAT), n.const(ROOM_MIN)), n.const(ROOM_K))
    end
    -- The floor's height over the water (negative: under it). The bed, then
    -- the shelves and the stones lifting it to DRY: bed + (DRY - bed) * s.
    local function floor_at()
        local bed = n.sub(n.mul(n.clamp(n.add(n.mul(n.noise("spc_bed", BED_FREQ, 1, 1.0, FLAT), n.const(3.0)), n.const(0.5)), 0.0, 1.0),
            n.const(-BED_FALL)), n.const(BED_TOP))
        local s = n.max(n.clamp(n.mul(n.sub(n.noise("spc_shelf", SHELF_FREQ, 1, 1.0, FLAT), n.const(SHELF_MIN)), n.const(8.0)), 0.0, 1.0),
            n.clamp(n.mul(n.sub(n.noise("spc_stone", STONE_FREQ, 1, 1.0, FLAT), n.const(STONE_MIN)), n.const(10.0)), 0.0, 1.0))
        return n.add(n.mul(n.sub(bed, n.const(DRY)), n.add(n.mul(s, n.const(-1.0)), n.const(1.0))), n.const(DRY))
    end
    local function ceiling_at()
        local low = n.add(n.mul(n.clamp(n.add(n.mul(n.noise("spc_ceil", CEIL_FREQ, 2, 1.0, FLAT), n.const(1.4)), n.const(0.6)), 0.0, 1.0),
            n.const(CEIL_SPAN)), n.const(CEIL_LOW))
        return n.add(low, n.mul(n.clamp(n.mul(n.sub(n.noise("spc_hollow", HOLLOW_FREQ, 1, 1.0, FLAT), n.const(HOLLOW_MIN)), n.const(8.0)), 0.0, 1.0),
            n.const(HOLLOW_H)))
    end
    local function chamber(k)
        return n.min(n.min(n.sub(up(k), floor_at()), n.sub(ceiling_at(), up(k))), footprint(k))
    end
    local v, floors, wet = nil, nil, nil
    for k = 1, #STOREYS do
        v = v and n.max(v, chamber(k)) or chamber(k)
        -- The rock under a chamber's floor, for the mud.
        local f = n.min(n.sub(floor_at(), up(k)), n.add(footprint(k), n.const(2.0)))
        floors = floors and n.max(floors, f) or f
        -- How far under the water a place is, in a chamber's reach.
        local w = n.min(n.mul(up(k), n.const(-1.0)), n.add(footprint(k), n.const(1.0)))
        wet = wet and n.max(wet, w) or w
    end
    local void = ctx.mine(v)
    local carve = ctx.compile("carve", void)
    local function step(f) return n.clamp(n.mul(f, n.const(1e4)), 0.0, 1.0) end
    local code = n.max(n.const(1.0), n.mul(step(floors), n.const(2.0)))
    local depth = ctx.compile("depth", n.mul(void, n.const(-1.0)))
    local fills = {
        { layers = true, depth = depth, code = ctx.compile("codes", code), entries = {
            { code = 1, to = 3.0, material = blocks.charcoal },
            { code = 2, to = 2.0, material = blocks.black_mud },
            { code = 2, from = 2.0, to = 3.0, material = blocks.charcoal },
        } },
        { carve = carve },
        -- The weed ribbons, standing a block or so high in the deeper water;
        -- the biofilm, a sheet a cell thick along the shores. Before the
        -- water, which takes the room they leave.
        { cover = blocks.seagrass, cells = 4, take = ctx.compile("take_weed",
            ctx.mine(n.min(n.sub(wet, n.const(WEED_DEEP)), n.sub(n.noise("spc_weed", WEED_FREQ, 1, 1.0, FLAT), n.const(WEED_MIN))))) },
        { cover = blocks.black_mud, cells = 1, take = ctx.compile("take_film",
            ctx.mine(n.sub(n.const(0.8), n.abs(n.add(wet, n.const(0.3)))))) },
    }
    if game.schematic_shapes then
        local built = structures()
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.sponges, cell = SPONGE_CELL, chance = SPONGE_SQUARES, salt = 491, sink = 1,
            stand = ctx.compile("stand_sponges", ctx.mine(n.sub(wet, n.const(0.8)))) }
    end
    -- The reservoirs: still water to each storey's level, within its
    -- chambers, held by mud where the rock leaves a block less than whole.
    for k = 1, #STOREYS do
        local level_y = n.add(n.mul(n.sub(shape.dome_node(), centre(k)), n.const(1000.0)), n.const(shape.Y0))
        -- `reach`: this storey's chunks alone (caves.lua, `M.into`) — laid in
        -- the storeys under it, the water would fill their chambers solid.
        local reach = STOREY_WANDER + 0.02
        fills[#fills + 1] = { fluid = "tiamat_default_world:still_water", lip = blocks.black_mud,
            reach = { STOREYS[k] - reach, STOREYS[k] + reach },
            level = ctx.compile("water_level" .. k, level_y),
            within = ctx.compile("water_within" .. k, ctx.mine_flat(n.sub(footprint(k), n.const(1.0)))) }
    end
    return fills
end)

-- ------------------------------------------------------------ the drips

-- Heavy drops from the hollows, now and then, near each player the HUD's
-- cave test puts in these chambers.
local DRIP_EVERY = 22
local drip_tick, drip_n = 0, 0
if game.emit_particles then
    tdw.on_tick(function(dt)
        drip_tick = drip_tick + dt
        if drip_tick < DRIP_EVERY or not tdw.online or not tdw.cave_under then
            return
        end
        drip_tick = 0
        for uuid in pairs(tdw.online) do
            local body = game.player_entity(uuid)
            local e = body and game.entity(body)
            local p = e and e.pos
            if p and tdw.cave_under(math.floor(p.x), math.floor(p.y), math.floor(p.z)) == ID then
                drip_n = drip_n + 1
                local d = schem.DIR16[(drip_n * 5) % 16 + 1]
                local r = 2 + (drip_n * 3) % 6
                game.emit_particles{ pos = { x = p.x + d[1] * r, y = p.y + 4.0, z = p.z + d[2] * r }, count = 1, size = 0.16, lifetime = 1.4,
                    colour = { r = 0.30, g = 0.34, b = 0.40, a = 0.8 }, velocity = { y = -1.2 }, spread = 0.0, gravity = 1.0,
                    area = { x = 0.1, y = 0.0, z = 0.1 }, collide = true }
            end
        end
    end)
end
