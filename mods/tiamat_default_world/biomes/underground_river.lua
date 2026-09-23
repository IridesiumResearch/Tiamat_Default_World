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
--
-- **2.3.1 Petrified Driftwood Rapids** (2026-09-23, "one decoration
-- variant of each of the cave biomes", and no new blocks): the same tubes
-- on the far side of the `cave_variant` line (caves.lua), redecorated and
-- nothing else — the carve, the water, the walls and the crystal veins
-- are shared. Where a slow rapids noise says the water runs white,
-- "jagged mid-stream rock teeth" stand in the channel: granite pinnacles
-- breaking the surface, each with a ragged calcite collar at the
-- waterline — the froth, frozen into stone, since the water itself cannot
-- be redrawn and particles are a later round. The silt and the cobbles
-- keep to the base side; the Rapids petrify the same patches instead —
-- cobbles scoured to bare `slate`, silt hardened to `calcite` pan — and
-- lodge "massive petrified tree trunks" across the channel: ironwood in a
-- ragged calcite crust, proud of the water, walkable bank to bank, a jam
-- where two land close. The ceiling's roots calcify into cages: calcite
-- ribs bowed round a heart of "smooth polished river glass" — crystal or
-- clear ice — with a mineralised bone shard and a knot of old shells
-- (`barnacles`) caught against it. The waterline's glow algae stays on
-- BOTH dressings: it is the biome's one light, and the brief left the
-- waterline ours to call. The moss pads keep to the base side —
-- still-water flora, and the Rapids' channel is scoured bare between the
-- teeth. No new material and no new plant.

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
-- 2.3.1 Petrified Driftwood Rapids: the variant's numbers. One new
-- stream, `pdr_rapids`; where a Rapids field reads a `ur_` stream instead,
-- that is on purpose — the courses and the ceiling's crevices are the
-- TUBE's features, and the tube does not move when the dressing does.
local RAPID_FREQ, RAPID_MIN = 1 / 90, 0.10              -- where a stretch runs white: roughly two fifths of the course
local TOOTH_CELL, TOOTH_SQUARES = 5, 0.55               -- a tooth every several blocks of a white stretch
local TRUNK_CELL, TRUNK_SQUARES = 11, 0.45              -- a trunk or two per stretch: a jam where they land close

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
-- A tooth (the Rapids): a granite pinnacle rooted a block under the bed,
-- leaning as it tapers, tall enough to break WATER_DEEP of water; half of
-- them carry a splinter off the flank. The calcite collar sits AT the
-- waterline, ragged (`rough`), and granite outranks it, so it survives
-- only as a ring of pale fleck round the tooth where the water froths —
-- the white of the white water, in stone.
local function tooth(rng)
    schem.record_begin()
    local h = 3.5 + rng:below(5) * 0.5
    local d = schem.DIR16[rng:below(16) + 1]
    local lean = 0.2 + rng:below(3) * 0.2
    schem.push_path(blocks.granite, { { 0.5, -1.0, 0.5, 1.4 }, { 0.5 + d[1] * lean, h, 0.5 + d[2] * lean, 0.3 } }, { rough = 0.35, blind = true })
    if rng:below(2) == 0 then
        local e = schem.DIR16[rng:below(16) + 1]
        schem.push_path(blocks.granite, { { 0.5 + e[1] * 0.8, -0.5, 0.5 + e[2] * 0.8, 0.8 }, { 0.5 + e[1] * 1.5, h * 0.5, 0.5 + e[2] * 1.5, 0.2 } }, { rough = 0.35, blind = true })
    end
    schem.push_ellipsoid(blocks.calcite, 0.5, WATER_DEEP, 0.5, 1.15, 0.45, 1.15, { rough = 0.6, blind = true })
    return schem.record_schematic({ [blocks.granite] = 1 })
end
-- A petrified trunk (the Rapids): ironwood — dark, dense, nearly stone —
-- eight to thirteen long, thick enough that its back stands proud of the
-- channel's water, one end lifted onto a bank. The calcite goes down
-- first, a hair wider and very rough, and the log outranks it, so what
-- survives is a ragged crust and fleck of calcification along the wood.
local function trunk(rng)
    schem.record_begin()
    local len = 8 + rng:below(6)
    local d = schem.DIR16[rng:below(16) + 1]
    local r = 1.0 + rng:below(3) * 0.2
    local rise = 0.3 + rng:below(3) * 0.3
    local y = r + 0.2
    schem.push_path(blocks.calcite, { { 0.5 - d[1] * len / 2, y, 0.5 - d[2] * len / 2, r + 0.3 }, { 0.5 + d[1] * len / 2, y + rise, 0.5 + d[2] * len / 2, r * 0.85 + 0.3 } }, { rough = 0.55, blind = true })
    schem.push_path(blocks.ironwood_log, { { 0.5 - d[1] * len / 2, y, 0.5 - d[2] * len / 2, r }, { 0.5 + d[1] * len / 2, y + rise, 0.5 + d[2] * len / 2, r * 0.85 } }, BLIND)
    if rng:below(2) == 0 then
        local e = schem.DIR16[rng:below(16) + 1]
        schem.push_path(blocks.ironwood_log, { { 0.5, y + r * 0.4, 0.5, r * 0.5 }, { 0.5 + e[1] * 2.0, y + r + 1.2, 0.5 + e[2] * 2.0, 0.2 } }, BLIND)
    end
    return schem.record_schematic({ [blocks.ironwood_log] = 1 })
end
-- A root-cage (the Rapids): four or five calcified ribs out of one
-- ceiling root, bowed out at the waist and drawn back together below —
-- the basket a root grows when the flesh rots and the mineral stays —
-- round a heart of river glass, crystal or clear ice, with a bone shard
-- and, on half of them, a knot of old shells pressed against it. The ribs
-- outrank everything and the glass nothing, so the trapped things show
-- through the gaps between ribs, never through a rib.
local function cage(rng)
    schem.record_begin()
    local drop = 3 + rng:below(3)
    local w = 1.2 + rng:below(3) * 0.3
    local ribs = 4 + rng:below(2)
    local start = rng:below(16)
    for i = 1, ribs do
        local d = schem.DIR16[(start + (i - 1) * (16 // ribs)) % 16 + 1]
        schem.push_path(blocks.calcite, {
            { 0.5, 0.3, 0.5, 0.45 },
            { 0.5 + d[1] * w, -drop * 0.5, 0.5 + d[2] * w, 0.3 },
            { 0.5 + d[1] * 0.3, -drop, 0.5 + d[2] * 0.3, 0.25 },
        }, BLIND)
    end
    local glass = rng:below(2) == 0 and blocks.crystal or blocks.clear_ice
    schem.push_ellipsoid(glass, 0.5, -drop * 0.5, 0.5, w * 0.65, drop * 0.28, w * 0.65, { rough = 0.25, blind = true })
    local e = schem.DIR16[rng:below(16) + 1]
    schem.push_ellipsoid(blocks.bone, 0.5 + e[1] * w * 0.4, -drop * 0.45, 0.5 + e[2] * w * 0.4, 0.7, 0.35, 0.35, { rough = 0.3, blind = true })
    if rng:below(2) == 0 then
        local f = schem.DIR16[rng:below(16) + 1]
        schem.push_ellipsoid(blocks.barnacles, 0.5 + f[1] * w * 0.5, -drop * 0.7, 0.5 + f[2] * w * 0.5, 0.5, 0.4, 0.5, { rough = 0.5, blind = true })
    end
    return schem.record_schematic({ [blocks.calcite] = 2, [blocks.bone] = 1, [blocks.barnacles] = 1 })
end
local BUILT = nil
local function structures()
    if BUILT then return BUILT end
    BUILT = { roots = {}, snags = {}, teeth = {}, trunks = {}, cages = {} }
    if game.schematic_shapes then
        for i = 1, 4 do BUILT.roots[i] = root(rng_for("root:" .. i)) end
        for i = 1, 4 do BUILT.snags[i] = snag(rng_for("snag:" .. i)) end
        for i = 1, 4 do BUILT.teeth[i] = tooth(rng_for("tooth:" .. i)) end
        for i = 1, 4 do BUILT.trunks[i] = trunk(rng_for("trunk:" .. i)) end
        for i = 1, 6 do BUILT.cages[i] = cage(rng_for("cage:" .. i)) end
    end
    return BUILT
end

-- ------------------------------------------------------------ the fields

tdw.cave_biome(ID, { 0.33, 1 }, function(ctx)         -- from 0.14 at first; a sixth since the six (2026-09-18)
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
    -- Where the Rapids run white: a slow gate along the course, flat in y,
    -- so the teeth and the trunks come in stretches — "rapids punctuated
    -- by" them — rather than salted evenly down the whole river.
    local function rapids()
        return n.sub(n.noise("pdr_rapids", RAPID_FREQ, 1, 1.0, shape.HUMIDITY_STRETCH), n.const(RAPID_MIN))
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
    -- Since the Rapids (2026-09-23) the patch conditions come in dressed
    -- pairs: the SAME silt and cobble patches, a different stone each side
    -- of the variant line — silt is 3 and mud on the base side, 7 and
    -- calcite pan on the Rapids'; cobbles 5 on the base side, 6 and
    -- scoured slate on the Rapids'. The side is ONE gate round each pair,
    -- not one per condition: the variant noise is two octaves and the
    -- codes program pays per read. In the overlap strip both gates pass
    -- and the higher code — the petrified stone — takes the patch, a few
    -- blocks of calcified fringe along the line.
    local in_channel = n.sub(n.mul(half(), n.const(CHANNEL)), across())
    local bank = n.sub(n.mul(half(), n.const(0.85)), across())
    local function silt_patch()
        return n.min(bank, n.sub(n.noise("ur_silt", SILT_FREQ, 1, 1.0), n.const(SILT_MIN)))
    end
    local function cobble_patch()
        return n.min(in_channel, n.sub(n.noise("ur_cobble", COBBLE_FREQ, 1, 1.0), n.const(COBBLE_MIN)))
    end
    local function coded(k, c) return n.mul(step(c), n.const(k)) end
    local code = n.max(n.max(coded(1, n.const(1.0)), coded(2, bank)), coded(4, in_channel))
    code = n.max(code, n.mul(step(ctx.side(-1)), n.max(coded(3, silt_patch()), coded(5, cobble_patch()))))
    -- The pan keeps off the channel bed, and it has to be said out loud:
    -- base silt is banks-only by PRECEDENCE (its 3 loses to the bed's 4
    -- wherever `in_channel` is positive), but the pan's 7 outranks 4, so
    -- the same silt condition would paint calcite across the Rapids' bed.
    -- Min against the negated `in_channel` and the pair is equal again.
    code = n.max(code, n.mul(step(ctx.side(1)), n.max(
        coded(7, n.min(silt_patch(), n.mul(in_channel, n.const(-1.0)))),
        coded(6, cobble_patch()))))
    local depth = ctx.compile("depth", n.mul(void, n.const(-1.0)))
    local codes = ctx.compile("codes", code)
    local entries = {
        { code = 2, to = 1.2, material = blocks.gravel },
        { code = 3, to = 1.2, material = blocks.black_mud },
        { code = 4, to = 1.5, material = blocks.gravel },
        { code = 5, to = 1.5, material = blocks.cobbles },
        { code = 6, to = 1.5, material = blocks.slate },
        { code = 7, to = 1.2, material = blocks.calcite },
    }
    -- A cover stands where air sits on rock: a cave floor, in these chunks.
    local function on_floor(f)
        return ctx.mine(f)
    end
    -- Algae at the waterline: on the floor just outside the channel; moss
    -- pads in the channel. The algae is BOTH dressings' — the biome's one
    -- light, and the call the brief left open — but the pads are
    -- still-water flora and keep to the base side (`ctx.base`): the
    -- Rapids' channel is scoured bare between the teeth.
    local algae = ctx.compile("algae", on_floor(n.min(n.min(n.sub(across(), n.mul(half(), n.const(CHANNEL - 0.05))), n.sub(n.mul(half(), n.const(0.8)), across())),
        n.sub(n.noise("ur_algae", ALGAE_FREQ, 1, 1.0), n.const(ALGAE_MIN)))))
    local pads = ctx.compile("pads", ctx.base(n.min(in_channel, n.sub(n.noise("ur_pad", PAD_FREQ, 1, 1.0), n.const(PAD_MIN)))))
    local fills = {
        { carve = carve },
        { layers = true, depth = depth, code = codes, entries = entries },
        caves.vein_fill(ctx, void, 0.0),              -- the crystal veins through the rock (caves.lua)
        { cover = blocks.glow_algae, cells = 1, take = algae },
        { cover = blocks.ocean_moss, cells = 1, take = pads },
    }
    if game.schematic_shapes then
        local built = structures()
        -- The roots and the snags are what the Rapids' brief replaces, so
        -- both keep to the base side (`ctx.base` where plain `ctx.mine`
        -- was); the Rapids hang and lodge their own below.
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.roots, cell = ROOT_CELL, chance = ROOT_SQUARES, salt = 421, sink = 0,
            stand = ctx.compile("stand_root", ctx.base(n.sub(n.noise("ur_roots", 1 / 20, 1, 1.0), n.const(0.1)))) }
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.snags, cell = SNAG_CELL, chance = SNAG_SQUARES, salt = 422, sink = 1,
            stand = ctx.compile("stand_snag", ctx.base(n.min(in_channel, n.sub(n.const(HALF - 0.8), half())))) }
        -- The Rapids' teeth: mid-channel, only where the rapids gate says
        -- the water runs white; sink 1 lodges each root in the bed.
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.teeth, cell = TOOTH_CELL, chance = TOOTH_SQUARES, salt = 423, sink = 1,
            stand = ctx.compile("stand_tooth", ctx.variant(n.min(in_channel, rapids()))) }
        -- The trunks root anywhere in the tube's width — a span from mid-
        -- channel reaches both banks, one rooted at the edge reaches the
        -- far one — in the same white stretches, where a jam belongs.
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.trunks, cell = TRUNK_CELL, chance = TRUNK_SQUARES, salt = 424, sink = 1,
            stand = ctx.compile("stand_trunk", ctx.variant(n.min(n.sub(n.mul(half(), n.const(0.8)), across()), rapids()))) }
        -- The cages hang where the roots would have (`ur_roots` reused on
        -- purpose: the ceiling's crevices do not move when the dressing
        -- does), the depth positive in the VOID so the crossing the engine
        -- stamps at is rock over air.
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.cages, cell = ROOT_CELL, chance = ROOT_SQUARES, salt = 425, sink = 0,
            stand = ctx.compile("stand_cage", ctx.variant(n.sub(n.noise("ur_roots", 1 / 20, 1, 1.0), n.const(0.1)))) }
    end
    -- Each river: WATER_DEEP over its channel's floor, in world y. The floor
    -- is the tube's, without the shelf (the channel is the middle).
    for k = 1, #RIVERS do
        local floor_y = n.sub(n.mul(n.sub(shape.dome_node(), floor_d(k)), n.const(1000.0)), n.const(-shape.Y0))
        fills[#fills + 1] = {
            fluid = "tiamat_default_world:water",
            lip = blocks.stone,
            level = ctx.compile("river_level" .. k, n.add(floor_y, n.const(WATER_DEEP))),
            -- `mine_flat`, not `mine`: a fluid fill's fields are read on the
            -- slice at y = 0.5 (caves.lua).
            within = ctx.compile("river_within" .. k, ctx.mine_flat(n.sub(n.mul(half(), n.const(CHANNEL)), across_of(k)))),
        }
    end
    return fills
end)
tdw.cave_variant(ID, "Petrified Driftwood Rapids")
