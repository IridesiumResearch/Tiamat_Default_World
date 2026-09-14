-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 1.6 River Valleys: troughs cut into the uplands, with a river in them.
--
-- A V or U trough with a meandering waterway down the middle, flat alluvial
-- terraces stepping back from it, steep undercut bluffs on the outer bends
-- and wide low point bars on the inner ones. Deep moist sand, clay at the
-- water line, gravel banks and bars, and bedrock shelves scoured bare where
-- the flow is fast. Dense riparian willow along the shore thinning into the
-- woodland as the slopes climb, palms standing over the terraces, iris and
-- mint and grass on the wet ground. Snags and drift jams lodged on the
-- bars, stepping stones across the shallows, and spring seeps weeping from
-- the valley walls.
--
-- THE COURSE is one line: the zero contour of a slow 2D noise, read through
-- the engine's `contour` node as a distance in blocks. Everything reads that
-- one distance — the trough's profile, which materials go where, where a
-- willow may stand — so nothing disagrees with anything at any height, and
-- the line meanders because a noise's contour does.
--
-- THE WATER is the engine's water FLUID, laid by `buf:fill_fluid_terraced`
-- (2026-09-14): the river's level read per column and taken down to a whole
-- block, and every block under it in the channel filled. It is ONE river
-- running the length of its course, with no lips. The first cut held each
-- step of the level up with a one-block stone lip, because a conserved fluid
-- on a slope runs to the bottom of its valley; the designer took the lips
-- out ("just make it a straight river") and is making the water stay put in
-- the engine instead.
--
-- THE CHANNEL is carved UNDER that level: a smooth U, deeper in the pools,
-- with low humps in the bed here and there, and a short bank rising from
-- the water's edge to stand a couple of blocks over the level — so the
-- water sits down in the creek rather than level with the ground.
--
-- THE VALLEY is subtracted from the terrain rather than replacing it
-- (`shape.river_valley`, called from `M.terrain`): the trough's surface is
-- the world's own smooth height minus the profile, and the terrain is the
-- lesser of itself and that. So a river cuts through whatever biome it
-- crosses and the uplands keep their own shape.

local blocks = tdw.blocks
local shape = tdw.shape
local n = shape.node
local schem = tdw.schem
local edits = tdw.edits

