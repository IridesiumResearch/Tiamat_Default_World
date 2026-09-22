-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- The seas: where they are, and the level each stands at.
--
-- The decision (2026-09-15): "Do what you think is best with the sea
-- sizing. Obviously we will have to terrace the seas, and they can be a lot
-- longer than they are wide. Whatever the numbers say is most natural. Two
-- thirds land, one third sea."
--
-- THE NUMBERS. The world's surface is a dome, SUMMIT - DROP * u * (2 - u)
-- with u = r^2 / R^2: its slope is 4 * DROP * r * (1 - u) / R^2, never more
-- than 6.5% (at r = 34 km) and never under 3.9% outside the cold core. A
-- flat sea a kilometre across the slope has forty to sixty-five blocks of
-- dome between its two shores. ALONG a ring the dome is level. So:
--
--   * Seas run along the rings, as long arcs — tens of kilometres — in
--     LANES of a set radius and width, which is the world's own idiom (the
--     catalogue's Long Shore is a ring).
--   * Across a lane the sea is TERRACED: the dome's height is quantised in
--     steps of STEP km, and every pool stands at one of those levels, so a
--     sea three to five kilometres wide is three to six pools stepping down
--     outward, each level, with a SILL of land between — a strip of ground
--     lifted above the upper pool, dropping a step to the lower. The steps
--     are circles of constant radius; every sea shares them.
--   * The level of a pool is the dome's height at its inner edge less half
--     a step: the ground at the inner shore stands half a step over the
--     water (cliffs), at the outer shore half a step under it (a rim the
--     terrain lifts). Off the spawn's plain the world's relief is a hundred
--     and fifty blocks either way, far more than that; so within FADE
--     blocks of a shore the relief and the ring's own terms fade out and
--     the ground converges to the dome, and the coast's own face and shelf
--     take over the last few dozen blocks.
--   * A third of the world: the lanes' area, times the arcs' share of each
--     lane (two noises' positive regions, three quarters), less the sills.
--     Measured headless and tuned (`tdw.seas.measure`).
--   * None in the cold core — the alpine map and the Frozen Wastes are not
--     built for a shore — and none across the Glass Waste, the world's dry
--     band, whose terrain program is the heaviest in the world and could
--     not carry the shore's terms beside its own.
--
-- THE MAPS. Two, 1024 samples a side at MAP_SCALE blocks, filled once when
-- the world opens (`register_on_world_init`, as the alpine's are):
--   `sea_dist`  the signed distance to the nearest shore, blocks, positive
--               at sea, clamped to +/-DIST_FAR; bilinear between samples,
--               so a shore is a smooth line at the map's scale, with the
--               bays and headlands under that added by noises in the
--               programs (`M.d`).
--   `sea_level` the pool's level, km over Y0: the quantised dome. Defined
--               everywhere (the level the nearest pool at this radius would
--               have), so the terrain can read it on land too.
--   `sea_rel`   the same level over the DOME, km: what the terrain wants,
--               and the dome is thirty-one operations a read, so it is
--               paid once here rather than three times in every program.
-- A density program cannot quantise, and a lane is a band of the radius
-- with the arcs a noise cuts from it — forty-odd steps and five lanes are
-- six hundred operations, which a map pays once and a program reads in two.
--
-- THE SILLS are in the map, and wide: a strip of land SILL_HALF blocks
-- either side of a step circle, wider than two samples, so no sill is ever
-- missed between them (a missed sill is two pools sixty blocks apart with
-- nothing between). The level map holds the UPPER pool's level across the
-- whole strip — its step is at the strip's outer edge, not the circle —
-- so the sill stands at the upper level plus a beach all the way across
-- (the shore's floor, coastal_cliffs.lua), and the map's one-sample ramp
-- from the upper level to the lower lies just outside the strip, in the
-- lower pool: there the seabed follows it down, sixty blocks over a
-- hundred, a bank into the lower pool. The first cut had sills sixty
-- blocks wide as terms of the radius in every program with the ramp
-- inside them, and the water flooded the land beside them up to the
-- ramp's error — thirty blocks — with the woodland's trees under it.
--
-- THE WATER is the engine's terraced fluid (`fill_fluid_terraced`), its
-- level the map's level quantised DOWN in the program (`M.fluid_level`):
-- on the ramp the water is the lower pool's, and stops where the bank
-- rises out of it.

local shape = tdw.shape
local n = shape.node
local M = {}
tdw.seas = M

local R = shape.R_DISC                                  -- km
local R2 = R * R
local KM = 1000.0

-- The terrace: the step between pool levels, and where a level sits.
M.STEP = 0.060                                          -- km: sixty blocks a step
M.SEA_DROP = M.STEP / 2                                 -- km under the dome at a pool's inner edge
-- The lanes: centre radius and width, km. Between them the land. The
-- first is the temperate ring's, short of the Ember Ridge; the
-- second straddles the Verdant Belt's outer edge (a lane through the
-- belt's middle drowned most of the rainforest, 2026-09-15); the rest run
-- out across the Long Shore to the Hem. The Glass Waste (24.8 to 28.3 km)
-- and the cold core have none.
M.LANES = {
    { r = 17.7, w = 2.8 },                              -- the temperate ring's: 16.3 to 19.1 km
    { r = 21.9, w = 1.8 },                              -- the Ember Ridge's (2026-09-16): 21.0 to 22.8, its outer shore cut by the Glass Waste's keep-out at 22.9; the Cinder Coast (3.5)
    { r = 36.8, w = 5.4 },                              -- 34.1 to 39.5, off the rainforest
    { r = 44.8, w = 7.4 },
    { r = 53.4, w = 7.2 },
}
-- The arcs: where either of two slow noises is positive, read through the
-- signed contour so the map holds a distance. Nine kilometres of feature.
local ARC_FREQ, ARC_OCTAVES = 1 / 9000, 2
-- A lane's edges wander in and out by this much of u (a couple of hundred
-- blocks), on a slow noise, so no shore is a circle.
local WOBBLE_FREQ, WOBBLE_U = 1 / 5200, 0.004
-- Bays and headlands at the map's scale, blocks either way.
local BAYS_FREQ, BAYS_OCTAVES, BAYS_AMP = 1 / 700, 2, 90.0
-- The shore's detail under the map's scale, added in the programs: the
-- coast's own numbers (bites of a dozen blocks, crenellations of two).
local FINE_DETAIL = { { 1 / 150, 3, 24.0 }, { 1 / 9, 2, 5.0 } }
-- The map's clamp. Past the shore's reach (FADE + 20 = 920 blocks): at 400
-- (until 2026-09-15) EVERY land chunk read as within reach of a shore, so
-- the whole of every ring in a sea mode ran the shore program, and
-- `near()` — which lifts the river trough out of reach toward a shore —
-- never fell under 0.56: no river anywhere in those modes had its valley,
-- only its bed painted on the uplands, with a 27-block step where a sea
-- mode met one that is not.
M.DIST_FAR = 1100.0
M.SILL_HALF = 130.0                                     -- blocks: a sill's land either side of its circle: more than a map sample
M.PLAIN_W = 130.0                                       -- blocks: inland of any shore the ground keeps to the level plus a beach this far (a sill, whole)
M.FADE = 900.0                                          -- blocks: past PLAIN_W the floor falls away from the level over this; the rivers stop over it
M.FLOOR_KM = 0.45                                       -- km the floor falls to over FADE: deeper than any relief low, a one-in-two slope
M.BEACH = 0.002                                         -- km: the lifted ground stands this over the level
-- The ceiling (2026-09-17, "a cliff behind it that is about 4x too tall"):
-- the floor lifts low ground to a beach, and nothing held high ground DOWN,
-- so wherever the world's relief stood a hill at a pool the coast was a
-- face as tall as the hill — a fifth of all shores over sixty blocks, up
-- to two hundred. Land at a shore now stands at most CLIFF_H over the
-- level for CLIFF_FLAT blocks inland, the ceiling rising CLIFF_RISE over
-- CLIFF_FADE past that (one in two), so a hill comes down to the sea as a
-- slope and meets it as a cliff of forty blocks at most.
-- 2026-09-17, from the window: the bank read as "weirdly ramp like" — a
-- 1-in-2 slope held for nine hundred blocks is a plane, and a gentle plane
-- in blocks is a staircase of wide terraces. The climb is twice as steep
-- now (1 in 1.1, over 450 blocks), and the ceiling's own height wanders
-- along the coast (CLIFF_WANDER on a slow noise), so a shore is a low
-- headland in one place and a high bluff in the next rather than one
-- height everywhere.
M.CLIFF_H = 0.040
M.CLIFF_FLAT = 60.0
M.CLIFF_FADE = 450.0
M.CLIFF_RISE = 0.45
M.CLIFF_WANDER_FREQ, M.CLIFF_WANDER = 1 / 900, 0.030    -- km: +/-15 blocks of headland and bay, at the map's scale
-- **The cap gives** (2026-09-17): a hard cap shears a hill to a surface of
-- its own, which reads as a ramp however it is roughened. The ceiling
-- carries SOFT of however far the world's RELIEF stands over it, so the
-- ground it cuts keeps the hill's broad shape while a cliff stays a
-- fraction of the hill's height. It is done in the MAP, so the terrain
-- programs pay nothing for it — they are at 994 and 1,004 of 1,024, and a
-- cap that gives INSIDE a program would need the land's height twice,
-- five hundred operations, which is engine-asks 30.
M.CLIFF_SOFT = 0.35
M.WATER_INLAND = 80.0                                   -- blocks past the shoreline the sea's water may lie, where there is room under its level
M.SHELF_END = 130.0                                     -- blocks out: the coast's shelf ends, the ocean's floor begins...
M.DEEP_FROM = 200.0                                     -- ...and is the whole floor from here
-- Where a sea may not be.
local U_MIN = 0.06                                      -- past the cold core and the frost ring's blend: r = 14.4 km
local GLASS_MARGIN = 0.006                              -- past the Glass Waste and its cross-fades either side
local SPAWN_KEEP = 700.0                                -- blocks: the spawn's plain stays dry
local RIM_KEEP_U = (57.0 / 59.0) ^ 2                    -- the fourth lane's outer shore, and no further

local MAP_SIDE, MAP_SCALE = 1024, 116                   -- 118,784 blocks: the disc is 118,000 across
local MAP_ORIGIN = -(MAP_SIDE * MAP_SCALE) // 2
local MAP_SEED = 2207
local function map_spec(name)
    return { name = name, side = MAP_SIDE, scale = MAP_SCALE, origin_x = MAP_ORIGIN, origin_z = MAP_ORIGIN }
end

-- ------------------------------------------------------------ the steps

-- The step circles: u_j where the dome is SUMMIT - j * STEP, so a pool
-- between u_j and u_(j+1) stands at SUMMIT - j * STEP - SEA_DROP.
M.STEPS = {}
do
    local j = 1
    while j * M.STEP < shape.DOME_DROP do
        local u = 1.0 - math.sqrt(1.0 - j * M.STEP / shape.DOME_DROP)
        local r = R * math.sqrt(u)
        M.STEPS[j] = { u = u, r = r, level = shape.SUMMIT - j * M.STEP - M.SEA_DROP,
            blocks_per_u = R2 / (2.0 * r) * KM }              -- dr = R^2 du / 2r
        j = j + 1
    end
end
-- The lanes in u, and each lane's steps.
for k, lane in ipairs(M.LANES) do
    local lo, hi = lane.r - lane.w / 2, lane.r + lane.w / 2
    lane.u = (lane.r / R) ^ 2
    lane.u_lo, lane.u_hi = (lo / R) ^ 2, (hi / R) ^ 2
    lane.half_blocks = lane.w / 2 * KM
    lane.blocks_per_u = R2 / (2.0 * lane.r) * KM
    lane.steps = {}
    for _, step in ipairs(M.STEPS) do
        if step.u > lane.u_lo - 2 * WOBBLE_U and step.u < lane.u_hi + 2 * WOBBLE_U then
            lane.steps[#lane.steps + 1] = step
        end
    end
    lane.index = k
end

-- Whether seas are in this world: the ring world, or the dev switch's
-- world of the coast or the ocean.
function M.on()
    local only = tdw.config.everywhere
    return only == nil or only == "coastal_cliffs" or only == "deep_ocean"
end

-- ------------------------------------------------------------ the maps

local u = shape.sub.u

-- The level, km over Y0: a staircase down the radius, each step at the
-- outer edge of its sill's strip, so the strip is the upper pool's.
local function level_field()
    local acc = n.const(shape.SUMMIT - M.SEA_DROP)
    for _, step in ipairs(M.STEPS) do
        local at = step.u + M.SILL_HALF / step.blocks_per_u
        acc = n.sub(acc, n.mul(n.clamp(n.mul(n.sub(u(), n.const(at)), n.const(1e7)), 0.0, 1.0), n.const(M.STEP)))
    end
    return acc
end

-- The signed distance to the shore, blocks: the lanes (a radial band each,
-- their edges wobbled), cut to arcs by the noises, bays and headlands on
-- that, and the places a sea may not be taken out.
local function dist_field(everywhere)
    local arc = n.max(n.contour("sea_arc_a", ARC_FREQ, ARC_OCTAVES, true), n.contour("sea_arc_b", ARC_FREQ, ARC_OCTAVES, true))
    local radial = nil
    local lanes = M.LANES
    if everywhere then
        -- The dev switch's world: one lane through the spawn, whole.
        local r = math.sqrt(shape.PLAIN_U) * R
        lanes = { { u = shape.PLAIN_U, half_blocks = 1.6 * KM, blocks_per_u = R2 / (2.0 * r) * KM } }
        arc = n.const(M.DIST_FAR)
    end
    for _, lane in ipairs(lanes) do
        local uw = n.add(u(), n.noise("sea_wobble", WOBBLE_FREQ, 2, 2.0 * WOBBLE_U))
        local band = n.sub(n.const(lane.half_blocks), n.mul(n.abs(n.sub(uw, n.const(lane.u))), n.const(lane.blocks_per_u)))
        radial = radial and n.max(radial, band) or band
    end
    local d = n.min(radial, arc)
    d = n.add(d, n.noise("sea_bays", BAYS_FREQ, BAYS_OCTAVES, BAYS_AMP))
    -- The sills: a strip of land on every step circle a sea can reach.
    for _, step in ipairs(M.STEPS) do
        if step.u > U_MIN - 0.01 then
            d = n.min(d, n.sub(n.mul(n.abs(n.sub(u(), n.const(step.u))), n.const(step.blocks_per_u)), n.const(M.SILL_HALF)))
        end
    end
    -- Not in the cold core.
    d = n.min(d, n.mul(n.sub(u(), n.const(U_MIN)), n.const(R2 / (2.0 * math.sqrt(U_MIN) * R) * KM)))
    if not everywhere then
        -- Not across the Glass Waste and its cross-fades.
        local reach = shape.reach() + GLASS_MARGIN
        local lo, hi = shape.GLASS_U[1] - reach, shape.GLASS_U[2] + reach
        local mid, half = (lo + hi) / 2, (hi - lo) / 2
        d = n.min(d, n.mul(n.sub(n.abs(n.sub(u(), n.const(mid))), n.const(half)), n.const(R2 / (2.0 * math.sqrt(mid) * R) * KM)))
        -- Not against the rim (2026-09-16): the Rime Wall's drifts start two
        -- hundred blocks in from an edge that wanders to 57.8 km.
        d = n.min(d, n.mul(n.sub(n.const(RIM_KEEP_U), u()), n.const(R2 / (2.0 * math.sqrt(RIM_KEEP_U) * R) * KM)))
        -- Not on the spawn's plain: a disc, its distance linearised as the
        -- coast's island was.
        local dx = n.sub(n.X(), n.const(shape.SPAWN_X + 0.5))
        local dz = n.sub(n.Z(), n.const(shape.SPAWN_Z + 0.5))
        local d2 = n.add(n.mul(dx, dx), n.mul(dz, dz))
        d = n.min(d, n.mul(n.sub(d2, n.const(SPAWN_KEEP * SPAWN_KEEP)), n.const(1.0 / (2.0 * SPAWN_KEEP))))
    end
    return n.clamp(d, -M.DIST_FAR, M.DIST_FAR)
end

tdw.on_world_init(function()
    local only = tdw.config.everywhere
    local everywhere = only == "coastal_cliffs" or only == "deep_ocean"
    local dist = game.map(map_spec("sea_dist"))
    local level = game.map(map_spec("sea_level"))
    local rel = game.map(map_spec("sea_rel"))
    local fill = { y = 0.0, seed = MAP_SEED }
    dist:fill(shape.compile("sea.dist_fill", dist_field(everywhere)), fill)
    level:fill(shape.compile("sea.level_fill", level_field()), fill)
    rel:fill(shape.compile("sea.rel_fill", n.sub(level_field(), shape.dome_node())), fill)
    -- The shore's floor and ceiling, km over the dome, from the two maps
    -- above: each a map read in the programs where the floor was fourteen
    -- operations of the distance and the level.
    local function inland(from, over)
        return n.clamp(n.mul(n.add(n.mul(M.d_map(), n.const(-1.0)), n.const(-from)), n.const(1.0 / over)), 0.0, 1.0)
    end
    local floor = game.map(map_spec("sea_floor"))
    floor:fill(shape.compile("sea.floor_fill", n.sub(n.add(M.rel(), n.const(M.BEACH)),
        n.mul(inland(M.PLAIN_W, M.FADE), n.const(M.FLOOR_KM)))), fill)
    local ceiling = game.map(map_spec("sea_ceiling"))
    local function base_ceiling()
        return n.add(n.add(n.add(M.rel(), n.const(M.CLIFF_H)),
            n.mul(inland(M.CLIFF_FLAT, M.CLIFF_FADE), n.const(M.CLIFF_RISE))),
            n.noise("cliff_wander", M.CLIFF_WANDER_FREQ, 2, M.CLIFF_WANDER, shape.HUMIDITY_STRETCH))
    end
    -- The base, plus SOFT of what the relief stands over it: the hill's own
    -- shape kept. `relief_node` is km over the dome, as the ceiling is.
    ceiling:fill(shape.compile("sea.ceiling_fill",
        n.add(base_ceiling(),
            n.mul(n.max(n.sub(shape.relief_node(), base_ceiling()), n.const(0.0)), n.const(M.CLIFF_SOFT)))), fill)
    game.log(string.format("tiamat_default_world seas: maps built, %d samples a side at %d blocks; %d lanes, %d steps of %.0f blocks",
        MAP_SIDE, MAP_SCALE, #M.LANES, #M.STEPS, M.STEP * KM))
end)

-- ------------------------------------------------------------ the nodes

-- The map nodes, fetched when a program is compiled (after the pre-pass).
function M.d_map()
    return { op = "map", map = game.map(map_spec("sea_dist")) }
end
function M.level()
    return { op = "map", map = game.map(map_spec("sea_level")) }
end
-- The distance with the shore's fine detail: what the face and the shelf read.
function M.d()
    local acc = M.d_map()
    for i, detail in ipairs(FINE_DETAIL) do
        acc = n.add(acc, n.noise("sea_fine" .. i, detail[1], detail[2], detail[3]))
    end
    return acc
end
-- 1 at the shore and at sea, 0 FADE blocks inland: how much of the land's
-- own shape is left.
function M.near()
    return n.clamp(n.add(n.mul(M.d_map(), n.const(1.0 / M.FADE)), n.const(1.0)), 0.0, 1.0)
end
-- The pool's level over the dome, km: its own map.
function M.rel()
    return { op = "map", map = game.map(map_spec("sea_rel")) }
end
-- The shore's floor and ceiling, km over the dome (see M.CLIFF_H).
function M.floor()
    return { op = "map", map = game.map(map_spec("sea_floor")) }
end
function M.ceiling()
    return { op = "map", map = game.map(map_spec("sea_ceiling")) }
end
-- The water's level, world y: the map's level quantised DOWN to the
-- steps — the greatest level at or under the sample's value (a block of
-- slack for the float), so on a sill's ramp the water is the lower
-- pool's, never a strip of the upper pool's standing in the lower.
function M.fluid_level()
    local level = M.level()
    local acc = n.const(shape.SUMMIT - M.SEA_DROP - M.STEP)
    for _, step in ipairs(M.STEPS) do
        acc = n.sub(acc, n.mul(n.clamp(n.mul(n.sub(n.const(step.level - 0.001), level), n.const(1e5)), 0.0, 1.0), n.const(M.STEP)))
    end
    return n.add(n.mul(acc, n.const(KM)), n.const(shape.Y0))
end
-- Another biome's field kept out of the sea: positive only BLOCKS_IN inland.
function M.exclude(field, blocks_in)
    return n.min(field, n.sub(n.const(-blocks_in), M.d_map()))
end
shape.sea_exclude = M.exclude

-- ------------------------------------------------------------ per chunk

local DIST = nil
local function dist_program()
    DIST = DIST or shape.compile("sea.dist", M.d_map())
    return DIST
end
-- What a chunk is to the seas, from the map's bounds over it: "deep" past
-- the shelf, "shore" within FADE of a shore, nil out of their reach.
-- Whether any of a chunk may be more than `blocks` out to sea: for the
-- deep biomes, whose floor starts at the shelf's end. A chunk across that
-- line is a shore chunk by `class`, and until 2026-09-16 the deep floor in
-- it was painted by nobody (plain soil in a ring round every shelf).
function M.reaches(pos, blocks)
    return dist_program():bounds(pos).high > blocks
end
function M.class(pos)
    local b = dist_program():bounds(pos)
    if b.low > M.SHELF_END - 30.0 then
        return "deep"
    elseif b.high > -(M.FADE + 20.0) then
        return "shore"
    end
    return nil
end
-- The distance at a place, for the HUD and `/tp`.
function M.at(x, z, seed)
    return dist_program():at(x + 0.5, 0.0, z + 0.5, seed)
end

-- The water: the terraced fluid at the pool's level, within the shore.
local WATER = "tiamat_default_world:water"
local FLUID = nil
function M.fill(buf, pos)
    if not buf.fill_fluid_terraced then
        return
    end
    -- `within` reaches WATER_INLAND blocks past the shoreline (2026-09-18):
    -- the coast's terrain rises from the sea floor to the land on the LAND
    -- side of the line (the face, four blocks; a beach, thirty-four), and
    -- the notch, sea caves and tunnels are cut inland of it, so a `within`
    -- that stopped at the line left all of that dry under the sea's level —
    -- and the sea stood against it as a wall of water, up to sixteen blocks
    -- tall. Water goes only where there is room under the level, so past
    -- the line it fills that and nothing on dry land.
    FLUID = FLUID or {
        level = shape.compile("sea.level", M.fluid_level()),
        within = shape.compile("sea.within", n.add(M.d(), n.const(M.WATER_INLAND))),
    }
    -- The pack's ice first (biomes/pack_ice.lua): the water takes the room
    -- it leaves.
    if tdw.pack_ice_into then
        tdw.pack_ice_into(buf, pos)
    end
    tdw.fill_terraced(buf, { level = FLUID.level, within = FLUID.within, fluid = WATER }, "sea")
end

-- Which sea biome a place is, for the HUD: the coast within the shore
-- band and over the shelf, the ocean past it; nil on land. Cached by
-- eight-block square, as the cold biomes' tests are.
local zone_cache, zone_cached = {}, 0
function M.zone(x, z)
    if not M.on() then
        return nil
    end
    local seed = game.world_seed or tdw.seed
    if seed == nil then
        return nil
    end
    local key = (x // 8) * 65536 + (z // 8)
    local hit = zone_cache[key]
    if hit == nil then
        if zone_cached > 20000 then
            zone_cache, zone_cached = {}, 0
        end
        local d = M.at(x, z, seed)
        local shore = (tdw.cinder_zone and tdw.cinder_zone(x, z)) or (tdw.reef_zone and tdw.reef_zone(x, z)) or "coastal_cliffs"
        -- The seas with names of their own (2026-09-16): the pack over the
        -- fourth lane's water, deep or not; the kelp over the third's shelf.
        local pack = d > 0 and tdw.pack_zone and tdw.pack_zone(x, z)
        local kelp = d > 0 and tdw.kelp_zone and tdw.kelp_zone(x, z)
        -- The deep floor's province, and the reef lane's wet-side shores.
        local deep = d > M.SHELF_END and ((tdw.abyss_zone and tdw.abyss_zone(x, z)) or "deep_ocean")
        local mangrove = tdw.mangrove_at and tdw.mangrove_at(x, z, d)
        hit = pack or deep or kelp or mangrove or (d > -30.0 and shore) or false
        zone_cache[key] = hit
        zone_cached = zone_cached + 1
    end
    return hit or nil
end

-- A place whose shore distance is between `lo` and `hi`, for `/tp`: out
-- from the player's heading round the compass, across every lane in
-- forty-block steps, the nearest lane first. `u_lo` and `u_hi` narrow it
-- to one band of the radius, which is how the reef's lane is found and
-- the other three lanes are not (2.4).
function M.locate(px, pz, seed, lo, hi, u_lo, u_hi, skip, accept)
    -- `skip`: a range of u, or a list of them.
    local skips = {}
    if skip and type(skip[1]) == "table" then
        skips = skip
    elseif skip then
        skips = { skip }
    end
    local function skipped(a, b)
        for _, s in ipairs(skips) do
            if a >= s[1] and b <= s[2] then
                return true
            end
        end
        return false
    end
    local lanes = {}
    local pu = (px * px + pz * pz) * 1e-6 / R2
    for _, lane in ipairs(M.LANES) do
        local inside = u_lo == nil or (lane.u_hi >= u_lo and lane.u_lo <= u_hi)
        if skipped(lane.u_lo, lane.u_hi) then
            inside = false
        end
        if inside then
            lanes[#lanes + 1] = { lane = lane, away = math.max(lane.u_lo - pu, pu - lane.u_hi, 0.0) }
        end
    end
    table.sort(lanes, function(a, b) return a.away < b.away end)
    local r0 = math.sqrt(px * px + pz * pz)
    local hx, hz = 1.0, 0.0
    if r0 > 1 then hx, hz = px / r0, pz / r0 end
    for _, entry in ipairs(lanes) do
        local lane = entry.lane
        for k = 0, 15 do
            local d = tdw.schem.DIR16[(k % 16) + 1]
            local ax = hx * d[1] - hz * d[2]
            local az = hz * d[1] + hx * d[2]
            local from, to = (lane.r - lane.w / 2 - 0.3) * KM, (lane.r + lane.w / 2 + 0.3) * KM
            for r = from, to, 40.0 do
                local x, z = math.floor(ax * r), math.floor(az * r)
                local u = (x * x + z * z) * 1e-6 / R2
                local ok = u_lo == nil or (u >= u_lo and u <= u_hi)
                if skipped(u, u) then
                    ok = false
                end
                if ok then
                    local dist = M.at(x, z, seed)
                    if dist >= lo and dist <= hi and (accept == nil or accept(x, z)) then
                        return x, z
                    end
                end
            end
        end
    end
    return nil
end

-- How much of the disc is sea, sampled: `tdw.seas.measure(seed)`.
function M.measure(seed, count)
    count = count or 20000
    local rng = game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "sea_measure")
    local sea, land = 0, 0
    for _ = 1, count do
        -- Uniform over the disc: r = R sqrt(t).
        local t = rng:below(1000000) / 1000000.0
        local a = rng:below(1000000) / 1000000.0 * 2.0 * math.pi
        local r = R * KM * math.sqrt(t)
        local x, z = r * math.cos(a), r * math.sin(a)
        if M.at(x, z, seed) > 0 then sea = sea + 1 else land = land + 1 end
    end
    return sea / (sea + land)
end

return M
