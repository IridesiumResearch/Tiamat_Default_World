-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 1.7 Jungle (the Dense Rainforest Canopy until 2026-09-15: "let's change
-- the name to just 'Jungle'"): the wet half of the Verdant Belt.
--
-- The brief (2026-09-14):
--
--   Topography: low karst ridges and humid ravines broken by sunken
--   sinkholes and muddy hummocks; the true ground deeply undulating and
--   obstructed by colossal above-ground root networks.
--   Surface: water-saturated mud, moss*, grass, clay, deep puddles of black
--   mud*; stone outcrops rare and almost entirely masked beneath moss.
--   Canopy: multi-layered and towering, blocking 85-90% of direct sunlight.
--   Megatrees (ironwoods* and kapoks), very tall with massive trunks flaring
--   into wide, stepped buttress root walls. A sub-canopy at 12 to 18 blocks
--   of broad fan-leafed palms and giant tree ferns.
--   Flora: vines and climbing ivy* hanging from upper limbs, giant broadleaf
--   monsteras*, carnivorous pitcher plants hugging root hollows.
--   Atmosphere: humid ground fog or mist, drips from the canopy.
--   Accents: natural timber bridges of massive horizontal branches high in
--   the air, and hollow fallen logs wide enough to walk through.
--
-- THE GROUND is terms of the terrain (`shape.rainforest_terms`), added to
-- the wet half's own by the verdant weight in the "verdant" mode
-- (shape.lua), so the karst fades in over five hundred metres at the belt's
-- edges: an undulation of about nine blocks either way; karst ridges twelve
-- blocks high with flat tops and steep sides along the zero contour of a
-- slow noise; ravines sixteen blocks deep with sheer two-block walls along
-- another's; round sinkholes ten deep where a middling noise peaks; and
-- hummocks a block and a half high over nearly half the floor. The
-- materials read the same weights back.
--
-- THE CANOPY is its own shade. The engine lets light through a block only
-- where it has air (light/mod.rs: "judged by occupancy and not by
-- material"), so leaf clumps with whole blocks in their middles are a roof,
-- and the light that reaches the floor is what comes through the gaps
-- between crowns and round their ragged edges. Megatrees one to a square of
-- twenty blocks, three in four squares, with crowns ten to fourteen blocks
-- across, and the sub-canopy under them. A chunk tint takes the floor's
-- greens toward emerald. The fog, the mist and the drips are the engine's
-- (docs/engine-asks.md, items 20 and 23): it has no particles and no fog by
-- place.
--
-- THE TREES are paths with a thickness (`schem.push_path`), cut once into
-- schematics at the first rainforest chunk and stamped by the engine's
-- scatter at generation, as the river's are.

local blocks = tdw.blocks
local shape = tdw.shape
local n = shape.node
local schem = tdw.schem

local ID = "jungle"

-- The ground's terms. Heights in km, distances in blocks.
local UNDULATE_FREQ, UNDULATE_AMP = 1 / 90, 0.022     -- about nine blocks either way
local RIDGE_FREQ, RIDGE_W, RIDGE_H = 1 / 240, 12.0, 0.012
local RAVINE_FREQ, RAVINE_W, RAVINE_WALL, RAVINE_D = 1 / 310, 5.0, 2.0, 0.016
-- Thresholds are against the engine's noise as MEASURED (2026-09-14, 30,000
-- samples): it is clamped to +/-0.5 and spends much of its time there, so
-- one octave is over 0.35 on 22% of the ground, over 0.42 on 18%, and AT the
-- clamp on 13%; two octaves are over 0.35 on 14%, 0.42 on 10%, and at the
-- clamp on 6%. Nothing rarer than the clamp comes from one noise: the
-- sinkholes are where two independent ones are both high, about 2%.
local SINK_FREQ, SINK_MIN, SINK_EDGE, SINK_D = 1 / 45, 0.30, 12.0, 0.010
local HUMMOCK_FREQ, HUMMOCK_MIN, HUMMOCK_EDGE, HUMMOCK_H = 1 / 5, 0.05, 5.0, 0.0015
-- The materials.
local GRASS_PATCH_FREQ, GRASS_PATCH_MIN = 1 / 18, 0.35   -- two octaves: 14% of the floor
local MUD_PATCH_FREQ, MUD_PATCH_MIN = 1 / 25, 0.35       -- one octave: 22%
local OUTCROP_FREQ, OUTCROP_MIN = 1 / 30, 0.22        -- on the ridge crests only: rare
local PUDDLE_FREQ, PUDDLE_MIN = 1 / 14, 0.42           -- two octaves, 10%, and only in a hollow: about 4%
-- The cover.
local FERN_FREQ, FERN_MIN = 1.5, 0.16
local FERN_PATCH_FREQ, FERN_PATCH_MIN = 1 / 30, -0.08
local MONSTERA_FREQ, MONSTERA_MIN = 1.4, 0.30
local MONSTERA_PATCH_FREQ, MONSTERA_PATCH_MIN = 1 / 26, 0.05
-- The structures: cell, share of squares, salt.
local MEGA_CELL, MEGA_SQUARES, MEGA_SALT = 20, 0.75, 71
local SUB_CELL, SUB_SQUARES, SUB_SALT = 7, 0.5, 72
local LOG_CELL, LOG_SQUARES, LOG_SALT = 36, 0.35, 73
local IRONWOOD_TEMPLATES, KAPOK_TEMPLATES, PALM_TEMPLATES, FERN_TEMPLATES, LOG_TEMPLATES = 5, 3, 5, 5, 4

-- ------------------------------------------------------------ the ground

-- 1 on a karst ridge's flat top, falling to 0 over its steep sides.
local function ridge_w()
    return n.clamp(n.mul(n.add(n.contour("rf_ridge", RIDGE_FREQ, 2), n.const(-RIDGE_W)), n.const(-2.2 / RIDGE_W)), 0.0, 1.0)
end
-- 1 on a ravine's floor, falling to 0 up its walls.
local function ravine_w()
    return n.clamp(n.mul(n.add(n.contour("rf_ravine", RAVINE_FREQ, 2), n.const(-RAVINE_W)), n.const(-1.0 / RAVINE_WALL)), 0.0, 1.0)
end
-- 1 in a sinkhole, 0 outside it; the noise climbs steeply there, so the
-- sides are near sheer. The sinkholes' and hummocks' noises are flat in y
-- (2026-09-17): a 3D gate on a depth changes its footprint with height and
-- leaves lips and hanging slabs.
local function sink_w()
    local both = n.min(n.sub(n.noise("rf_sink", SINK_FREQ, 2, 1.0, shape.HUMIDITY_STRETCH), n.const(SINK_MIN)),
        n.sub(n.noise("rf_sink_b", SINK_FREQ, 2, 1.0, shape.HUMIDITY_STRETCH), n.const(SINK_MIN)))
    return n.clamp(n.mul(both, n.const(SINK_EDGE)), 0.0, 1.0)
end
local function hummock_w()
    return n.clamp(n.mul(n.sub(n.noise("rf_hummock", HUMMOCK_FREQ, 1, 1.0, shape.HUMIDITY_STRETCH), n.const(HUMMOCK_MIN)), n.const(HUMMOCK_EDGE)), 0.0, 1.0)
end

-- The rainforest's terms of the terrain, km: each a weight times a height,
-- summed one at a time so no more than three buffers are ever held.
function shape.rainforest_terms()
    local acc = n.mul(ridge_w(), n.const(RIDGE_H))
    acc = n.add(acc, n.mul(ravine_w(), n.const(-RAVINE_D)))
    acc = n.add(acc, n.mul(sink_w(), n.const(-SINK_D)))
    acc = n.add(acc, n.mul(hummock_w(), n.const(HUMMOCK_H)))
    return n.add(acc, n.noise("rf_undulate", UNDULATE_FREQ, 2, UNDULATE_AMP))
end

tdw.biomes[ID].ring_mode = "verdant"
tdw.biomes[ID].lazy = true                -- its terms are this file's, and every terrain mode compiles on demand
tdw.biomes[ID].soil = blocks.mud

-- ------------------------------------------------------------ the trees

local AIR = game.AIR
-- Priorities for the engine's cut: wood keeps its cells from the leaves and
-- the ivy pushed across it, and a log's hollow of air takes them from the
-- wood.
local PRIORITY = { [blocks.ironwood_log] = 1, [blocks.kapok_log] = 1, [blocks.willow_log] = 1, [blocks.oak_log] = 1, [AIR] = 2 }
local BLIND = { blind = true }

local function pick(rng, range)
    return range[1] + rng:below(range[2] + 1)
end
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "rainforest_template:" .. name)
end

