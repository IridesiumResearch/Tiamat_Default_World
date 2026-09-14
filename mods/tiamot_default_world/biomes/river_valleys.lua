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
-- midstream bars, stepping stones across the shallows, and spring seeps
-- weeping from the valley walls.
--
-- THE COURSE is one line: the zero contour of a slow 2D noise, read through
-- the engine's `contour` node as a distance in blocks. Everything reads that
-- one distance — the trough's profile, which materials go where, where a
-- willow may stand — so nothing disagrees with anything at any height, and
-- the line meanders because a noise's contour does.
--
-- THE WATER is the water BLOCK, not the fluid, exactly as the alpine lakes
-- are: the channel's GROUND is carved to the water's own height and the
-- layered fill paints the top blocks of it as water. A fluid would have to
-- be flat, and a river that runs across a 2.5 km dome cannot be; a block
-- takes whatever height the valley floor has, and because a block's height
-- is an integer the surface comes out as a staircase of one-block steps —
-- which, with the riffles laid on the steps, is what a river does anyway.
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
local CHANNEL = 9.0                                   -- blocks: the water's half-width
local BAR = 17.0                                      -- to the top of the gravel bank and the point bars
local TERRACE = 58.0                                  -- the floodplain terrace's outer edge
local RIM = 150.0                                     -- the valley rim
local BEYOND = 24.0                                   -- blocks past the rim over which the trough stops biting at all
local BAR_RISE = 0.002                                -- km: the bank stands two blocks over the water
local TERRACE_RISE = 0.006                            -- six more to the terrace
local RIM_RISE = 0.018                                -- eighteen more to the rim
local VALLEY_DEPTH = BAR_RISE + TERRACE_RISE + RIM_RISE   -- how far under the uplands the water sits
-- The bends: a slow noise along the course decides which bank is the
-- undercut bluff and which is the point bar. Times the SIGNED distance it
-- is positive on the bar's side, and the bank's width is stretched there
-- and squeezed on the bluff's.
local BEND_FREQ = 1 / 420
local BEND_BIAS = 0.55                                -- how much wider a point bar is than a bluff
-- Pools and riffles: a noise along the course, deep and slow where it is
-- high, shallow and stony where it is low.
local POOL_FREQ = 1 / 90
local POOL_MIN = 0.02
local POOL_DEPTH = 0.005                              -- km: five blocks of water in a pool
local RIFFLE_DEPTH = 0.001                            -- one over a riffle
-- The materials.
local CLAY_HALF = 4.0                                 -- blocks either side of the water's edge the clay beds hold
local SHELF_FREQ = 1 / 140
local SHELF_MIN = 0.16                                -- where the bedrock is scoured bare
local SEEP_FREQ = 1 / 55
local SEEP_MIN = 0.30                                 -- springs weeping from the valley walls
local SAND_DEPTH = 0.004
local SOIL_DEPTH = 0.002
-- The cover.
local IRIS_FREQ, IRIS_MIN = 1.4, 0.10                 -- dense, in the shallows and on the wet bank
local MINT_FREQ, MINT_MIN = 1.4, 0.28
local GRASS_FREQ, GRASS_MIN = 1.5, 0.22
-- The trees.
local WILLOW_CELL, WILLOW_SQUARES, WILLOW_SALT = 5, 0.55, 41
local PALM_CELL, PALM_SQUARES, PALM_SALT = 11, 0.30, 42
local SNAG_CELL, SNAG_SQUARES, SNAG_SALT = 9, 0.35, 43
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
-- How far the ground stands over the water at a distance from the line:
-- nothing in the channel, the bank, the terrace, the rim, and then a great
-- deal so the trough stops biting into the uplands at all.
local function rise()
    -- The bank's width swings with the bend: wide where the point bar is,
    -- narrow where the bluff is undercut.
    local bar = n.add(n.const(BAR), n.mul(bend(), n.const(BAR * BEND_BIAS)))
    local bank = n.mul(n.clamp(n.div(n.add(course(), n.const(-CHANNEL)), n.add(bar, n.const(-CHANNEL))), 0.0, 1.0),
        n.const(BAR_RISE))
    local acc = n.add(bank, ramp(BAR, TERRACE, TERRACE_RISE))
    acc = n.add(acc, ramp(TERRACE, RIM, RIM_RISE))
    return n.add(acc, ramp(RIM, RIM + BEYOND, 1.0))
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
-- The water's own surface, as a terrain field: the channel's floor is
-- carved to it, and the layered fill paints the top blocks water.
local function water_level()
    return n.add(smooth_height(), n.const(-VALLEY_DEPTH))
