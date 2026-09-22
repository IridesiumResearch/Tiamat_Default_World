-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 2.4 Coral-Fringed Shallows: the reef and its lagoon, on the second sea
-- lane — the warm water between the Verdant Belt and the Long Shore.
--
-- The brief (2026-09-15):
--
--   Shallow, sunlit lagoon flats (1 to 5 blocks deep) protected by an outer
--   barrier reef crest that drops steeply into deep open water. Flat,
--   shallow sandbars are cut by narrow surge channels and tidal gutters.
--   Surface: white sand, gravel, calcite, and rare pumice; reef blocks
--   encrusted in vibrant pink algae*.
--   Trees: absent across the open water; very rare leaning palms,
--   exclusively on dry sandspits or sand islets breaching the tide.
--   Corals: medium elkhorn, wide horizontal table corals, dense rounded
--   brain coral domes, tinted magenta*, cyan* and amber*.
--   Drainage: carved jagged surge channels and undercut reef shelves; the
--   inner lagoons stay protected.
--   Accents: swim-through coral arches, hollow limestone reef heads
--   (bomboras), tide-exposed sand flats, dense clusters of sea anemones
--   lining the reef drop-off walls.
--
-- WHERE, and how it shares the shore's programs. Every shore in the world
-- is `shape.coast_shore` (biomes/coastal_cliffs.lua): the land's own ground
-- on the inside, the shelf's floor on the outside, the face between them.
-- The reef does not get a terrain mode of its own — the shore modes are
-- already 797 and 868 operations of the thousand — so it is a REPLACEMENT
-- FOR THE SHELF'S FLOOR inside its band of the radius, blended in by
-- `shape.reef_weight()` and gone outside it. The band is the second lane's
-- (34.1 to 39.5 km), which is where the Goldwater dunes and the Jungle
-- meet the sea; the other three lanes keep the Coastal Cliffs.
--
-- The lagoon's floor is three and a half blocks under the pool's level,
-- give or take two; the barrier crest stands ninety blocks out, just
-- inside the shelf's own ledge break (DROP_AT, 100 blocks), so past the
-- crest the coast's ledge drops thirty blocks to the shelf's foot and the
-- Deep Ocean takes it from there. That is the brief's "drops steeply into
-- deep open water", for no terms of its own.
--
-- New nodes, asked for by name: pink algae, and the three coral tints.
-- White sand, calcite and the anemones are new because nothing registered
-- stands in for them; the gravel is `gravel`, the pumice the Ember
-- Ridge's, the palms' timber the river's willow and their fronds the oak's.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local seas = tdw.seas
local ID = "coral_fringed_shallows"

-- ------------------------------------------------------------ the band

-- The lane this biome is: u = (r/R)^2, and the cross-fade at each edge.
-- 0.30 to 0.466 is 32.3 to 40.3 km — the second lane (34.1 to 39.5) with
-- room either side, and short of the third lane's inner edge (u 0.485).
local REEF_U = { 0.30, 0.466 }
local REEF_FADE_U = 0.010

-- The reef's profile, all in km over the pool's level (negative is under
-- water), all of it a function of the distance OUT from the coastline.
local LAGOON_D = 0.0035                                  -- the flats: three and a half blocks under the level
local VARY_FREQ, VARY_AMP = 1 / 40, 0.0016               -- give or take a block and a half: one to five blocks deep
local CREST_AT, CREST_W, CREST_H = 90.0, 20.0, 0.0042    -- the barrier: a tent on the distance, its top about at the level
local CREST_END, CREST_FADE = 116.0, 14.0                -- the blend's outer edge: past it the shelf's own ledge drops away
local BAR_FREQ, BAR_MIN, BAR_H = 1 / 55, 0.30, 0.0058    -- sandbars, and the rare spit that breaches the tide
local SURGE_FREQ, SURGE_W, SURGE_D = 1 / 45, 1.4, 0.0042 -- surge channels: narrow, jagged, cut through the flats and the crest
local GUTTER_FREQ, GUTTER_W = 1 / 17, 0.8                -- tidal gutters: gravel runnels in the sand, a surface, not a cut

-- The surface.
local GRAVEL_FREQ, GRAVEL_MIN = 1 / 14, 0.26             -- gravel patches in the sand
local PUMICE_FREQ, PUMICE_MIN = 1.3, 0.44                -- rare pumice pebbles
local ALGAE_FREQ, ALGAE_MIN = 1 / 9, -0.16               -- pink algae over most of the reef rock
local HEAD_FREQ, HEAD_MIN = 1 / 26, 0.22                 -- reef heads standing out of the lagoon floor

