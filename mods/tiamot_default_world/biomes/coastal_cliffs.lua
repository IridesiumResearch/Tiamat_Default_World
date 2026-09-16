-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 1.4 Coastal Cliffs and, on its sea side, the Coastal Shelf: one biome,
-- every shore of every sea, and the inshore waters off it.
--
-- THE CLIFFS. Sheer precipices thirty to sixty blocks straight into open
-- water or a short abrupt beach; sea stacks, narrow headlands, an undercut
-- notch at the waterline, sea caves that punch through a thin headland as
-- an arch, flooded caves tunnelling inland under the cliff tops, blowholes
-- from those up through the plateau; the face jagged over most of its
-- length. Layered horizontal strata of stone, dark basalt, slate and
-- (limestone, standing in for) sandstone; a thin wind-scoured turf on the
-- rim, light yellow-green, with sparse grass of the same and small
-- wind-bent pines along it; the splash zone slick with dead coral, stone,
-- slate and gravel.
--
-- THE SHELF. A sunlit terrace sloping from two to twelve blocks under the
-- sea over the first eighty blocks offshore, breaking at a drop-off ledge
-- a hundred blocks out; two sandbars parallel to the coast with tidal
-- gutters between, wave-scoured rock flats level at four blocks, and
-- hollows for the kelp. Sand, beds of gravel, and on the flats limestone
-- pavement coated in ocean moss and crusted with barnacles. Prairies of
-- seagrass two to four blocks tall, kelp ten tall in the hollows and off
-- the ledge, boulder clusters colonised by barnacles on the flats, crab
-- burrows with their cones of sand — all stamped by the scatter on the
-- seabed the terrain field finds, before the sea is filled, so the water
-- takes the cells they leave.
--
-- THE SEA is the world's (seas.lua, 2026-09-15): long arcs along the rings,
-- terraced across them in pools of one level each. This file no longer
-- draws a coastline of its own or stands on a flat sea of its own: the
-- shore is the sea map's signed distance `d` (blocks, positive at sea), the
-- level is the pool's, and the LAND behind the shore is whatever ring the
-- shore is in — its own terrain, faded out toward the sea so the ground
-- converges to the dome, and lifted to the level where it would fall under
-- it. This file's job is the last hundred and thirty blocks either side of
-- the line: `shape.coast_shore` takes the ring's terrain and returns the
-- ground with the face, the shelf, the jag and the cuts; `shape.sea_deep`
-- is the floor past the shelf, blending into the ocean's (deep_ocean.lua).
--
-- Written left-leaning throughout (deepest operand first): the land's
-- terms are the deepest thing in any program, and they come first in every
-- expression they are in — once, since the stack machine has no dup.

local blocks = tdw.blocks
local shape = tdw.shape
local seas = tdw.seas
local n = shape.node

