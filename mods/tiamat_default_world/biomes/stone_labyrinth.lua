-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.1 Stone Labyrinth (2026-09-26), the first of the dark caves.
--
-- A dense grid of narrow rectangular passages, three to five wide and four
-- to six high, turning at right angles, stopping dead, and stacked in
-- levels a dozen blocks apart with shafts between them, so nothing is in
-- sight past a turn or two. Chiselled dark stone with flat sheared faces;
-- a slab floor with stone dust in the seams; black lichen in the corners
-- and petrified tendrils hanging out of the ceiling's fractures; square
-- pillars standing in rows where the grid opens into a hall; heaps of
-- sheared rubble; horizontal grooves cut along the walls.
--
-- THE GRID is two families of planes. A noise stretched a thousandfold in
-- y and z varies in x alone, so its zero crossings are vertical planes
-- x = const, irregularly spaced; the passages along z are the slabs within
-- half a width of them, and the passages along x the same from a noise in
-- z alone. Their faces are planes, which is the sheared look, and their
-- crossings are the right-angle turns. A third noise along each passage
-- (stretched across it, so one passage reads one value) cuts it into
-- segments: dead ends. THE LEVELS are the zero crossings of a noise in y
-- alone, every dozen blocks or so, each a slab four to six tall; the
-- same grid runs through every level, and the segments differ between
-- them because their noise reads y a little. SHAFTS drop through a
-- level's floor at a few crossings. THE HALLS: where a slow noise says, a
-- level is cut open except the cores of the grid's cells — square pillars
-- in rows. THE GROOVES: thin horizontal slots a block into the walls, at
-- the zero crossings of a fine noise in y.
--
-- Materials: `slate` banded with `dark_basalt` for the walls and the slab
-- floor, `volcanic_ash` for the dust, `charcoal` for the black lichen. **No
-- new block.** The brief asks for near-total absence of life, and gets it.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "stone_labyrinth"
local FLAT = tdw.caves.DEEP_FLAT                     -- varies in x and z: flat in y all the way to y = 0.5 (caves.lua)
local ALONG_X = { y = 1000, z = 1000 }                 -- varies in x alone
local ALONG_Z = { x = 1000, y = 1000 }                 -- varies in z alone
local ALONG_Y = { x = 1000, z = 1000 }                 -- varies in y alone
-- A one-octave noise near its zero crossing climbs about one unit in
-- 0.625 / frequency blocks (the crystal veins' K, caves.lua): so |n| * K is
-- roughly the distance in blocks to the crossing.
local function k_of(freq) return 0.625 / freq end

local STOREYS = { 1.95, 2.55, 3.15, 3.70 }             -- km under the dome
local STOREY_WANDER = 0.06
local ZH = 28.0                                        -- blocks either side of a storey's centre: five levels or so
local GRID_FREQ, HALF_W = 1 / 13, 2.0                  -- passages 3 to 5 wide, 5 to 10 apart
local SEG_FREQ, SEG_MIN = 1 / 16, -0.10                -- a passage runs where this is over its min: about 60% of it
local LEVEL_FREQ, HALF_H = 1 / 24, 2.5                 -- a level every dozen blocks, 4 to 6 tall
local SHAFT_FREQ, SHAFT_MIN = 1 / 11, 0.33             -- shafts at a crossing in eight or so
local HALL_FREQ, HALL_MIN, PILLAR_OFF = 1 / 70, 0.33, 2.6   -- halls where the grid opens; pillars clear of the lines by this
local GROOVE_FREQ, GROOVE_W, GROOVE_REACH = 1 / 9, 0.5, 1.2
local STRATA_FREQ, STRATA_MIN = 1 / 10, 0.10           -- dark basalt bands in the slate
local DUST_FREQ, DUST_MIN = 1 / 7, 0.0
local LICHEN_REACH = 0.8                               -- blocks from a wall
local RUBBLE_CELL, RUBBLE_SQUARES = 9, 0.22
local TENDRIL_CELL, TENDRIL_SQUARES = 5, 0.10

-- ------------------------------------------------------------ the structures

local FULL = game.OCCUPANCY_FULL
-- The bottom two thirds of a block: the cells of rows y = 0 and 1.
local LOWER = 0
for z = 0, 2 do for y = 0, 1 do for x = 0, 2 do LOWER = LOWER | (1 << (x + 3 * y + 9 * z)) end end end
local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "stone_labyrinth_template:" .. name)
end
-- A heap of sheared rubble: three to six blocks of slate and basalt in a
-- low pile, the odd one a slab, filling most of a passage's width.
local function rubble(rng)
    schem.record_begin()
    local spots = { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 } }
    local count = 3 + rng:below(4)
    for i = 1, count do
        local s = spots[i]
        local material = rng:below(3) == 0 and blocks.dark_basalt or blocks.slate
        schem.push_cells(material, s[1], 1, s[2], rng:below(3) == 0 and LOWER or FULL)
    end
    if count >= 4 then
        schem.push_cells(blocks.slate, 0, 2, 0, rng:below(2) == 0 and LOWER or FULL)
    end
    return schem.record_schematic({})