-- The structures: cell, share of squares, salt.
local ELKHORN_CELL, ELKHORN_SQUARES = 5, 0.35
local TABLE_CELL, TABLE_SQUARES = 9, 0.30
local BRAIN_CELL, BRAIN_SQUARES = 7, 0.35
local ARCH_CELL, ARCH_SQUARES = 40, 0.25
local BOMBORA_CELL, BOMBORA_SQUARES = 48, 0.30
local PALM_CELL, PALM_SQUARES = 40, 0.35
local ANEMONE_FREQ, ANEMONE_MIN = 1.4, 0.10              -- dense on the drop-off wall

-- ------------------------------------------------------------ the shape

-- Blocks out to sea, the sea map's own distance: 0 at the coastline.
local function out()
    return n.clamp(seas.d_map(), 0.0, seas.DIST_FAR)
end
-- How far over the pool's level a place is, km: negative under water. The
-- map's distance says a place is at sea; only this says it is WET, and a
-- sandspit or the reef crest at high water is neither.
local function over_sea()
    return n.sub(n.mul(n.sub(n.Y(), n.const(shape.Y0)), n.const(shape.SCALE)), seas.level())
end
-- 1 across the lane, 0 outside it, fading over REEF_FADE_U at each edge.
-- `shape.ring` is `half - |u - mid|` on the WOBBLED radius, which is the
-- distance in u to the nearer edge: one clamp turns it into the weight,
-- and the lane's edges wander like every other ring's.
local function band()
    return n.clamp(n.mul(shape.ring(REEF_U[1], REEF_U[2]), n.const(1.0 / REEF_FADE_U)), 0.0, 1.0)
end
-- 1 on the crest's line, 0 CREST_W blocks either side of it.
local function crest_w()
    return n.clamp(n.add(n.mul(n.abs(n.sub(out(), n.const(CREST_AT))), n.const(-1.0 / CREST_W)), n.const(1.0)), 0.0, 1.0)
end
-- The sandbars, and the spits that breach the tide.
local function bar_w()
    return n.clamp(n.mul(n.sub(n.noise("reef_bar", BAR_FREQ, 2, 1.0), n.const(BAR_MIN)), n.const(7.0)), 0.0, 1.0)
end
-- The surge channels, as a depth in km to take out of the flats and the
-- crest. One contour, not two: the tidal gutters are a surface below
-- (code 7) rather than a cut, because this expression goes into every
-- shore program in the world and the deepest of them is at 995 of the
-- engine's 1,024 operations.
local function cuts()
    local surge = n.clamp(n.mul(n.add(n.abs(n.contour("reef_surge", SURGE_FREQ, 2)), n.const(-SURGE_W)), n.const(-0.7)), 0.0, 1.0)
    return n.mul(surge, n.const(SURGE_D))
end
-- The gutters: where a fine contour runs across the flats.
local function gutter_w()
    return n.clamp(n.mul(n.add(n.abs(n.contour("reef_gutter", GUTTER_FREQ, 1)), n.const(-GUTTER_W)), n.const(-1.2)), 0.0, 1.0)
end

-- **The reef's floor**, km over the pool's level: the flats, the barrier
-- crest on them, the bars and spits, less the channels. The shore program
-- blends this into the shelf's own floor by the weight below.
shape.reef_band = band
function shape.reef_bed()
    local acc = n.add(n.noise("reef_vary", VARY_FREQ, 2, VARY_AMP), n.const(-LAGOON_D))
    acc = n.add(acc, n.mul(crest_w(), n.const(CREST_H)))
    acc = n.add(acc, n.mul(bar_w(), n.const(BAR_H)))
    return n.sub(acc, cuts())
end
-- 0 where the reef is — across the lane, inside the crest — and 1 outside
-- either, over the same fades. Written as an OFF gate rather than `1 - w`
-- on purpose: a subtraction from a constant holds one of the engine's
-- eight buffers through everything under it, and the shore program this
-- goes into is the deepest in the world.
local function off_gate()
    local out_of_band = n.clamp(n.mul(shape.ring(REEF_U[1], REEF_U[2]), n.const(-1.0 / REEF_FADE_U)), 0.0, 1.0)
    local past_crest = n.clamp(n.mul(n.sub(out(), n.const(CREST_END)), n.const(1.0 / CREST_FADE)), 0.0, 1.0)
    return n.max(out_of_band, past_crest)