-- The cliff.
local FACE_W = 4.0                                    -- blocks from the coastline to the full height where the rock stands: steep, not a wall
-- The jag: a fast 3D noise of JAG_AMP added to the terrain within
-- JAG_REACH of the line, above the splash zone, over the areas JAG_AREA
-- says — most of them. Ledges, overhangs, a face that is rock and not a
-- wall.
-- The jag runs DOWN the face, not across it. A term that varies with x and
-- z but not with y moves a vertical face in and out by the same amount at
-- every height — a rib the height of the cliff. A 3D noise moves it by a
-- different amount at every height, which is a lumpy face, "jagged on
-- every axis". The ribs are the lines of a 2D contour: rock out along each
-- line, recessed between, at two scales, with a little grain that does
-- vary with height so a rib is not a cast column.
local JAG_RIB_FREQ = 1 / 13                           -- lines of the ground plane, about thirteen blocks apart
local JAG_RIB_W = 5.0                                 -- blocks either side of a line the rib reaches
local JAG_RIB_AMP = 0.0015                            -- km: +/- three quarters of a block of buttress and flute (0.0045 until 2026-09-15: "tone those structures way down")
local JAG_GRAIN_FREQ = 1 / 18
local JAG_GRAIN = 0.0004                              -- km: +/- a fifth of a block
local JAG_REACH = 9.0
local JAG_AREA_FREQ = 1 / 300
local JAG_AREA_MIN = -0.28                            -- four fifths of the coast
-- The beaches: where a slow noise is over BEACH_MIN, the face is BEACH_W
-- blocks wide instead — a short, abrupt shingle beach up to the cliff.
local BEACH_FREQ = 1 / 700
local BEACH_MIN = 0.02                                -- about half the coast (a tenth until 2026-09-16: "the beach just looks like a sheared off stone pad" - the other nine tenths met the water in a two-block step)
local BEACH_W = 34.0
-- The sea stacks.
local STACK_FREQ = 1 / 45
local STACK_ERODE = 3.0                               -- blocks: the noise's positive blobs shrunk by this — the ones left are the stacks
local STACK_NEAR = 120.0                              -- blocks off the shore a stack may stand
-- The shelf: the terrace, the ledge, the bars, the flats, the hollows.
local TERRACE = { 0.002, 0.012 }                      -- km under the sea at the shore, and at TERRACE_W out
local TERRACE_W = 80.0
local DROP_AT = 100.0                                 -- blocks out the ledge breaks...
local DROP_W = 14.0                                   -- ...over this many...
local DROP_DEPTH = 0.030                              -- ...to this much deeper
local BARS = { 28.0, 58.0 }                           -- blocks out: the sandbars, parallel to the coast
local BAR_HALF = 9.0                                  -- blocks: their half-width, and the length of their slope
local BAR_HEIGHT = 0.0025
local BED_WAVE_FREQ = 1 / 110
local BED_WAVE = 0.005                                -- km: +/- two and a half blocks of long swell in the floor
local FLAT_FREQ = 1 / 140
local FLAT_MIN = 0.12                                 -- the flat noise over this: a rock flat, level...
local FLAT_DEPTH = 0.004                              -- ...at this under the sea
local FLAT_EDGE = 1.2                                 -- how hard the flat comes in
local FLAT_PULL = 0.55                                -- how far toward the level a flat pulls the floor
local FLAT_RIPPLE_FREQ = 1 / 14
local FLAT_RIPPLE = 0.0018                            -- km: +/- most of a block of wave-scour across a flat
local HOLLOW_FREQ = 1 / 60
local HOLLOW_MIN = 0.16
local HOLLOW_EDGE = 1.5
local HOLLOW_DEPTH = 0.005                            -- km: the hollows the kelp anchors in
-- The undercut notch at the waterline: NOTCH_IN blocks into the face,
-- NOTCH_HALF either side of the sea level.
local NOTCH_HALF = 0.0025
-- Sea caves and arches: a fast 3D noise over ARCH_MIN, within ARCH_IN of
-- the coastline, between ARCH_LO and ARCH_HI over the sea. A cave in a
-- thick cliff; through a thin headland, an arch.
local ARCH_FREQ = 1 / 16
local ARCH_MIN = 0.34                                 -- 0.22 until 2026-09-15: fewer arches
local ARCH_LO, ARCH_HI = 0.002, 0.016
-- The flooded caves: tunnels along the contour lines of a slow noise,
-- TUNNEL_W blocks half-width, from TUNNEL_LO to TUNNEL_HI about the sea
-- level (so the sea fills them), TUNNEL_IN blocks inland, where the area
-- noise says. Where a line crosses the coast the cave opens to the sea.
local TUNNEL_FREQ = 1 / 90
local TUNNEL_W = 2.5
local TUNNEL_LO, TUNNEL_HI = -0.004, 0.003
local TUNNEL_AREA_FREQ = 1 / 250
local TUNNEL_AREA_MIN = 0.0
-- (The blowholes went on 2026-09-15, with the seas: a shore program carries
-- the ring's own terms as well now, and they were the least of the cuts
-- for what they cost. They wanted the engine's particles anyway.)
-- How much is taken out of the terrain where a cut is: more than the
-- cliff is tall, so the cut is air to its bottom.
local CUT = 0.05                                      -- 0.08 until 2026-09-15
-- The materials.
local STRATA = {                                      -- the strata, bottom up from STRATA_BASE below the sea: km thick, material code
    { 0.006, 1 }, { 0.004, 2 }, { 0.003, 3 }, { 0.005, 4 }, { 0.003, 1 }, { 0.006, 2 }, { 0.002, 3 },
    { 0.005, 1 }, { 0.004, 4 }, { 0.003, 2 }, { 0.005, 3 }, { 0.004, 1 }, { 0.006, 4 }, { 0.003, 2 },
    { 0.005, 1 }, { 0.004, 3 }, { 0.006, 2 }, { 0.005, 4 },
}
local STRATA_BASE = -0.040                            -- km: the first stratum starts here, under the ledge's foot
local SHORE_LAND = 24.0                               -- blocks inland this biome's ground reaches; past it the ring's own
local SPLASH_HALF = 0.003                             -- km either side of the sea: the splash zone
local SPLASH_IN = 6.0                                 -- blocks from the coastline
local SPLASH_FREQ = 1 / 12
local CORAL_MIN = 0.12                                -- the splash noise over this: dead coral...
local GRAVEL_MIN = 0.12                               -- ...under minus this: gravel; between: the strata's own stone and slate
local BEACH_IN = 30.0                                 -- blocks from the coastline the beach's gravel reaches: the whole ramp, so a beach is gravel and not turf
local TUFT_FREQ = 1.5
local TUFT_MIN = 0.28                                 -- sparse
local SAND_DEPTH = 0.004                              -- km: the sand over the shelf's rock
local GRAVEL_BED_FREQ = 1 / 60
local GRAVEL_BED_MIN = 0.2
local MOSS_FREQ = 1 / 9
local MOSS_MIN = 0.05
local BARNACLE_FREQ = 1 / 7
local BARNACLE_MIN = 0.18
-- The pines: small, wind-bent, along the rim — between PINE_RIM[1] and
-- PINE_RIM[2] blocks in from the coastline, in stands where the patch
-- noise says. Never on the face: the rim band starts past it.
local PINE_CELL = 7
local PINE_SQUARES = 0.22
local PINE_RIM = { 12.0, 34.0 }                       -- blocks back from the water: off the beach itself (2026-09-16)
local PINE_PATCH_FREQ = 1 / 120
local PINE_PATCH_MIN = 0.05
local PINE_TEMPLATES = 10
-- The shelf's life.
local SEAGRASS_CELL, SEAGRASS_SQUARES = 2, 0.65
local SEAGRASS_DEPTH = { 0.003, 0.010 }
local PRAIRIE_FREQ, PRAIRIE_MIN = 1 / 150, -0.05
local KELP_CELL, KELP_SQUARES = 4, 0.35
local KELP_DEPTH = 0.008                              -- km: at least this deep — the hollows and off the ledge
local KELP_GROVE_FREQ, KELP_GROVE_MIN = 1 / 90, 0.16
local BOULDER_CELL, BOULDER_SQUARES = 18, 0.3
local BURROW_CELL, BURROW_SQUARES = 8, 0.15
local BURROW_DEPTH = { 0.002, 0.008 }

-- y in km, as the terrain has it.
local function ys()
    return n.mul(n.sub(n.Y(), n.const(shape.Y0)), n.const(shape.SCALE))
end
-- The signed distance to the coastline, blocks: positive on LAND, as this
-- file has always read it — the sea map's distance, turned round, with the
-- shore's fine detail on it.
local function shore()
    return n.mul(seas.d(), n.const(-1.0))
end
-- The distance out to sea, blocks, for the shelf's shapes: the map's alone,
-- and nothing on land.
local function offshore()
    return n.clamp(seas.d_map(), 0.0, seas.DIST_FAR)
end
-- The pool's level, km over Y0, and y against it.
local function level()
    return seas.level()
end
local function over_sea()
    return n.sub(ys(), level())
end
-- 1 on land or a stack, 0 at sea. The shore first (deeper), then the
-- stacks: a stack counts as land within STACK_NEAR of the shore.
local function on_land()
    local stack = n.clamp(n.sub(n.contour("stack", STACK_FREQ, 1, true), n.const(STACK_ERODE)), 0.0, 1.0)
    return n.clamp(n.mul(n.add(shore(), n.mul(stack, n.const(STACK_NEAR))), n.const(2.0)), 0.0, 1.0)
end
-- The face: 0 at the coastline, 1 FACE_W blocks in — or BEACH_W where the
-- beach noise says. The distance first, then the width it is divided by.
local function face()
    local width = n.add(n.mul(n.clamp(n.mul(n.sub(n.noise("beach", BEACH_FREQ, 1, 1.0), n.const(BEACH_MIN)), n.const(8.0)), 0.0, 1.0),
        n.const(BEACH_W - FACE_W)), n.const(FACE_W))
    return n.clamp(n.div(shore(), width), 0.0, 1.0)
end
-- The shelf: the seabed's height over the sea, km, negative. The terrace
-- and the ledge by distance out, the bars over them, the flats level, the
-- hollows under.
local function seabed()
    local out = offshore()
    local terrace = n.add(n.mul(n.clamp(n.mul(out, n.const(1.0 / TERRACE_W)), 0.0, 1.0), n.const(-(TERRACE[2] - TERRACE[1]))), n.const(-TERRACE[1]))
    local ledge = n.mul(n.clamp(n.mul(n.sub(offshore(), n.const(DROP_AT)), n.const(1.0 / DROP_W)), 0.0, 1.0), n.const(-DROP_DEPTH))
    local bars = nil
    for _, at in ipairs(BARS) do
        local band = n.clamp(n.mul(n.add(n.abs(n.sub(offshore(), n.const(at))), n.const(-BAR_HALF)), n.const(-1.0 / BAR_HALF)), 0.0, 1.0)
        bars = bars and n.max(bars, band) or band
    end
    local bed = n.add(n.add(terrace, ledge), n.mul(bars, n.const(BAR_HEIGHT)))
    bed = n.add(bed, n.noise("bed_wave", BED_WAVE_FREQ, 2, BED_WAVE))
    bed = n.sub(bed, n.mul(n.clamp(n.mul(n.sub(n.noise("hollow", HOLLOW_FREQ, 1, 1.0), n.const(HOLLOW_MIN)), n.const(HOLLOW_EDGE)), 0.0, 1.0), n.const(HOLLOW_DEPTH)))
    local flat = n.clamp(n.mul(n.sub(n.noise("flat", FLAT_FREQ, 1, 1.0), n.const(FLAT_MIN)), n.const(FLAT_EDGE)), 0.0, 1.0)
    -- A flat pulls the floor PART of the way to a level that is itself
    -- rippled: flatter than the floor round it, never a slab.
    local level_ = n.add(n.const(-FLAT_DEPTH), n.noise("flat_ripple", FLAT_RIPPLE_FREQ, 2, FLAT_RIPPLE))
    return n.add(n.mul(n.mul(n.sub(level_, bed), flat), n.const(FLAT_PULL)), bed)
end
-- 0 to 1 within `half` km of the sea level.
local function at_sea_level(half)
    return n.clamp(n.mul(n.sub(n.const(half), n.abs(over_sea())), n.const(2.0 / half)), 0.0, 1.0)
end
-- 0 to 1 within `blocks_in` of the coastline, on the land side; the second
-- from the map alone, for the wide gates the fine detail is nothing to.
local function near_shore(blocks_in)
    return n.clamp(n.mul(n.sub(shore(), n.const(blocks_in)), n.const(-0.5)), 0.0, 1.0)
end
local function near_shore_map(blocks_in)
    return n.clamp(n.mul(n.add(seas.d_map(), n.const(blocks_in)), n.const(-0.5)), 0.0, 1.0)
end
-- 0 to 1 from `lo` km over the sea up; 0 to 1 up to `hi` km over the sea.
local function above(lo)
    return n.clamp(n.mul(n.sub(over_sea(), n.const(lo)), n.const(1000.0)), 0.0, 1.0)
end
local function below(hi)
    return n.clamp(n.mul(n.sub(n.const(hi), over_sea()), n.const(1000.0)), 0.0, 1.0)
end
local CUT_NEAR = 5.0                                  -- blocks: the notch and the caves reach this far in
local CUT_IN = 70.0                                   -- blocks: the tunnels and the blowholes
-- The undercut notch and the sea caves.
local function face_cuts()
    local holes = n.clamp(n.mul(n.sub(n.noise("arch", ARCH_FREQ, 1, 1.0), n.const(ARCH_MIN)), n.const(30.0)), 0.0, 1.0)
    local caves = n.mul(n.mul(holes, above(ARCH_LO)), below(ARCH_HI))
    return n.mul(near_shore(CUT_NEAR), n.add(at_sea_level(NOTCH_HALF), caves))
end
-- The flooded tunnels, and the blowholes where a tunnel line crosses a
-- second contour: a shaft from the tunnel's floor up.
local function deep_cuts()
    local line = n.clamp(n.mul(n.add(n.contour("tunnel", TUNNEL_FREQ), n.const(-TUNNEL_W)), n.const(-1.0)), 0.0, 1.0)
    local area = n.clamp(n.mul(n.sub(n.noise("tunnel_area", TUNNEL_AREA_FREQ, 1, 1.0), n.const(TUNNEL_AREA_MIN)), n.const(8.0)), 0.0, 1.0)
    local tunnels = n.mul(n.mul(n.mul(line, above(TUNNEL_LO)), below(TUNNEL_HI)), area)
    return n.mul(near_shore_map(CUT_IN), tunnels)
end
-- The jag, km, either sign: within JAG_REACH of the line, above the splash
-- zone, over most areas.
local function rib(stream, freq, w)
    return n.clamp(n.mul(n.add(n.contour(stream, freq), n.const(-w)), n.const(-1.0 / w)), -1.0, 1.0)
end
local function jag()
    -- On land only (2026-09-15): thrown either side of the line, the jag
    -- lifted the seabed off the coast into ribs that read as floating.
    local near = n.clamp(n.min(n.mul(shore(), n.const(0.5)), n.mul(n.add(shore(), n.const(-JAG_REACH)), n.const(-0.3))), 0.0, 1.0)
    local area = n.clamp(n.mul(n.sub(n.noise("jag_area", JAG_AREA_FREQ, 1, 1.0), n.const(JAG_AREA_MIN)), n.const(8.0)), 0.0, 1.0)
    local throw = n.mul(rib("jag_rib", JAG_RIB_FREQ, JAG_RIB_W), n.const(JAG_RIB_AMP))
    throw = n.add(throw, n.noise("jag_grain", JAG_GRAIN_FREQ, 1, JAG_GRAIN))
    return n.mul(n.mul(n.mul(near, throw), above(SPLASH_HALF)), area)
end

-- The shore: the ring's own ground (`land`, km over the dome) within reach
-- of a sea, returned as the ground's height over the dome with the sea's
-- shape on it. The land FIRST in every expression: it is the deepest term.
--   1. The hills stay and the basins go: the ground is never under a
--      floor that is the pool's level plus a beach for PLAIN_W blocks
--      inland of the shore — a sill, whole — and falls away from there
--      over FADE blocks to FLOOR_KM under it. A hill meets the sea as a
--      cliff its own height; a basin meets it as a coastal plain at the
--      water's height and a bank down behind it. (The first cut faded ALL
--      the relief out toward the shore, and every shore was a two-block
--      beach behind a one-in-twenty slope; the second measured the floor
--      from the dome, and the land twenty blocks in could stand twelve
--      under the water behind a rim the width of a dyke.)
--   3. From the coastline the face rises over FACE_W blocks (BEACH_W on a
--      beach) from the shelf's edge to that ground: `seabed * (1 - f) +
--      ground * f`; at sea f is 0 and the ground is the shelf.
--   4. The jag on the face, and the cuts: the notch, the caves and the
--      tunnels, on land only.
-- (A sill is land in the map, and the lift in 2 is what makes it a bank:
-- the level ramps across it from one pool's to the next.)
function shape.coast_shore(land)
    local inland = n.clamp(n.mul(n.add(n.mul(seas.d_map(), n.const(-1.0)), n.const(-seas.PLAIN_W)), n.const(1.0 / seas.FADE)), 0.0, 1.0)
    local floor = n.sub(n.add(seas.rel(), n.const(seas.BEACH)), n.mul(inland, n.const(seas.FLOOR_KM)))
    local g = n.max(land, floor)
    local f = n.mul(face(), on_land())
    local h = n.add(n.mul(g, f), n.mul(n.add(seas.rel(), seabed()), n.sub(n.const(1.0), f)))
    h = n.add(h, jag())
    local cuts = n.add(face_cuts(), deep_cuts())
    local ground = n.sub(h, n.mul(n.mul(cuts, on_land()), n.const(CUT)))
    if shape.reef_shelf then
        -- The Coral-Fringed Shallows (2.4): inside their lane the reef's
        -- floor stands over the shelf's, and the greater of the two is the
        -- sea floor. Everywhere else `reef_shelf` is a kilometre down and
        -- this is the coast, unchanged.
        return n.max(ground, n.add(seas.rel(), shape.reef_shelf()))
    end
    return ground
end
-- The plain shore (2026-09-16), for the Hem's cold programs — and for any
-- ring whose own terms leave no room for the full one: the floor, the face
-- and a bare shelf (the terrace, the ledge, the long swell). No stacks, no
-- jag, no notch, caves or tunnels, no bars, flats or hollows, no reef —
-- about a fifth of the full shore's five hundred operations. The land
-- FIRST, as above.
function shape.coast_plain(land)
    local inland = n.clamp(n.mul(n.add(n.mul(seas.d_map(), n.const(-1.0)), n.const(-seas.PLAIN_W)), n.const(1.0 / seas.FADE)), 0.0, 1.0)
    local floor = n.sub(n.add(seas.rel(), n.const(seas.BEACH)), n.mul(inland, n.const(seas.FLOOR_KM)))
    local g = n.max(land, floor)
    local f = n.mul(face(), n.clamp(n.mul(shore(), n.const(2.0)), 0.0, 1.0))
    local out = offshore()
    local terrace = n.add(n.mul(n.clamp(n.mul(out, n.const(1.0 / TERRACE_W)), 0.0, 1.0), n.const(-(TERRACE[2] - TERRACE[1]))), n.const(-TERRACE[1]))
    local ledge = n.mul(n.clamp(n.mul(n.sub(offshore(), n.const(DROP_AT)), n.const(1.0 / DROP_W)), 0.0, 1.0), n.const(-DROP_DEPTH))
    local bed = n.add(n.add(terrace, ledge), n.noise("bed_wave", BED_WAVE_FREQ, 2, BED_WAVE))
    return n.add(n.mul(g, f), n.mul(n.add(seas.rel(), bed), n.sub(n.const(1.0), f)))
end
-- Past the shelf: the shelf's foot blending into the ocean's floor from
-- SHELF_END to DEEP_FROM blocks out, at the pool's level.
function shape.sea_deep()
    local b = n.clamp(n.mul(n.sub(offshore(), n.const(seas.SHELF_END)), n.const(1.0 / (seas.DEEP_FROM - seas.SHELF_END))), 0.0, 1.0)
    local bed = n.add(n.mul(seabed(), n.sub(n.const(1.0), b)), n.mul(shape.ocean_floor(), b))
    if shape.abyss_terms then
        -- The Abyssal Trench's rifts (3.9), in its province, past the shelf.
        local b2 = n.clamp(n.mul(n.sub(offshore(), n.const(seas.SHELF_END)), n.const(1.0 / (seas.DEEP_FROM - seas.SHELF_END))), 0.0, 1.0)
        bed = n.sub(bed, n.mul(n.mul(shape.abyss_terms(), shape.abyss_weight()), b2))
    end
    return n.add(seas.rel(), bed)
end

-- The structures, as schematics for the scatter: `{dx, dy, dz, material,
-- mask}` each. Built once at load from a fixed seed.
local CENTRE_COLUMN = (1 << 4) | (1 << 13) | (1 << 22)   -- the middle cell column of a block: one card the block's height
local BOTTOM_LAYER = 7 | (7 << 9) | (7 << 18)     -- the nine cells of the bottom layer: x + 3y + 9z with y = 0
local FULL = game.OCCUPANCY_FULL
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "coast_template:" .. name)
end
local function column(material, tall)
    local list = {}
    for dy = 0, tall - 1 do
        list[#list + 1] = { 0, dy, 0, material, CENTRE_COLUMN }
    end
    return game.schematic(list)
end
-- A pine: small and wind-bent, and a PATH with a thickness, as the river's
-- trees are (2026-09-14). The trunk climbs from a flared foot and bows
-- over downwind for its top few blocks; flat pads of needles are swept the
-- same way off short limbs up its upper half, and one sits on the tip —
-- the shape the wind leaves a pine on a cliff top. It was a column of plus
-- blocks with the top shunted sideways and random half-blocks of needles.
local schem = tdw.schem
local edits = tdw.edits
local BLIND = { blind = true }
local function pine(rng)
    schem.record_begin()
    local tall = 5 + rng:below(4)                     -- five to eight blocks of trunk
    local heading = rng:below(16)
    local d = schem.DIR16[heading + 1]
    local bend_at = math.max(2, tall - 3)
    local over = 1.2 + rng:below(3) * 0.4
    local trunk = {
        { 0.5, -1.5, 0.5, 0.5 },
        { 0.5, 0.3, 0.5, 0.42 },
        { 0.5, bend_at, 0.5, 0.34 },
        { 0.5 + d[1] * over * 0.45, bend_at + (tall - bend_at) * 0.7, 0.5 + d[2] * over * 0.45, 0.27 },
        { 0.5 + d[1] * over, tall, 0.5 + d[2] * over, 0.2 },
    }
    schem.push_path(blocks.fir_log, trunk, BLIND)
    local function pad(cx, cy, cz, r)
        schem.push_ellipsoid(blocks.fir_needles, cx, cy, cz, r, 0.75, r, { rough = 0.4, jitter = rng, blind = true })
    end
    local pads = 4 + rng:below(3)
    for i = 1, pads do
        local h = bend_at * 0.8 + (tall - bend_at * 0.8) * (i - 1) / pads
        local sx, sy, sz = schem.path_point(trunk, h)
        local w = schem.DIR16[(heading + (rng:below(3) - 1) * 2) % 16 + 1]
        local reach = 1.0 + rng:below(3) * 0.5
        local tip = { sx + w[1] * reach, sy + 0.3, sz + w[2] * reach, 0.14 }
        schem.push_path(blocks.fir_log, { { sx, sy, sz, 0.2 }, tip }, BLIND)
        pad(tip[1], tip[2] + 0.3, tip[3], 1.5 + rng:below(3) * 0.3)
    end
    local top = trunk[#trunk]
    pad(top[1], top[2] + 0.4, top[3], 2.0 + rng:below(3) * 0.3)
    -- Cut natively (2026-09-15): ten pines rasterised in Lua, in the same
    -- generator call as the river's trees, were past the call's budget.
    return schem.record_schematic({ [blocks.fir_log] = 1 })
end
-- A boulder cluster: a three-by-three footprint two tall with the blocks
-- picked by chance, barnacles on the tops of some.
local function boulders(rng)
    local list = {}
    for dz = -1, 1 do
        for dx = -1, 1 do
            local corner = dx ~= 0 and dz ~= 0
            if rng:below(100) < (corner and 40 or 85) then
                list[#list + 1] = { dx, 0, dz, blocks.stone, FULL }
                if rng:below(100) < 45 then
                    list[#list + 1] = { dx, 1, dz, blocks.stone, FULL }
                    if rng:below(100) < 50 then list[#list + 1] = { dx, 2, dz, blocks.barnacles, BOTTOM_LAYER } end
                elseif rng:below(100) < 60 then
                    list[#list + 1] = { dx, 1, dz, blocks.barnacles, BOTTOM_LAYER }
                end
            end
        end
    end
    if #list == 0 then list[1] = { 0, 0, 0, blocks.stone, FULL } end
    return game.schematic(list)
end
-- A crab burrow: a hole a block down with a ring of sand half a block
-- high thrown up round it.
local function burrow()
    local list = { { 0, -1, 0, game.AIR, FULL } }
    for dz = -1, 1 do
        for dx = -1, 1 do
            if dx ~= 0 or dz ~= 0 then
                list[#list + 1] = { dx, 0, dz, blocks.sand, BOTTOM_LAYER }
            end
        end
    end
    return game.schematic(list)
end
local PINES, SEAGRASS, KELP, BOULDERS, BURROWS = {}, {}, {}, {}, {}
if game.schematic then
    for _, tall in ipairs({ 2, 3, 3, 4 }) do SEAGRASS[#SEAGRASS + 1] = column(blocks.seagrass, tall) end
    for _, tall in ipairs({ 8, 10, 12 }) do KELP[#KELP + 1] = column(blocks.kelp, tall) end
    for i = 1, 6 do BOULDERS[i] = boulders(rng_for("boulders:" .. i)) end
    BURROWS[1] = burrow()
end

tdw.biomes.coastal_cliffs.ring_mode = "temperate"
tdw.biomes.coastal_cliffs.lazy = true                 -- its terms read the sea maps: compiled at the first chunk
-- Where this biome is: the sea map's, not a ring's. The shore band, the
-- face and the shelf, to the ocean's edge.
tdw.biomes.coastal_cliffs.present = function(pos)
    local class = seas.class(pos)
    return class == "shore" or class == "deep"
end
tdw.biomes.coastal_cliffs.locate = function(px, pz, seed)
    -- Not the reef's lane: its water is the Coral-Fringed Shallows' and
    -- `/tp coastal cliffs` should not land on the lagoon's own beach.
    return seas.locate(px, pz, seed, -40.0, -6.0, nil, nil, { tdw.reef_u, tdw.cinder_u })
end
tdw.build_biome("coastal_cliffs", function(ctx)
    -- This biome's ground: SHORE_LAND blocks inland to SHELF_END blocks out.
    -- Everything else is the ring's own biome's.
    local function zone()
        local band = n.min(n.sub(n.const(seas.SHELF_END), seas.d_map()), n.add(seas.d_map(), n.const(SHORE_LAND)))
        -- Not in the reef's lane: its sand, its algae and its corals are
        -- the Coral-Fringed Shallows', and so is everything this biome
        -- would otherwise put there — the strata, the turf, the pines.
        band = shape.off_reef and n.min(band, shape.off_reef()) or band
        -- Nor on the Ember Ridge: its shores are the Cinder Coast's (3.5).
        band = shape.off_cinder and n.min(band, shape.off_cinder()) or band
        -- Nor the third lane's water: the Kelp Forest's (3.7).
        band = shape.off_kelp and n.min(band, shape.off_kelp()) or band
        -- Nor the reef lane's wet-side shores: the Mangrove Coast's (3.10).
        return shape.off_mangrove and n.min(band, shape.off_mangrove()) or band
    end
    local function masked(field)
        return n.min(field, zone())
    end
    -- Every surface material from one evaluation of the terrain and one of
    -- a code field (`fill_layers`, as the alpine): the strata as a sum of
    -- steps up y, then the zones over them by the greatest code.
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    -- The strata: code = c_1 + sum_k step(y - y_k) * (c_k - c_(k-1)), each
    -- boundary a step up the column, from the pool's level. Horizontal.
    local code = n.const(STRATA[1][2])
    local level_, previous = STRATA_BASE, STRATA[1][2]
    for k = 2, #STRATA do
        level_ = level_ + STRATA[k - 1][1]
        local delta = STRATA[k][2] - previous
        if delta ~= 0 then
            code = n.add(code, n.mul(step(n.sub(over_sea(), n.const(level_))), n.const(delta)))
        end
        previous = STRATA[k][2]
    end
    local function landward() return n.sub(on_land(), n.const(0.5)) end
    local function seaward() return n.sub(n.const(0.5), on_land()) end
    -- The splash zone: within SPLASH_HALF of the sea and SPLASH_IN of the
    -- coastline, on land; coral where the splash noise is high (5), gravel
    -- where it is low (6), the strata's own rock between.
    local function splash_zone()
        local zone_ = landward()
        zone_ = n.min(zone_, n.sub(near_shore(SPLASH_IN), n.const(0.5)))
        return n.min(zone_, n.sub(at_sea_level(SPLASH_HALF), n.const(0.5)))
    end
    local function splash_codes()
        local coral = n.mul(step(n.sub(n.noise("splash", SPLASH_FREQ, 1, 1.0), n.const(CORAL_MIN))), n.const(5))
        local gravel = n.mul(step(n.sub(n.mul(n.noise("splash", SPLASH_FREQ, 1, 1.0), n.const(-1.0)), n.const(GRAVEL_MIN))), n.const(6))
        return n.mul(step(splash_zone()), n.add(coral, gravel))
    end
    -- The beach (7): gravel over the ramp, where the beach noise says and
    -- within BEACH_IN of the line, a little under the sea to a little over.
    local function beach()
        local gate = landward()
        gate = n.min(gate, n.sub(near_shore(BEACH_IN), n.const(0.5)))
        gate = n.min(gate, n.sub(n.noise("beach", BEACH_FREQ, 1, 1.0), n.const(BEACH_MIN)))
        gate = n.min(gate, n.add(over_sea(), n.const(0.003)))
        return n.min(gate, n.sub(n.const(0.006), over_sea()))
    end
    -- The turf (8): the land behind the face — SHORE_LAND blocks of it,
    -- then the ring's own turf takes over. Whatever its height: the strata
    -- are the FACE'S, and on a shore that slopes to the water they came
    -- out as bands across the ground (2026-09-15, from the window).
    local function turf()
        local top = n.min(landward(), n.sub(n.const(-FACE_W - 1.0), seas.d()))
        return n.min(top, n.add(seas.d_map(), n.const(SHORE_LAND)))
    end
    -- The shelf's floor: sand at sea this side of the ledge's foot (9),
    -- beds of gravel in it (10).
    local function shelf()
        return n.min(seaward(), n.sub(n.const(DROP_AT + DROP_W), offshore()))
    end
    local function shelf_codes()
        local gravel = step(n.sub(n.noise("gravel_bed", GRAVEL_BED_FREQ, 1, 1.0), n.const(GRAVEL_BED_MIN)))
        return n.mul(step(shelf()), n.add(n.const(9), gravel))
    end
    -- The flats' pavement (11), and on it the moss (12) and, over that,
    -- the barnacles (13).
    local function flats()
        return n.min(seaward(), n.sub(n.noise("flat", FLAT_FREQ, 1, 1.0), n.const(FLAT_MIN)))
    end
    local function flat_codes()
        local moss = step(n.sub(n.noise("moss", MOSS_FREQ, 1, 1.0), n.const(MOSS_MIN)))
        local crust = n.mul(step(n.sub(n.noise("barnacle", BARNACLE_FREQ, 1, 1.0), n.const(BARNACLE_MIN))), n.const(2))
        return n.mul(step(flats()), n.add(n.const(11), n.max(moss, crust)))
    end
    for _, over in ipairs({ splash_codes(), n.mul(step(beach()), n.const(7)), n.mul(step(turf()), n.const(8)), shelf_codes(), flat_codes() }) do
        code = n.max(code, over)
    end
    code = n.mul(code, step(zone()))
    local depth = shape.compile("biome.coast.depth", shape.terrain(false))
    local codes = shape.compile("biome.coast.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 12 * km, material = blocks.stone },
        { code = 2, to = 12 * km, material = blocks.dark_basalt },
        { code = 3, to = 12 * km, material = blocks.slate },
        { code = 4, to = 12 * km, material = blocks.limestone },
        { code = 5, to = 2 * km, material = blocks.dead_coral },
        { code = 6, to = 2 * km, material = blocks.creek_bed },
        { code = 7, to = 3 * km, material = blocks.creek_bed },
        { code = 8, to = 1 * km, material = blocks.moss },          -- moss, not the coast turf ("i did not ok that block", 2026-09-15)
        { code = 8, from = 1 * km, to = 12 * km, material = blocks.stone },
        { code = 9, to = SAND_DEPTH, material = blocks.sand },
        { code = 10, to = 3 * km, material = blocks.creek_bed },
        { code = 11, to = 3 * km, material = blocks.limestone },
        { code = 12, to = 1 * km, material = blocks.ocean_moss },
        { code = 12, from = 1 * km, to = 3 * km, material = blocks.limestone },
        { code = 13, to = 1 * km, material = blocks.barnacles },
        { code = 13, from = 1 * km, to = 3 * km, material = blocks.limestone },
    }
    -- Sparse grass on the rim's turf: the cover fill, where the turf is and
    -- a fast noise picks a column in some.
    local take = n.min(n.min(n.min(landward(), n.sub(shore(), n.const(FACE_W + 1.0))), n.sub(over_sea(), n.const(0.006))),
        n.sub(n.noise("coast_tuft", TUFT_FREQ, 1, 1.0), n.const(TUFT_MIN)))
    local tufts = shape.compile("biome.coast.tufts", masked(take))
    -- Where each structure may stand, sampled at the surface the scatter
    -- finds. Depth under the sea is level - y there.
    local function depth_between(lo, hi)
        return n.min(n.sub(n.const(-lo), over_sea()), n.add(over_sea(), n.const(hi)))
    end
    local pines_stand = shape.compile("biome.coast.pines", masked(n.min(n.min(n.min(landward(),
        n.sub(shore(), n.const(PINE_RIM[1]))), n.sub(n.const(PINE_RIM[2]), shore())),
        n.sub(n.noise("pine_patch", PINE_PATCH_FREQ, 1, 1.0), n.const(PINE_PATCH_MIN)))))
    local seagrass_stand = shape.compile("biome.coast.seagrass", masked(n.min(n.min(n.min(seaward(),
        depth_between(SEAGRASS_DEPTH[1], SEAGRASS_DEPTH[2])),
        n.sub(n.noise("prairie", PRAIRIE_FREQ, 1, 1.0), n.const(PRAIRIE_MIN))),
        n.sub(n.const(FLAT_MIN), n.noise("flat", FLAT_FREQ, 1, 1.0)))))
    local kelp_stand = shape.compile("biome.coast.kelp", masked(n.min(n.min(seaward(),
        n.sub(n.const(-KELP_DEPTH), over_sea())),
        n.sub(n.noise("kelp_grove", KELP_GROVE_FREQ, 1, 1.0), n.const(KELP_GROVE_MIN)))))
    local boulders_stand = shape.compile("biome.coast.boulders", masked(n.min(flats(), depth_between(0.002, 0.030))))
    local burrows_stand = shape.compile("biome.coast.burrows", masked(n.min(n.min(seaward(),
        depth_between(BURROW_DEPTH[1], BURROW_DEPTH[2])), n.sub(n.const(FLAT_MIN), n.noise("flat", FLAT_FREQ, 1, 1.0)))))
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries },
        { cover = blocks.tall_grass, cells = 2, take = tufts },
    }
    if game.schematic and game.schematic_shapes then
        -- The pines are cut here, at the first coast chunk, not at load.
        if #PINES == 0 then
            for i = 1, PINE_TEMPLATES do PINES[i] = pine(rng_for("pine:" .. i)) end
        end
        local function scatter(stand, list, cell, chance, salt, sink)
            fills[#fills + 1] = { scatter = true, depth = depth, stand = stand, schematics = list, cell = cell, chance = chance, salt = salt, sink = sink }
        end
        scatter(pines_stand, PINES, PINE_CELL, PINE_SQUARES, 21, 1)
        scatter(boulders_stand, BOULDERS, BOULDER_CELL, BOULDER_SQUARES, 22, 1)
        scatter(burrows_stand, BURROWS, BURROW_CELL, BURROW_SQUARES, 23, 0)
        scatter(seagrass_stand, SEAGRASS, SEAGRASS_CELL, SEAGRASS_SQUARES, 24, 0)
        scatter(kelp_stand, KELP, KELP_CELL, KELP_SQUARES, 25, 0)
    end
    return fills
end)
tdw.biomes.coastal_cliffs.soil = blocks.stone
