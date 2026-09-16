-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.9 Abyssal Trench: a province of the deep floors (2026-09-16).
--
-- Where the Deep Ocean is plains and guyots, this is the floor torn open:
-- a rift a couple of hundred blocks across, its walls of black basalt
-- falling away to a slot as deep again, and along a line in its floor the
-- vents — black smoker chimneys up to twenty blocks tall, crusted in
-- sulfur and glowing at the throat, a crust of barnacles round their feet,
-- glowing magma mats, and glowing polyps scattered over the dark mud where
-- no light has ever reached.
--
-- Its terms (`shape.abyss_terms`) cut into the Deep Ocean's floor in the
-- coast's `shape.sea_deep`, weighted by this province and by the shelf's
-- blend, so no rift reaches the shelf. The Deep Ocean keeps off it
-- (`shape.off_abyss`). New node: `glow_polyp`. The worm fields round the
-- vents are a barnacle crust (tube worms were a node until 2026-09-16).

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local seas = tdw.seas
local n = shape.node
local ID = "abyssal_trench"

local SPLIT = 0.10                                       -- the province noise's "b" side past this: about two fifths of the deep floors
local RIFT_FREQ, RIFT_W, RIFT_D = 1 / 1600, 110.0, 0.170 -- the rift: a V a hundred and ten blocks either side of a contour, 170 deep
local SLOT_W, SLOT_EDGE, SLOT_D = 9.0, 0.4, 0.200        -- the slot in its floor: eighteen across, steep, 200 deeper
local VENT_FREQ, VENT_W = 1 / 220, 7.0                   -- the vent line along a second contour
local VENT_SEG_FREQ, VENT_SEG_MIN = 1 / 300, 0.0
local MAT_FREQ, MAT_MIN = 1 / 30, 0.15
local POLYP_FREQ, POLYP_MIN = 1.3, 0.38
local WORM_FREQ, WORM_MIN = 1.2, 0.05
local SMOKER_CELL, SMOKER_SQUARES = 12, 0.55

-- ------------------------------------------------------------ the ground

-- 0 to 1: the province, with a short blend.
function shape.abyss_weight()
    if tdw.config.everywhere == ID then
        return n.const(1.0)
    end
    return shape.province_weight("b", SPLIT)
end
local function rift_w()
    return n.clamp(n.add(n.mul(n.contour("ab_rift", RIFT_FREQ, 2), n.const(-1.0 / RIFT_W)), n.const(1.0)), 0.0, 1.0)
end
local function slot_w()
    return n.clamp(n.mul(n.add(n.contour("ab_rift", RIFT_FREQ, 2), n.const(-SLOT_W)), n.const(-SLOT_EDGE)), 0.0, 1.0)
end
local function vent_near(blocks_in)
    return n.min(n.sub(n.const(blocks_in), n.contour("ab_vent", VENT_FREQ, 1)),
        n.mul(n.sub(n.noise("ab_vent_seg", VENT_SEG_FREQ, 1, 1.0), n.const(VENT_SEG_MIN)), n.const(40.0)))
end

-- The rift's cut, km, positive: what `shape.sea_deep` takes off the floor.
function shape.abyss_terms()
    return n.add(n.mul(rift_w(), n.const(RIFT_D)), n.mul(slot_w(), n.const(SLOT_D)))
end
-- For the Deep Ocean: positive off this province.
function shape.off_abyss()
    return n.sub(n.const(0.5), shape.abyss_weight())
end

-- For the HUD, through the sea's zone: the province at (x, z).
local FIELD = nil
function tdw.abyss_zone(x, z)
    local only = tdw.config.everywhere
    if only then
        return only == ID and ID or nil
    end
    local seed = game.world_seed or tdw.seed
    if seed == nil then
        return nil
    end
    FIELD = FIELD or shape.compile("abyss.at", shape.province_mask("b", SPLIT))
    return FIELD:at(x + 0.5, 20000.5, z + 0.5, seed) > 0 and ID or nil
end

tdw.biomes[ID].ring_mode = "temperate"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.black_mud
tdw.biomes[ID].present = function(pos)
    return seas.reaches(pos, seas.SHELF_END)
end
tdw.biomes[ID].locate = function(px, pz, seed)
    return seas.locate(px, pz, seed, seas.DEEP_FROM + 20.0, seas.DIST_FAR, nil, nil, nil, function(x, z)
        return tdw.abyss_zone(x, z) ~= nil
    end)
