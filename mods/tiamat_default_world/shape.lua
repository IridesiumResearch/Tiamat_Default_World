-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- The shape of the Spindle, as density programs.
--
-- Everything here is a DESCRIPTION handed to `game.density` once, at load.
-- Nothing samples a field in Lua (charter rule 4; AGENTS.md rule 1). The
-- numbers follow docs/spindle-mod-plan.md Part B, with the magma shell
-- thinned to the designer's later figures (50 / 25 / 50 blocks) and the
-- stack squished further so the magma is always under the abyss.
--
-- Units: fields work in KILO-BLOCKS. f32 has the same RELATIVE precision at
-- any magnitude, so squaring a world coordinate and scaling afterwards costs
-- nothing in accuracy — what matters is that the numbers being SUBTRACTED
-- (W^2 - r^2, R^2 - E^2) are a few thousand km^2, where an f32 step is two
-- ten-thousandths, and not billions of blocks^2.
--
-- Spindle frame: Y = y - Y0, so the disc's summit is at Y = +19 km.
--
-- Two limits of the density compiler shape the code below: 4,096 ops per
-- program, and 16 live buffers (256 and 8 until engine eab4c2d,
-- 2026-09-19 — the code's habits date from the tight days and are still
-- worth keeping, because what a program COSTS is its noise reads, not its
-- length). A subtree is walked once per place it appears
-- (no sharing), and evaluation is left to right, so a big subtree goes FIRST
-- in a `min`/`add` and the small one second.
--
-- Sub-node fills ADD: a smooth fill writes its material into the cells where
-- its field is positive and leaves every other cell as it was (engine
-- `fill_density_detail`, since 2026-09-09). That is what lets the layers
-- below be painted one on top of another; the first fill at a surface is the
-- one that gives it its shape, so it must be the smooth one.

local M = {}

-- Frame ---------------------------------------------------------------------
M.SCALE = 0.001          -- blocks -> km
M.Y0 = 11000             -- world y at Spindle Y = 0
M.R_DISC = 59.0          -- km, radius of the disc
M.K = 5.0                -- ellipsoid squish: vertical semi-axis = R / K.
                         -- 3.7 in the plan; 5 keeps the magma's top pole
                         -- 5.9 km under the Crown (so the abyss is above it
                         -- everywhere) and the stack inside the underside.
M.STACK_Y = 2.0          -- km, centre of the core stack (Spindle frame)

-- Dome: H(u) = SUMMIT - DOME_DROP * u * (2 - u), u = r^2 / R^2. Flat at the
-- centre, flat at the rim, 6.5% grade at worst. Needs no sqrt.
M.SUMMIT = 19.0          -- km at the axis
M.DOME_DROP = 2.5        -- km from summit to rim (rim at +16.5)

-- Relief: 3D fBm with a vertical gradient of 1 km per km. The fractal runs to
-- roughly +/-0.42, so RELIEF_AMP = 4 is +/-1.7 km of mountain at the Crown
-- before the mask. The mask holds full relief inside the Crown (u < 0.0064)
-- and ramps to RELIEF_FLOOR by u ~ 0.034, so the rings roll at +/-0.42 km on
-- a 12 km wavelength. Doubling this (tried 2026-09-08) made the rings a tilt
-- into kilometre walls; what reads as "bigger" at a player's scale is the
-- DETAIL term below — shorter hills, not taller tilts.
M.RELIEF_AMP = 4.0       -- km, before the mask
M.RELIEF_FREQ = 1 / 12000
M.RELIEF_OCTAVES = 2     -- 12 and 6 km; the hills carry on from 150 m. Each octave
                         -- here is paid five times per surface chunk.
M.RELIEF_FLOOR = 0.09    -- share of relief left outside the Crown (0.25, then 60%, then 60% again)
M.RELIEF_RAMP = 27.0     -- mask = clamp(1 - RAMP * (u - CROWN_U), FLOOR, 1)
M.CROWN_U = 0.0064
-- Detail: the hills you walk over. Low and rolling, with soft crests: +/-15
-- blocks on a 290 m wavelength is a 17% grade at the steepest, and two
-- octaves rather than three is what keeps the crests soft. (The woodland
-- brief, 2026-09-09, then "60% of that" twice the same day — both the
-- height and the width. Other rings will want their own terms, masked.)
M.DETAIL_AMP = 0.0067    -- km, x0.42 = +/-3 blocks (a third of +/-8, 2026-09-09)
M.DETAIL_FREQ = 1 / 150
M.DETAIL_OCTAVES = 2     -- 150 and 75 m. Noise cost is per octave, and the
                         -- terrain is evaluated once per skin fill.
-- Gullies: a V-shaped groove cut along the zero crossings of a slow noise.
-- Those crossings are meandering, connected lines, which is what a creek
-- bed looks like from above. Depth GULLY_DEPTH at the line, sloping up to
-- nothing where |noise| reaches GULLY_WIDTH — about seven blocks across.
M.GULLY_DEPTH = 0.0025   -- km: two and a half blocks
M.GULLY_WIDTH = 0.04     -- in the noise's own units (it runs +/-0.42): ~9 blocks across
M.GULLY_FREQ = 1 / 260
M.GULLY_OCTAVES = 2
-- Roughness: a fine noise that moves each bank in and out by a block or so
-- and, the same noise, makes the floor uneven — one node doing both, since
-- the field is evaluated five times a surface chunk and every noise node in
-- it is paid five times. The groove is not a perfect V along a perfect line.
M.GULLY_ROUGH = 0.4
M.GULLY_ROUGH_FREQ = 1 / 9
M.GULLY_BANK_WOBBLE = 0.012   -- in the noise's units: about +/-1 block of bank
-- Bluffs: a low-frequency noise clamped hard makes plateaus at +/-BLUFF_AMP
-- with a short, steep step between them wherever the noise crosses zero.
-- Clamped that hard the steps run along EVERY zero crossing, which as a
-- constant was a wall every two hundred blocks in a random direction — so
-- the term is masked by a second, slower noise, and shows only in patches
-- that cover about a fifth of the ground.
-- Small and soft for the woodland — two-block steps with rounded edges,
-- in patches — "clamped hill detail here and there" on hills that were
-- otherwise too smooth. The Ember Ridge will want 0.008 and STEEP 20.
M.BLUFF_AMP = 0.0012     -- km: steps of about two blocks
M.BLUFF_FREQ = 1 / 140
M.BLUFF_OCTAVES = 1
M.BLUFF_STEEP = 10.0     -- how sharply the noise is clamped: bigger is steeper
M.BLUFF_PATCH_FREQ = 1 / 900
M.BLUFF_PATCH_MIN = 0.08 -- the patch noise (+/-0.42) must exceed this: a third of the ground
M.BLUFF_PATCH_RAMP = 15.0 -- how quickly a patch fades in past that
-- The biome blend. One slow "humidity" noise splits a ring into a wet half
-- and a dry half at HUMIDITY_SPLIT (the temperate ring: woodlands wet,
-- grasslands dry). The two halves' own terrain terms CROSS-FADE over
-- HUMIDITY_BLEND of the noise either side of the split, so the ground never
-- steps at a border; their materials meet on the same contour, dithered at
-- the cell by a fine noise so the edge is a speckled band rather than a
-- line. The relief and the detail are the whole world's and need no blend.
M.HUMIDITY_FREQ = 1 / 9000
M.HUMIDITY_OCTAVES = 2
-- **Flat in y** (2026-09-16). The humidity is a 3D noise, and everything
-- that asks which half of a ring a place is samples it at a different
-- height: `/tp` and the HUD at the base dome, a fill at the block it is
-- painting, which the relief puts up to four hundred blocks away. At
-- 1/9000 with two octaves that is a tenth of a period — more than
-- HUMIDITY_BLEND — so a place could be the Taiga to the HUD and the
-- Frozen Wastes to the generator, and `/tp frozen wastes` landed in
-- spruce. Stretched a thousand times in y the noise is the same field at
-- every height a player can stand, and the three agree.
M.HUMIDITY_STRETCH = { y = 1000 }

-- **The provinces** (2026-09-16). A ring's half used to be one biome all
-- the way round, and at nine kilometres of humidity that is a five to
-- fifteen kilometre walk through one thing. A second slow noise cuts each
-- half again, into patches two or three kilometres across, and the two
-- biomes that share the half take one side each: the Long Shore's dry side
-- is the Dunes and the Rolling Grasslands in turn, its wet side the Flower
-- Forest and the Temperate Woodlands. Same field, same stretch in y as the
-- humidity, and a different stream — a province that followed the humidity
-- would only move the same edge.
M.PROVINCE_FREQ = 1 / 3000
M.PROVINCE_OCTAVES = 2
M.PROVINCE_SPLIT = 0.0    -- the noise runs +/-0.5: an even share either side
M.PROVINCE_BLEND = 0.05   -- in the noise's units: the terms fade up over this, from the line the materials change on
M.SALT_RAMP = 0.10        -- km: how far the Salt Pan's clamps stand off the ground where the pan is not (a bench is 64 blocks at most)
M.HUMIDITY_SPLIT = -0.05  -- the noise runs +/-0.5 after the clamp: the dry half is the smaller
M.HUMIDITY_BLEND = 0.04   -- in the noise's units: a few hundred blocks of cross-fade
M.HUMIDITY_DITHER = 0.03  -- +/-, at DITHER_FREQ: the speckle of the material edge
M.HUMIDITY_DITHER_FREQ = 1 / 10
-- The presence test's allowance past the dither (humidity_mask, below), in
-- the noise's units: a structure roots outside the chunk that asks, so the
-- test must keep a chunk any tree within reach of it could lean into. The
-- humidity's steepest stacked slope is under 0.00045 a block (half-range
-- 0.5 over a quarter of 9,000 blocks is 0.00022, and the second octave the
-- same again), so 0.008 covers roots sixteen blocks out — the widest
-- canopy off-chunk. Too small, the symptom is visible and shaped like the
-- lode gate's would be: a canopy clipped flat on a chunk face, only ever
-- along the wet/dry line.
M.HUMIDITY_PRESENCE_SLACK = 0.008
-- Rolling grasslands (1.2): broad swells and long ridges. A ridge follows
-- the zero contour of a noise — a long continuous meandering line — as
-- RIDGE_AMP * (1 - |n| / RIDGE_WIDTH), clamped: a crest with gentle sides.
M.SWELL_AMP = 0.008       -- km, x0.5 = +/-4 blocks over SWELL_FREQ
M.SWELL_FREQ = 1 / 420
M.SWELL_OCTAVES = 2
M.RIDGE_AMP = 0.0045      -- km: a ridge stands four or five blocks over the swell
M.HOLLOW_DEEPEN = 0.35    -- the swell's low side is this much deeper than its high side is high
-- Alpine highlands (1.3): the range is a MAP (biomes/alpine_highlands.lua
-- builds it in the world pre-pass and defines `M.alpine_terms`, which the
-- terrain reads through a map node); nothing of its shape lives here.
-- Where the alpine terms apply: the frost ring, fading over ALPINE_BLEND_U
-- of u at its outer edge into the temperate ring's terms. (Its inner edge,
-- the Crown, is left to the Crown's biomes when they are built.)
-- ALPINE_EDGE_U is the frost ring's outer edge from layers.lua, repeated
-- here because shape.lua loads first; layers.lua asserts they agree.
M.ALPINE_EDGE_U = 0.18 * 0.18
-- Wide enough to cover the wobble below and still fade: the alpine edge is
-- no longer a circle, so the band the blended programs cover has to hold
-- every place the edge can be.
M.ALPINE_BLEND_U = 0.024

