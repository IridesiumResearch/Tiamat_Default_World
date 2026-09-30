-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 4.1 Pressure-Crushed Depths (2026-09-30), the first of the Abyss Below.
--
-- Crawl-chambers twelve to twenty blocks across and only two to four high,
-- their ceilings buckled into bulges that sag down to the floor in places,
-- and squeezed oval tunnels between them. Hyper-compressed rock flattened
-- into laminated plates, gneiss and ironstone through it; dark mineral oil
-- on the floors; a blue-black bacterial film along the fault seams; rock
-- powder; slabs peeled off the ceiling lying where they fell; hairline
-- fault-cracks that spray cold brine.
--
-- THE CHAMBERS: a footprint noise, flat in y, per storey, the Shadow
-- Pools' shape. The floor wanders half a block. The ceiling stands two to
-- four blocks over it, less the BULGES, blobs of a noise that push it
-- down as much as three and a half, so it touches the floor where one is
-- strongest: a squeeze, or a pillar. THE TUNNELS follow the zero contours
-- of a second noise, an oval three blocks wide either side and a block
-- and a half high either side of a line just over the floor. THE CRACKS
-- are the zero sheets of a flat noise, a third of a block wide, standing
-- through each chamber and a few blocks into the rock round it.
--
-- Materials: `morphic_rock` (the abyss's own crushed rock) laminated with
-- `granite` for the gneiss and `rust_red_sandstone` for the ironstone, in
-- bands of a noise in y alone; `black_mud` for the oil residue; `obsidian`
-- for the bacterial film, violet-black and glossy, along the seams;
-- `volcanic_ash` for the powder; the slabs `morphic_rock`. No new block.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "pressure_crushed_depths"
local FLAT = tdw.caves.DEEP_FLAT
local ALONG_Y = { x = 1000, z = 1000 }               -- varies in y alone
local function k_of(freq) return 0.625 / freq end

local STOREYS = { 4.35, 4.85, 5.35 }                  -- km under the dome
local STOREY_WANDER, WANDER_FREQ = 0.02, 1 / 3000
local ROOM_FREQ, ROOM_MIN, ROOM_K = 1 / 34, 0.08, 26.0    -- twelve to twenty across
local FLOOR_FREQ, FLOOR_VARY = 1 / 12, 1.0                 -- the floor wanders half a block either way
local CEIL_FREQ, CEIL_LOW, CEIL_SPAN = 1 / 16, 2.0, 2.0    -- two to four over the floor
local BULGE_FREQ, BULGE_MIN, BULGE_H = 1 / 9, 0.12, 3.5
local TUNNEL_FREQ, TUNNEL_HW, TUNNEL_HH, TUNNEL_MID = 1 / 60, 3.0, 1.5, 1.2
local CRACK_FREQ, CRACK_W, CRACK_REACH, CRACK_TOP = 1 / 25, 0.17, 3.0, 5.0
local LAMINA_FREQ, GNEISS_MIN, IRON_MIN = 1 / 2.5, 0.12, -0.28
local OIL_FREQ, OIL_MIN = 1 / 7, 0.05
local FILM_W = 0.9                                          -- blocks either side of a seam's line
local POWDER_FREQ, POWDER_MIN = 1 / 5, 0.12
local SLAB_CELL, SLAB_SQUARES = 7, 0.35

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "crushed_template:" .. name)
end
-- Spall: two or three flat plates of the crushed rock, a block or two
-- across and a cell thick, lying one over another where they came down.
local function spall(rng)
    schem.record_begin()
    for i = 1, 2 + rng:below(2) do
        local d = schem.DIR16[rng:below(16) + 1]
        local off = (i - 1) * 0.5
        local r = 0.8 + rng:below(4) * 0.25
        schem.push_ellipsoid(blocks.morphic_rock, 0.5 + d[1] * off, 1.05 + (i - 1) * 0.3, 0.5 + d[2] * off, r, 0.17, r * (0.6 + rng:below(3) * 0.2), BLIND)
    end
    return schem.record_schematic({})
end
local BUILT = nil
local function structures()
    if BUILT then return BUILT end
    BUILT = { slabs = {} }
    if game.schematic_shapes then
        for i = 1, 6 do BUILT.slabs[i] = spall(rng_for("slab:" .. i)) end
    end
    return BUILT
end

-- ------------------------------------------------------------ the fields

local function centre(k)
    return n.add(n.noise("pcd_storey" .. k, WANDER_FREQ, 1, 2.0 * STOREY_WANDER, FLAT), n.const(STOREYS[k]))
end