-- The megatrees. `height` and the rest are { least, extra } in whole
-- blocks; radii and shares are plain numbers.
local IRONWOOD = {
    log = blocks.ironwood_log, leaves = blocks.ironwood_leaves,
    height = { 44, 13 }, r = { 2.5, 1.0 },
    fins = { 5, 2 }, fin_h = { 7, 3 }, fin_reach = { 6, 3 },
    limbs = { 5, 2 }, limb_from = 0.60, limb_reach = { 8, 5 }, limb_rise = { 4, 3 },
    clump = { 5, 2 }, flat = 0.5, crown = { 6, 2 },
    bridge_one_in = 1,
}
-- The kapok: an emergent, taller and paler, its buttresses the biggest in
-- the forest, branching only near the top into flat tiers of limbs.
local KAPOK = {
    log = blocks.kapok_log, leaves = blocks.kapok_leaves,
    height = { 54, 12 }, r = { 2.8, 1.1 },
    fins = { 6, 2 }, fin_h = { 10, 4 }, fin_reach = { 9, 3 },
    limbs = { 6, 2 }, limb_from = 0.78, limb_reach = { 11, 5 }, limb_rise = { 1, 2 },
    clump = { 6, 2 }, flat = 0.38, crown = { 7, 2 },
    bridge_one_in = 2,
    mounds = true,
}