-- **The rings are not circles.** A world of perfect rings reads as a
-- target, so the radius the BIOMES are placed by is the true radius pushed
-- in and out by a slow noise: every ring's edge wanders by up to
-- RING_WOBBLE in u, which near the frost edge is about two kilometres of
-- coast either way. The terrain's own shape (the dome, the relief, the
-- depth bands) still goes by the true radius — only the question "which
-- biome is here" takes the wandering one, so nothing about the world's
-- form depends on it.
--
-- Every Lua-side test against a ring widens by this, since a chunk within
-- RING_WOBBLE of an edge may be either side of it.
M.RING_WOBBLE = 0.010     -- the old fixed slack; nothing reads it now (see M.wobble)
M.RING_WOBBLE_SHARE = 0.04   -- what the edge actually wanders: a fortieth of the radius, either way
-- The slack a test at a given u widens by (2026-09-16): the wobble is a
-- share of the radius, so in u it is SHARE * u at the noise's clamp — and
-- a hair over. A fixed 0.010 was four times too little at the rim and too
-- little from the Verdant Belt out: a chunk past a ring's edge by more
-- than the slack, whose wobbled radius was still inside, was offered no
-- biome of that ring and painted nothing.
function M.wobble(u_value)
    return M.RING_WOBBLE_SHARE * u_value + 0.001
end
-- The Hem's inner edge (layers.lua asserts it against the ring) and the
-- band across it where the mild rings' terrain fades out under the rim's
-- (the "hem" programs, below).
M.HEM_U = 0.85 * 0.85
-- The world's edge on the wobbled radius (2026-09-16). The engine's world
-- is 60,000 blocks either way on each axis — a square — and a rim at
-- u_biome = 1 wandered out to 60.2 km along the axes, past it: the Rime
-- Wall there was outside the world and `/tp` to it silently did nothing.
-- At this the rim runs 57.45 to 59.8 km.
M.EDGE_U = (59.8 / 59.0) ^ 2 * (1.0 - 0.04)
M.HEM_BLEND_U = 0.008
function M.hem_in() return M.HEM_U - M.HEM_BLEND_U / 2 - M.wobble(M.HEM_U) end
function M.edge_from() return M.HEM_U + M.HEM_BLEND_U / 2 + M.wobble(M.HEM_U) end
-- The Verdant Belt, whose wet half is the rainforest (1.7): its span in u,
-- repeated from layers.lua (which loads after this file), and how wide the
-- cross-fade into the rainforest's own terrain is at either edge — about
-- five hundred metres there.
M.VERDANT_U = { 0.48 * 0.48, 0.60 * 0.60 }
M.VERDANT_BLEND_U = 0.008
-- The Glass Waste, whose dry half is the Arid Mesa (2.0): its span in u, and
-- the cross-fade into the mesa's terrain at its edges, as the rainforest's.
M.GLASS_U = { 0.42 * 0.42, 0.48 * 0.48 }
M.GLASS_BLEND_U = 0.008
-- The mesa's and the badlands' terms begin this far INSIDE the Glass
-- Waste (2026-09-15, with the Volcanic Foothills): the Waste's inner
-- eight hundred metres are plains, which the mesa has anyway, and the
-- Ember Ridge's terms get the room to stand at full height across most
-- of their ring before they must be gone for the Waste's programs.
M.GLASS_INSET_U = 0.012
-- The Ember Ridge, the Volcanic Foothills (2.3): its span in u, the
-- cross-fade into its terms at the inner edge, and where they fade OUT
-- again short of the Glass Waste's programs (which begin at GLASS_U[1]
-- less their reach, and carry the mesa's terms, not these).
M.EMBER_U = { 0.35 * 0.35, 0.42 * 0.42 }
M.EMBER_BLEND_U = 0.006
M.EMBER_OUT_U = 0.42 * 0.42 + 0.012 - 0.014 - 0.010     -- gone by here on the wobbled radius: the "glass" programs' first chunk, less the wobble
M.EMBER_FADE_U = 0.012
-- The Frozen Wastes (1.9) take the frost ring's dry half — Frostmoor — from
-- the alpine. Their flat permafrost fades into the alpine's mountains across
-- the Crown's edge over FROZEN_RING_BLEND_U of radius, and across the
-- humidity split over FROZEN_HUMIDITY_BLEND of the noise either side: much
-- wider than the woodland/grassland blend, because a mountain range has a
-- long way to come down.
M.FROZEN_RING_BLEND_U = 0.003
M.FROZEN_HUMIDITY_BLEND = 0.10
M.RING_WOBBLE_FREQ = 1 / 5200
M.RING_WOBBLE_OCTAVES = 2

-- (A warmth field that moved the wet/dry split with the radius was tried
-- and taken out: it sits inside `dry_weight`, which the temperate terrain
-- evaluates while it holds the wet terms, and that came to ten live
-- buffers against the engine's eight. Which biome is warm enough for
-- which ring is a fact about biomes, and it lives in their ring spans —
-- see biomes/catalogue.lua.)
M.RIDGE_FREQ = 1 / 650
M.RIDGE_WIDTH = 0.16      -- noise units: about fifty blocks from crest to foot
-- The plain. Nothing in Lua can evaluate the relief, so the one place a
-- player has to be put down blind is where the relief is SMALL by
-- construction: a ring of the disc, centred on the spawn radius and about
-- three kilometres wide, where the RING relief — the 12 km term, the one
-- that puts the surface hundreds of blocks from the base dome — is scaled
-- down to PLAIN_FLOOR of itself. The hills, the steps and the gullies run
-- through it at full strength: they are a few blocks, and a first visit can
-- see that far down. (Damping them too made the spawn read as plains.)
M.SPAWN_X = 15300        -- blocks; in the temperate ring, u ~ 0.067
M.SPAWN_Z = 0
M.PLAIN_HALF_WIDTH_U = 0.0125   -- in u: about 1.4 km of radius either side
M.PLAIN_FLOOR = 0.05            -- share of the relief left at the plain's centre

