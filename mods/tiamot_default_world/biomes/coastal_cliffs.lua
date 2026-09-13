-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 1.4 Coastal Cliffs: the steep stretches of the Long Shore.
--
-- Sheer precipices thirty to sixty blocks straight into open water or a
-- short abrupt beach; sea stacks off the coast, narrow headlands, undercut
-- notches at the waterline, sea caves that punch through a thin headland
-- as an arch; the cliff tops cracked and fissured. Layered horizontal
-- strata of stone, dark basalt, slate and (limestone, standing in for)
-- sandstone; a thin wind-scoured turf on the cliff tops with sparse grass;
-- the splash zone slick with dead coral, stone, slate and tide-washed
-- gravel.
--
-- THE SEA. The world's surface is a dome — every other biome's terrain sits
-- on `shape.depth()`, the dome minus y — and a sea cannot lie on a dome.
-- So this biome's terms CANCEL the dome (`SEA_KM - dome(u)`) and stand the
-- land on one flat sea level, and the generator fills the engine's water
-- fluid below that level in every coast chunk (`fill_fluid_below`). In the
-- dev world (`tdw.config.everywhere`) the sea is eight blocks under the
-- spawn base. In the ring world the Long Shore drops eight hundred metres
-- from its inner edge to its outer, so where the sea sits there — one
-- level, a shelf, terraces — is a design question still open; see the
-- changelog.
--
-- THE COAST is one 2D line: the zero contour of the `coast` noise, three
-- octaves at a kilometre, read through the engine's SIGNED `contour` node —
-- the distance in blocks to the line, positive on land. Everything about
-- the shore reads that one field, so nothing disagrees with anything at
-- any height: land is where it is positive, the cliff rises from nothing
-- at the line to the plateau's height over FACE_W blocks of it (sheer; over
-- BEACH_W where the beach noise says), the notch and the caves lie within
-- so many blocks of it. (A 3D noise for the coast would put the line at a
-- different place at every height, and a band `|noise| < w` is a cliff
-- where the noise climbs and a slope where it lies flat.) The sea stacks
-- are the positive blobs of a fast noise, read the same way and eroded by
-- STACK_ERODE blocks, on the sea side within STACK_NEAR of the shore.
--
-- Written left-leaning throughout (deepest operand first): the terms are
-- evaluated inside the terrain with a buffer or two held, against the
-- engine's eight.

local blocks = tdw.blocks
local shape = tdw.shape
local n = shape.node

-- The sea, in the km frame the terrain uses (y = Y0 + km * 1000).
local SEA_BELOW_SPAWN = 0.008                         -- km: eight blocks under the spawn base
local SEA_KM = shape.dome_at(shape.PLAIN_U) - SEA_BELOW_SPAWN
-- The coastline.
local COAST_FREQ = 1 / 1100
local COAST_OCTAVES = 3                               -- a kilometre, 550 and 275 m: bays, headlands, coves
-- The cliff.
local CLIFF_MEAN = 0.045                              -- km: forty-five blocks over the sea...
local CLIFF_VARY = 0.030                              -- ...thirty to sixty, by a slow noise
local CLIFF_VARY_FREQ = 1 / 500
local FACE_W = 2.0                                    -- blocks from the coastline to the full height: sheer
local PLATEAU_RELIEF = 0.004                          -- km: the cliff top undulates by a couple of blocks
local PLATEAU_FREQ = 1 / 70
-- The beaches: where a slow noise is over BEACH_MIN, the face is BEACH_W
-- blocks wide instead — a short, abrupt shingle beach up to the cliff.
local BEACH_FREQ = 1 / 700
local BEACH_MIN = 0.22                                -- about a tenth of the coast
local BEACH_W = 28.0
-- The sea stacks.
local STACK_FREQ = 1 / 45
local STACK_ERODE = 3.0                               -- blocks: the noise's positive blobs shrunk by this — the ones left are the stacks
local STACK_NEAR = 120.0                              -- blocks off the shore a stack may stand
-- The seabed, off the coast.
local SEABED = -0.012                                 -- km: twelve blocks under the sea
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
-- The cracks and crevices of the cliff top, the alpine's kind: wedges
-- along a contour, CRACK_W blocks half-width at the top, CRACK_D km deep,
-- in stretches where CRACK_SEG says so. Where one meets the cliff edge it
-- opens the face as a fissure.
local CRACK_FREQ = 1 / 40
local CRACK_W = 1.0
local CRACK_D = 0.012
local CRACK_SEG_FREQ = 1 / 50
local CRACK_SEG_MIN = 0.05
-- How much is taken out of the terrain where a notch, a cave or a crack
-- is: more than the cliff is tall, so the cut is air to its bottom.
local CUT = 0.08
-- The materials.
local STRATA = {                                      -- the strata, bottom up from STRATA_BASE below the sea: km thick, material code
    { 0.006, 1 }, { 0.004, 2 }, { 0.003, 3 }, { 0.005, 4 }, { 0.003, 1 }, { 0.006, 2 }, { 0.002, 3 },
    { 0.005, 1 }, { 0.004, 4 }, { 0.003, 2 }, { 0.005, 3 }, { 0.004, 1 }, { 0.006, 4 }, { 0.003, 2 },
    { 0.005, 1 }, { 0.004, 3 }, { 0.006, 2 }, { 0.005, 4 },
}
local STRATA_BASE = -0.020                            -- km: the first stratum starts here
local SPLASH_HALF = 0.003                             -- km either side of the sea: the splash zone
local SPLASH_IN = 6.0                                 -- blocks from the coastline
local SPLASH_FREQ = 1 / 12
local CORAL_MIN = 0.12                                -- the splash noise over this: dead coral...
local GRAVEL_MIN = 0.12                               -- ...under minus this: gravel; between: the strata's own stone and slate
local BEACH_IN = 14.0                                 -- blocks from the coastline the beach's gravel reaches
local TURF_DEPTH = 0.0015                             -- km: the top block and a half of the plateau is turf
local TUFT_FREQ = 1.5
local TUFT_MIN = 0.35                                 -- sparse

