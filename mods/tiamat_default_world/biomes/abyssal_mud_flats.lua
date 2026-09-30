-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 4.3 Abyssal Mud Flats (2026-09-30).
--
-- Vast low voids with no horizon, six to ten blocks high and running on
-- for hundreds, held up by pillars barely in sight of one another.
-- Pitch-black silt over ash over waterlogged clay. Pale hollow worm-tubes
-- poking up through the mire; rare glassy silicate sponge-stalks; the
-- ribs of old megafauna half-buried in it; mud pots burping gas;
-- mirror-flat pools of stagnant black water; a heavy mist on the floor.
--
-- THE FLATS: at each storey, a slab of void from the floor to a ceiling
-- six to ten over it, everywhere a very slow noise is over a low cut (so
-- the walls are hundreds of blocks apart), less THE PILLARS, blobs of a
-- sparse noise four to eight across that flare where they meet the floor
-- and the ceiling. THE FLOOR is flat but for its hollows: shallow broad
-- ones where a slow noise says (the pools), and small deep bowls (the mud
-- pots). THE WATER is `still_water`, the Shadow Pools' black, laid half a
-- block under the flat floor so it stands in the hollows alone, at rest.
--
-- Materials: the floor `black_mud` over a band of `volcanic_ash` over
-- `wet_clay`; walls, ceiling and pillars `morphic_rock`; worm-tubes `bone`,
-- in runs of cells out of the mud; the sponge-stalks `crystal`; the ribs
-- `bone` (the Dunes' ribcage, sunk deeper). No new block. The ground
-- does not give underfoot: nothing in the engine lets a block do that.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "abyssal_mud_flats"
local FLAT = tdw.caves.DEEP_FLAT

local STOREYS = { 4.30, 4.90, 5.50 }                   -- km under the dome
local STOREY_WANDER, WANDER_FREQ = 0.01, 1 / 5000     -- a mire lies level
local AREA_FREQ, AREA_MIN, AREA_K = 1 / 300, -0.22, 60.0
local CEIL_FREQ, CEIL_LOW, CEIL_SPAN = 1 / 40, 6.0, 4.0
local PILLAR_FREQ, PILLAR_MIN, PILLAR_K, FLARE = 1 / 70, 0.33, 22.0, 2.5
local POOL_FREQ, POOL_MIN, POOL_D = 1 / 30, 0.18, 1.3
local POT_FREQ, POT_MIN, POT_D = 1 / 7, 0.36, 2.2
local WATER = -0.5                                     -- the water's surface, blocks over the flat floor
local TUBE_FREQ, TUBE_MIN, TALL_MIN = 1 / 4, 0.20, 0.34
local STALK_CELL, STALK_SQUARES = 9, 0.10
local RIB_CELL, RIB_SQUARES = 40, 0.25

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local ROUGH = { rough = 0.3, blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "mud_flats_template:" .. name)
end
-- A silicate sponge-stalk: a glassy stem a block or two tall, a little
-- thicker at the top, anchored down in the silt.
local function stalk(rng)
    schem.record_begin()
    local tall = 1.0 + rng:below(3) * 0.5
    local d = schem.DIR16[rng:below(16) + 1]
    schem.push_path(blocks.crystal, { { 0.5, 0.4, 0.5, 0.15 }, { 0.5 + d[1] * 0.2, 1.0 + tall, 0.5 + d[2] * 0.2, 0.22 } }, BLIND)
    return schem.record_schematic({})
end
-- The ribs of something very large: a spine along the ground and five to
-- eight pairs of ribs arching off it, sunk so most of each is under the
-- mud (the Dunes' ribcage, lower and further gone).
local function ribs(rng)
    schem.record_begin()
    local d = schem.DIR16[rng:below(16) + 1]
    local side = schem.DIR16[(rng:below(16) + 4) % 16 + 1]
    local pairs_n = 5 + rng:below(4)
    local step = 1.7 + rng:below(3) * 0.2
    local half = pairs_n * step / 2
    schem.push_path(blocks.bone, { { 0.5 - d[1] * half, -0.2, 0.5 - d[2] * half, 0.5 }, { 0.5, 0.2, 0.5, 0.55 },
        { 0.5 + d[1] * half, -0.3, 0.5 + d[2] * half, 0.45 } }, BLIND)
    for i = 0, pairs_n - 1 do
        local t = -half + i * step
        local x, z = 0.5 + d[1] * t, 0.5 + d[2] * t
        local reach = 2.0 + rng:below(4) * 0.3
        local rise = 2.0 + rng:below(4) * 0.4
        for _, s in ipairs({ 1, -1 }) do
            schem.push_path(blocks.bone, { { x, 0.0, z, 0.38 }, { x + side[1] * reach * s, rise * 0.55, z + side[2] * reach * s, 0.28 },
                { x + side[1] * reach * 0.7 * s, rise, z + side[2] * reach * 0.7 * s, 0.2 } }, BLIND)
        end
    end
    schem.push_ellipsoid(blocks.bone, 0.5 - d[1] * (half + 2.2), 0.1, 0.5 - d[2] * (half + 2.2), 1.4, 1.0, 1.1, ROUGH)
    return schem.record_schematic({ [blocks.bone] = 1 })
end
local BUILT = nil
local function structures()
    if BUILT then return BUILT end
    BUILT = { stalks = {}, ribs = {} }
    if game.schematic_shapes then
        for i = 1, 5 do BUILT.stalks[i] = stalk(rng_for("stalk:" .. i)) end
        for i = 1, 4 do BUILT.ribs[i] = ribs(rng_for("ribs:" .. i)) end
    end
    return BUILT
end

-- ------------------------------------------------------------ the fields

local function centre(k)
    return n.add(n.noise("amf_storey" .. k, WANDER_FREQ, 1, 2.0 * STOREY_WANDER, FLAT), n.const(STOREYS[k]))
end

tdw.cave_biome(ID, { 0.15, 1 }, function(ctx)
    local caves = ctx.caves
    local function step(f, k) return n.clamp(n.mul(f, n.const(k)), 0.0, 1.0) end
    local function up(k)
        return n.mul(n.sub(centre(k), caves.D()), n.const(1000.0))
    end
    local area = n.mul(n.sub(n.noise("amf_area", AREA_FREQ, 2, 1.0, FLAT), n.const(AREA_MIN)), n.const(AREA_K))
    -- The floor's height over the flat: its hollows, the pools and the pots.
    local floor_at = n.mul(n.max(n.mul(step(n.sub(n.noise("amf_pool", POOL_FREQ, 1, 1.0, FLAT), n.const(POOL_MIN)), 6.0), n.const(POOL_D)),
        n.mul(step(n.sub(n.noise("amf_pot", POT_FREQ, 1, 1.0, FLAT), n.const(POT_MIN)), 8.0), n.const(POT_D))), n.const(-1.0))
    local ceiling_at = n.add(n.mul(step(n.add(n.mul(n.noise("amf_ceil", CEIL_FREQ, 1, 1.0, FLAT), n.const(3.0)), n.const(0.5)), 1.0), n.const(CEIL_SPAN)),
        n.const(CEIL_LOW))
    local pillar = n.mul(n.sub(n.noise("amf_pillar", PILLAR_FREQ, 1, 1.0, FLAT), n.const(PILLAR_MIN)), n.const(PILLAR_K))
    local function storey(k)
        local u = up(k)
        -- The pillar, flared by FLARE within two blocks of the floor and the ceiling.
        local near = n.max(n.sub(n.const(2.0), u), n.sub(u, n.sub(ceiling_at, n.const(2.0))))
        local col = n.add(pillar, n.mul(n.clamp(near, 0.0, 2.0), n.const(FLARE * 0.5)))
        return n.min(n.min(n.min(n.sub(u, floor_at), n.sub(ceiling_at, u)), area), n.mul(col, n.const(-1.0)))
    end
    local v, floors = nil, nil
    for k = 1, #STOREYS do
        v = v and n.max(v, storey(k)) or storey(k)
        local fl = n.min(n.sub(floor_at, up(k)), n.add(area, n.const(2.0)))
        floors = floors and n.max(floors, fl) or fl
    end
    local void = ctx.mine(v)
    local carve = ctx.compile("carve", void)
    local code = n.max(n.const(1.0), n.mul(step(floors, 1e4), n.const(2.0)))
    local depth = ctx.compile("depth", n.mul(void, n.const(-1.0)))
    -- How far over the flat floor a place is, near it: for the tubes, out
    -- of the water only.
    local over = nil
    for k = 1, #STOREYS do
        local o = n.sub(up(k), n.const(WATER))
        over = over and n.max(over, n.min(o, n.sub(n.const(3.0), o))) or n.min(o, n.sub(n.const(3.0), o))
    end
    local fills = {
        { layers = true, depth = depth, code = ctx.compile("codes", code), entries = {
            { code = 1, to = 3.0, material = blocks.morphic_rock },
            { code = 2, to = 1.5, material = blocks.black_mud },
            { code = 2, from = 1.5, to = 2.5, material = blocks.volcanic_ash },
            { code = 2, from = 2.5, to = 4.0, material = blocks.wet_clay },
        } },
        { carve = carve },
        -- The worm-tubes: runs of pale cells out of the mud, most two cells
        -- (two thirds of a block), the tallest six. Out of the water.
        { cover = blocks.bone, cells = 6, take = ctx.compile("take_tall_tubes",
            ctx.mine(n.min(over, n.sub(n.noise("amf_tube", TUBE_FREQ, 1, 1.0, FLAT), n.const(TALL_MIN))))) },
        { cover = blocks.bone, cells = 2, take = ctx.compile("take_tubes",
            ctx.mine(n.min(over, n.sub(n.noise("amf_tube", TUBE_FREQ, 1, 1.0, FLAT), n.const(TUBE_MIN))))) },
    }
    if game.schematic_shapes then
        local built = structures()
        local anywhere = ctx.compile("stand_floor", ctx.mine(n.const(1.0)))
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.stalks, cell = STALK_CELL,
            chance = STALK_SQUARES, salt = 561, sink = 1, stand = anywhere }
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.ribs, cell = RIB_CELL,
            chance = RIB_SQUARES, salt = 562, sink = 1, stand = anywhere }
    end
    -- The black water: half a block under the flat floor, so it stands in
    -- the pools and the pots and nowhere else, held by mud.
    for k = 1, #STOREYS do
        local level_y = n.add(n.mul(n.sub(shape.dome_node(), centre(k)), n.const(1000.0)), n.const(shape.Y0 + WATER))
        local reach = STOREY_WANDER + 0.02
        fills[#fills + 1] = { fluid = "tiamat_default_world:still_water", lip = blocks.black_mud,
            reach = { STOREYS[k] - reach, STOREYS[k] + reach },
            level = ctx.compile("water_level" .. k, level_y),
            within = ctx.compile("water_within" .. k, ctx.mine_flat(n.sub(area, n.const(1.0)))) }
    end
    return fills
end)