-- Body: W(Y) is the half-width in km at Spindle height Y, piecewise linear
-- through these knots, top to bottom. Above the first knot W is flat; the dome
-- caps it anyway. The plan's (-63, 0.9) knot is left out: each segment is
-- seven ops, twice. The needle tapers straight from 2 km wide at -37 to the
-- point at -70.
M.KNOTS = {
    { 16.5, 59.0 }, { 3.1, 58.5 }, { -8.0, 46.0 }, { -12.0, 30.0 }, { -16.0, 16.0 },
    { -25.0, 6.0 }, { -37.0, 2.0 }, { -70.0, 0.0 },
}
M.FLANK_WARP = 0.15      -- W' = W * (1 + FLANK_WARP * n * below), n in +/-0.5
M.FLANK_FREQ = 1 / 4000
-- **The rim wanders by the rings' own noise** (2026-09-16): at the surface
-- the body's edge is where the wobbled radius the biomes go by is exactly
-- 1, so the Rime Wall (3.2) stands on it and the Hem's bands are the same
-- width all round. The flank's own warp comes in under it, from
-- FLANK_TOP_Y down over FLANK_RAMP_KM, so the world's underside keeps the
-- shape it had. The generator's gate bounds the result by these.
M.FLANK_TOP_Y = 14.0     -- Spindle km: the rim's surface is at 16.5 +/- a few hundred blocks
M.FLANK_RAMP_KM = 6.0
-- The flank's warp pulls IN only, from 0 to FLANK_WARP of W: warped out
-- as it was, the underside bulged to 63 km, past the world's square.
M.WARP_HI = math.sqrt(M.EDGE_U / (1.0 - M.RING_WOBBLE_SHARE)) + 0.001
-- The least the warp can leave of W at Spindle height Y km: none of it is
-- taken above FLANK_TOP_Y, so the gate proves the surface inside out to
-- 57.4 km. (A bound for the lowest warp at every height proved nothing
-- past 48.8 km, and the Hem's blend band painted no biome.)
function M.warp_lo_at(Y_km)
    local below = (M.FLANK_TOP_Y - Y_km) / M.FLANK_RAMP_KM
    below = below < 0 and 0 or (below > 1 and 1 or below)
    return (1.0 - M.FLANK_WARP * below) * math.sqrt(M.EDGE_U / (1.0 + M.RING_WOBBLE_SHARE)) - 0.001
end

-- The core stack, as horizontal radii in km on the squished ellipsoid. A
-- thickness of t km in these units is t/K km vertically at the poles, which
-- is the direction a player digs into it from, so the magma's 25-block lava
-- layer is 25 * K blocks in E.
local MAGMA_R = 55.0
local function blocks_in_e(n) return n * M.K * M.SCALE end
M.SHELLS = {
    -- id,            outer R (km),                       inner R (km)
    { "magma_above",  MAGMA_R + blocks_in_e(12.5 + 50),   MAGMA_R + blocks_in_e(12.5) },
    { "magma",        MAGMA_R + blocks_in_e(12.5),        MAGMA_R - blocks_in_e(12.5) },
    { "magma_below",  MAGMA_R - blocks_in_e(12.5),        MAGMA_R - blocks_in_e(12.5 + 50) },
    { "hot_magical",  MAGMA_R - blocks_in_e(12.5 + 50),   50.3 },
    { "slime_border", 50.3,                               49.7 },
    { "cold_magical", 49.7,                               46.0 },
    { "hollow_ring",  46.0,                               37.0 },
}
M.HOLLOW_R = 37.0

-- Depth bands. The SKIN follows the real surface (the noisy terrain field);
-- the deeper bands follow the SMOOTH dome depth, which needs no noise and
-- lets the generator place them exactly. Under a mountain the gloam begins
-- deeper than 1.6 km below the peak, under a valley shallower — the proxy
-- error the plan accepts until there is an exact depth (B.5).
-- **The turf is three blocks thick for a reason that is not the look.** A
-- band is `half - |T - mid|`, which has a kink at `mid`; a block whose eight
-- corner samples straddle the kink interpolates its cells low, so the
-- band's upper edge lands a hair below the soil's and shows as a thin band
-- of soil on any slope. With `mid` at 1.5 blocks the kink is more than a
-- block from every surface block, and the two edges coincide exactly.
M.SKIN_TOP = 0.003       -- km: the biome's own material, three blocks
M.SKIN_DIRT = 0.005      -- km: soil under it, stone below that
M.SURFACE_BAND_D = 0.10  -- km: the bottom of the surface depth band; layers.lua asserts it against the band's own
M.GLOAM_D = 1.6          -- km below the base dome
M.ABYSS_D = 4.0

-- The tail, Spindle Y in km.
M.TAIL_Y = -37.0
M.APEX_Y = -63.0

-- Sub-node detail for every fill a player can stand on or look at. `smooth`
-- interpolates the block samples down to the cells (1.5x the block cost);
-- `sampled` asks the field about all 27 cells (5.5x) and only pays off when
-- a term finer than a block is added. `nil` is block resolution, staircases
-- and all.
M.SURFACE_DETAIL = { detail = "smooth" }

-- Node builders ---------------------------------------------------------------
local function const(v) return { op = "const", value = v } end
local function X() return { op = "x" } end
local function Y() return { op = "y" } end
local function Z() return { op = "z" } end
local function add(a, b) return { op = "add", a = a, b = b } end
local function sub(a, b) return { op = "sub", a = a, b = b } end
local function mul(a, b) return { op = "mul", a = a, b = b } end
local function min(a, b) return { op = "min", a = a, b = b } end
local function max(a, b) return { op = "max", a = a, b = b } end
local function clamp(a, lo, hi) return { op = "clamp", a = a, low = lo, high = hi } end
local function abs(a) return { op = "abs", a = a } end
-- Every noise node is CLAMPED to +/-NOISE_RANGE of its amplitude. The
-- fractal never leaves that range (it runs to about +/-0.42), so the clamp
-- changes no terrain; what it changes is what the engine can PROVE about
-- the field. `Density:bounds` is an interval extension, and its bound on a
-- bare noise node is 3.78x the amplitude — safe, and so wide that no chunk
-- under a relief term is ever decided. A clamp's interval is the clamp, so
-- with it the engine skips a chunk the surface cannot reach before any
-- evaluation, for every fill, and the generator's gate reads the same bound.
M.NOISE_RANGE = 0.5
local function noise(stream, frequency, octaves, amplitude, stretch)
    local raw = { op = "noise", stream = stream, frequency = frequency, octaves = octaves, amplitude = amplitude, stretch = stretch }
    return { op = "clamp", a = raw, low = -M.NOISE_RANGE * amplitude, high = M.NOISE_RANGE * amplitude }
end
-- The distance, in blocks, from the zero contour of a 2D noise (engine
-- `contour` node, 2026-09-13): a line across the ground with a width, for
-- cracks. Same stream and frequency as a noise; one octave.
local function contour(stream, frequency, octaves, signed)
    return { op = "contour", stream = stream, frequency = frequency, octaves = octaves or 1, signed = signed or false }
end
local function div(a, b) return { op = "div", a = a, b = b } end
M.node = { const = const, X = X, Y = Y, Z = Z, add = add, sub = sub, mul = mul, div = div, min = min, max = max, clamp = clamp, abs = abs, noise = noise, contour = contour }

-- Shared subexpressions (each call builds a fresh tree) ----------------------
-- r^2 in km^2: seven ops and three buffers.
local function r2() return mul(add(mul(X(), X()), mul(Z(), Z())), const(M.SCALE * M.SCALE)) end
local function u() return mul(r2(), const(1 / (M.R_DISC * M.R_DISC))) end
local function ys() return mul(sub(Y(), const(M.Y0)), const(M.SCALE)) end
-- The radius the BIOMES are placed by: the true one, pushed in and out by
-- a slow noise so no ring edge is a circle. See M.RING_WOBBLE.
-- The radius a biome is placed by: the true one pushed in and out by a
-- slow noise, flat in y for the reason the humidity is (above) — a ring's
-- edge that wandered with height put `/tp` on the wrong side of it.
--
-- **The wobble is a SHARE of the radius, not an amount of u** (2026-09-16).
-- u is r^2/R^2, so a fixed wobble in u is a fixed wobble in r only at one
-- radius: at 0.010 it was 580 m out at 30 km, 3.5 km out at the Crown's
-- edge, and more than the whole Crown at the axis — which left the middle
-- of the world unclaimed and made the Taiga/Frozen Wastes line wander by
-- kilometres. Written as `u * (1 + noise)` it is the same fraction of the
-- radius everywhere (±2% of r, so ±600 m at 30 km, ±94 m at the Crown's
-- edge, nothing at the axis) and costs two operations over the old form,
-- because `u` is still evaluated once.
local function wobble_node()
    return noise("ring_wobble", M.RING_WOBBLE_FREQ, M.RING_WOBBLE_OCTAVES, 2.0 * M.RING_WOBBLE_SHARE, M.HUMIDITY_STRETCH)
end
local function u_biome()
    return mul(u(), add(wobble_node(), const(1.0)))
end
M.u_biome_node = u_biome
M.sub = { r2 = r2, u = u, ys = ys }

-- H(u) = SUMMIT - u * (2*DROP - DROP*u), with u evaluated second in the
-- product so the peak stays at six buffers.
local function dome()
    -- **The radius first in both terms.** Written with the constants pushed
    -- before it, the radius — three buffers of its own — was evaluated with
    -- two already held, and the dome is inside every program in the world:
    -- it cost two of the engine's eight everywhere, which is what stopped
    -- the river's code field compiling at all.
    local inner = add(mul(u(), const(-M.DOME_DROP)), const(2.0 * M.DOME_DROP))
    return add(mul(mul(inner, u()), const(-1.0)), const(M.SUMMIT))
end

-- D: km below the base dome, smooth. The proxy for the deep bands.
function M.depth()
    return sub(dome(), ys())
end

-- mask(u) = clamp(1 + RAMP*CROWN_U - RAMP*u, FLOOR, 1)
local function relief_mask()
    -- The radius FIRST: with the constant pushed before it, the radius —
    -- which is three buffers of its own — was evaluated with two already
    -- held, and this mask is inside every surface program in the world.
    return clamp(add(mul(u(), const(-M.RELIEF_RAMP)), const(1.0 + M.RELIEF_RAMP * M.CROWN_U)),
        M.RELIEF_FLOOR, 1.0)
end

-- The terraces: BLUFF_AMP * clamp(STEEP * n, -1, 1) * patch, where patch
-- is clamp(RAMP * (n2 - MIN), 0, 1) on a much slower noise.
local function bluffs()
    local step = clamp(mul(noise("bluff", M.BLUFF_FREQ, M.BLUFF_OCTAVES, 1.0), const(M.BLUFF_STEEP)), -1.0, 1.0)
    local patch = clamp(mul(sub(noise("bluff_patch", M.BLUFF_PATCH_FREQ, 1, 1.0), const(M.BLUFF_PATCH_MIN)),
        const(M.BLUFF_PATCH_RAMP)), 0.0, 1.0)
    return mul(mul(step, patch), const(M.BLUFF_AMP))
end

-- PLAIN_FLOOR at the plain's centre radius, 1 from PLAIN_HALF_WIDTH_U out:
-- FLOOR + (1 - FLOOR) * clamp((u - u_plain)^2 / w^2, 0, 1).
M.PLAIN_U = (M.SPAWN_X * M.SPAWN_X + M.SPAWN_Z * M.SPAWN_Z) * 1e-6 / (M.R_DISC * M.R_DISC)
local function plain_mask()
    local function du() return sub(u(), const(M.PLAIN_U)) end
    local ramp = clamp(mul(mul(du(), du()), const(1 / (M.PLAIN_HALF_WIDTH_U * M.PLAIN_HALF_WIDTH_U))), 0.0, 1.0)
    return add(mul(ramp, const(1.0 - M.PLAIN_FLOOR)), const(M.PLAIN_FLOOR))
end

-- How deep in a gully a point is, 0..1: 1 on the creek line, 0 at the
-- gully's edge. The same noise node in two programs is the same field. A
-- fine noise wobbles the banks (added to |n| before the clamp) and roughens
-- the floor (scaling the result), so the profile is not a perfect V.
-- One roughness node serves both: the bank wobble is `|n| + w*r` and the
-- floor is scaled by `1 + k*r` — but rather than evaluate r twice, the floor
-- roughness rides on the SAME term: the profile is clamp(1 - (|n| + w*r)/W)
-- and a rougher floor comes from r moving the whole profile, which is what a
-- bank that wanders does to the floor under it anyway.
local function gully_depth()
    local groove = add(abs(noise("gully", M.GULLY_FREQ, M.GULLY_OCTAVES, 1.0)),
        mul(noise("gully_rough", M.GULLY_ROUGH_FREQ, 1, 1.0), const(M.GULLY_BANK_WOBBLE * (1.0 + M.GULLY_ROUGH))))
    return clamp(sub(const(1.0), mul(groove, const(1.0 / M.GULLY_WIDTH))), 0.0, 1.0)
end
-- Positive on the floor of a gully — the inner two fifths of its width —
-- for the creek-bed material. Multiplied by the plain mask's complement is
-- not needed: gullies run through the plain too.
function M.gully_floor()
    return sub(gully_depth(), const(0.6))
end
-- **A gully's water level, on the real ground** (2026-09-18: "water
-- running across a cherry tree field ... originating from a little cubby
-- hole"). World y, `at` of GULLY_DEPTH under the ground as it would stand
-- without the gully: the terrain of the program's own mode, plus the
-- gully's cut, less the water's depth under the rim, read as a level.
--
-- The brooks' and pools' levels used to be the SMOOTH ground (relief,
-- dome, knolls) less that depth, and the real ground carries the world's
-- detail (+/-3 blocks) and the bluffs' steps (+/-1) besides, so where a
-- gully ran through a dip of the detail its bank stood under the water and
-- the brook poured out over the grass. This is the ground itself, so the
-- bank is always `at` of the gully's depth over the water.
--
-- The engine solves a terraced fill's level at its own height (a fixed
-- point, engine ed211d8): `y + (T + cut - at) / SCALE` is still at the
-- height where the ungullied terrain is `at` deep, and it moves with y
-- only by the relief's own lean, so the iteration settles in a step or two.
-- The terrain FIRST: it is the deepest operand by far.
function M.gully_water_level(at)
    local ungullied = add(M.terrain(false), mul(gully_depth(), const(M.GULLY_DEPTH)))
    return add(mul(sub(ungullied, const(M.GULLY_DEPTH * at)), const(1.0 / M.SCALE)), M.node.Y())