end
-- A petrified tendril: a withered vine turned to stone, a block or two
-- long, hanging crooked out of a crack in the ceiling.
local function tendril(rng)
    schem.record_begin()
    local d = schem.DIR16[rng:below(16) + 1]
    local len = 1.0 + rng:below(4) * 0.3
    schem.push_path(blocks.dark_basalt, { { 0.5, 0.95, 0.5, 0.12 }, { 0.5 + d[1] * 0.3, 0.95 - len * 0.6, 0.5 + d[2] * 0.3, 0.09 },
        { 0.5 - d[1] * 0.1, 0.95 - len, 0.5 - d[2] * 0.1, 0.07 } }, BLIND)
    return schem.record_schematic({})
end
local BUILT = nil
local function structures()
    if BUILT then return BUILT end
    BUILT = { rubble = {}, tendrils = {} }
    if game.schematic_shapes then
        for i = 1, 6 do BUILT.rubble[i] = rubble(rng_for("rubble:" .. i)) end
        for i = 1, 5 do BUILT.tendrils[i] = tendril(rng_for("tendril:" .. i)) end
    end
    return BUILT
end

-- ------------------------------------------------------------ the fields

local function centre(k)
    return n.add(n.noise("sl_storey" .. k, 1 / 900, 1, 2.0 * STOREY_WANDER, FLAT), n.const(STOREYS[k]))
end