-- The Abyss's province, three ways until its other three are built (they
-- will take ground from these, as the Gloam's second three did): the
-- shafts under -0.2, these crushed chambers to 0.15, the mud flats over it.
tdw.cave_biome(ID, { -0.2, 0.15 }, function(ctx)
    local caves = ctx.caves
    local function step(f, k) return n.clamp(n.mul(f, n.const(k)), 0.0, 1.0) end
    -- Blocks over a storey's centre: the depth FIRST.
    local function up(k)
        return n.mul(n.sub(centre(k), caves.D()), n.const(1000.0))
    end
    local function footprint(k)
        return n.mul(n.sub(n.noise("pcd_room" .. k, ROOM_FREQ, 2, 1.0, FLAT), n.const(ROOM_MIN)), n.const(ROOM_K))
    end
    local floor_at = n.noise("pcd_floor", FLOOR_FREQ, 1, FLOOR_VARY, FLAT)
    local ceiling_at = n.sub(n.add(n.add(floor_at, n.const(CEIL_LOW)), n.mul(step(n.add(n.mul(n.noise("pcd_ceil", CEIL_FREQ, 1, 1.0, FLAT), n.const(3.0)), n.const(0.5)), 1.0),
        n.const(CEIL_SPAN))), n.mul(step(n.sub(n.noise("pcd_bulge", BULGE_FREQ, 1, 1.0, FLAT), n.const(BULGE_MIN)), 5.0), n.const(BULGE_H)))
    local tunnel_d = n.contour("pcd_tunnel", TUNNEL_FREQ, 1)
    local crack = n.sub(n.const(CRACK_W), n.mul(n.abs(n.noise("pcd_crack", CRACK_FREQ, 1, 1.0, FLAT)), n.const(k_of(CRACK_FREQ))))
    local function storey(k)
        local u = up(k)
        local f = footprint(k)
        local room = n.min(n.min(n.sub(u, floor_at), n.sub(ceiling_at, u)), f)
        -- The oval: 1 - (d / HW)^2 - ((u - MID) / HH)^2, in blocks.
        local dx = n.mul(tunnel_d, n.const(1.0 / TUNNEL_HW))
        local dy = n.mul(n.sub(u, n.const(TUNNEL_MID)), n.const(1.0 / TUNNEL_HH))
        local oval = n.mul(n.sub(n.sub(n.const(1.0), n.mul(dx, dx)), n.mul(dy, dy)), n.const(TUNNEL_HH))
        local cracks = n.min(n.min(crack, n.add(f, n.const(CRACK_REACH))), n.min(n.add(u, n.const(1.0)), n.sub(n.const(CRACK_TOP), u)))
        return n.max(n.max(room, oval), cracks)
    end
    local v = nil
    for k = 1, #STOREYS do
        v = v and n.max(v, storey(k)) or storey(k)
    end
    local void = ctx.mine(v)
    local carve = ctx.compile("carve", void)
    -- 1 crushed rock; 2 a gneiss lamina; 3 an ironstone lamina (thin
    -- horizontal plates of a noise in y alone, either side of its middle).
    local lamina = n.noise("pcd_lamina", LAMINA_FREQ, 1, 1.0, ALONG_Y)
    local code = n.max(n.max(n.const(1.0), n.mul(step(n.sub(lamina, n.const(GNEISS_MIN)), 1e4), n.const(2.0))),
        n.mul(step(n.sub(n.const(IRON_MIN), lamina), 1e4), n.const(3.0)))
    local depth = ctx.compile("depth", n.mul(void, n.const(-1.0)))
    local fills = {
        { layers = true, depth = depth, code = ctx.compile("codes", code), entries = {
            { code = 1, to = 3.0, material = blocks.morphic_rock },
            { code = 2, to = 3.0, material = blocks.granite },
            { code = 3, to = 3.0, material = blocks.rust_red_sandstone },
        } },
        { carve = carve },
        -- The floors: the bacterial film first, along the seams where the
        -- cracks come up through; then the oil; then the powder.
        { cover = blocks.obsidian, cells = 1, take = ctx.compile("take_film",
            ctx.mine(n.sub(n.const(FILM_W), n.mul(n.abs(n.noise("pcd_crack", CRACK_FREQ, 1, 1.0, FLAT)), n.const(k_of(CRACK_FREQ)))))) },
        { cover = blocks.black_mud, cells = 1, take = ctx.compile("take_oil",
            ctx.mine(n.sub(n.noise("pcd_oil", OIL_FREQ, 1, 1.0, FLAT), n.const(OIL_MIN)))) },
        { cover = blocks.volcanic_ash, cells = 1, take = ctx.compile("take_powder",
            ctx.mine(n.sub(n.noise("pcd_powder", POWDER_FREQ, 1, 1.0, FLAT), n.const(POWDER_MIN)))) },
    }
    if game.schematic_shapes then
        local built = structures()
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.slabs, cell = SLAB_CELL, chance = SLAB_SQUARES, salt = 541, sink = 1,
            stand = ctx.compile("stand_slabs", ctx.mine(n.const(1.0))) }
    end
    return fills
end)

-- ------------------------------------------------------------ the brine

-- Cold brine spraying out of a fault-crack now and then, near each player
-- the HUD's cave test puts in these chambers: a short hiss of fine
-- pale droplets, sideways.
local SPRAY_EVERY = 30
local spray_tick, spray_n = 0, 0
if game.emit_particles then
    tdw.on_tick(function(dt)
        spray_tick = spray_tick + dt
        if spray_tick < SPRAY_EVERY or not tdw.online or not tdw.cave_under then
            return
        end
        spray_tick = 0
        for uuid in pairs(tdw.online) do
            local body = game.player_entity(uuid)
            local e = body and game.entity(body)
            local p = e and e.pos
            if p and tdw.cave_under(math.floor(p.x), math.floor(p.y), math.floor(p.z)) == ID then
                spray_n = spray_n + 1
                local d = schem.DIR16[(spray_n * 7) % 16 + 1]
                local r = 2 + (spray_n * 3) % 5
                game.emit_particles{ pos = { x = p.x + d[1] * r, y = p.y + 0.6, z = p.z + d[2] * r }, count = 14, size = 0.05, lifetime = 0.7,
                    colour = { r = 0.78, g = 0.86, b = 0.92, a = 0.7 }, velocity = { x = -d[1] * 2.5, y = 0.4, z = -d[2] * 2.5 }, spread = 0.6,
                    gravity = 0.6, area = { x = 0.05, y = 0.3, z = 0.05 }, collide = true }
            end
        end
    end)
end
