-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 1.4 Coastal Cliffs and, on its sea side, the Coastal Shelf: one biome,
-- the steep stretches of the Long Shore and the inshore waters off them.
--
-- THE CLIFFS. Sheer precipices thirty to sixty blocks straight into open
-- water or a short abrupt beach; sea stacks, narrow headlands, an undercut
-- notch at the waterline, sea caves that punch through a thin headland as
-- an arch, flooded caves tunnelling inland under the cliff tops, blowholes
-- from those up through the plateau; the face jagged over most of its
-- length; the tops cracked here and there. Layered horizontal strata of
-- stone, dark basalt, slate and (limestone, standing in for) sandstone; a
-- thin wind-scoured turf on top, light yellow-green, with sparse grass of
-- the same and small wind-bent pines along the rim; the splash zone slick
-- with dead coral, stone, slate and gravel.
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
-- THE SEA. The world's surface is a dome — every other biome's terrain sits
-- on `shape.depth()`, the dome minus y — and a sea cannot lie on a dome.
-- So this biome's terms CANCEL the dome and stand the land on one flat sea
-- level, and the generator fills the engine's water fluid below that level
-- in every coast chunk. In the dev world the sea is eight blocks under the
-- spawn base. In the ring world the Long Shore drops eight hundred metres
-- from its inner edge to its outer, so where the sea sits there is a
-- design question still open.
--
-- THE COAST is one 2D line: the zero contour of the `coast` noise, read
-- through the engine's SIGNED `contour` node — the distance in blocks to
-- the line, positive on land. Everything about the shore reads that one
-- field, so nothing disagrees with anything at any height: land is where
-- it is positive, the cliff rises from nothing at the line to the
-- plateau's height over FACE_W blocks of it, the shelf slopes down from it,
-- the bars lie at set distances from it.
--
-- Written left-leaning throughout (deepest operand first), and the cut
-- terms each start from the shore distance: they are evaluated inside the
-- terrain with three buffers held, against the engine's eight.

local blocks = tdw.blocks
local shape = tdw.shape
local n = shape.node