tdw.cave_biome(ID, { -1, -0.15 }, function(ctx)
    local caves = ctx.caves
    -- Blocks from the passage lines, each family: |n| * K.
    local function dist_x()
        return n.mul(n.abs(n.noise("sl_grid_x", GRID_FREQ, 1, 1.0, ALONG_X)), n.const(k_of(GRID_FREQ)))
    end
    local function dist_z()
        return n.mul(n.abs(n.noise("sl_grid_z", GRID_FREQ, 1, 1.0, ALONG_Z)), n.const(k_of(GRID_FREQ)))
    end
    -- The passages: within HALF_W of a line, where its segment noise runs.
    -- The segments stretch across their passage (x for the passages along
    -- z) so one passage reads one value, and a little in y so the levels
    -- differ.
    local seg_k = k_of(SEG_FREQ)
    local along_z = n.min(n.sub(n.const(HALF_W), dist_x()),
        n.mul(n.sub(n.noise("sl_seg_z", SEG_FREQ, 1, 1.0, { x = 4, y = 3 }), n.const(SEG_MIN)), n.const(seg_k)))
    local along_x = n.min(n.sub(n.const(HALF_W), dist_z()),
        n.mul(n.sub(n.noise("sl_seg_x", SEG_FREQ, 1, 1.0, { z = 4, y = 3 }), n.const(SEG_MIN)), n.const(seg_k)))
    local passages = n.max(along_z, along_x)
    -- The levels: slabs about the zero crossings of a noise in y alone.
    local level = n.sub(n.const(HALF_H), n.mul(n.abs(n.noise("sl_level", LEVEL_FREQ, 1, 1.0, ALONG_Y)), n.const(k_of(LEVEL_FREQ))))
    -- The halls: a level opened out wherever a line is near, leaving the
    -- cores of the grid's cells standing as pillars.
    local near_line = n.max(n.sub(n.const(PILLAR_OFF), dist_x()), n.sub(n.const(PILLAR_OFF), dist_z()))
    local hall = n.min(n.min(n.mul(n.sub(n.noise("sl_hall", HALL_FREQ, 1, 1.0, FLAT), n.const(HALL_MIN)), n.const(40.0)), near_line), level)
    -- The grooves: thin slots a block into the walls, near a level.
    local groove = n.min(n.min(n.sub(n.const(GROOVE_W), n.mul(n.abs(n.noise("sl_groove", GROOVE_FREQ, 1, 1.0, ALONG_Y)), n.const(k_of(GROOVE_FREQ)))),
        n.add(passages, n.const(GROOVE_REACH))), n.add(level, n.const(2.0)))
    -- The shafts: at a crossing, where a flat noise says, through the storey.
    local shaft = n.min(n.min(n.sub(n.const(HALF_W), dist_x()), n.sub(n.const(HALF_W), dist_z())),
        n.mul(n.sub(n.noise("sl_shaft", SHAFT_FREQ, 1, 1.0, FLAT), n.const(SHAFT_MIN)), n.const(k_of(SHAFT_FREQ))))
    local v = n.max(n.max(n.max(n.min(passages, level), hall), groove), shaft)
    -- The storeys: within ZH of one's wandering centre. The depth FIRST.
    local zone = nil
    for k = 1, #STOREYS do
        local z = n.sub(n.const(ZH), n.abs(n.mul(n.sub(caves.D(), centre(k)), n.const(1000.0))))
        zone = zone and n.max(zone, z) or z
    end
    local void = ctx.mine(n.min(zone, v))
    local carve = ctx.compile("carve", void)
    local function step(f) return n.clamp(n.mul(f, n.const(1e4)), 0.0, 1.0) end
    local conditions = {
        n.const(1.0),                                                                          -- 1 slate
        n.sub(n.noise("sl_strata", STRATA_FREQ, 1, 1.0, ALONG_Y), n.const(STRATA_MIN)),        -- 2 basalt bands
    }
    local code = n.const(0.0)
    for k, c in ipairs(conditions) do
        code = n.max(code, n.mul(step(c), n.const(k)))
    end
    local depth = ctx.compile("depth", n.mul(void, n.const(-1.0)))
    local fills = {
        { layers = true, depth = depth, code = ctx.compile("codes", code), entries = {
            { code = 1, to = 3.0, material = blocks.slate },
            { code = 2, to = 3.0, material = blocks.dark_basalt },
        } },
        { carve = carve },
        -- The black lichen, flush in the corners where a floor meets a wall;
        -- then the dust over the rest of the slabs, in the seams' patches.
        -- (In a hall the passages' value runs negative away from the lines;
        -- the second term keeps the lichen to the pillars' feet there.)
        { cover = blocks.charcoal, cells = 1, take = ctx.compile("take_lichen",
            ctx.mine(n.min(n.sub(n.const(LICHEN_REACH), passages), n.add(passages, n.const(3.0))))) },
        { cover = blocks.volcanic_ash, cells = 1, take = ctx.compile("take_dust",
            ctx.mine(n.sub(n.noise("sl_dust", DUST_FREQ, 1, 1.0, FLAT), n.const(DUST_MIN)))) },
    }
    if game.schematic_shapes then
        local built = structures()
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.rubble, cell = RUBBLE_CELL, chance = RUBBLE_SQUARES, salt = 471, sink = 1,
            stand = ctx.compile("stand_rubble", ctx.mine(n.const(1.0))) }
        -- The tendrils hang from ceilings: the depth positive in the VOID.
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.tendrils, cell = TENDRIL_CELL, chance = TENDRIL_SQUARES, salt = 472, sink = 0,
            stand = ctx.compile("stand_tendrils", ctx.mine(n.const(1.0))) }
    end
    return fills
end)