-- The course, and the trough's cross-section. Distances in blocks from the
-- line; heights in km, as the terrain has them.
local COURSE_FREQ = 1 / 2600                          -- courses about two and a half kilometres apart
local CHANNEL = 9.0                                   -- blocks: where the bed comes up to the water's level
local BANK_W = 3.0                                    -- from the water's edge to the top of the bank
local BAR = 17.0                                      -- to the top of the gravel bank and the point bars
local TERRACE = 58.0                                  -- the floodplain terrace's outer edge
local RIM = 150.0                                     -- the valley rim
local BEYOND = 24.0                                   -- blocks past the rim over which the trough stops biting at all
-- The bank top over the level. A column's water fills whole blocks up to
-- the block its level is in, so the surface stands up to a block over the
-- level: 2.2 leaves at least 1.2 blocks between the water and the bank top.
local FREEBOARD = 0.0022
local BAR_RISE = 0.001                                -- one more block out to the bar
local TERRACE_RISE = 0.006                            -- six more to the terrace
local RIM_RISE = 0.018                                -- eighteen more to the rim
local VALLEY_DEPTH = FREEBOARD + BAR_RISE + TERRACE_RISE + RIM_RISE   -- how far under the uplands the level sits
-- The bed: a U under the level, BED_DEPTH at the middle, POOL_EXTRA deeper
-- where the pool noise is up. Smooth: the pools fade in over a few blocks.
local BED_DEPTH = 0.0025
local POOL_EXTRA = 0.002
local POOL_FREQ = 1 / 90
local POOL_MIN = 0.02
local POOL_EDGE = 6.0
-- Humps in the bed, here and there: rounded, a block or so high.
local BUMP_FREQ = 1 / 7
local BUMP_MIN = 0.14
local BUMP_EDGE = 4.0
local BUMP_HEIGHT = 0.0012
-- The bends: a slow noise along the course decides which bank is the
-- undercut bluff and which is the point bar. Times the SIGNED distance it
-- is positive on the bar's side, and the bank's width is stretched there
-- and squeezed on the bluff's.
local BEND_FREQ = 1 / 420
local BEND_BIAS = 0.55                                -- how much wider a point bar is than a bluff
-- The materials.
local CLAY_HALF = 4.0                                 -- blocks either side of the water's edge the clay beds hold
local SHELF_FREQ = 1 / 140
local SHELF_MIN = 0.16                                -- where the bedrock is scoured bare
local SEEP_FREQ = 1 / 55
local SEEP_MIN = 0.30                                 -- springs weeping from the valley walls
local SAND_DEPTH = 0.004
local SOIL_DEPTH = 0.002
local WATER = "tiamot_default_world:water"
-- The cover.
local IRIS_FREQ, IRIS_MIN = 1.4, 0.10                 -- dense, in the shallows and on the wet bank
local MINT_FREQ, MINT_MIN = 1.4, 0.28
-- The grass: 0.20 puts a card on 34% of the valley's cell columns. The
-- woodland's and the grassland's own grass used to stand in the valley too
-- (half-width RIM), and with the river's 0.22 (32.5%) the valley carried
-- 44% where woodland hosted it and 55% where grassland did. Theirs is kept
-- out now, and 34% is 77% and 61% of those: 70% between them, as asked.
local GRASS_FREQ, GRASS_MIN = 1.5, 0.12   -- 0.20 until "more grass" (2026-09-14)
-- The trees.
local WILLOW_CELL, WILLOW_SQUARES, WILLOW_SALT = 5, 0.55, 41
local PALM_CELL, PALM_SQUARES, PALM_SALT = 11, 0.30, 42
local SNAG_CELL, SNAG_SQUARES, SNAG_SALT = 9, 0.105, 43   -- 70% fewer drift piles than the 0.35 of the first cut
local STEP_CELL, STEP_SQUARES, STEP_SALT = 14, 0.25, 44
local WILLOW_TEMPLATES, PALM_TEMPLATES = 5, 4   -- each is thousands of cell tests to cut: enough for variety, not more

-- The distance to the course, in blocks: unsigned for the profile, signed
-- for the bends.
local function course()
    return n.contour("river_course", COURSE_FREQ, 2)
end
local function course_signed()
    return n.contour("river_course", COURSE_FREQ, 2, true)
end
-- +1 on the point bar's side of the water, -1 on the bluff's.
local function bend()
    return n.clamp(n.mul(n.mul(course_signed(), n.noise("river_bend", BEND_FREQ, 1, 1.0)), n.const(0.25)), -1.0, 1.0)
end
-- One step of the trough: nothing until `from`, rising to `rise` by `to`.
-- The distance FIRST, it being the deeper operand.
local function ramp(from, to, rise)
    return n.mul(n.clamp(n.mul(n.add(course(), n.const(-from)), n.const(1.0 / (to - from))), 0.0, 1.0), n.const(rise))
end
-- 0 at the middle of the channel to 1 at the water's edge.
local function across()
    return n.clamp(n.mul(course(), n.const(1.0 / CHANNEL)), 0.0, 1.0)