-- y in km, as the terrain has it.
local function ys()
    return n.mul(n.sub(n.Y(), n.const(shape.Y0)), n.const(shape.SCALE))
end
-- A headland under the spawn, so a new player stands on a cliff top and
-- not in the sea: a disc ISLAND_R blocks across, its edge wobbled by a 2D
-- contour, joined to whatever land the coast noise puts beside it. Its
-- signed distance is the linearised (R^2 - d^2) / 2R, since the language
-- has no square root; exact at the rim, which is where it matters.
local ISLAND_R = 90.0
local ISLAND_WOBBLE = 15.0                            -- blocks either way
local function island()
    local dx = n.sub(n.X(), n.const(shape.SPAWN_X + 0.5))
    local dz = n.sub(n.Z(), n.const(shape.SPAWN_Z + 0.5))
    local d2 = n.add(n.mul(dx, dx), n.mul(dz, dz))
    local rim = n.mul(n.sub(n.const(ISLAND_R * ISLAND_R), d2), n.const(1.0 / (2.0 * ISLAND_R)))
    return n.add(rim, n.clamp(n.contour("island", 1 / 40, 1, true), -ISLAND_WOBBLE, ISLAND_WOBBLE))
end
-- The signed distance to the coastline, blocks: positive on land. The
-- island first: it is the deeper operand.
local function shore()
    return n.max(island(), n.contour("coast", COAST_FREQ, COAST_OCTAVES, true))
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
-- The land's height over the sea, km: the seabed, and on land the plateau
-- through its face. The rise first (it is the deeper), then the gate.
local function land_height()
    local rise = n.sub(n.mul(plateau(), face()), n.const(SEABED))
    return n.add(n.mul(rise, on_land()), n.const(SEABED))
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
-- The undercut notch, 0 to 1.
local function notch()
    return n.mul(at_sea_level(NOTCH_HALF), near_shore(NOTCH_IN))
end
-- The sea caves, 0 to 1.
local function caves()
    local holes = n.clamp(n.mul(n.sub(n.noise("arch", ARCH_FREQ, 1, 1.0), n.const(ARCH_MIN)), n.const(30.0)), 0.0, 1.0)
    local band = n.mul(n.clamp(n.mul(n.sub(ys(), n.const(SEA_KM + ARCH_LO)), n.const(1000.0)), 0.0, 1.0),
        n.clamp(n.mul(n.sub(n.const(SEA_KM + ARCH_HI), ys()), n.const(1000.0)), 0.0, 1.0))
    return n.mul(n.mul(holes, near_shore(ARCH_IN)), band)