end

-- The humidity noise, +/-0.5.
function M.humidity()
    return noise("humidity", M.HUMIDITY_FREQ, M.HUMIDITY_OCTAVES, 1.0, M.HUMIDITY_STRETCH)
end


-- Which half of the split a biome takes, as a mask positive on its side:
-- the humidity plus the dither against the split, so the two sides are
-- exact complements and the edge is speckled rather than drawn.
function M.humidity_mask(wet)
    local h = add(M.humidity(), noise("biome_dither", M.HUMIDITY_DITHER_FREQ, 1, 2.0 * M.HUMIDITY_DITHER))
    if wet then
        return sub(h, const(M.HUMIDITY_SPLIT))
    end
    return mul(sub(h, const(M.HUMIDITY_SPLIT)), const(-1.0))
end

-- The same half as a PRESENCE test: the smooth humidity alone, its
-- threshold moved past the split by the dither's whole reach and the
-- structure slack (biomes.lua asks it per chunk, before a biome's fills
-- are run at all). A sibling of `humidity_mask` rather than a flag on it,
-- because the two answer different questions: the mask says which BLOCK
-- is this side's, the presence test which CHUNK could hold one. It may be
-- smooth where the mask may not, and the arithmetic is short: the dither
-- is a noise bounded by ±HUMIDITY_DITHER, so a block of the wet mask needs
-- humidity + dither > SPLIT, hence humidity > SPLIT - HUMIDITY_DITHER —
-- with the threshold HUMIDITY_DITHER (and the slack) outside the split, no
-- dithered block can land on the side this test rules out, and inside the
-- strip it keeps, both halves' fills still run and their own masks still
-- decide per block, speckle and all.
function M.humidity_presence(wet)
    local out = M.HUMIDITY_DITHER + M.HUMIDITY_PRESENCE_SLACK
    if wet then
        return sub(M.humidity(), const(M.HUMIDITY_SPLIT - out))
    end
    return sub(const(M.HUMIDITY_SPLIT + out), M.humidity())
end

-- Which side of a province a place is, as a mask positive on its side:
-- "a" and "b" are exact complements, as the humidity's halves are.
function M.province_mask(side, split)
    split = split or M.PROVINCE_SPLIT
    local p = noise("province", M.PROVINCE_FREQ, M.PROVINCE_OCTAVES, 1.0, M.HUMIDITY_STRETCH)
    if side == "b" then
        return sub(p, const(split))
    end
    return mul(sub(p, const(split)), const(-1.0))
end
-- The same as a 0-to-1 weight for a biome's TERMS, rising from nothing at
-- the line its materials change on: a dune field starts flat exactly where
-- the sand starts. Six operations, which is what it costs every program
-- that carries the terms.
-- `split` moves the line (a span's fifth entry): 0 is an even share, 0.2
-- gives side "b" about a third of the ground.
function M.province_weight(side, split)
    split = split or M.PROVINCE_SPLIT
    local p = noise("province", M.PROVINCE_FREQ, M.PROVINCE_OCTAVES, 1.0, M.HUMIDITY_STRETCH)
    local raw = side == "b" and sub(p, const(split)) or sub(const(split), p)
    return clamp(mul(raw, const(1.0 / M.PROVINCE_BLEND)), 0.0, 1.0)
end
-- The province's "a" side as a weight centred on the line (2026-09-16): 1
-- well into "a", 0 well into "b", one half on the line, so it and one less
-- it sum to one across the blend — which `province_weight` on its two
-- sides does not (both are 0 on the line). For the Ember Ridge's terms.
function M.ember_province_a()
    local p = noise("province", M.PROVINCE_FREQ, M.PROVINCE_OCTAVES, 1.0, M.HUMIDITY_STRETCH)
    return clamp(add(mul(p, const(-0.5 / M.PROVINCE_BLEND)), const(0.5)), 0.0, 1.0)
end

-- The dry side's weight, 0 in the wet half to 1 in the dry, crossing over
-- HUMIDITY_BLEND either side of the split.
-- (Noise first, constants after: a constant evaluated first holds a buffer
-- for everything after it, and the programs run close to the eight.)
local function dry_weight()
    return clamp(add(mul(sub(M.humidity(), const(M.HUMIDITY_SPLIT)), const(-0.5 / M.HUMIDITY_BLEND)), const(0.5)),
        0.0, 1.0)
end
-- The same weight for a biome on half a ring: the Dunes take the dry side
-- of the Long Shore, the Flower Forest the wet.
M.dry_weight = dry_weight

-- Terrain MODES: which biome terms a program carries. A density program
-- cannot ask where it is, so the world's rings each get their own programs
-- and the generator picks by the chunk's radius (`terrain_mode_for`):
--   "wet"       the temperate ring's wet half alone (dev switch: woodlands)
--   "dry"       its dry half alone (dev switch: grasslands)
--   "temperate" both halves cross-faded by humidity — the temperate ring
--   "alpine"    the frost ring's terms alone
--   "coast"     the shore ring's cliffs alone, on a flat sea (dev switch: coastal cliffs)
--   "verdant"   the temperate pair as "temperate", with the rainforest's
--               terms added to the wet half by the verdant weight and the
--               mesa's to the dry half by the glass weight: the Glass Waste
--               and the Verdant Belt, and a band either side of them
--   "mesa"      the Arid Mesa's terms alone (dev switch: the mesa)
--   "badlands"  the Badlands' terms alone (dev switch: the badlands); in
--               "verdant" they are added to the Glass Waste's wet half
--   "rainforest" the rainforest's terms alone (dev switch: the rainforest)
--   "ocean"     the deep ocean's floor alone, on the coast's flat sea (dev switch: deep ocean)
--   "frozen"    the Frozen Wastes' terms alone (dev switch: frozen wastes)
--   "taiga"     the Taiga's terms alone (dev switch: taiga)
-- The alpine terms, in "alpine" and "all", are the COLD terms
-- (`cold_terms`): the alpine's mountains in the Crown, cross-faded across
-- its edge into the frost ring's two halves — the Frozen Wastes' plains on
-- Frostmoor, the Taiga's uplands on Firwold — which cross-fade into each
-- other across the humidity split.
--   "all"       temperate and alpine cross-faded by the alpine weight: the
--               band a few hundred metres wide at the frost ring's edge,
--               and the only programs that carry every ring's noise.
--   "rim"       "all" past the Crown's reach: the same, with the cold terms
--               the frost ring's two halves alone, no alpine mountains. The
--               Taiga (2.2) took "all" to 968 operations and the woodlands'
--               grass, which is the terrain and a mask, to 1,031 of 1,024;
--               the temperate ring's biomes are only ever in this part.
--   "ember"     the Ember Ridge: the temperate pair with the Volcanic
--               Foothills' terms (2.3), weighted in across the ring's
--               inner edge and out again over its outer third — the Glass
--               Waste's programs begin at the ring's outer edge and have
--               no room for them
--   "glass"     the Glass Waste alone: the temperate pair with the mesa's
--               and the badlands' terms, no rainforest (2026-09-15; the
--               seas need room beside the land terms, and "verdant" had
--               none: it is the band where the Glass Waste meets the
--               Verdant Belt now, and nothing else)
--   "belt"      the Verdant Belt and outward: the pair with the rainforest
--   "hem"       the Hem's inner band (2026-09-16): the temperate ring's
--               whole terrain fading out under the Rime Tundra's
--   "edge"      the rim: the tundra's ground, the Rime Wall, and the
--               body's own wall in every program, so every fill clips at
--               it and the chunks past 54 km are painted like the rest
-- THE SEAS (seas.lua) are a suffix on a mode. A chunk within reach of a
-- shore is "<mode>_shore" — the mode's own terms with the coast's face and
-- shelf on them (`M.coast_shore`); a chunk past the shelf is "deep" — the
-- ocean's floor (`M.sea_deep`), no land terms. Only the modes a sea can be
-- in take the suffix: "temperate", "belt", and the dev switch's "wet".
-- `M.terrain_mode` is what `terrain()` reads while a program is being
-- built; whoever compiles a program sets it and puts it back.
M.terrain_mode = nil
function M.default_mode()
    local only = tdw.config.everywhere
    if only == nil then
        return "all"
    elseif only == "rolling_grasslands" then
        return "dry"
    elseif only == "alpine_highlands" then
        return "alpine"
    elseif only == "coastal_cliffs" then
        return "wet"
    elseif only == "jungle" then
        return "rainforest"
    elseif only == "deep_ocean" then
        return "wet"
    elseif only == "frozen_wastes" then
        return "frozen"
    elseif only == "taiga" then
        return "taiga"
    elseif only == "arid_mesa" then
        return "mesa"
    elseif only == "badlands" then
        return "badlands"
    elseif only == "volcanic_foothills" then
        return "ember"
    elseif only == "dunes" or only == "flower_forest" or only == "coral_fringed_shallows" then
        return "temperate"
    elseif only == "frostpine_coast" or only == "rime_tundra" then
        return "hem"
    elseif only == "rime_wall" then
        return "edge"
    end
    return "wet"