end

-- ------------------------------------------------------------ the structures

local ROUGH = { rough = 0.3, blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "abyss_template:" .. name)
end
local PRIORITY = { [blocks.dark_basalt] = 1, [blocks.sulfur] = 1, [blocks.magma] = 1 }

-- A black smoker: a knobbly chimney six to twenty blocks, sulfur-crusted in
-- bands, glowing magma in its throat.
local function smoker(rng)
    schem.record_begin()
    local tall = 6 + rng:below(15)
    local pts, x, z = {}, 0.5, 0.5
    for i = 0, 4 do
        local t = i / 4
        x = x + (rng:below(3) - 1) * 0.25
        z = z + (rng:below(3) - 1) * 0.25
        pts[#pts + 1] = { x, -1.5 + t * (tall + 1.5), z, 1.3 - t * 0.7 }
    end
    schem.push_path(blocks.dark_basalt, pts, ROUGH)
    for _ = 1, 2 + rng:below(3) do
        local h = 1 + rng:below(math.max(1, tall - 2))
        local bx, by, bz = schem.path_point(pts, h)
        schem.push_ellipsoid(blocks.sulfur, bx, by, bz, 1.0, 0.45, 1.0, { rough = 0.5, blind = true })
    end
    local top = pts[#pts]
    schem.push_ellipsoid(blocks.magma, top[1], top[2] - 0.2, top[3], 0.4, 0.8, 0.4, { blind = true })
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { smokers = {} }
    if game.schematic_shapes then
        for i = 1, 8 do out.smokers[i] = smoker(rng_for("smoker:" .. i)) end
    end
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

tdw.build_biome(ID, function(ctx)
    local function zone()
        return n.min(n.sub(seas.d_map(), n.const(seas.SHELF_END)), n.sub(shape.abyss_weight(), n.const(0.5)))
    end
    local function masked(field)
        return n.min(field, zone())
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    local conditions = {
        -- 1: the floor's dark mud.
        n.const(1.0),
        -- 2: the rift's walls: basalt, all the way down.
        n.sub(rift_w(), n.const(0.08)),
        -- 3: bacterial mats on the floor near the vents.
        n.min(vent_near(28.0), n.sub(n.noise("ab_mat", MAT_FREQ, 2, 1.0), n.const(MAT_MIN))),
        -- 4: the vent line's crust: sulfur over basalt.
        vent_near(3.0),
        -- 5: the vent fauna's crust round the smokers' feet: barnacles.
        n.min(n.min(vent_near(16.0), n.mul(vent_near(3.0), n.const(-1.0))),
            n.sub(n.noise("ab_worm", WORM_FREQ, 1, 1.0), n.const(WORM_MIN))),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    code = n.mul(code, step(zone()))
    local depth = shape.compile("biome.abyss.depth", shape.terrain(false))
    local codes = shape.compile("biome.abyss.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 4 * km, material = blocks.black_mud },
        { code = 2, to = 500 * km, material = blocks.dark_basalt },
        { code = 3, to = 1 * km, material = blocks.magma },
        { code = 3, from = 1 * km, to = 4 * km, material = blocks.black_mud },
        { code = 4, to = 1 * km, material = blocks.sulfur },
        { code = 4, from = 1 * km, to = 500 * km, material = blocks.dark_basalt },
        { code = 5, to = 1 * km, material = blocks.barnacles },
        { code = 5, from = 1 * km, to = 4 * km, material = blocks.black_mud },
    }
    -- The polyps away from the worms: more than sixteen blocks off the vents.
    local polyps = shape.compile("biome.abyss.polyps", masked(n.min(n.sub(n.contour("ab_vent", VENT_FREQ, 1), n.const(16.0)),
        n.sub(n.noise("ab_polyp", POLYP_FREQ, 1, 1.0), n.const(POLYP_MIN)))))
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries },
        { cover = blocks.glow_polyp, cells = 1, take = polyps },
    }
    if game.schematic_shapes then
        local built = structures()
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.smokers, cell = SMOKER_CELL, chance = SMOKER_SQUARES,
            salt = 281, sink = 1, above = 0.022, stand = shape.compile("biome.abyss.stand_smoker", masked(vent_near(5.0))) }
    end
    return fills
end)