end
-- How far the ground stands over the level at a distance from the line:
-- the bed under it, the bank up out of the water, the bar, the terrace,
-- the rim, and then a great deal so the trough stops biting into the
-- uplands at all.
local function rise()
    -- The bar first (it is the deepest term): from the bank top out to the
    -- bar, its width swinging with the bend — wide where the point bar is,
    -- narrow where the bluff is undercut. The width is `w * (1 + bias *
    -- bend)`, which the bias under one keeps positive.
    local from = CHANNEL + BANK_W
    local w = BAR - from
    local width = n.add(n.mul(bend(), n.const(w * BEND_BIAS)), n.const(w))
    local acc = n.mul(n.clamp(n.div(n.add(course(), n.const(-from)), width), 0.0, 1.0), n.const(BAR_RISE))
    -- The bed: `-(depth) * (1 - across^2)`, a U whose sides come up to the
    -- level at the water's edge, deeper where the pool noise says.
    local u = n.add(n.mul(n.mul(across(), across()), n.const(-1.0)), n.const(1.0))
    local depth = n.add(n.mul(n.clamp(n.mul(n.sub(n.noise("river_pool", POOL_FREQ, 2, 1.0), n.const(POOL_MIN)),
        n.const(POOL_EDGE)), 0.0, 1.0), n.const(POOL_EXTRA)), n.const(BED_DEPTH))
    acc = n.add(acc, n.mul(n.mul(u, depth), n.const(-1.0)))
    -- The bank, out of the water to FREEBOARD over the level.
    acc = n.add(acc, ramp(CHANNEL, CHANNEL + BANK_W, FREEBOARD))
    acc = n.add(acc, ramp(BAR, TERRACE, TERRACE_RISE))
    acc = n.add(acc, ramp(TERRACE, RIM, RIM_RISE))
    acc = n.add(acc, ramp(RIM, RIM + BEYOND, 1.0))
    -- The humps, only ever up: in the bed they are shoals, on the bank a
    -- little more bank.
    return n.add(acc, n.mul(n.clamp(n.mul(n.sub(n.noise("river_bump", BUMP_FREQ, 1, 1.0), n.const(BUMP_MIN)),
        n.const(BUMP_EDGE)), 0.0, 1.0), n.const(BUMP_HEIGHT)))
end
-- The world's own height, smooth: the dome and the relief, without the
-- detail and the ledges. The trough is cut from this, so its floor is
-- smooth whatever the ground above it does.
-- The relief FIRST: it is the deeper of the two, and with the depth held
-- first the whole code field reached the ninth buffer.
local function smooth_height()
    return n.add(shape.relief_node(), shape.depth())
end
-- The trough's surface as a terrain field: the smooth height lowered by the
-- valley's depth and put back by the rise. `M.terrain` takes the lesser of
-- itself and this, so the trough cuts and the uplands keep their shape.
function shape.river_valley()
    return n.add(n.add(smooth_height(), n.const(-VALLEY_DEPTH)), rise())
end
-- The water's level as a depth field: positive under it.
local function water_level()
    return n.add(smooth_height(), n.const(-VALLEY_DEPTH))
end
-- The water's level as a WORLD height, for the fluid fill, which reads it
-- per column: the same surface as `water_level`'s zero, solved for y. The
-- relief and the dome read only x and z.
local function level_y()
    return n.add(n.mul(n.add(shape.relief_node(), shape.dome_node()), n.const(1.0 / shape.SCALE)),
        n.const(shape.Y0 - VALLEY_DEPTH / shape.SCALE))
end
shape.RIVER_REACH = RIM + BEYOND                      -- blocks: how far from a course anything of this biome is
shape.RIVER_RIM = RIM
shape.RIVER_BAR = BAR

-- Another biome's field, kept out of the valley: its ferns and grass stood
-- on the river's bed under the water, and in strips across the channel.
-- Only in the modes whose terrain carries the trough (shape.lua,
-- `M.terrain`); elsewhere the field as it was. The field first: the
-- distance is the shallow operand.
function shape.river_exclude(field, blocks_out)
    local mode = shape.terrain_mode or shape.default_mode()
    if mode == "alpine" or mode == "coast" then
        return field
    end
    return n.min(field, n.add(course(), n.const(-blocks_out)))
end