-- The sea, in the km frame the terrain uses (y = Y0 + km * 1000).
local SEA_BELOW_SPAWN = 0.008                         -- km: eight blocks under the spawn base
local SEA_KM = shape.dome_at(shape.PLAIN_U) - SEA_BELOW_SPAWN
-- The coastline.
local COAST_FREQ = 1 / 1100
local COAST_OCTAVES = 2                               -- a kilometre and 550 m: the broad sweep, bays and headlands. Four octaves made it meander
-- The line's detail is added to the DISTANCE, not to the noise: a coast
-- noise with fine octaves in it has a steep gradient everywhere, and the
-- contour node divides by that gradient, so the cliff went thin and the
-- line went wavy without ever getting small. Added to the signed distance
-- the line simply moves in and out by so many blocks, at the scale asked
-- for: bites of a dozen blocks at a hundred and fifty metres down to
-- crenellations of two at nine, and the cliff edge follows every one.
local SHORE_DETAIL = {
    { 1 / 150, 3, 24.0 },                             -- freq, octaves, amplitude in blocks (+/- half)
    { 1 / 9, 2, 5.0 },
}
-- The cliff.
local CLIFF_MEAN = 0.045                              -- km: forty-five blocks over the sea...
local CLIFF_VARY = 0.030                              -- ...thirty to sixty, by a slow noise
local CLIFF_VARY_FREQ = 1 / 500
local FACE_W = 2.0                                    -- blocks from the coastline to the full height: sheer
local PLATEAU_RELIEF = 0.004                          -- km: the cliff top undulates by a couple of blocks
local PLATEAU_FREQ = 1 / 70
-- The jag: a fast 3D noise of JAG_AMP added to the terrain within
-- JAG_REACH of the line, above the splash zone, over the areas JAG_AREA
-- says — most of them. Ledges, overhangs, a face that is rock and not a
-- wall.
-- The jag runs DOWN the face, not across it. A term that varies with x and
-- z but not with y moves a vertical face in and out by the same amount at
-- every height — a rib the height of the cliff. A 3D noise moves it by a
-- different amount at every height, which is a lumpy face, "jagged on
-- every axis". The engine's noise node is 3D; the one field of the ground
-- plane alone the language has is `contour`, the distance to a 2D noise's
-- zero contour, so the ribs are its lines: rock out along each line,
-- recessed between, at two scales, with a little grain that does vary with
-- height so a rib is not a cast column.
local JAG_RIB_FREQ = 1 / 13                           -- lines of the ground plane, about thirteen blocks apart
local JAG_RIB_W = 5.0                                 -- blocks either side of a line the rib reaches
local JAG_RIB_AMP = 0.009                             -- km: +/- four and a half blocks of buttress and flute
local JAG_FINE_FREQ = 1 / 5
local JAG_FINE_W = 2.0
local JAG_FINE_AMP = 0.003                            -- km: +/- a block and a half of fluting inside that
local JAG_GRAIN_FREQ = 1 / 9
local JAG_GRAIN = 0.0016                              -- km: +/- three quarters of a block, and the only part that varies with height
local JAG_REACH = 9.0
local JAG_AREA_FREQ = 1 / 300
local JAG_AREA_MIN = -0.28                            -- four fifths of the coast
-- The beaches: where a slow noise is over BEACH_MIN, the face is BEACH_W
-- blocks wide instead — a short, abrupt shingle beach up to the cliff.
local BEACH_FREQ = 1 / 700
local BEACH_MIN = 0.22                                -- about a tenth of the coast
local BEACH_W = 28.0
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
local FLAT_EDGE = 1.2                                 -- how hard the flat comes in: at 10 it was a drop-off round every flat
local FLAT_PULL = 0.55                                -- how far toward the level a flat pulls the floor: at 1 the flats were dead-level slabs in the shape of a noise
local FLAT_RIPPLE_FREQ = 1 / 14
local FLAT_RIPPLE = 0.0018                            -- km: +/- most of a block of wave-scour across a flat
local HOLLOW_FREQ = 1 / 60
local HOLLOW_MIN = 0.16
local HOLLOW_EDGE = 1.5                               -- likewise: at 6 the hollows were holes
local HOLLOW_DEPTH = 0.005                            -- km: the hollows the kelp anchors in
-- The undercut notch at the waterline: NOTCH_IN blocks into the face,
-- NOTCH_HALF either side of the sea level.
local NOTCH_IN = 3.5
local NOTCH_HALF = 0.0025
-- Sea caves and arches: a fast 3D noise over ARCH_MIN, within ARCH_IN of
-- the coastline, between ARCH_LO and ARCH_HI over the sea. A cave in a
-- thick cliff; through a thin headland, an arch.
local ARCH_FREQ = 1 / 16
local ARCH_MIN = 0.22
local ARCH_IN = 7.0
local ARCH_LO, ARCH_HI = 0.002, 0.016
-- The flooded caves: tunnels along the contour lines of a slow noise,
-- TUNNEL_W blocks half-width, from TUNNEL_LO to TUNNEL_HI about the sea
-- level (so the sea fills them), TUNNEL_IN blocks inland, where the area
-- noise says. Where a line crosses the coast the cave opens to the sea.
local TUNNEL_FREQ = 1 / 90
local TUNNEL_W = 2.5
local TUNNEL_LO, TUNNEL_HI = -0.004, 0.003
local TUNNEL_IN = 70.0
local TUNNEL_AREA_FREQ = 1 / 250
local TUNNEL_AREA_MIN = 0.0
-- The blowholes: a shaft BLOW_R blocks across where a tunnel line crosses
-- the contour of a second noise, from the tunnel up through the plateau,
-- within BLOW_IN of the shore. (Sea spray erupting from one is an engine
-- matter — particles — and is written down as an ask.)
local BLOW_FREQ = 1 / 70
local BLOW_R = 1.6
local BLOW_IN = 45.0
-- The cracks and crevices of the cliff top, the alpine's kind: wedges
-- along a contour, CRACK_W blocks half-width at the top, CRACK_D km deep,
-- in stretches where CRACK_SEG says so. Where one meets the cliff edge it
-- opens the face as a fissure.
local CRACK_FREQ = 1 / 40
local CRACK_W = 1.0
local CRACK_D = 0.012
local CRACK_SEG_FREQ = 1 / 50
local CRACK_SEG_MIN = 0.24                            -- was 0.05, two fifths of the contour length; a tenth now: "reduce by 75%"
-- How much is taken out of the terrain where a cut is: more than the
-- cliff is tall, so the cut is air to its bottom.
local CUT = 0.08
-- The materials.
local STRATA = {                                      -- the strata, bottom up from STRATA_BASE below the sea: km thick, material code
    { 0.006, 1 }, { 0.004, 2 }, { 0.003, 3 }, { 0.005, 4 }, { 0.003, 1 }, { 0.006, 2 }, { 0.002, 3 },
    { 0.005, 1 }, { 0.004, 4 }, { 0.003, 2 }, { 0.005, 3 }, { 0.004, 1 }, { 0.006, 4 }, { 0.003, 2 },
    { 0.005, 1 }, { 0.004, 3 }, { 0.006, 2 }, { 0.005, 4 },
}
local STRATA_BASE = -0.040                            -- km: the first stratum starts here, under the ledge's foot
local SPLASH_HALF = 0.003                             -- km either side of the sea: the splash zone
local SPLASH_IN = 6.0                                 -- blocks from the coastline
local SPLASH_FREQ = 1 / 12
local CORAL_MIN = 0.12                                -- the splash noise over this: dead coral...
local GRAVEL_MIN = 0.12                               -- ...under minus this: gravel; between: the strata's own stone and slate
local BEACH_IN = 14.0                                 -- blocks from the coastline the beach's gravel reaches
local TURF_DEPTH = 0.0015                             -- km: the top block and a half of the plateau is turf
local TUFT_FREQ = 1.5
local TUFT_MIN = 0.35                                 -- sparse
local SAND_DEPTH = 0.004                              -- km: the sand over the shelf's rock
local GRAVEL_BED_FREQ = 1 / 60
local GRAVEL_BED_MIN = 0.2
local MOSS_FREQ = 1 / 9
local MOSS_MIN = 0.05
local BARNACLE_FREQ = 1 / 7
local BARNACLE_MIN = 0.18
-- The pines: small, wind-bent, along the rim — between PINE_RIM[1] and
-- PINE_RIM[2] blocks in from the coastline, in stands where the patch
-- noise says, and always within PINE_FRACTURE of a crack line ("trees
-- cling to fractures"). Never on the face: the rim band starts past it.
local PINE_CELL = 7
local PINE_SQUARES = 0.22                             -- rarer: a pine per thirty-two columns where the rim allows one
local PINE_RIM = { 3.0, 26.0 }
local PINE_PATCH_FREQ = 1 / 120
local PINE_PATCH_MIN = 0.05
local PINE_FRACTURE = 3.0
local PINE_TEMPLATES = 10
-- The shelf's life.
local SEAGRASS_CELL, SEAGRASS_SQUARES = 2, 0.65
local SEAGRASS_DEPTH = { 0.003, 0.010 }
local PRAIRIE_FREQ, PRAIRIE_MIN = 1 / 150, -0.05
local KELP_CELL, KELP_SQUARES = 4, 0.35
local KELP_DEPTH = 0.008                              -- km: at least this deep — the hollows and off the ledge
local KELP_GROVE_FREQ, KELP_GROVE_MIN = 1 / 90, 0.0
local BOULDER_CELL, BOULDER_SQUARES = 18, 0.3
local BURROW_CELL, BURROW_SQUARES = 8, 0.15
local BURROW_DEPTH = { 0.002, 0.008 }

-- y in km, as the terrain has it.
local function ys()
    return n.mul(n.sub(n.Y(), n.const(shape.Y0)), n.const(shape.SCALE))
end
-- A headland under the spawn, so a new player stands on a cliff top and
-- not in the sea: a disc ISLAND_R blocks across, its edge wobbled by a 2D
-- contour, joined to whatever land the coast noise puts beside it. Its
-- signed distance is the linearised (R^2 - d^2) / 2R, since the language
-- has no square root; exact at the rim, which is where it matters.
local ISLAND_R = 55.0                                 -- blocks (was 90: the sea began past the view distance, and the dev world is here to look at the sea)
local function island()
    local dx = n.sub(n.X(), n.const(shape.SPAWN_X + 0.5))
    local dz = n.sub(n.Z(), n.const(shape.SPAWN_Z + 0.5))
    local d2 = n.add(n.mul(dx, dx), n.mul(dz, dz))
    return n.mul(n.sub(n.const(ISLAND_R * ISLAND_R), d2), n.const(1.0 / (2.0 * ISLAND_R)))
end
-- The detail added to the line, blocks either way. See SHORE_DETAIL.
local function shore_detail()
    local acc = nil
    for i, d in ipairs(SHORE_DETAIL) do
        local term = n.noise("shore_detail" .. i, d[1], d[2], d[3])
        acc = acc and n.add(acc, term) or term
    end
    return acc
end
-- The signed distance to the coastline, blocks: positive on land. The
-- island first: it is the deeper operand.
local function shore()
    return n.max(island(), n.add(n.contour("coast", COAST_FREQ, COAST_OCTAVES, true), shore_detail()))
end
-- The distance to the coast noise's line alone, unsigned: one buffer, for
-- the shelf's shapes, which are only ever read at sea.
-- The distance out to sea, blocks, for the shelf's own shapes: the same
-- line, unsigned and without the detail — one buffer and one op, and the
-- terrace is eighty blocks wide, so a dozen either way is no edge.
local function offshore()
    return n.contour("coast", COAST_FREQ, COAST_OCTAVES)
end
-- 1 on land or a stack, 0 at sea. The shore first (deeper), then the
-- stacks: a stack counts as land within STACK_NEAR of the shore.
local function on_land()
    local stack = n.clamp(n.sub(n.contour("stack", STACK_FREQ, 1, true), n.const(STACK_ERODE)), 0.0, 1.0)
    return n.clamp(n.mul(n.add(shore(), n.mul(stack, n.const(STACK_NEAR))), n.const(2.0)), 0.0, 1.0)
end
-- The plateau's height over the sea, km, before the face.
local function plateau()
    return n.add(n.add(n.const(CLIFF_MEAN), n.noise("cliff_h", CLIFF_VARY_FREQ, 1, CLIFF_VARY)),
        n.noise("plateau", PLATEAU_FREQ, 1, PLATEAU_RELIEF))
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
-- hollows under; all from the one-buffer unsigned distance.
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
    -- A long swell in the floor, and the hollows taken out of it softly:
    -- both of these were hard clamps, which is what made the floor a set of
    -- holes with drop-offs round them instead of a sunlit terrace.
    bed = n.add(bed, n.noise("bed_wave", BED_WAVE_FREQ, 2, BED_WAVE))
    bed = n.sub(bed, n.mul(n.clamp(n.mul(n.sub(n.noise("hollow", HOLLOW_FREQ, 1, 1.0), n.const(HOLLOW_MIN)), n.const(HOLLOW_EDGE)), 0.0, 1.0), n.const(HOLLOW_DEPTH)))
    local flat = n.clamp(n.mul(n.sub(n.noise("flat", FLAT_FREQ, 1, 1.0), n.const(FLAT_MIN)), n.const(FLAT_EDGE)), 0.0, 1.0)
    -- A flat pulls the floor PART of the way to a level that is itself
    -- rippled, rather than setting it to one depth: `bed + flat * PULL *
    -- (level - bed)`. Set to the depth, every flat was a dead-level slab in
    -- the shape of the noise that chose it, which is what the flats looked
    -- like from under the water. Pulled, a flat is flatter than the floor
    -- round it — wave-scoured, which is the design — and never a slab.
    local level = n.add(n.const(-FLAT_DEPTH), n.noise("flat_ripple", FLAT_RIPPLE_FREQ, 2, FLAT_RIPPLE))
    return n.add(n.mul(n.mul(n.sub(level, bed), flat), n.const(FLAT_PULL)), bed)
end
-- The land's height over the sea, km: the seabed, and on land the plateau
-- through its face. The rise first (it is the deeper), then the gate.
local function land_height()
    local rise = n.sub(n.mul(plateau(), face()), seabed())
    return n.add(n.mul(rise, on_land()), seabed())
end
-- 0 to 1 within `half` km of the sea level.
local function at_sea_level(half)
    return n.clamp(n.mul(n.sub(n.const(half), n.abs(n.sub(ys(), n.const(SEA_KM)))), n.const(2.0 / half)), 0.0, 1.0)
end
-- 0 to 1 within `blocks_in` of the coastline, on the land side. The shore
-- first: `(shore - in) * -1/2` rather than `(in - shore) / 2`, one buffer
-- fewer through the shore's evaluation.
local function near_shore(blocks_in)
    return n.clamp(n.mul(n.sub(shore(), n.const(blocks_in)), n.const(-0.5)), 0.0, 1.0)
end
-- 0 to 1 from `lo` km over the sea up.
local function above(lo)
    return n.clamp(n.mul(n.sub(ys(), n.const(SEA_KM + lo)), n.const(1000.0)), 0.0, 1.0)
end
-- 0 to 1 up to `hi` km over the sea.
local function below(hi)
    return n.clamp(n.mul(n.sub(n.const(SEA_KM + hi), ys()), n.const(1000.0)), 0.0, 1.0)
end
-- The cuts, 0 to 1 each, in two groups that share one read of the shore
-- (the deepest operand, and a four-octave contour): the notch and the
-- caves within CUT_NEAR of the line, the tunnels and the blowholes within
-- CUT_IN of it.
local CUT_NEAR = 5.0                                  -- blocks: the notch and the caves reach this far in
local CUT_IN = 70.0                                   -- blocks: the tunnels and the blowholes
-- The undercut notch and the sea caves.
local function face_cuts()
    local holes = n.clamp(n.mul(n.sub(n.noise("arch", ARCH_FREQ, 1, 1.0), n.const(ARCH_MIN)), n.const(30.0)), 0.0, 1.0)
    local caves = n.mul(n.mul(holes, above(ARCH_LO)), below(ARCH_HI))
    return n.mul(near_shore(CUT_NEAR), n.add(at_sea_level(NOTCH_HALF), caves))
end
-- The flooded tunnels, and the blowholes where a tunnel line crosses a
-- second contour: a shaft from the tunnel's floor up — through air above
-- the plateau too, which is nothing.
local function deep_cuts()
    local line = n.clamp(n.mul(n.add(n.contour("tunnel", TUNNEL_FREQ), n.const(-TUNNEL_W)), n.const(-1.0)), 0.0, 1.0)
    local area = n.clamp(n.mul(n.sub(n.noise("tunnel_area", TUNNEL_AREA_FREQ, 1, 1.0), n.const(TUNNEL_AREA_MIN)), n.const(8.0)), 0.0, 1.0)
    local tunnels = n.mul(n.mul(n.mul(line, above(TUNNEL_LO)), below(TUNNEL_HI)), area)
    local shaft = n.min(n.sub(n.const(BLOW_R), n.contour("tunnel", TUNNEL_FREQ)), n.sub(n.const(BLOW_R), n.contour("blowhole", BLOW_FREQ)))
    local blowholes = n.mul(n.clamp(shaft, 0.0, 1.0), above(TUNNEL_LO))
    return n.mul(near_shore(CUT_IN), n.add(tunnels, blowholes))
end
-- The cracks: a wedge from the plateau top, CRACK_D deep. The depth term
-- first (it carries the plateau's noise), then the contour, then the
-- stretches.
local function cracks()
    local wedge = n.add(n.mul(n.sub(n.add(n.const(SEA_KM), plateau()), ys()), n.const(-1.0 / CRACK_D)), n.const(1.0))
    wedge = n.sub(wedge, n.mul(n.contour("cliff_crack", CRACK_FREQ), n.const(1.0 / CRACK_W)))
    local gate = n.clamp(n.mul(n.sub(n.noise("cliff_crack_seg", CRACK_SEG_FREQ, 1, 1.0), n.const(CRACK_SEG_MIN)), n.const(10.0)), 0.0, 1.0)
    return n.mul(n.clamp(n.mul(wedge, n.const(6.0)), 0.0, 1.0), gate)
end
-- The jag, km, either sign: within JAG_REACH of the line, above the splash
-- zone, over most areas.
-- One rib scale: +1 along the contour's lines, -1 `w` blocks off them.
-- The contour first, it being the deeper operand.
local function rib(stream, freq, w)
    return n.clamp(n.mul(n.add(n.contour(stream, freq), n.const(-w)), n.const(-1.0 / w)), -1.0, 1.0)
end
local function jag()
    local near = n.clamp(n.mul(n.add(n.abs(shore()), n.const(-JAG_REACH)), n.const(-0.3)), 0.0, 1.0)
    local area = n.clamp(n.mul(n.sub(n.noise("jag_area", JAG_AREA_FREQ, 1, 1.0), n.const(JAG_AREA_MIN)), n.const(8.0)), 0.0, 1.0)
    local throw = n.mul(rib("jag_rib", JAG_RIB_FREQ, JAG_RIB_W), n.const(JAG_RIB_AMP))
    throw = n.add(throw, n.mul(rib("jag_fine", JAG_FINE_FREQ, JAG_FINE_W), n.const(JAG_FINE_AMP)))
    throw = n.add(throw, n.noise("jag_grain", JAG_GRAIN_FREQ, 1, JAG_GRAIN))
    return n.mul(n.mul(n.mul(near, throw), above(SPLASH_HALF)), area)
end

-- The coast's terms of the terrain, km: the land's height over the sea
-- (the deepest, first), the dome cancelled and the sea level added, the
-- jag, and the cuts taken out where there is land to cut. `terrain()`
-- adds `shape.depth()` — the dome minus y — after, so the sum is SEA +
-- height - y.
function shape.coast_terms()
    local acc = land_height()
    acc = n.add(acc, n.add(n.mul(shape.dome_node(), n.const(-1.0)), n.const(SEA_KM)))
    acc = n.add(acc, jag())
    local cuts = n.add(n.add(face_cuts(), deep_cuts()), cracks())
    return n.sub(acc, n.mul(n.mul(cuts, on_land()), n.const(CUT)))
end
shape.COAST_TOP = CLIFF_MEAN + CLIFF_VARY / 2 + PLATEAU_RELIEF / 2 - SEA_BELOW_SPAWN   -- km the cliff tops can stand over the spawn base

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
-- A pine: a trunk three to five tall, bent over sideways near the top by
-- a block or two, a block of root under it, and three to five clumps of
-- needles about the top and the bend, each a block with about half its
-- cells — sparse and chaotic.
local PLUS = 0
for cy = 0, 2 do
    for _, c in ipairs({ { 1, 1 }, { 0, 1 }, { 2, 1 }, { 1, 0 }, { 1, 2 } }) do
        PLUS = PLUS | (1 << (c[1] + 3 * cy + 9 * c[2]))
    end
end
local DIR4 = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local function pine(rng)
    local list = {}
    local tall = 5 + rng:below(4)                     -- bigger: five to eight blocks of trunk
    local d = DIR4[rng:below(4) + 1]
    local bend_at = math.max(1, tall - 3)
    local x, z = 0, 0
    list[#list + 1] = { 0, -1, 0, blocks.fir_log, PLUS }
    for dy = 0, tall - 1 do
        if dy >= bend_at then
            x, z = x + d[1], z + d[2]
        end
        list[#list + 1] = { x, dy, z, blocks.fir_log, PLUS }
    end
    local clumps = 6 + rng:below(4)                   -- leafier: six to nine clumps, and each fuller
    for _ = 1, clumps do
        local cx = x + rng:below(3) - 1
        local cz = z + rng:below(3) - 1
        local cy = tall - 2 + rng:below(4) - 1
        if cx == x and cz == z then cy = tall end
        local mask = 0
        for bit = 0, 26 do
            if rng:below(100) < 60 then mask = mask | (1 << bit) end
        end
        if mask ~= 0 then
            list[#list + 1] = { cx, cy, cz, blocks.fir_needles, mask }
        end
    end
    return game.schematic(list)
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
    for i = 1, PINE_TEMPLATES do PINES[i] = pine(rng_for("pine:" .. i)) end
    for _, tall in ipairs({ 2, 3, 3, 4 }) do SEAGRASS[#SEAGRASS + 1] = column(blocks.seagrass, tall) end
    for _, tall in ipairs({ 8, 10, 12 }) do KELP[#KELP + 1] = column(blocks.kelp, tall) end
    for i = 1, 6 do BOULDERS[i] = boulders(rng_for("boulders:" .. i)) end
    BURROWS[1] = burrow()
end

tdw.biomes.coastal_cliffs.ring_mode = "coast"
tdw.biomes.coastal_cliffs.lazy = true                 -- its terms are this file's, and shape.lua loads first: compiled at the first chunk
tdw.biomes.coastal_cliffs.sea_y = math.floor(shape.Y0 + SEA_KM * 1000)
tdw.build_biome("coastal_cliffs", function(ctx)
    local function masked(field)
        local mask = tdw.biome_mask(n, "shore", false)
        return mask and n.min(field, mask) or field
    end
    -- Every surface material from one evaluation of the terrain and one of
    -- a code field (`fill_layers`, as the alpine): the strata as a sum of
    -- steps up y, then the zones over them by the greatest code.
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    -- The strata: code = c_1 + sum_k step(y - y_k) * (c_k - c_(k-1)), each
    -- boundary a step up the column. Horizontal, as asked.
    local code = n.const(STRATA[1][2])
    local level, previous = STRATA_BASE, STRATA[1][2]
    for k = 2, #STRATA do
        level = level + STRATA[k - 1][1]
        local delta = STRATA[k][2] - previous
        if delta ~= 0 then
            code = n.add(code, n.mul(step(n.sub(ys(), n.const(SEA_KM + level))), n.const(delta)))
        end
        previous = STRATA[k][2]
    end
    -- The gates every override shares, each positive where it holds; the
    -- land test is the deepest, and comes first in every chain.
    local function landward() return n.sub(on_land(), n.const(0.5)) end
    local function seaward() return n.sub(n.const(0.5), on_land()) end
    -- The zones. Each zone is evaluated ONCE and its codes chosen inside
    -- it: a zone's test carries the land test (the shore's island, two
    -- contours and a stack), and one of those per code was eleven hundred
    -- operations against the program's thousand.
    -- The splash zone: within SPLASH_HALF of the sea and SPLASH_IN of the
    -- coastline, on land; coral where the splash noise is high (5), gravel
    -- where it is low (6), the strata's own rock between.
    local function splash_zone()
        local zone = landward()
        zone = n.min(zone, n.sub(near_shore(SPLASH_IN), n.const(0.5)))
        return n.min(zone, n.sub(at_sea_level(SPLASH_HALF), n.const(0.5)))
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
        gate = n.min(gate, n.sub(ys(), n.const(SEA_KM - 0.003)))
        return n.min(gate, n.sub(n.const(SEA_KM + 0.006), ys()))
    end
    -- The turf (8): the top TURF_DEPTH of the plateau, on land, above the
    -- splash. The land's height first: it is the deepest operand here.
    local function turf()
        local below_top = n.sub(n.add(land_height(), n.const(SEA_KM)), ys())   -- km under the plateau top
        local top = n.add(n.mul(below_top, n.const(-1.0)), n.const(TURF_DEPTH))
        top = n.min(top, n.sub(ys(), n.const(SEA_KM + 0.006)))
        return n.min(top, landward())
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
    local mask = tdw.biome_mask(n, "shore", false)
    if mask then
        code = n.mul(code, step(mask))
    end
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
        { code = 8, to = 1 * km, material = blocks.coast_turf },
        { code = 9, to = SAND_DEPTH, material = blocks.sand },
        { code = 10, to = 3 * km, material = blocks.creek_bed },
        { code = 11, to = 3 * km, material = blocks.limestone },
        { code = 12, to = 1 * km, material = blocks.ocean_moss },
        { code = 12, from = 1 * km, to = 3 * km, material = blocks.limestone },
        { code = 13, to = 1 * km, material = blocks.barnacles },
        { code = 13, from = 1 * km, to = 3 * km, material = blocks.limestone },
    }
    -- Sparse grass on the turf: the cover fill, where the turf is and a
    -- fast noise picks a column in some.
    -- Not `turf()`: that carries the land's height, and this field is
    -- evaluated over the twenty-seven cells of every surface block. On
    -- land, past the face, above the splash, and a fast noise picks.
    local take = n.min(n.min(n.min(landward(), n.sub(shore(), n.const(FACE_W + 1.0))), n.sub(ys(), n.const(SEA_KM + 0.006))),
        n.sub(n.noise("coast_tuft", TUFT_FREQ, 1, 1.0), n.const(TUFT_MIN)))
    local tufts = shape.compile("biome.coast.tufts", masked(take))
    -- Where each structure may stand, sampled at the surface the scatter
    -- finds. Depth under the sea is SEA - y there.
    local function depth_between(lo, hi)
        return n.min(n.sub(n.const(SEA_KM - lo), ys()), n.sub(ys(), n.const(SEA_KM - hi)))
    end
    local pines_stand = shape.compile("biome.coast.pines", masked(n.min(n.min(n.min(landward(),
        n.sub(shore(), n.const(PINE_RIM[1]))), n.sub(n.const(PINE_RIM[2]), shore())),
        n.max(n.sub(n.noise("pine_patch", PINE_PATCH_FREQ, 1, 1.0), n.const(PINE_PATCH_MIN)),
            n.sub(n.const(PINE_FRACTURE), n.contour("cliff_crack", CRACK_FREQ))))))
    local seagrass_stand = shape.compile("biome.coast.seagrass", masked(n.min(n.min(n.min(seaward(),
        depth_between(SEAGRASS_DEPTH[1], SEAGRASS_DEPTH[2])),
        n.sub(n.noise("prairie", PRAIRIE_FREQ, 1, 1.0), n.const(PRAIRIE_MIN))),
        n.sub(n.const(FLAT_MIN), n.noise("flat", FLAT_FREQ, 1, 1.0)))))
    local kelp_stand = shape.compile("biome.coast.kelp", masked(n.min(n.min(seaward(),
        n.sub(n.const(SEA_KM - KELP_DEPTH), ys())),
        n.sub(n.noise("kelp_grove", KELP_GROVE_FREQ, 1, 1.0), n.const(KELP_GROVE_MIN)))))
    local boulders_stand = shape.compile("biome.coast.boulders", masked(n.min(flats(), depth_between(0.002, 0.030))))
    local burrows_stand = shape.compile("biome.coast.burrows", masked(n.min(n.min(seaward(),
        depth_between(BURROW_DEPTH[1], BURROW_DEPTH[2])), n.sub(n.const(FLAT_MIN), n.noise("flat", FLAT_FREQ, 1, 1.0)))))
    local fills = {
        -- `body`: where the chunk is this biome's alone, this fill lays the
        -- stone under the layers too and the generator runs no body fill.
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
        { cover = blocks.coast_grass, cells = 2, take = tufts },
    }
    if game.schematic then
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