end
-- **The reef's floor as the shore program takes it**: its own bed where it
-- is, and a kilometre under the world where it is not, so the shore takes
-- the GREATER of this and the shelf's own floor and the whole change of
-- profile costs one operation and one buffer. Inside the lane the reef's
-- flats (three and a half blocks down) stand over the shelf's terrace
-- (two to twelve), and past the crest the gate drops this away and the
-- shelf's ledge falls thirty blocks to the Deep Ocean — the brief's
-- "drops steeply into deep open water", for no terms of its own.
function shape.reef_shelf()
    return n.sub(shape.reef_bed(), off_gate())
end
-- For the coast: positive where the reef's water is NOT — outside the
-- lane, or on the land side of the coastline anywhere. The cliffs keep
-- their beach, their face and their turf along the lagoon, which is what
-- the lagoon's own fills do not paint; the sea inside the lane is the
-- reef's alone.
function shape.off_reef()
    return n.max(n.sub(n.const(0.5), band()), n.mul(seas.d_map(), n.const(-1.0)))
end
-- The lane, for `/tp`: the coast looks for a shore outside it.
tdw.reef_u = { REEF_U[1], REEF_U[2] }

tdw.biomes[ID].ring_mode = "temperate"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.calcite

-- Whether (x, z) is the reef's, for the HUD: the band alone, which is a
-- circle of the radius and needs no field and no seed.
function tdw.reef_zone(x, z)
    local only = tdw.config.everywhere
    if only then
        return only == ID and ID or nil
    end
    local u = (x * x + z * z) * 1e-6 / (shape.R_DISC * shape.R_DISC)
    local w = shape.wobble(u)
    if u >= REEF_U[1] - w and u <= REEF_U[2] + w then
        return ID
    end
    return nil
end

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local ROUGH = { rough = 0.3, blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "reef_template:" .. name)
end
local CORALS = { blocks.coral_magenta, blocks.coral_cyan, blocks.coral_amber }
local PRIORITY = {
    [blocks.coral_magenta] = 1, [blocks.coral_cyan] = 1, [blocks.coral_amber] = 1,
    [blocks.calcite] = 1, [blocks.willow_log] = 1, [game.AIR] = 2,
}