end
-- The ranges of u a mode's programs are ever run over — the inverse of
-- `terrain_mode_for`, for the fills' masks (biomes.lua, `tdw.biome_mask`).
-- Nil for a mode without one: the dev switches, which put a biome
-- everywhere and mask nothing anyway.
function M.mode_u_ranges(mode)
    local base, _, deep = M.mode_parts(mode)
    if deep then
        mode = "belt"                           -- a deep chunk is in a lane: both the belt's range and the temperate ring's, below
    elseif base then
        mode = base
    end
    if mode == nil then
        return nil
    end
    local edge = M.ALPINE_EDGE_U
    local half = M.ALPINE_BLEND_U / 2 + M.wobble(edge)
    local reach = M.reach()
    local rim_from = M.CROWN_U + M.FROZEN_RING_BLEND_U / 2 + M.wobble(M.CROWN_U)
    if mode == "alpine" then
        return { { 0.0, edge - half } }
    elseif mode == "all" then
        return { { 0.0, edge + half } }
    elseif mode == "rim" then
        return { { rim_from, edge + half } }
    elseif mode == "temperate" then
        return { { edge - half, M.GLASS_U[1] + M.GLASS_INSET_U - reach }, { M.VERDANT_U[2] + reach, M.hem_in() } }
    elseif mode == "hem" then
        return { { M.hem_in(), M.edge_from() } }
    elseif mode == "edge" then
        return { { M.edge_from(), 2.0 } }
    elseif mode == "ember" then
        return { { M.EMBER_U[1] - M.EMBER_BLEND_U / 2 - M.wobble(M.EMBER_U[1]), M.GLASS_U[1] + M.GLASS_INSET_U - reach } }
    elseif mode == "verdant" then
        return { { M.VERDANT_U[1] - reach - 0.002, M.GLASS_U[2] + reach + 0.002 } }
    elseif mode == "glass" then
        return { { M.GLASS_U[1] + M.GLASS_INSET_U - reach, M.VERDANT_U[1] - reach } }
    elseif mode == "belt" then
        if base == nil then
            -- A deep chunk: any lane, so the temperate ring's too.
            return { { edge - half, M.GLASS_U[1] + M.GLASS_INSET_U - reach }, { M.GLASS_U[2] + reach, 2.0 } }
        end
        return { { M.GLASS_U[2] + reach, M.VERDANT_U[2] + reach } }
    end
    return nil
end
-- The mode for a chunk spanning [u_lo, u_hi]: one ring's own programs
-- wherever the alpine weight is exactly 0 or 1 over the whole chunk, the
-- cross-faded ones in the band between.
-- "ember" since 2026-09-16, with the plain shore profile (below): its terms
-- and the full shore's together were 1030 ops, six over
-- the compiler's cap, so the first lane keeps its shore reach (FADE, 920
-- blocks) short of the Ember Ridge's first "ember" chunk at 19.5 km.
local SEA_MODES = { temperate = true, belt = true, wet = true, dry = true, hem = true, edge = true, ember = true }
-- The modes whose programs carry the body's wall themselves: the generator
-- paints their chunks whether or not its gate can prove them inside.
M.CLIPPED = { edge = true, edge_shore = true }
-- The widening the Glass Waste's and the Verdant Belt's cross-fades ask
-- for, at the widest wobble either reaches.
function M.reach()
    return math.max(M.VERDANT_BLEND_U, M.GLASS_BLEND_U) / 2 + M.wobble(M.VERDANT_U[2])