end
shape.RIVER_REACH = RIM + BEYOND                      -- blocks: how far from a course anything of this biome is

tdw.biomes.river_valleys.spans = { { "temperate", "hem" } }
tdw.biomes.river_valleys.lazy = true                  -- its terms are this file's, and shape.lua loads first
-- Only chunks a course runs near are this biome's: one sample of the
-- distance at the chunk's centre, against its reach plus the chunk's own
-- diagonal. Without it every chunk of six rings would evaluate a terrain
-- and a code field to paint nothing.
local REACH = shape.compile("river.reach", course())
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
    -- y in km, as the terrain has it, and the water's height there.
    local function ys()
        return n.mul(n.sub(n.Y(), n.const(shape.Y0)), n.const(shape.SCALE))
    end
    -- Positive where the block is within `km` under the water's surface.
    -- `water_level` is a DEPTH field (larger is lower), so the height of the
    -- water is where it crosses zero: y is below the surface where
    -- water_level(y) > 0.
    -- Written as a BAND — `half - |below - mid|` — and left-leaning, so the
    -- water's own level is evaluated once and with nothing held: as a pair
    -- of tests it was evaluated twice, and the code field came to ten live
    -- buffers against the engine's eight.
    local function under_water(km)
        local mid, half = km / 2, km / 2
        return n.mul(n.sub(n.abs(n.sub(water_level(), n.const(mid))), n.const(half)), n.const(-1.0))
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
        -- 3: the clay beds along the water line.
        chain(inside(), { n.add(n.mul(course(), n.const(-1.0)), n.const(CHANNEL + CLAY_HALF)),
            n.add(n.mul(n.abs(water_level()), n.const(-1.0)), n.const(0.003)) }),
        -- 4: the moist sand of the bed and the wet bank.
        chain(inside(), { n.add(n.mul(course(), n.const(-1.0)), n.const(BAR)) }),
        -- 5: bedrock shelves, scoured bare where the flow is fast — the
        -- riffles, and the patches a slow noise picks.
        chain(inside(), { n.add(n.mul(course(), n.const(-1.0)), n.const(BAR)),
            n.min(n.sub(n.noise("river_shelf", SHELF_FREQ, 1, 1.0), n.const(SHELF_MIN)),
                n.mul(pool(), n.const(-1.0))) }),
        -- 6: a spring seep weeping from the valley wall.
        chain(inside(), { n.sub(n.noise("river_seep", SEEP_FREQ, 1, 1.0), n.const(SEEP_MIN)),
            n.add(n.mul(course(), n.const(-1.0)), n.const(RIM)),
            n.add(course(), n.const(-TERRACE)) }),
        -- 7: the water of a riffle, one block of it over the gravel.
        chain(in_channel(), { under_water(RIFFLE_DEPTH), n.mul(pool(), n.const(-1.0)) }),
        -- 8: the water of a pool, five blocks deep.
        chain(in_channel(), { under_water(POOL_DEPTH), pool() }),
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
        { code = 3, to = 3 * km, material = blocks.mud },
        { code = 4, to = SAND_DEPTH, material = blocks.sand },
        { code = 5, to = 4 * km, material = blocks.stone },
        { code = 6, to = 1 * km, material = blocks.water },
        { code = 6, from = 1 * km, to = 3 * km, material = blocks.mud },
        { code = 7, to = RIFFLE_DEPTH, material = blocks.water },
        { code = 7, from = RIFFLE_DEPTH, to = 3 * km, material = blocks.creek_bed },
        { code = 8, to = POOL_DEPTH, material = blocks.water },
        { code = 8, from = POOL_DEPTH, to = 4 * km, material = blocks.sand },
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
    local iris = tufts("iris", CHANNEL - 3.0, BAR + 4.0, IRIS_FREQ, IRIS_MIN)
    local mint = tufts("mint", BAR, TERRACE, MINT_FREQ, MINT_MIN)
    local grass = tufts("grass", BAR, RIM, GRASS_FREQ, GRASS_MIN)
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries },
        { cover = blocks.water_iris, cells = 3, take = iris },
        { cover = blocks.wild_mint, cells = 1, take = mint },
        { cover = blocks.tall_grass, cells = 2, take = grass },
    }
    if game.schematic and tdw.river_schematics then
        local trees = tdw.river_schematics()
        local function stand(name, from, to)
            return shape.compile("biome.river.stand_" .. name, masked(band(from, to)))
        end
        local function scatter(list, field, cell, chance, salt, sink)
            if #list > 0 then
                fills[#fills + 1] = { scatter = true, depth = depth, stand = field, schematics = list,
                    cell = cell, chance = chance, salt = salt, sink = sink }
            end
        end
        -- The willows hug the shoreline; the palms stand back on the
        -- terraces; the snags and drift jams lodge on the bars, and the
        -- stepping stones lie in the shallows.
        scatter(trees.willows, stand("willow", CHANNEL + 1.0, BAR + 10.0), WILLOW_CELL, WILLOW_SQUARES, WILLOW_SALT, 1)
        scatter(trees.palms, stand("palm", BAR + 6.0, TERRACE + 20.0), PALM_CELL, PALM_SQUARES, PALM_SALT, 1)
        scatter(trees.snags, stand("snag", CHANNEL - 2.0, BAR), SNAG_CELL, SNAG_SQUARES, SNAG_SALT, 0)
        scatter(trees.steps, stand("step", CHANNEL - 6.0, CHANNEL + 1.0), STEP_CELL, STEP_SQUARES, STEP_SALT, 0)
    end
    return fills