tdw.biomes.river_valleys.spans = { { "temperate", "hem" } }
tdw.biomes.river_valleys.lazy = true                  -- its terms are this file's, and shape.lua loads first
-- Only chunks a course runs near are this biome's: one sample of the
-- distance at the chunk's centre, against its reach plus the chunk's own
-- diagonal. Without it every chunk of six rings would evaluate a terrain
-- and a code field to paint nothing.
local REACH = shape.compile("river.reach", course())
-- Where a river is, for `/tp`: from a start on the river's rings, step
-- straight at the nearest course — the contour distance says how far, its
-- slope which way — until on the line, then back out onto the bank. A
-- start that finds nothing within a few kilometres tries further round.
tdw.biomes.river_valleys.locate = function(px, pz, seed)
    local function dist(x, z)
        return REACH:at(x + 0.5, 0.0, z + 0.5, seed)
    end
    local lo = tdw.layers.ring_by_id.temperate.u[1]
    local r = math.sqrt(px * px + pz * pz)
    local min_r = math.sqrt(lo) * shape.R_DISC * 1000 + RIM + 200
    local starts = {}
    local hx, hz = 1.0, 0.0
    if r > 1 then hx, hz = px / r, pz / r end
    local sr = math.max(r, min_r)
    for k = 0, 8 do
        local d = schem.DIR16[(k % 16) + 1]
        -- Round the player's heading, a sixteenth of a turn at a time.
        local ax = hx * d[1] - hz * d[2]
        local az = hz * d[1] + hx * d[2]
        starts[#starts + 1] = { ax * sr, az * sr }
    end
    for _, start in ipairs(starts) do
        local x, z = start[1], start[2]
        local gx, gz = 1.0, 0.0
        for _ = 1, 16 do
            local d = dist(x, z)
            if d < 2.0 then
                -- On the course: out onto the bank, the way we came.
                local bank = CHANNEL + BANK_W + 2.0
                local bx, bz = x + gx * bank, z + gz * bank
                if math.sqrt(bx * bx + bz * bz) >= min_r - RIM then
                    return math.floor(bx), math.floor(bz)
                end
                break
            end
            if d > 4000 then
                break
            end
            local sx = dist(x + 4, z) - dist(x - 4, z)
            local sz = dist(x, z + 4) - dist(x, z - 4)
            local len = math.sqrt(sx * sx + sz * sz)
            if len < 1e-6 then
                break
            end
            gx, gz = sx / len, sz / len
            x, z = x - gx * d, z - gz * d
        end
    end
    return nil
end
tdw.biomes.river_valleys.present = function(pos)
    local x, z = pos.x * 16 + 8, pos.z * 16 + 8
    return REACH:at(x + 0.5, 0.0, z + 0.5, pos.seed) < shape.RIVER_REACH + 24
end

tdw.build_biome("river_valleys", function(ctx)
    local function masked(field)
        local mask = tdw.biome_mask(n, "river_valleys")
        return mask and n.min(field, mask) or field
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    -- In the valley at all: the one gate every material shares.
    local function inside()
        return n.add(n.mul(course(), n.const(-1.0)), n.const(RIM))
    end
    -- The pools and the riffles.
    local function pool()
        return n.sub(n.noise("river_pool", POOL_FREQ, 2, 1.0), n.const(POOL_MIN))
    end
    local function in_channel()
        return n.add(n.mul(course(), n.const(-1.0)), n.const(CHANNEL))
    end
    local function chain(first, rest)
        local acc = first
        for _, term in ipairs(rest) do acc = n.min(acc, term) end
        return acc
    end
    local conditions = {
        -- 1: the terraces and the valley slopes: soil under turf.
        inside(),
        -- 2: the gravel of the banks and the bars.
        chain(inside(), { n.add(n.mul(course(), n.const(-1.0)), n.const(BAR + BAR * BEND_BIAS)) }),
        -- 3: the moist sand of the wet bank.
        chain(inside(), { n.add(n.mul(course(), n.const(-1.0)), n.const(BAR)) }),
        -- 4: the clay beds along the water line, wet clay. After the sand
        -- (2026-09-14): the sand's band holds the clay's, and as code 3 under
        -- the sand's 4 the clay never showed.
        chain(inside(), { n.add(n.mul(course(), n.const(-1.0)), n.const(CHANNEL + CLAY_HALF)),
            n.add(n.mul(n.abs(water_level()), n.const(-1.0)), n.const(0.003)) }),
        -- 5: bedrock shelves, scoured bare where the flow is fast — the
        -- riffles, and the patches a slow noise picks.
        chain(inside(), { n.add(n.mul(course(), n.const(-1.0)), n.const(BAR)),
            n.min(n.sub(n.noise("river_shelf", SHELF_FREQ, 1, 1.0), n.const(SHELF_MIN)),
                n.mul(pool(), n.const(-1.0))) }),
        -- 6: a spring seep weeping from the valley wall: wet mud.
        chain(inside(), { n.sub(n.noise("river_seep", SEEP_FREQ, 1, 1.0), n.const(SEEP_MIN)),
            n.add(n.mul(course(), n.const(-1.0)), n.const(RIM)),
            n.add(course(), n.const(-TERRACE)) }),
        -- 7: the bed of a riffle, gravel.
        chain(in_channel(), { n.mul(pool(), n.const(-1.0)) }),
        -- 8: the bed of a pool, sand.
        chain(in_channel(), { pool() }),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    local mask = tdw.biome_mask(n, "river_valleys")
    if mask then
        code = n.mul(code, step(mask))
    end
    local depth = shape.compile("biome.river.depth", shape.terrain(false))
    local codes = shape.compile("biome.river.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = SOIL_DEPTH, material = blocks.grass },
        { code = 1, from = SOIL_DEPTH, to = 4 * km, material = blocks.dirt },
        { code = 2, to = 3 * km, material = blocks.creek_bed },
        { code = 3, to = SAND_DEPTH, material = blocks.sand },
        { code = 4, to = 3 * km, material = blocks.wet_clay },
        { code = 5, to = 4 * km, material = blocks.stone },
        { code = 6, to = 3 * km, material = blocks.mud },
        { code = 7, to = 3 * km, material = blocks.creek_bed },
        { code = 8, to = 4 * km, material = blocks.sand },
    }
    -- The cover: iris in the shallows and on the wet bank, mint on the damp
    -- ground behind it, grass over the terraces.
    local function band(from, to)
        return n.min(n.add(n.mul(course(), n.const(-1.0)), n.const(to)), n.add(course(), n.const(-from)))
    end
    local function tufts(name, from, to, freq, min)
        return shape.compile("biome.river." .. name,
            masked(n.min(band(from, to), n.sub(n.noise("river_" .. name, freq, 1, 1.0), n.const(min)))))
    end
    local iris = tufts("iris", CHANNEL - 1.0, BAR + 4.0, IRIS_FREQ, IRIS_MIN)
    local mint = tufts("mint", BAR, TERRACE, MINT_FREQ, MINT_MIN)
    local grass = tufts("grass", BAR, RIM, GRASS_FREQ, GRASS_MIN)
    -- The meadow flowers on the terraces and the valley slopes, past the
    -- mint's band so they never stand on it.
    local lunaria, chamomile = tdw.flower_covers("biome.river", "river_grass", GRASS_FREQ, function(field)
        return masked(n.min(field, band(TERRACE, RIM)))
    end)
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries },
        { cover = blocks.water_iris, cells = 3, take = iris },
        { cover = blocks.wild_mint, cells = 1, take = mint },
        { cover = blocks.tall_grass, cells = 2, take = grass },
        lunaria,
        chamomile,
    }
    if game.schematic and tdw.river_schematics then
        local trees = tdw.river_schematics()
        local function stand(name, field)
            return shape.compile("biome.river.stand_" .. name, masked(field))
        end
        local function scatter(list, field, cell, chance, salt, sink)
            if #list > 0 then
                fills[#fills + 1] = { scatter = true, depth = depth, stand = field, schematics = list,
                    cell = cell, chance = chance, salt = salt, sink = sink }
            end
        end
        -- The willows hug the shoreline; the palms stand back on the
        -- terraces; the drift piles lie on the dry bank and the bars, never
        -- in the water or on the steep bank out of it; the stepping stones
        -- stand in the shallows of the riffles, where the bed is highest.
        scatter(trees.willows, stand("willow", band(CHANNEL + 1.0, BAR + 10.0)), WILLOW_CELL, WILLOW_SQUARES, WILLOW_SALT, 1)
        scatter(trees.palms, stand("palm", band(BAR + 6.0, TERRACE + 20.0)), PALM_CELL, PALM_SQUARES, PALM_SALT, 1)
        scatter(trees.snags, stand("snag", band(CHANNEL + BANK_W, BAR + 6.0)), SNAG_CELL, SNAG_SQUARES, SNAG_SALT, 1)
        scatter(trees.steps, stand("step", n.min(band(CHANNEL - 4.0, CHANNEL - 1.0), n.mul(pool(), n.const(-1.0)))),
            STEP_CELL, STEP_SQUARES, STEP_SALT, 1)
    end
    -- The water, last: after the structures, so it takes the room they
    -- leave. Within the channel and a block past the bank top.
    -- No `lip`: the designer's call (2026-09-14), the engine's fluid is to
    -- keep a river where it is laid.
    fills[#fills + 1] = {
        fluid = WATER,
        level = shape.compile("biome.river.level", level_y()),
        within = shape.compile("biome.river.within",
            masked(n.add(n.mul(course(), n.const(-1.0)), n.const(CHANNEL + BANK_W + 1.0)))),
    }
    return fills
end)
tdw.biomes.river_valleys.soil = blocks.dirt