-- An elkhorn: a short trunk off the floor and three to five flattened
-- antlers climbing out of it, each forking once. Medium — four to seven
-- blocks across and about as tall.
local function elkhorn(rng, material)
    schem.record_begin()
    local base = { { 0.5, -0.8, 0.5, 0.8 }, { 0.5, 1.0, 0.5, 0.6 } }
    schem.push_path(material, base, BLIND)
    local first = rng:below(16)
    local arms = 3 + rng:below(3)
    for a = 0, arms - 1 do
        local d = schem.DIR16[(first + a * 16 // arms + rng:below(2)) % 16 + 1]
        local reach = 1.6 + rng:below(4) * 0.5
        local rise = 1.6 + rng:below(4) * 0.4
        local tip = { 0.5 + d[1] * reach, 1.0 + rise, 0.5 + d[2] * reach, 0.42 }
        schem.push_path(material, { { 0.5, 1.0, 0.5, 0.55 },
            { 0.5 + d[1] * reach * 0.55, 1.0 + rise * 0.55, 0.5 + d[2] * reach * 0.55, 0.48 }, tip }, BLIND)
        -- The fork: two flattened fingers off the tip, spread a sixteenth
        -- of a turn apart, which is what makes an elkhorn read as antlers.
        for _, turn in ipairs({ -2, 2 }) do
            local f = schem.DIR16[(first + a * 16 // arms + turn) % 16 + 1]
            schem.push_path(material, { { tip[1], tip[2], tip[3], 0.4 },
                { tip[1] + f[1] * 1.3, tip[2] + 1.0 + rng:below(3) * 0.3, tip[3] + f[2] * 1.3, 0.3 } }, BLIND)
        end
    end
    return schem.record_schematic(PRIORITY)
end

-- A table coral: a stalk and a wide flat plate on it, four to nine blocks
-- across and one thick, with a nibbled edge.
local function table_coral(rng, material)
    schem.record_begin()
    local r = 2.0 + rng:below(6) * 0.5
    local h = 1.4 + rng:below(3) * 0.4
    schem.push_path(material, { { 0.5, -0.8, 0.5, 0.7 }, { 0.5, h, 0.5, 0.55 } }, BLIND)
    schem.push_ellipsoid(material, 0.5, h + 0.5, 0.5, r, 0.42, r, { rough = 0.35, blind = true })
    return schem.record_schematic(PRIORITY)
end

-- A brain coral: a dense rounded dome, three to seven blocks across, sunk
-- a little into the floor so it sits rather than perches.
local function brain_coral(rng, material)
    schem.record_begin()
    local r = 1.5 + rng:below(6) * 0.45
    schem.push_ellipsoid(material, 0.5, r * 0.45 - 0.5, 0.5, r, r * 0.8, r * (0.85 + rng:below(4) * 0.08), ROUGH)
    return schem.record_schematic(PRIORITY)
end

-- A swim-through arch: two calcite piers and a span between them, the
-- opening cut out as air so it is clear whatever it is stamped into, and
-- coral heads on the span.
local function arch(rng)
    schem.record_begin()
    local d = schem.DIR16[rng:below(16) + 1]
    local half = 2.5 + rng:below(3) * 0.5
    local rise = 4.0 + rng:below(3) * 0.6
    local ax, az = 0.5 - d[1] * half, 0.5 - d[2] * half
    local bx, bz = 0.5 + d[1] * half, 0.5 + d[2] * half
    schem.push_path(blocks.calcite, {
        { ax, -1.5, az, 1.5 }, { ax, rise * 0.55, az, 1.1 },
        { 0.5, rise, 0.5, 1.0 },
        { bx, rise * 0.55, bz, 1.1 }, { bx, -1.5, bz, 1.5 },
    }, { rough = 0.25, blind = true })
    -- The swim-through: a tunnel of air under the span, open both ends.
    local s = schem.DIR16[(rng:below(16)) % 16 + 1]
    schem.push_path(game.AIR, {
        { 0.5 - s[1] * (half + 2.0), 0.6, 0.5 - s[2] * (half + 2.0), 1.15 },
        { 0.5 + s[1] * (half + 2.0), 0.6, 0.5 + s[2] * (half + 2.0), 1.15 },
    }, BLIND)
    for _ = 1, 2 + rng:below(2) do
        local t = (rng:below(5) - 2) * 0.5
        schem.push_ellipsoid(CORALS[rng:below(3) + 1], 0.5 + d[1] * t, rise + 1.0, 0.5 + d[2] * t,
            1.0 + rng:below(3) * 0.3, 0.8, 1.0 + rng:below(3) * 0.3, ROUGH)
    end
    return schem.record_schematic(PRIORITY)
end

-- A bombora: a hollow limestone reef head standing off the lagoon floor,
-- its top nearly at the surface, with a cave in it and a hole in the top.
local function bombora(rng)
    schem.record_begin()
    local r = 3.0 + rng:below(4) * 0.5
    local h = 2.6 + rng:below(4) * 0.4
    schem.push_ellipsoid(blocks.stone, 0.5, h - r * 0.4, 0.5, r, h, r * (0.9 + rng:below(3) * 0.1), ROUGH)
    schem.push_ellipsoid(game.AIR, 0.5, h - r * 0.5, 0.5, r - 1.4, h - 1.0, r - 1.4, BLIND)
    -- The hole in the top, and a mouth in one side.
    local d = schem.DIR16[rng:below(16) + 1]
    schem.push_path(game.AIR, { { 0.5, h - 1.0, 0.5, 0.9 }, { 0.5, h + 1.0, 0.5, 0.8 } }, BLIND)
    schem.push_path(game.AIR, { { 0.5, h - r * 0.6, 0.5, 1.0 },
        { 0.5 + d[1] * (r + 0.8), h - r * 0.6, 0.5 + d[2] * (r + 0.8), 1.0 } }, BLIND)
    for _ = 1, 2 + rng:below(3) do
        local a = schem.DIR16[rng:below(16) + 1]
        schem.push_ellipsoid(blocks.pink_algae, 0.5 + a[1] * r * 0.7, h - r * 0.2 + rng:below(3) * 0.6, 0.5 + a[2] * r * 0.7,
            1.0, 0.7, 1.0, ROUGH)
    end
    return schem.record_schematic(PRIORITY)
end

-- A leaning palm, for a sandspit: a bowed willow-wood stem and a head of
-- fronds, the same build as the river's palms, leaning harder.
local function palm(rng)
    schem.record_begin()
    local tall = 7 + rng:below(5)
    local d = schem.DIR16[rng:below(16) + 1]
    local stem = {}
    for i = 0, 4 do
        local t = i / 4
        local bow = t * t * (2.2 + rng:below(3) * 0.4)
        stem[#stem + 1] = { 0.5 + d[1] * bow, -1.5 + t * (tall + 1.5), 0.5 + d[2] * bow, 0.62 - 0.26 * t }
    end
    schem.push_path(blocks.willow_log, stem, BLIND)
    local tip = stem[#stem]
    local fronds = 7 + rng:below(4)
    for f = 1, fronds do
        local w = schem.DIR16[(f * 16 // fronds + rng:below(2)) % 16 + 1]
        local reach = 3.0 + rng:below(3) * 0.5
        schem.push_path(blocks.oak_leaves, {
            { tip[1], tip[2], tip[3], 0.3 },
            { tip[1] + w[1] * reach * 0.45, tip[2] + 1.1, tip[3] + w[2] * reach * 0.45, 0.34 },
            { tip[1] + w[1] * reach, tip[2] - 0.9, tip[3] + w[2] * reach, 0.2 },
        }, BLIND)
    end
    return schem.record_schematic(PRIORITY)
end

-- Cut once, at the first reef chunk: a coral is thousands of cell tests,
-- and the registration window's budget is far smaller than a generator
-- call's.
local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out_ = { elkhorn = {}, tables = {}, brains = {}, arches = {}, bomboras = {}, palms = {} }
    if not game.schematic_shapes then
        game.log("tiamat_default_world reef: no game.schematic_shapes in this engine; no corals")
        BUILT = out_
        return out_
    end
    for i = 1, 6 do
        local material = CORALS[(i - 1) % 3 + 1]
        out_.elkhorn[i] = elkhorn(rng_for("elkhorn:" .. i), material)
        out_.tables[i] = table_coral(rng_for("table:" .. i), CORALS[i % 3 + 1])
        out_.brains[i] = brain_coral(rng_for("brain:" .. i), CORALS[(i + 1) % 3 + 1])
    end
    for i = 1, 3 do out_.arches[i] = arch(rng_for("arch:" .. i)) end
    for i = 1, 3 do out_.bomboras[i] = bombora(rng_for("bombora:" .. i)) end
    for i = 1, 4 do out_.palms[i] = palm(rng_for("palm:" .. i)) end
    local parts, total = {}, 0
    for key, list in pairs(out_) do
        local sum = 0
        for _, one in ipairs(list) do sum = sum + one:len() end
        parts[#parts + 1] = string.format("%d %s (%d blocks)", #list, key, sum)
        total = total + sum
    end
    game.log("tiamat_default_world reef: cut " .. table.concat(parts, ", "))
    BUILT = out_
    return out_
end

-- ------------------------------------------------------------ the fills

tdw.build_biome(ID, function(ctx)
    -- Where this biome paints: inside the lane, and only at sea — from the
    -- coastline out to the foot of the ledge. The sea map's distance says
    -- both, so there is no ring mask and no humidity half here.
    local function reef_only(field)
        field = n.min(field, n.sub(band(), n.const(0.5)))
        -- Not the Mangrove Coast's strip on the wet side (3.10).
        return shape.off_mangrove and n.min(field, shape.off_mangrove()) or field
    end
    local function at_sea()
        return n.min(seas.d_map(), n.sub(n.const(seas.SHELF_END + 20.0), out()))
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    -- The reef rock: the crest, and the heads that stand out of the lagoon.
    local function reef_rock()
        return n.max(n.sub(crest_w(), n.const(0.25)),
            n.sub(n.noise("reef_head", HEAD_FREQ, 2, 1.0), n.const(HEAD_MIN)))
    end
    local conditions = {
        -- 1: the flats: white coral sand.
        n.const(1.0),
        -- 2: gravel in patches over them.
        n.sub(n.noise("reef_gravel", GRAVEL_FREQ, 1, 1.0), n.const(GRAVEL_MIN)),
        -- 3: rare pumice pebbles.
        n.min(n.sub(n.noise("reef_pumice", PUMICE_FREQ, 1, 1.0), n.const(PUMICE_MIN)),
            n.sub(n.const(0.25), crest_w())),
        -- 4: the reef rock itself: calcite.
        reef_rock(),
        -- 5: and the pink algae encrusting most of it.
        n.min(reef_rock(), n.sub(n.noise("reef_algae", ALGAE_FREQ, 2, 1.0), n.const(ALGAE_MIN))),
        -- 6: the drop-off wall past the crest: bare calcite for the anemones.
        n.sub(out(), n.const(CREST_END)),
        -- 7: a tidal gutter's floor: gravel, scoured across the flats.
        n.min(n.sub(gutter_w(), n.const(0.5)), n.sub(n.const(0.3), crest_w())),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    code = n.mul(code, step(reef_only(at_sea())))
    local depth = shape.compile("biome.reef.depth", shape.terrain(false))
    local codes = shape.compile("biome.reef.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 4 * km, material = blocks.white_sand },
        { code = 1, from = 4 * km, to = 14 * km, material = blocks.calcite },
        { code = 2, to = 2 * km, material = blocks.gravel },
        { code = 2, from = 2 * km, to = 14 * km, material = blocks.white_sand },
        { code = 3, to = 1 * km, material = blocks.pumice },
        { code = 3, from = 1 * km, to = 14 * km, material = blocks.white_sand },
        { code = 4, to = 14 * km, material = blocks.calcite },
        { code = 5, to = 1 * km, material = blocks.pink_algae },
        { code = 5, from = 1 * km, to = 14 * km, material = blocks.calcite },
        { code = 6, to = 14 * km, material = blocks.calcite },
        { code = 7, to = 2 * km, material = blocks.gravel },
        { code = 7, from = 2 * km, to = 14 * km, material = blocks.white_sand },
    }
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, sink, above)
            if #list > 0 then
                fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                    salt = salt, sink = sink, above = above,
                    stand = shape.compile("biome.reef.stand_" .. name, reef_only(field)) }
            end
        end
        -- The corals grow in the lagoon and over the crest, never on a
        -- spit that is out of the water and never in a surge channel.
        -- Under water, inside the crest, off the spits: nothing of the
        -- reef's grows out of the water, whatever the sea map says — the
        -- flats rise over the level where the bars are.
        local function wet_floor()
            return n.min(n.min(n.min(at_sea(), n.sub(n.const(CREST_END), out())),
                n.sub(n.const(0.35), bar_w())), n.mul(n.add(over_sea(), n.const(0.0008)), n.const(-1.0)))
        end
        scatter("elkhorn", built.elkhorn, n.min(wet_floor(), n.sub(crest_w(), n.const(0.15))), ELKHORN_CELL, ELKHORN_SQUARES, 141, 1)
        scatter("table", built.tables, n.min(wet_floor(), n.sub(n.const(0.6), crest_w())), TABLE_CELL, TABLE_SQUARES, 142, 1)
        scatter("brain", built.brains, wet_floor(), BRAIN_CELL, BRAIN_SQUARES, 143, 1)
        scatter("arch", built.arches, n.min(wet_floor(), n.sub(crest_w(), n.const(0.3))), ARCH_CELL, ARCH_SQUARES, 144, 2, 0.008)
        scatter("bombora", built.bomboras, n.min(wet_floor(), n.sub(n.const(0.4), crest_w())), BOMBORA_CELL, BOMBORA_SQUARES, 145, 2, 0.010)
        -- The palms: only on a spit that breaches the tide.
        scatter("palm", built.palms, n.min(at_sea(), n.sub(bar_w(), n.const(0.85))), PALM_CELL, PALM_SQUARES, 146, 1, 0.014)
    end
    return fills
end)

-- Where the reef is, and which chunks are its: the sea map's class, and
-- the lane. The coast answers for every other shore.
tdw.biomes[ID].present = function(pos)
    if seas.class(pos) ~= "shore" then
        return false
    end
    local x, z = pos.x * 16 + 8, pos.z * 16 + 8
    return tdw.reef_zone(x, z) ~= nil
end
-- `/tp coral fringed shallows`: a place in the lagoon, ten to sixty
-- blocks out, inside the lane.
tdw.biomes[ID].locate = function(px, pz, seed)
    -- Thirty to ninety blocks out: the lagoon's flats, between the beach
    -- and the barrier crest, which is where the biome is worth landing in.
    return seas.locate(px, pz, seed, 30.0, 90.0, REEF_U[1], REEF_U[2])
end