-- Vines (2026-09-15: "links of vine that grow after some amount of ticks
-- one at a time, not really long single vines"): the template hangs the
-- first two links under a limb; the rest grow by the random tick at the
-- end of this file, a link at a time. `drop` is what it may grow to, and
-- is the tick's business now.
local function vine(x, y, z, drop, rng)
    schem.push_path(blocks.climbing_ivy, {
        { x, y - 0.3, z, 0.18 },                -- a cell thick (0.3 until 2026-09-22)
        { x + (rng:below(3) - 1) * 0.2, y - 1.8, z + (rng:below(3) - 1) * 0.2, 0.16 },
    }, BLIND)
end

local function megatree(rng, sp)
    schem.record_begin()
    local height = pick(rng, sp.height)
    local r0, r1 = sp.r[1], sp.r[2]
    -- The trunk: sunk into the ground under a wider foot, climbing with a
    -- slight lean and wander, thinning toward the crown.
    local lean = schem.DIR16[rng:below(16) + 1]
    local tx, tz = 0.5, 0.5
    local trunk = { { tx, -2.5, tz, r0 * 1.15 }, { tx, 2.0, tz, r0 } }
    for i = 1, 5 do
        local t = i / 5
        tx = tx + lean[1] * 0.25 + (rng:below(3) - 1) * 0.2
        tz = tz + lean[2] * 0.25 + (rng:below(3) - 1) * 0.2
        trunk[#trunk + 1] = { tx, 2.0 + t * (height - 2.0), tz, r0 + (r1 - r0) * t }
    end
    schem.push_path(sp.log, trunk, BLIND)

    -- The roots (2026-09-15: "draw the roots with a path just like the
    -- rest of the tree trunks and then have the thickness scale up toward
    -- the base"): each a path leaving the trunk a few blocks up, thick as
    -- half the trunk there, out and down over the ground with a kink at
    -- its knee, thinning to a tip that dives a block and a half under; a
    -- smaller side root off most of them at the knee. Gnarly, not a wall
    -- (the buttresses were stacks of horizontal paths, a staircase edge).
    local fins = pick(rng, sp.fins)
    local first = rng:below(16)
    local headings = {}
    for f = 0, fins - 1 do
        local heading = (first + f * 16 // fins + rng:below(2)) % 16
        headings[#headings + 1] = heading
        local d = schem.DIR16[heading + 1]
        local side = schem.DIR16[(heading + 4) % 16 + 1]
        local reach = pick(rng, sp.fin_reach) + 2
        local rise = pick(rng, sp.fin_h) * 0.35
        local kink = (rng:below(3) - 1) * 1.2
        local root = {
            { 0.5 + d[1] * r0 * 0.5, rise, 0.5 + d[2] * r0 * 0.5, r0 * 0.55 },
            { 0.5 + d[1] * reach * 0.35 + side[1] * kink, rise * 0.45, 0.5 + d[2] * reach * 0.35 + side[2] * kink, r0 * 0.38 },
            { 0.5 + d[1] * reach * 0.7 + side[1] * kink * 0.5, 0.2, 0.5 + d[2] * reach * 0.7 + side[2] * kink * 0.5, 0.55 },
            { 0.5 + d[1] * reach, -1.5, 0.5 + d[2] * reach, 0.35 },
        }
        schem.push_path(sp.log, root, BLIND)
        if rng:below(3) > 0 then
            local s = schem.DIR16[(heading + 3 + rng:below(2) * 10) % 16 + 1]
            local kx, ky, kz = root[2][1], root[2][2], root[2][3]
            schem.push_path(sp.log, {
                { kx, ky, kz, r0 * 0.3 },
                { kx + s[1] * reach * 0.3, ky * 0.5 + 0.1, kz + s[2] * reach * 0.3, 0.42 },
                { kx + s[1] * reach * 0.55, -1.0, kz + s[2] * reach * 0.55, 0.3 },
            }, BLIND)
        end
    end
    -- Earth heaped round the roots (2026-09-17, "random clumps of dirt at
    -- the roots of the giant kapok trees so that when it spawns on a
    -- hillside it does not look super strange with roots sticking out"):
    -- a low mound under the foot, a clump over each root's knee, and two
    -- or three more at random round the base. Under the wood's priority,
    -- so a root still breaks the surface of its mound.
    if sp.mounds then
        local rough = { rough = 0.45, blind = true }
        schem.push_ellipsoid(blocks.dirt, 0.5, -0.8, 0.5, r0 + 2.5 + rng:below(3) * 0.5, 2.0, r0 + 2.5 + rng:below(3) * 0.5, rough)
        for _, heading in ipairs(headings) do
            local d = schem.DIR16[heading + 1]
            local at = 0.4 + rng:below(3) * 0.1
            local reach = pick(rng, sp.fin_reach) + 2
            schem.push_ellipsoid(blocks.dirt, 0.5 + d[1] * reach * at, -0.5, 0.5 + d[2] * reach * at,
                2.0 + rng:below(3) * 0.5, 1.4 + rng:below(3) * 0.3, 2.0 + rng:below(3) * 0.5, rough)
        end
        for _ = 1, 2 + rng:below(2) do
            local d = schem.DIR16[rng:below(16) + 1]
            local dist = r0 + 1.5 + rng:below(5)
            schem.push_ellipsoid(blocks.dirt, 0.5 + d[1] * dist, -0.6, 0.5 + d[2] * dist,
                1.5 + rng:below(3) * 0.5, 1.2 + rng:below(2) * 0.4, 1.5 + rng:below(3) * 0.5, rough)
        end
    end
    -- Pitcher plants in the root hollows: in some of the bays between two
    -- walls, against the trunk, two cells tall in the block over the ground.
    local pitchers = schem.bit(1, 0, 1) | schem.bit(1, 1, 1) | schem.bit(0, 0, 1) | schem.bit(2, 0, 1)
    for f = 1, #headings do
        if rng:below(2) == 0 then
            local mid = (headings[f] + 8 // #headings) % 16
            local d = schem.DIR16[mid + 1]
            local px, pz = 0.5 + d[1] * (r0 + 1.4), 0.5 + d[2] * (r0 + 1.4)
            schem.push_cells(blocks.pitcher_plant, math.floor(px), 1, math.floor(pz), pitchers)
        end
    end
    -- Climbing ivy up the trunk in a few strips, from the ground to a third
    -- or two thirds of the way up.
    for _ = 1, 3 + rng:below(2) do
        local d = schem.DIR16[rng:below(16) + 1]
        local reach = height * (0.35 + rng:below(35) / 100)
        local strip = {}
        for _, p in ipairs(trunk) do
            if p[2] >= 0 and p[2] <= reach then
                -- One cell wide (0.5 until 2026-09-22, a strip of three: with
                -- the ivy drawn as cells rather than cards that was a green
                -- plate up the trunk).
                strip[#strip + 1] = { p[1] + d[1] * (p[4] + 0.1), p[2], p[3] + d[2] * (p[4] + 0.1), 0.2 }
            end
        end
        if #strip >= 2 then
            schem.push_path(blocks.climbing_ivy, strip, BLIND)
        end
    end

    -- A clump of leaves (2026-09-15: "a tad bigger, deformed or broken up
    -- with noise and more shapes"): a fifth larger, and not one ellipsoid
    -- but a core with two to three more thrown off it, each its own size
    -- and flatness, all rough-edged.
    local function clump(x, y, z, r)
        r = r * 1.2
        schem.push_ellipsoid(sp.leaves, x, y, z, r * 0.85, r * sp.flat * 0.9, r * 0.85, { rough = 0.3, blind = true })
        for _ = 1, 2 + rng:below(2) do
            local d = schem.DIR16[rng:below(16) + 1]
            local k = 0.45 + rng:below(4) * 0.1
            local off = r * (0.45 + rng:below(3) * 0.15)
            schem.push_ellipsoid(sp.leaves, x + d[1] * off, y + (rng:below(5) - 2) * 0.35 * r * sp.flat, z + d[2] * off,
                r * k, r * sp.flat * (k + 0.15), r * k * (0.8 + rng:below(3) * 0.15), { rough = 0.35, blind = true })
        end
    end
    -- The limbs of the crown, round the compass, each with a great clump of
    -- leaves on its end and a smaller one off its middle, and ropes of vine
    -- hung along it.
    local limbs = pick(rng, sp.limbs)
    local start = rng:below(16)
    for i = 0, limbs - 1 do
        local d = schem.DIR16[(start + i * 16 // limbs + rng:below(3) - 1) % 16 + 1]
        local h = height * (sp.limb_from + rng:below(100) / 100 * (0.95 - sp.limb_from))
        local bx, by, bz, br = schem.path_point(trunk, h)
        local reach = pick(rng, sp.limb_reach)
        local rise = pick(rng, sp.limb_rise)
        local mid = { bx + d[1] * reach * 0.5, by + rise * 0.55, bz + d[2] * reach * 0.5, math.max(0.5, br * 0.45) }
        local tip = { bx + d[1] * reach, by + rise, bz + d[2] * reach, 0.35 }
        schem.push_path(sp.log, { { bx, by, bz, br * 0.6 }, mid, tip }, BLIND)
        clump(tip[1], tip[2] + 1.2, tip[3], pick(rng, sp.clump))
        local side = schem.DIR16[(start + i * 16 // limbs + 4) % 16 + 1]
        clump(mid[1] + side[1] * 2.0, mid[2] + 1.5, mid[3] + side[2] * 2.0, pick(rng, sp.clump) * 0.6)
        for _ = 1, 1 + rng:below(3) do
            local t = 0.4 + rng:below(60) / 100
            vine(bx + (tip[1] - bx) * t, by + (tip[2] - by) * t - 0.5, bz + (tip[3] - bz) * t, 6 + rng:below(9), rng)
        end
    end
    -- A timber bridge: one long, near-level limb from the middle of the
    -- trunk, sagging and then lifting at its end, twenty-odd blocks out —
    -- where megatrees stand a square apart, their bridges cross and meet.
    if rng:below(sp.bridge_one_in) == 0 then
        local d = schem.DIR16[rng:below(16) + 1]
        local h = height * (0.50 + rng:below(12) / 100)
        local bx, by, bz, br = schem.path_point(trunk, h)
        local reach = 18 + rng:below(9)
        local path = {
            { bx, by, bz, br * 0.7 },
            { bx + d[1] * reach * 0.33, by - 1.0, bz + d[2] * reach * 0.33, 1.0 },
            { bx + d[1] * reach * 0.66, by - 1.2, bz + d[2] * reach * 0.66, 0.85 },
            { bx + d[1] * reach, by - 0.3, bz + d[2] * reach, 0.75 },
        }
        schem.push_path(sp.log, path, BLIND)
        clump(path[4][1], path[4][2] + 1.5, path[4][3], 3.0)
        for _ = 1, 2 + rng:below(3) do
            local t = 0.25 + rng:below(70) / 100
            vine(bx + d[1] * reach * t, by - 1.6, bz + d[2] * reach * t, 5 + rng:below(8), rng)
        end
    end
    -- The crown: a broad clump on the top and two lobes beside it.
    local top = trunk[#trunk]
    local crown = pick(rng, sp.crown)
    clump(top[1], top[2] + 1.5, top[3], crown)
    for _ = 1, 2 do
        local d = schem.DIR16[rng:below(16) + 1]
        clump(top[1] + d[1] * crown * 0.6, top[2] - 1.0, top[3] + d[2] * crown * 0.6, crown * 0.7)
    end
    return schem.record_schematic(PRIORITY)
end

-- A fan palm of the sub-canopy: a slim bowing stem twelve to seventeen
-- blocks tall and a head of broad fans, each three rays spread a sixteenth
-- of a turn apart, arching out and drooping.
local function fan_palm(rng)
    schem.record_begin()
    local tall = 12 + rng:below(6)
    local d = schem.DIR16[rng:below(16) + 1]
    local stem = {}
    for i = 0, 4 do
        local t = i / 4
        local bow = t * t * 1.4
        stem[#stem + 1] = { 0.5 + d[1] * bow, -1.0 + t * (tall + 1), 0.5 + d[2] * bow, 0.5 - 0.2 * t }
    end
    schem.push_path(blocks.willow_log, stem, BLIND)
    local tip = stem[#stem]
    local fans = 9 + rng:below(5)
    for f = 1, fans do
        local heading = (f * 16 // fans + rng:below(2)) % 16
        local reach = 3.5 + rng:below(3) * 0.5
        for k = -1, 1 do
            local ray = schem.DIR16[(heading + k) % 16 + 1]
            schem.push_path(blocks.oak_leaves, {
                { tip[1], tip[2], tip[3], 0.3 },
                { tip[1] + ray[1] * reach * 0.5, tip[2] + 0.6, tip[3] + ray[2] * reach * 0.5, 0.35 },
                { tip[1] + ray[1] * reach, tip[2] - 0.8, tip[3] + ray[2] * reach, 0.28 },
            }, BLIND)
        end
    end
    return schem.record_schematic(PRIORITY)
end

-- A giant tree fern: a straight fibrous trunk ten to fifteen blocks tall and
-- a crown of long fronds that climb out of it and droop at the tips.
local function tree_fern(rng)
    schem.record_begin()
    local tall = 10 + rng:below(6)
    local d = schem.DIR16[rng:below(16) + 1]
    local trunk = {
        { 0.5, -1.0, 0.5, 0.5 },
        { 0.5 + d[1] * 0.3, tall * 0.5, 0.5 + d[2] * 0.3, 0.42 },
        { 0.5 + d[1] * 0.5, tall, 0.5 + d[2] * 0.5, 0.4 },
    }
    schem.push_path(blocks.oak_log, trunk, BLIND)
    local tip = trunk[#trunk]
    local fronds = 8 + rng:below(4)
    for f = 1, fronds do
        local w = schem.DIR16[(f * 16 // fronds + rng:below(2)) % 16 + 1]
        local reach = 4.5 + rng:below(3) * 0.5
        schem.push_path(blocks.fern, {
            { tip[1], tip[2] + 0.2, tip[3], 0.25 },
            { tip[1] + w[1] * reach * 0.32, tip[2] + 1.4, tip[3] + w[2] * reach * 0.32, 0.32 },
            { tip[1] + w[1] * reach * 0.7, tip[2] + 1.0, tip[3] + w[2] * reach * 0.7, 0.26 },
            { tip[1] + w[1] * reach, tip[2] - 0.8, tip[3] + w[2] * reach, 0.15 },
        }, BLIND)
    end
    return schem.record_schematic(PRIORITY)
end

-- A hollow fallen log: an ironwood trunk twelve to eighteen blocks long
-- lying half sunk in the floor, mossed along its top, with its middle AIR —
-- a tunnel three blocks across, open at both ends. The hollow is written as
-- air cells, which the scatter's merge write takes out of whatever is there,
-- so the tunnel is clear of the ground it lies in; it runs two and a half
-- blocks past each end, so the ends are open and the entrances dug.
local function hollow_log(rng)
    local length = 12 + rng:below(7)
    local d = schem.DIR16[rng:below(16) + 1]
    local half = length / 2
    local cy = 1.5
    local ax, az = 0.5 - d[1] * half, 0.5 - d[2] * half
    local bx, bz = 0.5 + d[1] * half, 0.5 + d[2] * half
    schem.record_begin()
    schem.push_path(blocks.ironwood_log, { { ax, cy, az, 2.3 }, { bx, cy - 0.3, bz, 2.1 } }, BLIND)
    schem.push_path(blocks.moss, { { ax, cy + 0.7, az, 2.1 }, { bx, cy + 0.4, bz, 1.9 } }, BLIND)
    schem.push_path(AIR, { { ax - d[1] * 2.5, cy, az - d[2] * 2.5, 1.45 }, { bx + d[1] * 2.5, cy - 0.3, bz + d[2] * 2.5, 1.45 } }, BLIND)
    return schem.record_schematic(PRIORITY)
end

-- Whether (x, z) is the Jungle's, by its placement field, cached by
-- eight-block square as the cold biomes' tests are: the HUD asks when the
-- ground under a player says nothing (a ravine's clay, a mud patch).
local FIELD = nil
local cache, cached = {}, 0
function tdw.jungle_at(x, z)
    local only = tdw.config.everywhere
    if only then
        return only == ID
    end
    local u = (x * x + z * z) * 1e-6 / (shape.R_DISC * shape.R_DISC)
    local ring = tdw.layers.ring_by_id.verdant
    if u < ring.u[1] - shape.wobble(u) or u > ring.u[2] + shape.wobble(u) then
        return false
    end
    local seed = game.world_seed or tdw.seed
    if seed == nil then
        return false
    end
    local key = (x // 8) * 65536 + (z // 8)
    local hit = cache[key]
    if hit == nil then
        if cached > 20000 then
            cache, cached = {}, 0
        end
        FIELD = FIELD or shape.compile("jungle.at", tdw.biome_mask(n, ID))
        local y = shape.Y0 + 1000 * shape.dome_at(u)
        hit = FIELD:at(x + 0.5, y + 0.5, z + 0.5, seed) > 0
        cache[key] = hit
        cached = cached + 1
    end
    return hit
end

-- Cut once, at the first rainforest chunk, and kept: the scatter asks for
-- them per mode, and a megatree is hundreds of thousands of cell tests.
local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { mega = {}, sub = {}, logs = {} }
    if not game.schematic_shapes then
        game.log("tiamot_default_world rainforest: no game.schematic_shapes in this engine; no trees")
        BUILT = out
        return out
    end
    for i = 1, IRONWOOD_TEMPLATES do out.mega[#out.mega + 1] = megatree(rng_for("ironwood:" .. i), IRONWOOD) end
    for i = 1, KAPOK_TEMPLATES do out.mega[#out.mega + 1] = megatree(rng_for("kapok:" .. i), KAPOK) end
    for i = 1, PALM_TEMPLATES do out.sub[#out.sub + 1] = fan_palm(rng_for("palm:" .. i)) end
    for i = 1, FERN_TEMPLATES do out.sub[#out.sub + 1] = tree_fern(rng_for("fern:" .. i)) end
    for i = 1, LOG_TEMPLATES do out.logs[#out.logs + 1] = hollow_log(rng_for("log:" .. i)) end
    local counts = {}
    for _, key in ipairs({ "mega", "sub", "logs" }) do
        local total = 0
        for _, one in ipairs(out[key]) do total = total + one:len() end
        counts[#counts + 1] = string.format("%d %s (%d blocks)", #out[key], key, total)
    end
    game.log("tiamot_default_world rainforest: cut " .. table.concat(counts, ", "))
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

tdw.build_biome(ID, function(ctx)
    local function masked(field)
        local mask = tdw.biome_mask(n, ID)
        return mask and n.min(field, mask) or field
    end
    local function off_river(field, blocks_out)
        field = shape.river_exclude and shape.river_exclude(field, blocks_out) or field
        -- And out of the sea and off the shore's own ground (2026-09-15).
        return shape.sea_exclude and shape.sea_exclude(field, 20.0) or field
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    -- The code field: the greatest of k * step(condition k), then masked.
    local conditions = {
        -- 1: the floor: moss over saturated mud.
        n.const(1.0),
        -- 2: patches of grass.
        n.sub(n.noise("rf_grass", GRASS_PATCH_FREQ, 2, 1.0), n.const(GRASS_PATCH_MIN)),
        -- 3: patches of bare saturated mud.
        n.sub(n.noise("rf_mud", MUD_PATCH_FREQ, 1, 1.0), n.const(MUD_PATCH_MIN)),
        -- 4: dry clay up the ravines' walls.
        n.sub(ravine_w(), n.const(0.2)),
        -- 5: a stone outcrop on a ridge's crest, under a coat of moss.
        n.min(n.sub(ridge_w(), n.const(0.9)), n.sub(n.noise("rf_outcrop", OUTCROP_FREQ, 1, 1.0), n.const(OUTCROP_MIN))),
        -- 6: deep puddles of black mud: the sinkholes' floors, and the
        -- hollows between the hummocks where a puddle noise says.
        n.max(n.sub(sink_w(), n.const(0.6)),
            n.min(n.sub(n.noise("rf_puddle", PUDDLE_FREQ, 2, 1.0), n.const(PUDDLE_MIN)), n.sub(n.const(0.1), hummock_w()))),
        -- 7: wet clay on the ravines' floors, where the water sits.
        n.sub(ravine_w(), n.const(0.75)),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    local mask = tdw.biome_mask(n, ID)
    if mask then
        code = n.mul(code, step(mask))
    end
    if shape.sea_exclude then
        -- The shore's ground and the seabed are the coast's and the ocean's.
        code = n.mul(code, step(shape.sea_exclude(n.const(1.0), 20.0)))
    end
    local depth = shape.compile("biome.rainforest.depth", shape.terrain(false))
    local codes = shape.compile("biome.rainforest.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 1 * km, material = blocks.moss },
        { code = 1, from = 1 * km, to = 4 * km, material = blocks.mud },
        { code = 2, to = 1 * km, material = blocks.grass },
        { code = 2, from = 1 * km, to = 4 * km, material = blocks.mud },
        { code = 3, to = 4 * km, material = blocks.mud },
        { code = 4, to = 4 * km, material = blocks.dry_clay },
        { code = 5, to = 1 * km, material = blocks.moss },
        { code = 5, from = 1 * km, to = 6 * km, material = blocks.stone },
        { code = 6, to = 3 * km, material = blocks.black_mud },
        { code = 6, from = 3 * km, to = 5 * km, material = blocks.mud },
        { code = 7, to = 2 * km, material = blocks.wet_clay },
        { code = 7, from = 2 * km, to = 5 * km, material = blocks.dry_clay },
    }
    -- The cover: ferns in carpets, monsteras in stands. Not in a river's
    -- valley, whose ground cover is the river's.
    local function cover(name, freq, min, patch_freq, patch_min)
        return shape.compile("biome.rainforest." .. name, masked(off_river(
            n.min(n.sub(n.noise("rf_" .. name, freq, 1, 1.0), n.const(min)),
                n.sub(n.noise("rf_" .. name .. "_patch", patch_freq, 1, 1.0), n.const(patch_min))),
            shape.RIVER_RIM or 0)))
    end
    local fills = {
        -- `body`: where the chunk is the rainforest's alone, this lays the
        -- mud and the stone under it too (generate.lua).
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
        { cover = blocks.monstera, cells = 3, take = cover("monstera", MONSTERA_FREQ, MONSTERA_MIN, MONSTERA_PATCH_FREQ, MONSTERA_PATCH_MIN) },
        { cover = blocks.fern, cells = 2, take = cover("fern", FERN_FREQ, FERN_MIN, FERN_PATCH_FREQ, FERN_PATCH_MIN) },
    }
    if game.schematic then
        local built = structures()
        -- Nothing big in a ravine, a sinkhole or a river's channel and banks.
        local function firm()
            return n.min(n.sub(n.const(0.05), ravine_w()), n.sub(n.const(0.05), sink_w()))
        end
        local function stand(name, field, river)
            return shape.compile("biome.rainforest.stand_" .. name, masked(off_river(field, river)))
        end
        -- `above`: how far over the ground the structure reaches, km, so the
        -- chunks of air its crown stands in stamp it too (generate.lua).
        local function scatter(list, field, cell, chance, salt, above)
            if #list > 0 then
                fills[#fills + 1] = { scatter = true, depth = depth, stand = field, schematics = list,
                    cell = cell, chance = chance, salt = salt, sink = 1, above = above }
            end
        end
        -- The logs first: their hollows are air, and a tree stamped after
        -- keeps its roots where a log's hollow would have taken them.
        scatter(built.logs, stand("log", firm(), (shape.RIVER_BAR or 0) + 12), LOG_CELL, LOG_SQUARES, LOG_SALT, 0.006)
        scatter(built.mega, stand("mega", firm(), (shape.RIVER_BAR or 0) + 12), MEGA_CELL, MEGA_SQUARES, MEGA_SALT, 0.08)
        scatter(built.sub, stand("sub", n.sub(n.const(0.05), sink_w()), (shape.RIVER_BAR or 0) + 4), SUB_CELL, SUB_SQUARES, SUB_SALT, 0.024)
    end
    return fills
end)

-- ------------------------------------------------------------ the light

-- Emerald twilight on the floor: the chunk tint takes every tinted material
-- in the rainforest's chunks toward a darker green, half way in a chunk the
-- biome only partly covers. The engine blends it across chunk corners.
local TINT_IN = { 0.76, 0.90, 0.78 }
local TINT_EDGE = { 0.88, 0.95, 0.89 }
local tint_mask = nil
if tdw.on_chunk_tint then
    tdw.on_chunk_tint(function(pos)
        local only = tdw.config.everywhere
        if only then
            if only == ID then
                return TINT_IN[1], TINT_IN[2], TINT_IN[3]
            end
            return nil
        end
        if tint_mask == nil then
            tint_mask = shape.compile("rainforest.tint", tdw.biome_mask(n, ID))
        end
        local b = tint_mask:bounds(pos)
        if b.high <= 0 then
            return nil
        elseif b.low > 0 then
            return TINT_IN[1], TINT_IN[2], TINT_IN[3]
        end
        return TINT_EDGE[1], TINT_EDGE[2], TINT_EDGE[3]
    end)
end

-- ------------------------------------------------------------ the vines' growth

-- A rope of ivy grows a link at a time: a random tick on an ivy block that
-- hangs (no wood beside it — the strips up a trunk stay as they are) and
-- has air under it sets the rope growing, a link every VINE_TICKS, until it
-- is VINE_MAX links long or meets something. The tick offers any one block
-- about every twenty minutes, so a rope takes its time to start and then
-- comes down over a quarter of a minute.
local VINE_MAX, VINE_TICKS = 12, 30
local IVY = "tiamot_default_world:climbing_ivy"
local CENTRE_COLUMN = (1 << 4) | (1 << 13) | (1 << 22)   -- the middle cell column of a block: a rope a third of a block across
local WOOD = { [blocks.ironwood_log] = true, [blocks.kapok_log] = true, [blocks.willow_log] = true, [blocks.oak_log] = true }
local edits = tdw.edits
local function has(b, material)
    if b == nil then
        return false
    end
    if b.material then
        return b.material == material
    end
    if b.cells then
        for _, c in ipairs(b.cells) do
            if c == material then
                return true
            end
        end
    end
    return false
end
local function beside_wood(x, y, z)
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        local b = schem.at(x + d[1], y, z + d[2])
        for material in pairs(WOOD) do
            if has(b, material) then
                return true
            end
        end
    end
    return false
end
local function grow(x, y, z, links)
    if links >= VINE_MAX or not edits.room(2) then
        return
    end
    local below = schem.at(x, y - 1, z)
    if below == nil or below.occupancy ~= 0 then
        return
    end
    edits.begin()
    edits.push({ x = x, y = y - 1, z = z }, IVY, CENTRE_COLUMN)
    edits.commit(2)
    edits.later(VINE_TICKS, function() grow(x, y - 1, z, links + 1) end)
end
tdw.on_random_tick(blocks.climbing_ivy, function(x, y, z)
    if beside_wood(x, y, z) then
        return true
    end
    -- How long the rope is already: the links up to the limb.
    local links = 1
    while links < VINE_MAX and has(schem.at(x, y + links, z), blocks.climbing_ivy) do
        links = links + 1
    end
    grow(x, y, z, links)
    return true
end)