end)
tdw.biomes.river_valleys.soil = blocks.dirt

-- ------------------------------------------------------------ the trees

local FULL = game.OCCUPANCY_FULL
local CENTRE = (1 << 4) | (1 << 13) | (1 << 22)       -- the middle cell column: a stem a cell thick
local PLUS = 0
for cy = 0, 2 do
    for _, c in ipairs({ { 1, 1 }, { 0, 1 }, { 2, 1 }, { 1, 0 }, { 1, 2 } }) do
        PLUS = PLUS | schem.bit(c[1], cy, c[2])
    end
end
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
local function schematic_of_batch()
    local out = {}
    for _, e in ipairs(edits.take()) do
        local at, material, mask = e[1], e[2], e[3]
        local id = type(material) == "number" and material or game.get_block_id(material)
        out[#out + 1] = { at.x, at.y, at.z, id, mask or FULL }
    end
    return game.schematic(out)
end

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

-- A snag or a drift jam: dead wood lying on a bar, a few trunks across one
-- another and a tangle of branches.
local function snag(rng)
    edits.begin()
    for _ = 1, 2 + rng:below(3) do
        local d = schem.DIR16[rng:below(16) + 1]
        local length = 3 + rng:below(5)
        local ox, oz = rng:below(3) - 1 + 0.5, rng:below(3) - 1 + 0.5
        local y = 0.3 + rng:below(2) * 0.6
        schem.push_path(blocks.dead_wood, {
            { ox, y, oz, 0.45 },
            { ox + d[1] * length, y - 0.2, oz + d[2] * length, 0.3 },
        }, { blind = true })
    end
    return schematic_of_batch()
end

-- A stepping stone: one block of scoured rock standing just clear of the
-- water, for crossing a shallow.
local function stepping_stone()
    return game.schematic({ { 0, 0, 0, blocks.stone, FULL } })
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
    out.steps[1] = stepping_stone()
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