end
local function land_mode_for(u_lo, u_hi)
    if tdw.config.everywhere then
        return M.default_mode()
    end
    -- Widened by the wobble: a chunk within the wobble of the edge may be
    -- either side of it, and the programs it gets have to carry both.
    local edge = M.ALPINE_EDGE_U
    local half = M.ALPINE_BLEND_U / 2 + M.wobble(edge)
    if u_hi <= edge - half then
        return "alpine"
    elseif u_lo >= edge + half then
        -- The rim (2026-09-16): the Hem's programs from where the mild
        -- rings' terrain starts fading out, and the edge's — clipped to the
        -- body, with the Rime Wall — from where it is gone.
        if u_lo >= M.edge_from() then
            return "edge"
        elseif u_hi > M.hem_in() then
            return "hem"
        end
        local reach = M.reach()
        if u_hi >= M.GLASS_U[1] + M.GLASS_INSET_U - reach and u_lo <= M.VERDANT_U[2] + reach then
            if u_hi < M.VERDANT_U[1] - reach then
                return "glass"
            elseif u_lo > M.GLASS_U[2] + reach then
                return "belt"
            end
            return "verdant"
        end
        -- The Ember Ridge, INSIDE the Glass Waste's own programs' inner
        -- edge (2026-09-16). Without that second test this branch caught
        -- every chunk outward of the Waste as well — the whole Long Shore
        -- and the Hem ran in the "ember" mode, whose u range is the ridge
        -- alone, so `biome_mask` pruned every span out there to nothing and
        -- the woodland, the grassland and the two new biomes of the Long
        -- Shore painted no surface at all. The ground was right (the
        -- ridge's terms weigh nothing that far out) and the world was bare
        -- soil from 28 km to the rim.
        if M.volcanic_terms and u_hi >= M.EMBER_U[1] - M.EMBER_BLEND_U / 2 - M.wobble(M.EMBER_U[1])
            and u_lo <= M.GLASS_U[1] + M.GLASS_INSET_U - reach then
            return "ember"
        end
        return "temperate"
    end
    -- Past everywhere the Crown's edge can wander to, the cold terms are
    -- the frost ring's alone.
    if u_lo >= M.CROWN_U + M.FROZEN_RING_BLEND_U / 2 + M.wobble(M.CROWN_U) and M.taiga_terms then
        return "rim"
    end
    return "all"
end
-- `pos` is the chunk (with its seed), for the seas' map bounds; without it
-- a chunk is taken to be dry land.
function M.terrain_mode_for(u_lo, u_hi, pos)
    local mode = land_mode_for(u_lo, u_hi)
    local seas = tdw.seas
    if pos and seas and seas.on() and SEA_MODES[mode] and M.coast_shore then
        local class = seas.class(pos)
        if class == "deep" then
            return "deep"
        elseif class == "shore" then
            return mode .. "_shore"
        end
    end
    return mode
end
-- A mode's land half, whether it is a shore, and whether it is the deep.
function M.mode_parts(mode)
    if mode == nil then
        return nil, false, false
    end
    if mode == "deep" then
        return nil, false, true
    end
    local base = mode:match("^(.-)_shore$")
    if base then
        return base, true, false
    end
    return mode, false, false
end

-- The alpine weight: 1 through the frost ring, fading to 0 over
-- ALPINE_BLEND_U past its outer edge.
local function alpine_weight()
    return clamp(add(mul(sub(u_biome(), const(M.ALPINE_EDGE_U)), const(-1.0 / M.ALPINE_BLEND_U)), const(0.5)), 0.0, 1.0)
end

-- The verdant weight: 1 inside the Verdant Belt, fading to 0 over
-- VERDANT_BLEND_U across each edge, on the wobbled radius the biome masks
-- use. Written `(|u - mid| - half) * -1` so the radius is evaluated first
-- and once.
local function verdant_weight()
    local mid, half = (M.VERDANT_U[1] + M.VERDANT_U[2]) / 2, (M.VERDANT_U[2] - M.VERDANT_U[1]) / 2
    local inside = mul(sub(abs(sub(u_biome(), const(mid))), const(half)), const(-1.0 / M.VERDANT_BLEND_U))
    return clamp(add(inside, const(0.5)), 0.0, 1.0)
end

-- The glass weight: the same for the Glass Waste.
local function glass_weight()
    local inner = M.GLASS_U[1] + M.GLASS_INSET_U
    local mid, half = (inner + M.GLASS_U[2]) / 2, (M.GLASS_U[2] - inner) / 2
    local inside = mul(sub(abs(sub(u_biome(), const(mid))), const(half)), const(-1.0 / M.GLASS_BLEND_U))
    return clamp(add(inside, const(0.5)), 0.0, 1.0)
end

-- The Ember Ridge's weight: in over EMBER_BLEND_U at the ring's inner
-- edge, out again over EMBER_FADE_U to EMBER_OUT_U, on the wobbled radius.
local function ember_weight()
    local inner = clamp(add(mul(sub(u_biome(), const(M.EMBER_U[1])), const(1.0 / M.EMBER_BLEND_U)), const(0.5)), 0.0, 1.0)
    local outer = clamp(mul(sub(const(M.EMBER_OUT_U), u_biome()), const(1.0 / M.EMBER_FADE_U)), 0.0, 1.0)
    return mul(inner, outer)
end
M.ember_weight = ember_weight

-- The Hem's weight (2026-09-16): 0 through the mild rings, 1 past the
-- Hem's inner edge, across HEM_BLEND_U of the wobbled radius. What the
-- "hem" programs fade the temperate terrain out by and the tundra's in.
local function hem_w()
    if tdw.config.everywhere then
        return const(1.0)
    end
    return clamp(add(mul(sub(u_biome(), const(M.HEM_U)), const(1.0 / M.HEM_BLEND_U)), const(0.5)), 0.0, 1.0)
end
M.hem_weight = hem_w

-- How far the river trough is lifted across a shore's FADE band, km: the
-- valley (VALLEY_DEPTH deep, river_valleys.lua) is gone where the lift
-- passes its depth, and the river's own surface stops there too.
M.RIVER_LIFT_KM = 0.06

-- The Frozen Wastes' weight: 0 in the Crown and the frost ring's wet half,
-- 1 deep in its dry half, as the product of the ring's share (past the
-- Crown's edge) and the dry side's (past the humidity split). The radius
-- FIRST, it being the deeper operand.
local function frost_ring_w()
    return clamp(add(mul(sub(u_biome(), const(M.CROWN_U)), const(1.0 / M.FROZEN_RING_BLEND_U)), const(0.5)), 0.0, 1.0)
end
local function frost_dry_w()
    return clamp(add(mul(sub(M.humidity(), const(M.HUMIDITY_SPLIT)), const(-0.5 / M.FROZEN_HUMIDITY_BLEND)), const(0.5)),
        0.0, 1.0)
end
local function frozen_weight()
    return mul(frost_ring_w(), frost_dry_w())
end
-- The Taiga's weight (2.2): the frost ring's share times the wet side's.
-- (Its pools stood only where this was all but 1, until they went,
-- 2026-09-18: biomes/taiga.lua.)
function M.taiga_weight()
    return mul(frost_ring_w(), add(mul(frost_dry_w(), const(-1.0)), const(1.0)))
end
-- The cold core's terms: the alpine's in the Crown; past its edge the
-- Frozen Wastes' on the dry side and the Taiga's on the wet, cross-faded by
-- the dry weight, as `alpine * (1 - ring) + ring * (frozen * dry + taiga *
-- (1 - dry))`: each program once, the weights twice, which is what the
-- Wastes alone cost when their weight was built twice. The alpine FIRST,
-- the Wastes next and the Taiga deepest in: the Taiga's terms run with two
-- buffers held, and are written for it. The alpine alone, or with the
-- Wastes alone, when a file is not loaded.
-- **Swapped 2026-09-16** ("the alpine highlands and frozen wastes need to
-- switch spots"): the Frozen Wastes' plains are the ICE CAP on the Crown,
-- and the alpine's mountains stand round it on Frostmoor, the frost ring's
-- dry half — `frozen * (1 - ring) + ring * (alpine * dry + taiga * (1 -
-- dry))`. The alpine map is 1,024 samples at 24 blocks, twelve kilometres
-- from the axis either way, so it reaches the frost ring's outer edge with
-- room to spare. Same programs, same weights, the same number of
-- operations as the other way round.
local function cold_terms(no_crown)
    if no_crown and M.alpine_terms and M.taiga_terms then
        -- Outside the Crown's reach the ring weight is 1: the two halves.
        return add(mul(M.alpine_terms(), frost_dry_w()), mul(M.taiga_terms(), add(mul(frost_dry_w(), const(-1.0)), const(1.0))))
    end
    if not M.frozen_terms then
        return M.alpine_terms()
    end
    if not M.taiga_terms then
        local w = frost_ring_w()
        return add(mul(M.frozen_terms(), add(mul(w, const(-1.0)), const(1.0))), mul(M.alpine_terms(), frost_ring_w()))
    end
    local mix = add(mul(M.alpine_terms(), frost_dry_w()), mul(M.taiga_terms(), add(mul(frost_dry_w(), const(-1.0)), const(1.0))))
    return add(mul(M.frozen_terms(), add(mul(frost_ring_w(), const(-1.0)), const(1.0))), mul(mix, frost_ring_w()))
end
-- The Crown's share, for the biomes that stand on the ice cap.
function M.crown_weight()
    return add(mul(frost_ring_w(), const(-1.0)), const(1.0))
end

-- A grassland ridge: positive along the zero contour of its noise.
function M.ridge()
    return mul(clamp(add(mul(abs(noise("ridge", M.RIDGE_FREQ, 1, 1.0)), const(-1.0 / M.RIDGE_WIDTH)), const(1.0)), 0.0, 1.0),
        const(M.RIDGE_AMP))
end

-- The hollows more pronounced than the swells (2026-09-11): the noise's
-- low side is deepened by HOLLOW_DEEPEN, as n + k * min(n, 0), which is
-- (1 + k/2) n - (k/2) |n| — the noise evaluated twice, since the stack
-- machine has no dup and the same stream gives the same values.
local function swells()
    local k = M.HOLLOW_DEEPEN
    local swell = add(mul(noise("swell", M.SWELL_FREQ, M.SWELL_OCTAVES, M.SWELL_AMP), const(1.0 + k / 2)),
        mul(abs(noise("swell", M.SWELL_FREQ, M.SWELL_OCTAVES, M.SWELL_AMP)), const(-k / 2)))
    return add(swell, M.ridge())
end

-- The wet half's own terms: the bluffs (when on) and the gullies. A gully
-- lowers the surface, which is LESS depth at a given height.
local function wet_terms()
    local gully = mul(gully_depth(), const(M.GULLY_DEPTH))
    if M.BLUFF_AMP > 0 then
        return sub(bluffs(), gully)
    end
    return mul(gully, const(-1.0))
end

-- T: km below the real surface, positive underground. D plus the relief,
-- the detail and the biome terms — the wet half's gullies and bluffs, the
-- dry half's swells and ridges, cross-faded by the dry weight where both
-- are in play — a noise node each, every time it is evaluated. `flank`
-- programs run only near the rim and the underside, far from the plain, so
-- they leave the plain and the blend out and keep the ops for the body.
-- The world's hills on their own, for anything that wants the smooth height
-- without the fine detail: the river cuts its valley from this, so a trough
-- has a smooth floor whatever the ground above it is doing.
function M.relief_node()
    return mul(mul(relief_mask(), noise("relief", M.RELIEF_FREQ, M.RELIEF_OCTAVES, M.RELIEF_AMP)), plain_mask())
end

-- The mild rings' terms: the pair cross-faded by humidity, and on top of
-- it the two biomes of the Long Shore that have terms of their own — the
-- Dunes on the dry side (2.5) and the Flower Forest's knolls on the wet
-- (2.6). Both are weighted to their half of that one ring and are nothing
-- anywhere else, and both go in FIRST, with the pair as the shallow
-- operand: the pair is the deeper of the two and the engine holds every
-- pending operand in a buffer. The "temperate" programs are this; the
-- "hem" ones fade it out under the tundra's.
local function temperate_terms()
    local pair = add(mul(wet_terms(), add(mul(dry_weight(), const(-1.0)), const(1.0))), mul(swells(), dry_weight()))
    local extra = nil
    if M.dune_terms then
        extra = mul(M.dune_terms(), M.dune_weight())
    end
    if M.knoll_terms then
        local knolls = mul(M.knoll_terms(), M.knoll_weight())
        extra = extra and add(extra, knolls) or knolls
    end
    return extra and add(extra, pair) or pair
end

function M.terrain(flank)
    local relief = mul(relief_mask(), noise("relief", M.RELIEF_FREQ, M.RELIEF_OCTAVES, M.RELIEF_AMP))
    -- The world's own hills: two octaves every surface program pays. The
    -- alpine map and its ledges carry that scale themselves, so the alpine
    -- mode leaves them out — a third of the noise in every alpine fill.
    local full_mode = flank and "wet" or M.terrain_mode or M.default_mode()
    local mode, shore, deep = M.mode_parts(full_mode)
    if deep then
        -- Past the shelf: the ocean's floor at the pool's level. No land.
        return add(M.sea_deep(), M.depth())
    end
    local detail = mode == "alpine" and const(0.0) or noise("detail", M.DETAIL_FREQ, M.DETAIL_OCTAVES, M.DETAIL_AMP)
    if mode == "all" or mode == "rim" then
        -- **Out of the cold core, as the "alpine" mode has it.** The frost
        -- ring is "alpine" inside a radius and "all" outside it, and with the
        -- world's detail in one and not the other the ground stepped by up to
        -- three blocks on the chunk boundary between them (2026-09-15, found
        -- building the Taiga across that line).
        detail = mul(detail, add(mul(alpine_weight(), const(-1.0)), const(1.0)))
    end
    if not flank then
        relief = mul(relief, plain_mask())
    end
    if mode == "glass" and M.salt_weight and M.SALT_RELIEF_DAMP then
        -- The Salt Pan (2026-09-17, "a little flatter"): the pan caps the
        -- ring's terms at its floor, but the world's relief comes after the
        -- cap and tilted the pan by tens of blocks a kilometre; part of it
        -- is taken out on the pan.
        relief = mul(relief, add(mul(M.salt_weight(), const(-M.SALT_RELIEF_DAMP)), const(1.0)))
    end
    local shape = add(relief, detail)
    if mode == "coast" then
        -- The coast stands on a flat sea, not on the dome or the world's
        -- hills: its terms cancel the dome and carry their own relief. Its
        -- terms first and the depth after: the terms are the deeper, and
        -- with the depth held first they reached the eighth buffer.
        return add(M.coast_terms(), M.depth())
    end
    if mode == "ocean" then
        return add(M.ocean_terms(), M.depth())
    end
    -- **The ring's own terms FIRST, the hills after, the depth last.** The
    -- stack machine holds every pending operand in one of eight buffers, so
    -- `add(a, b)` peaks at the deeper of `peak(a)` and `1 + peak(b)`: the
    -- deepest operand belongs first, where nothing is held while it runs.
    -- Written the other way round — the hills first and the ring's terms
    -- inside — the "all" mode needed NINE, and every chunk of the band
    -- where the frost ring meets the temperate one failed to generate and
    -- took the whole mod down with it. It was never compiled until the
    -- world had both rings live: the dev switch had pinned every world to
    -- one ring, and one ring's terms fit.
    local terms
    if mode == "wet" then
        terms = wet_terms()
    elseif mode == "dry" then
        terms = swells()
    elseif mode == "alpine" then
        terms = cold_terms()
    elseif mode == "frozen" then
        terms = M.frozen_terms()
    elseif mode == "taiga" then
        terms = M.taiga_terms()
    elseif mode == "mesa" then
        terms = M.mesa_terms()
    elseif mode == "badlands" then
        terms = M.badlands_terms()
    elseif mode == "temperate" then
        terms = temperate_terms()
    elseif mode == "hem" then
        -- The Hem's inner band (2026-09-16): the mild rings' whole terrain
        -- fading out across HEM_BLEND_U under the Rime Tundra's (3.1). The
        -- tundra FIRST: the deeper operand goes where nothing is held.
        local cold = M.tundra_terms and M.tundra_terms() or const(0.0)
        terms = add(mul(cold, hem_w()), mul(temperate_terms(), add(mul(hem_w(), const(-1.0)), const(1.0))))
    elseif mode == "edge" then
        -- The rim: the tundra's ground with the Rime Wall (3.2) standing up
        -- out of it over the last two hundred blocks; and, below, the whole
        -- clipped to the body's wall.
        local cold = M.tundra_terms and M.tundra_terms() or const(0.0)
        terms = M.wall_lift and add(cold, M.wall_lift()) or cold
    elseif mode == "ember" then
        -- The Volcanic Foothills' terms over the pair, weighted across the
        -- ring. The volcanic FIRST: the deepest term in the program.
        local pair = add(mul(wet_terms(), add(mul(dry_weight(), const(-1.0)), const(1.0))), mul(swells(), dry_weight()))
        local ridge = M.volcanic_terms()
        local split = M.obsidian_terms and M.geyser_terms
        if split then
            -- The ridge's other province (2026-09-16): the Obsidian Barrens'
            -- flows on the dry side, the Geyser Basin's terraces on the wet,
            -- where the Foothills' ridges and cones are not. The province
            -- weight is centred on the line the materials change on, so the
            -- two sides always sum to one. The Foothills FIRST: the deepest.
            local other = add(mul(M.obsidian_terms(), dry_weight()), mul(M.geyser_terms(), add(mul(dry_weight(), const(-1.0)), const(1.0))))
            ridge = add(mul(ridge, M.ember_province_a()), mul(other, add(mul(M.ember_province_a(), const(-1.0)), const(1.0))))
        end
        terms = add(mul(ridge, ember_weight()), pair)
        if M.volcanic_cap then
            -- The lava pits: the ground capped down to a flat floor where
            -- a pit is (`volcanic_cap`, far above the ground elsewhere),
            -- after the pair, so the floor is where the lava's level
            -- expects it whatever the hills were doing. Not in the other
            -- province: the cap a kilometre up there.
            local cap = M.volcanic_cap()
            if split then
                cap = add(cap, add(mul(M.ember_province_a(), const(-1.0)), const(1.0)))
            end
            terms = min(terms, cap)
        end
    elseif mode == "rainforest" then
        terms = M.rainforest_terms()
    elseif mode == "belt" then
        -- The Verdant Belt and outward: the rainforest over the wet half,
        -- weighted in across the belt's edges.
        local rain = mul(M.rainforest_terms(), verdant_weight())
        if M.karst_damp then
            -- The Karst Towers' province: the Jungle's ground calmed under
            -- the towers (2026-09-17).
            rain = mul(rain, M.karst_damp())
        end
        if M.karst_terms then
            -- The Karst Towers (3.12), in their province well inside the
            -- belt: the pinnacles FIRST, the deepest.
            rain = add(mul(M.karst_terms(), M.karst_weight()), rain)
        end
        local wet = add(rain, wet_terms())
        terms = add(mul(swells(), dry_weight()), mul(wet, add(mul(dry_weight(), const(-1.0)), const(1.0))))
    elseif mode == "glass" then
        -- The Glass Waste: the mesa over the dry half, the badlands over the
        -- wet, weighted in across its edges. The dry side FIRST: the mesa is
        -- the deepest term in the program.
        local wet = wet_terms()
        if M.badlands_terms then
            wet = add(mul(M.badlands_terms(), glass_weight()), wet)
        end
        local dry = swells()
        if M.mesa_terms then
            dry = add(mul(M.mesa_terms(), glass_weight()), dry)
        end
        terms = add(mul(dry, dry_weight()), mul(wet, add(mul(dry_weight(), const(-1.0)), const(1.0))))
        if M.salt_floor then
            -- The Salt Pan (2026-09-16): where its weight is 1 the ground is
            -- clamped down to the pan's own floor — the benches and fins cut
            -- to it — and where the weight is 0 the cap stands SALT_RAMP
            -- above and touches nothing. `terms` is evaluated once, as the
            -- left operand of the min.
            -- From above only: the ring's cuts under its base are shallow
            -- (an arroyo two blocks, a piping void six) and the pan keeps
            -- them as its own low spots. Clamping from below as well cost
            -- another fifty operations, and the ring was at 1,020.
            local off = mul(sub(const(1.0), M.salt_weight()), const(M.SALT_RAMP))
            terms = min(terms, add(M.salt_floor(), off))
        end
    elseif mode == "verdant" then
        -- The rainforest's karst, ravines and sinkholes over the wet half's
        -- own gullies, weighted in across the belt's edges; the dry half is
        -- the grassland's swells, as everywhere.
        -- And the mesa's benches and canyons over the dry half's swells,
        -- weighted in across the Glass Waste's edges. The dry side FIRST: the
        -- mesa is the deepest term in the program.
        local wet = mul(M.rainforest_terms(), verdant_weight())
        if M.karst_damp then
            wet = mul(wet, M.karst_damp())
        end
        if M.badlands_terms then
            wet = add(wet, mul(M.badlands_terms(), glass_weight()))
        end
        wet = add(wet, wet_terms())
        local dry = swells()
        if M.mesa_terms then
            dry = add(mul(M.mesa_terms(), glass_weight()), dry)
        end
        terms = add(mul(dry, dry_weight()), mul(wet, add(mul(dry_weight(), const(-1.0)), const(1.0))))
    else
        -- The temperate pair cross-faded by humidity, and that whole
        -- cross-faded by the alpine weight against the alpine terms at the
        -- frost ring's edge, so neither ring steps at the border.
        local temperate = add(mul(wet_terms(), add(mul(dry_weight(), const(-1.0)), const(1.0))), mul(swells(), dry_weight()))
        terms = add(mul(cold_terms(mode == "rim"), alpine_weight()),
            mul(temperate, add(mul(alpine_weight(), const(-1.0)), const(1.0))))
    end
    local out
    if shore then
        -- Within reach of a shore: the coast's face and shelf on the land's
        -- own shape (coastal_cliffs.lua). The Hem's shores take the plain
        -- profile: the full one is five hundred operations, and the Hem's
        -- blend band carries two rings' terms.
        local coast = (mode == "hem" or mode == "edge" or mode == "ember") and M.coast_plain or M.coast_shore
        out = add(coast(add(terms, shape)), M.depth())
    else
        out = add(add(terms, shape), M.depth())
    end
    -- **The river valleys are SUBTRACTED from whatever is there**, rather
    -- than being a mode of their own: a river crosses biomes, and the
    -- uplands either side keep their own shape. The terrain is the lesser
    -- of itself and the trough's surface, which is the smooth height minus
    -- the valley's depth plus the profile — and the profile rises a
    -- kilometre past the rim, so beyond the valley the trough never bites.
    --
    -- The terrain FIRST and the trough second: `min(a, b)` peaks at the
    -- deeper of `peak(a)` and `1 + peak(b)`, and the terrain is much the
    -- deeper of the two, so this costs no buffer at all.
    if not flank and mode ~= "alpine" and mode ~= "coast" and mode ~= "ocean" and mode ~= "edge" and M.river_valley then
        -- In the shore programs the valley is cut from the coast's beach
        -- floor where that stands higher (river_valleys.lua): two ops.
        local trough = M.river_valley(shore and tdw.seas and tdw.seas.floor() or nil)
        if mode == "all" or mode == "rim" then
            -- Not into the mountains: where the alpine weight is up, the
            -- trough's surface is put a kilometre out of reach.
            trough = add(trough, mul(alpine_weight(), const(1.0)))
        end
        if mode == "hem" then
            -- Nor onto the rim: the valley shallows across the Hem's blend
            -- band and is gone where the "edge" programs, which carry no
            -- trough, begin.
            trough = add(trough, hem_w())
        end
        if shore then
            -- Nor into a sea: a valley cut through the shore's rim would
            -- drain it. The trough rises RIVER_LIFT_KM over the FADE band
            -- toward the shore, so a valley shallows and is gone by half
            -- way across it: a river peters out before the shore. (A
            -- kilometre of lift until 2026-09-15: the valley's whole depth
            -- rose in the band's first twenty-five blocks, a wall the
            -- river's bed carried on past, painted on the uplands.)
            trough = add(trough, mul(tdw.seas.near(), const(M.RIVER_LIFT_KM)))
        end
        out = min(out, trough)
    end
    if mode == "edge" then
        -- The body's wall: past it, the void. Every program of the mode and
        -- every fill compiled in it has this, so nothing paints past the
        -- edge and the generator needs no flank set for these chunks.
        out = min(out, M.edge_body())
    end
    return out
end

-- A band of T between two depths, at ONE evaluation of the terrain:
-- half - |T - mid| is positive exactly where lo < T < hi. Negative depths
-- are ABOVE the ground.
function M.terrain_band(lo, hi, flank)
    local mid, half = (lo + hi) / 2, (hi - lo) / 2
    -- Written terrain-first: `half - |T - mid|` as `(|T - mid| - half) * -1`,
    -- one op more and one buffer fewer for the whole of T's evaluation.
    return mul(sub(abs(sub(M.terrain(flank), const(mid))), const(half)), const(-1.0))
end

-- W(Y) as a sum of clamped ramps on RAW y, so each segment is seven ops.
-- W = W_top + sum_i s_i * clamp(y - y_i, dy_i, 0), s_i in km per block.
local function half_width(segments)
    local acc = const(M.KNOTS[1][2])
    for i = 1, segments or #M.KNOTS - 1 do
        local y_i = M.KNOTS[i][1] * 1000 + M.Y0
        local dy = (M.KNOTS[i + 1][1] - M.KNOTS[i][1]) * 1000        -- negative
        local slope = (M.KNOTS[i + 1][2] - M.KNOTS[i][2]) / dy         -- positive
        acc = add(acc, mul(const(slope), clamp(sub(Y(), const(y_i)), dy, 0.0)))
    end
    return acc
end

-- B = W'^2 - r^2 (1 + wobble), positive inside the body. At the surface
-- W' = W and the edge is where `u_biome` is 1; under FLANK_TOP_Y the
-- flank's warp comes in as it always was (see M.WARP_HI).
local function warped_half_width(segments)
    local below = clamp(mul(sub(const(M.FLANK_TOP_Y), ys()), const(1.0 / M.FLANK_RAMP_KM)), 0.0, 1.0)
    local warp = add(noise("flank", M.FLANK_FREQ, 2, M.FLANK_WARP), const(-0.5 * M.FLANK_WARP))
    return mul(half_width(segments), add(mul(warp, below), const(1.0)))
end
local function body(segments)
    local w = warped_half_width(segments)
    return sub(mul(w, mul(warped_half_width(segments), const(M.EDGE_U))), mul(r2(), add(wobble_node(), const(1.0))))
end
function M.body()
    return body()
end
-- The same with only the knots a rim chunk can reach, for the "edge"
-- programs (`M.terrain`): two segments are exact down to Y = -8 km, nineteen
-- kilometres under the rim, and below that W is 46 km at most either way,
-- so a chunk 53 km out is air by both. Forty-two operations, not 121.
M.EDGE_SEGMENTS = 2
function M.edge_body()
    return body(M.EDGE_SEGMENTS)
end

-- E2: squared ellipsoidal distance from the stack centre, km^2.
local function e2()
    local dy = mul(sub(Y(), const(M.STACK_Y * 1000 + M.Y0)), const(M.K * M.SCALE))
    return add(r2(), mul(dy, dy))
end
-- A shell between two radii: positive inside outer and outside inner.
function M.shell(outer, inner)
    return min(sub(const(outer * outer), e2()), sub(e2(), const(inner * inner)))
end
function M.inside(radius)
    return sub(const(radius * radius), e2())
end

-- Ring mask on u: positive between two thresholds.
-- Positive inside the ring, written `half - |u - mid|` so the radius is
-- evaluated ONCE: `min(u - lo, hi - u)` evaluates it twice, and this is
-- read by every biome mask in every fill.
function M.ring(u_lo, u_hi)
    local mid, half = (u_lo + u_hi) / 2, (u_hi - u_lo) / 2
    return sub(const(half), abs(sub(u_biome(), const(mid))))
end

-- Compiled programs -----------------------------------------------------------
-- Compiled ONCE here and captured. `top` programs assume the chunk is inside
-- the body wall (the generator's gate guarantees it); `flank` programs also
-- test the body, at a noise node more, for chunks near the rim, the underside
-- or the needle.
-- What each program was compiled from, so a finished program can be built on
-- (`M.thinned`). Weak, so a program nobody holds takes its source with it.
local SOURCES = setmetatable({}, { __mode = "k" })
local function compile(name, spec)
    local ok, field = pcall(game.density, spec)
    if not ok then
        -- The host reports only "errored in init.lua"; say which program and why.
        game.log(string.format("tiamat_default_world density %s REFUSED: %s", name, tostring(field)))
        error(field, 0)
    end
    game.log(string.format("tiamat_default_world density %-18s %3d ops", name, field:len()))
    SOURCES[field] = spec
    return field
end
M.compile = compile

-- EVERY ground cover at half the density its biome asks for (2026-09-25:
-- "too thick everywhere" — half the grass, half the flowers, in every
-- biome). A cover's take is min'd with a fine noise that is positive half
-- the time: symmetric about zero, so exactly half of what the take allows
-- survives, and at 1.7 a block its features are under a cell apart, so it
-- thins evenly rather than cutting bald patches. Done here, once for every
-- biome, rather than by retuning forty thresholds that each thin a
-- different shape of patch. A take compiled elsewhere is passed through.
local COVER_THIN_FREQ = 1.7
local THINNED = setmetatable({}, { __mode = "k" })
function M.thinned(take)
    local done = THINNED[take]
    if done == nil then
        local spec = SOURCES[take]
        done = spec and compile("cover.thinned", min(spec, noise("cover_thin", COVER_THIN_FREQ, 1, 1.0))) or take
        THINNED[take] = done
    end
    return done
end

M.programs = {}
local P = M.programs
-- The top programs, one set per terrain mode the world needs: the dev
-- switch's one mode, or the three of the real world. The deep bands follow
-- D alone and are the same programs in every set.
-- The bottom of the surface band: everything under it belongs to an area
-- whose biomes are not built, and the generator paints that white while
-- that is true (generate.lua, tdw.config.white_unbuilt).
local deep = compile("top.deep", sub(M.depth(), const(M.SURFACE_BAND_D)))
local gloam = compile("top.gloam", sub(M.depth(), const(M.GLOAM_D)))
local abyss = compile("top.abyss", sub(M.depth(), const(M.ABYSS_D)))
-- Modes whose deep bands are measured down from the TERRAIN rather than the
-- dome: an ocean floor stands a hundred blocks under the dome and its
-- trenches hundreds more, and bands by the dome would paint them white.
-- The generator reads the same table for its gate.
--
-- **Every mode, since 2026-09-15.** The world's relief is four kilometres
-- of noise masked to a tenth outside the Crown — still four hundred blocks
-- either way — and the surface band is a hundred blocks: wherever a hill
-- dipped more than that under the dome the ground was the white
-- placeholder from five blocks down, a white slope with grass on it. The
-- spawn's plain flattens the relief, which is why nobody saw it until
-- `/tp` put a player on real hills. A terrain a mode, compiled once.
M.BANDS_BY_TERRAIN = setmetatable({}, { __index = function() return true end })
local function top_programs(mode)
    M.terrain_mode = mode
    local set = {
        solid = compile("top." .. mode .. ".solid", M.terrain(false)),
        stone = compile("top." .. mode .. ".stone", sub(M.terrain(false), const(M.SKIN_DIRT))),
        deep = deep,
        gloam = gloam,
        abyss = abyss,
    }
    if M.BANDS_BY_TERRAIN[mode] then
        set.deep = compile("top." .. mode .. ".deep", sub(M.terrain(false), const(M.SURFACE_BAND_D)))
        set.gloam = compile("top." .. mode .. ".gloam", sub(M.terrain(false), const(M.GLOAM_D)))
        set.abyss = compile("top." .. mode .. ".abyss", sub(M.terrain(false), const(M.ABYSS_D)))
    end
    M.terrain_mode = nil
    return set
end
-- The alpine and cross-faded sets read the alpine maps, which exist only
-- after the world pre-pass, so they are compiled at the first chunk that
-- needs them (`top_for`); the rest are compiled here, at load, where
-- `--check-mods` sees them.
P.top = {}
-- Every mode is built on demand now. The temperate set used to be built
-- here, at load, which was before the river valleys had defined the trough
-- they cut into it — so the world's most common programs were the only ones
-- without a river in them.
local LAZY = { alpine = true, all = true, coast = true, temperate = true, wet = true, dry = true, verdant = true, rainforest = true, ocean = true, frozen = true, mesa = true, badlands = true, taiga = true, rim = true, glass = true, belt = true, ember = true, hem = true, edge = true }
function M.top_for(mode)
    local set = P.top[mode]
    if set == nil then
        set = top_programs(mode)
        P.top[mode] = set
    end
    return set
end
if tdw.config.everywhere then
    local mode = M.default_mode()
    if not LAZY[mode] then
        P.top[mode] = top_programs(mode)
    end
end
P.flank = {
    deep = compile("flank.deep", min(sub(M.depth(), const(M.SURFACE_BAND_D)), M.body())),
    solid = compile("flank.solid", min(M.terrain(true), M.body())),
    stone = compile("flank.stone", min(sub(M.terrain(true), const(M.SKIN_DIRT)), M.body())),
    gloam = compile("flank.gloam", min(sub(M.depth(), const(M.GLOAM_D)), M.body())),
    abyss = compile("flank.abyss", min(sub(M.depth(), const(M.ABYSS_D)), M.body())),
}
P.shells = {}
for _, shell in ipairs(M.SHELLS) do
    P.shells[shell[1]] = compile("shell." .. shell[1], M.shell(shell[2], shell[3]))
end
P.hollow = compile("hollow", M.inside(M.HOLLOW_R))

-- Plain-Lua evaluations of the same curves, for the generator's gate and the
-- spawn. These are BOUNDS on a chunk, not samples of the field: the fields
-- are the density programs above, and these only decide which programs are
-- worth running. Ordinary + - * / on doubles is IEEE-exact everywhere; no
-- libm here.
-- How far above the base dome a landing player is dropped, beyond the
-- plain's own thirty: the alpine range stands its peaks ALPINE_PEAK km
-- over the dome (the biome file says how high), and a player put down
-- inside a mountain would have to climb out through chunks the vertical
-- view does not reach. The landing scans down and hops, so a valley floor
-- far below the drop is found in a few hops.
function M.spawn_extra_above()
    if M.default_mode() == "alpine" then
        return math.ceil((M.ALPINE_PEAK or 0.4) * 1000) + 10
    elseif M.default_mode() == "coast" then
        return math.ceil((M.COAST_TOP or 0.06) * 1000) + 10
    end
    return 0
end
-- The dome, as a node, for a biome that has to cancel it (the coast: a
-- sea is flat).
function M.dome_node()
    return dome()
end
function M.dome_at(u_value)
    return M.SUMMIT - M.DOME_DROP * u_value * (2.0 - u_value)
end
function M.mask_at(u_value)
    local m = 1.0 + M.RELIEF_RAMP * M.CROWN_U - M.RELIEF_RAMP * u_value
    if m < M.RELIEF_FLOOR then return M.RELIEF_FLOOR end
    if m > 1.0 then return 1.0 end
    return m
end
-- W(Y) in km for a Spindle Y in km, from the knots.
function M.half_width_at(Y_km)
    local knots = M.KNOTS
    if Y_km >= knots[1][1] then return knots[1][2] end
    for i = 1, #knots - 1 do
        local y_hi, w_hi = knots[i][1], knots[i][2]
        local y_lo, w_lo = knots[i + 1][1], knots[i + 1][2]
        if Y_km >= y_lo then
            return w_lo + (w_hi - w_lo) * (Y_km - y_lo) / (y_hi - y_lo)
        end
    end
    return 0.0
end
-- How much of the relief the plain leaves at a given u; the gate takes the
-- larger value at a chunk's two ends, which is the most since the curve is
-- a bowl.
function M.plain_at(u_value)
    local d = (u_value - M.PLAIN_U) / M.PLAIN_HALF_WIDTH_U
    local ramp = d * d
    if ramp > 1.0 then ramp = 1.0 end
    return M.PLAIN_FLOOR + (1.0 - M.PLAIN_FLOOR) * ramp
end
-- The world y of the base dome at the spawn column. The ground is within
-- PLAIN_FLOOR of the full relief of it.
function M.spawn_base_y()
    return M.Y0 + 1000.0 * M.dome_at(M.PLAIN_U)
end

-- The ground at a column, by the field: the terrain program for the
-- column's ring, compiled once per mode, sampled every COLUMN_STEP blocks
-- from `top` down until it is solid and then block by block within that
-- step — the topmost solid block. Some two hundred samples, once per
-- landing, which is what `Density:at` is for ("for choosing WHERE, not for
-- looping"). nil if nothing is solid within COLUMN_REACH below `top`.
--
-- For the spawn: the alpine dev world stood the spawn a thousand blocks
-- over the base dome, since the peaks can reach that, and a new player
-- fell the whole way. This finds the ground before they drop.
local COLUMN_STEP, COLUMN_REACH = 8, 1600
local column_programs = {}
function M.ground_at_column(x, z, seed, top)
    local u = (x * x + z * z) * 1e-6 / (M.R_DISC * M.R_DISC)
    local mode = M.terrain_mode_for(u, u, { x = x // 16, y = math.floor(top) // 16, z = z // 16, seed = seed })
    local program = column_programs[mode]
    if program == nil then
        local was = M.terrain_mode
        M.terrain_mode = mode
        program = game.density(M.terrain(false))
        M.terrain_mode = was
        column_programs[mode] = program
    end
    local y = math.floor(top)
    local lowest = y - COLUMN_REACH
    while y > lowest and program:at(x + 0.5, y + 0.5, z + 0.5, seed) <= 0 do
        y = y - COLUMN_STEP
    end
    if y <= lowest then
        return nil
    end
    for yy = y + COLUMN_STEP - 1, y + 1, -1 do
        if program:at(x + 0.5, yy + 0.5, z + 0.5, seed) > 0 then
            return yy
        end
    end
    return y
end

return M