-- ------------------------------------------------------------ the air

-- Near each player the HUD's cave test puts on the flats: a heavy mist
-- lying on the floor, and now and then a mud pot's burp, a few dark
-- bubbles rising.
local MIST_EVERY = 16
local mist_tick, mist_n = 0, 0
if game.emit_particles then
    tdw.on_tick(function(dt)
        mist_tick = mist_tick + dt
        if mist_tick < MIST_EVERY or not tdw.online or not tdw.cave_under then
            return
        end
        mist_tick = 0
        for uuid in pairs(tdw.online) do
            local body = game.player_entity(uuid)
            local e = body and game.entity(body)
            local p = e and e.pos
            if p and tdw.cave_under(math.floor(p.x), math.floor(p.y), math.floor(p.z)) == ID then
                mist_n = mist_n + 1
                game.emit_particles{ pos = { x = p.x, y = p.y + 0.2, z = p.z }, count = 10, size = 0.9, lifetime = 7.0,
                    colour = { r = 0.42, g = 0.43, b = 0.44, a = 0.10 }, velocity = { y = 0.0 }, spread = 0.08, gravity = 0.0,
                    area = { x = 7.0, y = 0.3, z = 7.0 }, collide = false }
                if mist_n % 4 == 0 then
                    local d = schem.DIR16[(mist_n * 5) % 16 + 1]
                    game.emit_particles{ pos = { x = p.x + d[1] * 4, y = p.y - 0.4, z = p.z + d[2] * 4 }, count = 5, size = 0.14, lifetime = 1.4,
                        colour = { r = 0.16, g = 0.13, b = 0.10, a = 0.8 }, velocity = { y = 0.9 }, spread = 0.15, gravity = -0.2,
                        area = { x = 0.3, y = 0.0, z = 0.3 }, collide = false }
                end
            end
        end
    end)
end
