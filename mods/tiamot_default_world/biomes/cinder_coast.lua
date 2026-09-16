-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.5 Cinder Coast: the Ember Ridge's shores (2026-09-16) — "the volcanic
-- foothills needs to be broken up with some oceans".
--
-- The ridge has a sea lane now (seas.lua, 21.0 to 22.8 km), and where the
-- basalt meets it: black sand beaches glittering with glass, faces of dark
-- basalt glazed with obsidian, pavements of lava rock in the shallows,
-- basalt sea stacks standing off the shore in columns, black boulders on
-- the sand, and sulfur at the tide line puffing steam.
--
-- Its ground is the plain shore profile on the ridge's own terms (the
-- "ember_shore" programs, shape.lua): the floor, the face, the terrace and
-- the ledge. It paints the shore and the shelf, as the Coastal Cliffs do
-- everywhere else, and the cliffs keep off the ridge (`shape.off_cinder`).
-- Past the shelf is the Deep Ocean's. New node: `black_sand`.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local seas = tdw.seas
local n = shape.node
local ID = "cinder_coast"

local CINDER_U = { shape.EMBER_U[1] - 0.008, shape.GLASS_U[1] }  -- the ridge on the wobbled radius, from 20.2 km: the lane's inner shores wobble under the ridge's edge (lane 1's coast is at 19.1)
local SHORE_LAND = 24.0                                  -- blocks inland this biome's ground reaches
local BEACH_IN, BEACH_TOP = 30.0, 0.006                  -- the sand: within this of the line, to this over the sea
local GLAZE_FREQ, GLAZE_MIN = 1 / 20, 0.10               -- obsidian glaze on the faces
local PAVE_FREQ, PAVE_MIN = 1 / 50, 0.15                 -- lava rock pavements in the shallows
local VENT_FREQ, VENT_MIN, VENT_HALF = 1 / 9, 0.38, 0.003 -- sulfur within three blocks of the sea
local STACK_CELL, STACK_SQUARES = 26, 0.30
local BOULDER_CELL, BOULDER_SQUARES = 14, 0.30

-- The ridge's band, 0 to 1 over a few hundred blocks at its edges.
local function band()
    return n.clamp(n.mul(shape.ring(CINDER_U[1], CINDER_U[2]), n.const(1.0 / 0.004)), 0.0, 1.0)
end
-- For the Coastal Cliffs: positive off the ridge.
function shape.off_cinder()
    return n.sub(n.const(0.5), band())
end
tdw.cinder_u = { CINDER_U[1] - 0.004, CINDER_U[2] + 0.004 }

-- Whether (x, z) is this biome's, for the HUD: the band alone.
function tdw.cinder_zone(x, z)
    local only = tdw.config.everywhere
    if only then
        return only == ID and ID or nil
    end
    local u = (x * x + z * z) * 1e-6 / (shape.R_DISC * shape.R_DISC)
    if u >= CINDER_U[1] and u <= CINDER_U[2] then
        return ID
    end
    return nil
end

tdw.biomes[ID].ring_mode = "ember"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.dark_basalt
tdw.biomes[ID].present = function(pos)
    local class = seas.class(pos)
    if class ~= "shore" and class ~= "deep" then
        return false
    end
    local x, z = pos.x * 16 + 8, pos.z * 16 + 8
    local u = (x * x + z * z) * 1e-6 / (shape.R_DISC * shape.R_DISC)
    local w = shape.wobble(u) + 0.004
    return u >= CINDER_U[1] - w and u <= CINDER_U[2] + w
end
tdw.biomes[ID].locate = function(px, pz, seed)
    return seas.locate(px, pz, seed, -40.0, -6.0, CINDER_U[1], CINDER_U[2])
end

-- ------------------------------------------------------------ the structures

local ROUGH = { rough = 0.3, blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "cinder_template:" .. name)
end
local PRIORITY = { [blocks.dark_basalt] = 1, [blocks.obsidian] = 1 }

-- A sea stack: three to five basalt columns bundled, the tallest nine to
-- sixteen blocks, standing out of the water.
local function stack(rng)
    schem.record_begin()
    local tall = 9 + rng:below(8)
    for i = 0, 2 + rng:below(3) do
        local d = schem.DIR16[(i * 5 + rng:below(3)) % 16 + 1]
        local off = i == 0 and 0 or 0.9
        local h = tall - i * (1 + rng:below(3))
        schem.push_path(blocks.dark_basalt, { { 0.5 + d[1] * off, -12.0, 0.5 + d[2] * off, 0.75 }, { 0.5 + d[1] * off, h, 0.5 + d[2] * off, 0.62 } }, { blind = true })
    end
    return schem.record_schematic(PRIORITY)
end
-- A black boulder, glazed.
local function boulder(rng)
    schem.record_begin()
    local r = 0.9 + rng:below(4) * 0.3
    schem.push_ellipsoid(blocks.dark_basalt, 0.5, r * 0.2, 0.5, r, r * 0.7, r * 0.85, ROUGH)
    if rng:below(2) == 0 then
        schem.push_ellipsoid(blocks.obsidian, 0.5, r * 0.6, 0.5, r * 0.5, r * 0.35, r * 0.5, ROUGH)
    end
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { stacks = {}, boulders = {} }
    if game.schematic_shapes then
        for i = 1, 5 do out.stacks[i] = stack(rng_for("stack:" .. i)) end
        for i = 1, 4 do out.boulders[i] = boulder(rng_for("boulder:" .. i)) end
    end
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

tdw.build_biome(ID, function(ctx)
    local function ys()
        return n.mul(n.sub(n.Y(), n.const(shape.Y0)), n.const(shape.SCALE))
    end
    local function over_sea()
        return n.sub(ys(), seas.level())
    end
    -- Blocks from the coastline, positive on land.
    local function shore()
        return n.mul(seas.d(), n.const(-1.0))
    end
    local function landward()
        return n.sub(n.clamp(n.mul(shore(), n.const(2.0)), 0.0, 1.0), n.const(0.5))
    end
    local function seaward()
        return n.sub(n.const(0.5), n.clamp(n.mul(shore(), n.const(2.0)), 0.0, 1.0))
    end
    local function zone()
        local reach = n.min(n.sub(n.const(seas.SHELF_END), seas.d_map()), n.add(seas.d_map(), n.const(SHORE_LAND)))
        return n.min(reach, n.sub(band(), n.const(0.5)))
    end
    local function masked(field)
        return n.min(field, zone())
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    local function beach()
        local gate = n.min(landward(), n.sub(n.const(BEACH_IN), shore()))
        return n.min(gate, n.sub(n.const(BEACH_TOP), over_sea()))
    end
    local conditions = {
        -- 1: basalt: the faces and the land behind.
        n.const(1.0),
        -- 2: obsidian glaze on the faces, above the sand.
        n.min(landward(), n.sub(n.noise("cc_glaze", GLAZE_FREQ, 2, 1.0), n.const(GLAZE_MIN))),
        -- 3: volcanic ash on the land behind the face.
        n.min(landward(), n.sub(shore(), n.const(10.0))),
        -- 4: the beaches, and the shelf's floor: black sand.
        n.max(beach(), seaward()),
        -- 5: lava rock pavements in the shallows.
        n.min(seaward(), n.sub(n.noise("cc_pave", PAVE_FREQ, 1, 1.0), n.const(PAVE_MIN))),
        -- 6: sulfur at the tide line.
        n.min(n.min(landward(), n.sub(n.const(VENT_HALF), n.abs(over_sea()))), n.sub(n.noise("cc_vent", VENT_FREQ, 1, 1.0), n.const(VENT_MIN))),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    code = n.mul(code, step(zone()))
    local depth = shape.compile("biome.cinder.depth", shape.terrain(false))
    local codes = shape.compile("biome.cinder.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 12 * km, material = blocks.dark_basalt },
        { code = 2, to = 2 * km, material = blocks.obsidian },
        { code = 2, from = 2 * km, to = 12 * km, material = blocks.dark_basalt },
        { code = 3, to = 2 * km, material = blocks.volcanic_ash },
        { code = 3, from = 2 * km, to = 12 * km, material = blocks.dark_basalt },
        { code = 4, to = 4 * km, material = blocks.black_sand },
        { code = 4, from = 4 * km, to = 12 * km, material = blocks.dark_basalt },
        { code = 5, to = 3 * km, material = blocks.lava_rock },
        { code = 5, from = 3 * km, to = 12 * km, material = blocks.dark_basalt },
        { code = 6, to = 1 * km, material = blocks.sulfur },
        { code = 6, from = 1 * km, to = 12 * km, material = blocks.dark_basalt },
    }
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, sink, above)
            fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                salt = salt, sink = sink, above = above, stand = shape.compile("biome.cinder.stand_" .. name, masked(field)) }
        end
        -- Stacks a few blocks under the water, off the beach.
        scatter("stack", built.stacks, n.min(n.sub(n.const(-0.002), over_sea()), n.add(over_sea(), n.const(0.012))), STACK_CELL, STACK_SQUARES, 251, 1, 0.020)
        scatter("boulder", built.boulders, beach(), BOULDER_CELL, BOULDER_SQUARES, 252, 1, 0.004)
    end
    return fills
end)