-- ------------------------------------------------------------ the trees

local FULL = game.OCCUPANCY_FULL
local DIR4 = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- **Every trunk, branch and frond here is a PATH with a thickness**, not a
-- stack of blocks: `schem.push_path` takes a list of points with a radius
-- at each and fills the cells within that radius of the line through them.
-- A trunk tapers because its last point is thinner than its first, a branch
-- leaves at whatever angle its points do, and a frond droops because its
-- points droop. The palms were stacks of blocks with three-block arms
-- stuck on the top, and looked it.
--
-- The geometry is pushed blind into an edit batch and taken back as a list
-- (`edits.take`), which is the same trick the alpine firs use to build a
-- schematic out of the shape code that grows them.
local schematic_of_batch = schem.schematic_of_batch

-- A willow: four stems on a two-by-two footprint, each twisting its own way
-- and the whole leaning, branches arcing out of their tops, a clump of
-- leaves on each, and curtains hung from them — longest on the side the
-- tree leans over, which is the side the water is on.
local function willow(rng)
    edits.begin()
    local tall = 7 + rng:below(4)
    local lean = DIR4[rng:below(4) + 1]
    local tops = {}
    for _, base in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
        local height = tall - rng:below(3)
        local x, z = base[1] + 0.5, base[2] + 0.5
        local points = { { x, -1.0, z, 0.8 } }
        for i = 1, 4 do
            local t = i / 4
            x = x + (rng:below(3) - 1) * 0.4 + lean[1] * t * 0.8
            z = z + (rng:below(3) - 1) * 0.4 + lean[2] * t * 0.8
            points[#points + 1] = { x, -1.0 + t * (height + 1), z, 0.74 - 0.42 * t }
        end
        schem.push_path(blocks.willow_wood, points, { blind = true })
        tops[#tops + 1] = points[#points]
    end
    -- The branches, and what hangs off them.
    for _, top in ipairs(tops) do
        for _ = 1, 1 + rng:below(2) do   -- branches per stem: four stems make a crown between them
            local d = schem.DIR16[rng:below(16) + 1]
            local reach = 2.4 + rng:below(4) * 0.5
            local tip = { top[1] + d[1] * reach, top[2] + 1.0 + rng:below(3) * 0.4, top[3] + d[2] * reach, 0.2 }
            schem.push_path(blocks.willow_wood, {
                { top[1], top[2], top[3], 0.34 },
                { top[1] + d[1] * reach * 0.5, top[2] + 0.9, top[3] + d[2] * reach * 0.5, 0.27 },
                tip,
            }, { blind = true })
            schem.push_ellipsoid(blocks.willow_leaves, tip[1], tip[2], tip[3],
                1.7 + rng:below(3) * 0.3, 1.1, 1.7 + rng:below(3) * 0.3, { rough = 0.3, blind = true })
            -- The curtain: straight down from the branch end, wandering a
            -- little, and longer over the water than away from it.
            local toward = (d[1] * lean[1] + d[2] * lean[2]) > 0
            local drop = (toward and 6 or 3) + rng:below(4)
            local cx, cz = tip[1] + d[1] * 0.4, tip[3] + d[2] * 0.4
            local curtain = { { cx, tip[2] - 0.6, cz, 0.4 } }
            for i = 1, 3 do
                cx = cx + (rng:below(3) - 1) * 0.25
                cz = cz + (rng:below(3) - 1) * 0.25
                curtain[#curtain + 1] = { cx, tip[2] - 0.6 - drop * i / 3, cz, 0.36 - 0.1 * i }
            end
            schem.push_path(blocks.willow_leaves, curtain, { blind = true })
        end
    end
    return schematic_of_batch()
end

-- A palm: one bare stem bowing as it climbs, and a spray of fronds from its
-- crown, each arcing up and out and then drooping at the tip.
local function palm(rng)
    edits.begin()
    local tall = 9 + rng:below(6)
    local lean = DIR4[rng:below(4) + 1]
    local points = {}
    for i = 0, 5 do
        local t = i / 5
        local bow = t * t * (1.2 + rng:below(3) * 0.3)
        points[#points + 1] = { 0.5 + lean[1] * bow, -1.0 + t * (tall + 1), 0.5 + lean[2] * bow,
            0.66 - 0.28 * t }
    end
    schem.push_path(blocks.willow_wood, points, { blind = true })
    local tip = points[#points]
    local fronds = 7 + rng:below(3)
    for f = 1, fronds do
        local d = schem.DIR16[(f * 16 // fronds + rng:below(2)) % 16 + 1]
        local reach = 3.0 + rng:below(5) * 0.4
        schem.push_path(blocks.oak_leaves, {
            { tip[1], tip[2], tip[3], 0.5 },
            { tip[1] + d[1] * reach * 0.4, tip[2] + 1.0, tip[3] + d[2] * reach * 0.4, 0.45 },
            { tip[1] + d[1] * reach * 0.8, tip[2] + 0.7, tip[3] + d[2] * reach * 0.8, 0.32 },
            { tip[1] + d[1] * reach, tip[2] - 1.2, tip[3] + d[2] * reach, 0.18 },
        }, { blind = true })
    end
    return schematic_of_batch()
end

-- A drift pile: dead wood lying IN the ground, not over it. The root is the
-- surface block (the scatter sinks it one), so a trunk whose line runs at
-- y 0.1 to 0.35 has its lower half in that block's ground; each trunk dips
-- to its far end, so on a slope it digs in rather than sticking out; and
-- they are short, so a slope never has far to fall away under one. A
-- second trunk may lie across the first, a little higher.
local function snag(rng)
    edits.begin()
    local logs = 1 + rng:below(3)
    for i = 1, logs do
        local d = schem.DIR16[rng:below(16) + 1]
        local length = 2 + rng:below(3)
        local ox, oz = rng:below(3) - 1 + 0.5, rng:below(3) - 1 + 0.5
        local y = 0.1 + (i - 1) * 0.35
        schem.push_path(blocks.dead_wood, {
            { ox - d[1] * length * 0.5, y, oz - d[2] * length * 0.5, 0.42 },
            { ox + d[1] * length * 0.5, y - 0.45, oz + d[2] * length * 0.5, 0.32 },
        }, { blind = true })
    end
    return schematic_of_batch()
end

-- A stepping stone: a column of scoured rock from the bed of a riffle up
-- through the water, its top a block or so clear of it.
local function stepping_stone(tall)
    local list = {}
    for dy = 0, tall - 1 do
        list[#list + 1] = { 0, dy, 0, blocks.stone, FULL }
    end
    return game.schematic(list)
end

-- Built once and kept: the scatter asks for them per mode, and cutting a
-- willow out of cells eight times over is work nobody needs done twice.
local BUILT = nil
function tdw.river_schematics()
    if BUILT then
        return BUILT
    end
    local out = { willows = {}, palms = {}, snags = {}, steps = {} }
    if not game.schematic then
        return out
    end
    local function rng_for(name)
        return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "river_template:" .. name)
    end
    for i = 1, WILLOW_TEMPLATES do out.willows[i] = willow(rng_for("willow:" .. i)) end
    for i = 1, PALM_TEMPLATES do out.palms[i] = palm(rng_for("palm:" .. i)) end
    for i = 1, 5 do out.snags[i] = snag(rng_for("snag:" .. i)) end
    out.steps[1] = stepping_stone(3)
    out.steps[2] = stepping_stone(4)
    local total = 0
    for _, list in pairs(out) do
        for _, one in ipairs(list) do total = total + one:len() end
    end
    game.log(string.format("tiamot_default_world river: %d willows, %d palms, %d snags — %d blocks of schematic in all",
        #out.willows, #out.palms, #out.snags, total))
    BUILT = out
    return out
end

-- NOT built at load. Cutting a tree out of cells is tens of thousands of
-- operations and the registration window's instruction budget is a good
-- deal smaller than a generator call's; the first valley builds them, once,
-- and the memo above keeps them.