end
-- The cracks, 0 to 1: a wedge from the plateau top, CRACK_D deep. The depth
-- term first (it carries the plateau's noise), then the contour, then the
-- stretches.
local function cracks()
    local wedge = n.add(n.mul(n.sub(n.add(n.const(SEA_KM), plateau()), ys()), n.const(-1.0 / CRACK_D)), n.const(1.0))
    wedge = n.sub(wedge, n.mul(n.contour("cliff_crack", CRACK_FREQ), n.const(1.0 / CRACK_W)))
    local gate = n.clamp(n.mul(n.sub(n.noise("cliff_crack_seg", CRACK_SEG_FREQ, 1, 1.0), n.const(CRACK_SEG_MIN)), n.const(10.0)), 0.0, 1.0)
    return n.mul(n.clamp(n.mul(wedge, n.const(6.0)), 0.0, 1.0), gate)
end

-- The coast's terms of the terrain, km: the dome cancelled, the sea level
-- and the land's height added, the cuts taken out where there is land to
-- cut. `terrain()` adds `shape.depth()` — the dome minus y — so the sum is
-- SEA + height - y.
-- The cuts first (they are the deepest), then the dome, then the land:
-- every operand evaluated with as little pending as can be, against the
-- eight buffers.
function shape.coast_terms()
    local cuts = n.add(n.add(notch(), caves()), cracks())
    local taken = n.mul(n.mul(cuts, on_land()), n.const(-CUT))
    local sea = n.add(n.mul(shape.dome_node(), n.const(-1.0)), n.const(SEA_KM))
    return n.add(n.add(taken, sea), land_height())
end
shape.COAST_TOP = CLIFF_MEAN + CLIFF_VARY / 2 + PLATEAU_RELIEF / 2 - SEA_BELOW_SPAWN   -- km the cliff tops can stand over the spawn base

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
    -- steps up y, then the splash zone, the beach and the turf over them
    -- by the greatest code.
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
    -- The gates every override shares, each positive where it holds.
    local function landward() return n.sub(on_land(), n.const(0.5)) end
    -- The splash zone: within SPLASH_HALF of the sea and SPLASH_IN of the
    -- coastline, on land; coral where the splash noise is high, gravel
    -- where it is low, the strata's own rock between.
    local function splash(sign, min)
        local patch = landward()                       -- the deepest first
        patch = n.min(patch, n.sub(near_shore(SPLASH_IN), n.const(0.5)))
        patch = n.min(patch, n.sub(at_sea_level(SPLASH_HALF), n.const(0.5)))
        return n.min(patch, n.sub(n.mul(n.noise("splash", SPLASH_FREQ, 1, 1.0), n.const(sign)), n.const(min)))
    end
    -- The beach: gravel over the ramp, where the beach noise says and within
    -- BEACH_IN of the line, a little under the sea to a little over.
    local function beach()
        local gate = landward()                        -- the deepest first
        gate = n.min(gate, n.sub(near_shore(BEACH_IN), n.const(0.5)))
        gate = n.min(gate, n.sub(n.noise("beach", BEACH_FREQ, 1, 1.0), n.const(BEACH_MIN)))
        gate = n.min(gate, n.sub(ys(), n.const(SEA_KM - 0.003)))
        return n.min(gate, n.sub(n.const(SEA_KM + 0.006), ys()))
    end
    -- The turf: the top TURF_DEPTH of the plateau, on land, above the
    -- splash. The land's height first: it is the deepest operand here.
    local function turf()
        local below_top = n.sub(n.add(land_height(), n.const(SEA_KM)), ys())   -- km under the plateau top
        local top = n.add(n.mul(below_top, n.const(-1.0)), n.const(TURF_DEPTH))
        top = n.min(top, n.sub(ys(), n.const(SEA_KM + 0.006)))
        return n.min(top, landward())
    end
    local conditions = {
        [5] = splash(1.0, CORAL_MIN),
        [6] = splash(-1.0, GRAVEL_MIN),
        [7] = beach(),
        [8] = turf(),
    }
    for k = 5, 8 do
        code = n.max(code, n.mul(step(conditions[k]), n.const(k)))
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
        { code = 8, to = 1 * km, material = blocks.grass },
    }
    -- Sparse grass on the turf: the cover fill, where the turf is and a
    -- fast noise picks a column in some.
    local take = n.min(turf(), n.sub(n.noise("coast_tuft", TUFT_FREQ, 1, 1.0), n.const(TUFT_MIN)))
    local tufts = shape.compile("biome.coast.tufts", masked(take))
    return {
        { layers = true, depth = depth, code = codes, entries = entries },
        { cover = blocks.tall_grass, cells = 2, take = tufts },
    }
end)
tdw.biomes.coastal_cliffs.soil = blocks.stone
