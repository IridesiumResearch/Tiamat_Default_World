-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.12 Karst Towers: a third of the Jungle's ground (2026-09-16).
--
-- Limestone pinnacles standing up out of the forest floor, up to twenty
-- blocks (fifty until 2026-09-17), weathered grey walls streaked with moss
-- over a skirt of scree, their tops crowned in
-- scrub and small trees; between them a floor of grass, ferns and mud
-- pools under scattered broadleaf trees. Where the Jungle is karst UNDER a
-- canopy, this is karst standing OVER one.
--
-- WHERE: the Jungle's province side "b" past a split of 0.25 (the Jungle
-- keeps the rest). Its terms (`shape.karst_terms`) stand in the "belt"
-- programs, weighted in only well inside the Verdant Belt, where no chunk
-- runs the "verdant" programs (989 of 1,024, no room). New nodes: none.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "karst_towers"

local SPLIT = 0.25
-- 2026-09-17: "needs its noise turned down about 60% and could use some
-- erosion". The towers stood fifty blocks with eight of jitter on top, on
-- sheer walls, from 3D noise (so their outline changed with height and left
-- hanging slabs), on the Jungle's whole ground: its undulation, ridges,
-- ravines and sinkholes at full strength. Now: two fifths of the towers'
-- height and jitter, every noise FLAT in y, the Jungle's terms under them
-- damped to two fifths (`shape.karst_damp`), and weathering — walls sloped
-- (edge 16 -> 7), their outline torn by a fine noise, and a skirt of scree
-- round each tower's foot. The scree is a material, not a rise: the belt's
-- shore programs had no room for both it and the damping (1,014 of 1,024).
local FLAT = shape.HUMIDITY_STRETCH
local TOWER_FREQ, TOWER_MIN, TOWER_EDGE, TOWER_H = 1 / 90, 0.30, 7.0, 0.020
local THIN_FREQ, THIN_MIN = 1 / 400, -0.05
local TOP_FREQ, TOP_AMP = 1 / 12, 0.0032
local RAG_FREQ, RAG_AMP = 1 / 7, 0.10                    -- the walls' weathered outline
local APRON_BELOW, APRON_EDGE = 0.10, 5.0               -- the scree skirt: further out than the tower
local DAMP = 0.6                                        -- the Jungle's terms lose this share in the province
local IN_U = { 0.271, 0.349 }                           -- where the terms stand, on the wobbled radius
local STREAK_FREQ, STREAK_MIN = 1 / 6, 0.25
local POOL_FREQ, POOL_MIN = 1 / 35, 0.30
local FERN_FREQ, FERN_MIN = 1.5, 0.05
local SCRUB_CELL, SCRUB_SQUARES = 5, 0.45
local TREE_CELL, TREE_SQUARES = 16, 0.45

-- Positive over a tower's footprint, before its edge is drawn.
local function tower_g()
    return n.min(n.sub(n.noise("kt_tower", TOWER_FREQ, 1, 1.0, FLAT), n.const(TOWER_MIN)),
        n.sub(n.noise("kt_thin", THIN_FREQ, 1, 1.0, FLAT), n.const(THIN_MIN)))
end
-- 0 to 1: the tower, its outline weathered.
local function tower_w()
    return n.clamp(n.mul(n.add(tower_g(), n.noise("kt_rag", RAG_FREQ, 1, RAG_AMP, FLAT)), n.const(TOWER_EDGE)), 0.0, 1.0)
end
-- 0 to 1: the scree skirt, wider than the tower. Materials only.
local function apron_w()
    return n.clamp(n.mul(n.add(tower_g(), n.const(APRON_BELOW)), n.const(APRON_EDGE)), 0.0, 1.0)
end
-- The towers' terms, km.
function shape.karst_terms()
    return n.mul(tower_w(), n.add(n.noise("kt_top", TOP_FREQ, 1, TOP_AMP, FLAT), n.const(TOWER_H)))
end
-- What the Jungle's terms are multiplied by: 1 off the province, 1 - DAMP
-- in it. On the province alone (flat, seven operations), not the belt's
-- inside weight: the Jungle's terms stand in the "verdant" programs too,
-- and the damping must agree across that chunk boundary.
function shape.karst_damp()
    if tdw.config.everywhere == ID then
        return n.const(1.0 - DAMP)
    end
    return n.add(n.mul(shape.province_weight("b", SPLIT), n.const(-DAMP)), n.const(1.0))
end
-- 0 to 1: the province, inside the belt.
function shape.karst_weight()
    if tdw.config.everywhere == ID then
        return n.const(1.0)
    end
    local inside = n.clamp(n.mul(shape.ring(IN_U[1], IN_U[2]), n.const(1.0 / 0.008)), 0.0, 1.0)
    return n.mul(inside, shape.province_weight("b", SPLIT))
end

tdw.biomes[ID].ring_mode = "belt"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.dirt

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "karst_template:" .. name)
end
local PRIORITY = { [blocks.kapok_log] = 1, [blocks.oak_log] = 1 }

-- Scrub on a tower's top: a clump of leaves on a short stem.
local function scrub(rng)
    schem.record_begin()
    local tall = 1 + rng:below(3)
    schem.push_path(blocks.oak_log, { { 0.5, -0.8, 0.5, 0.16 }, { 0.5, tall, 0.5, 0.12 } }, BLIND)
    schem.push_ellipsoid(blocks.ironwood_leaves, 0.5, tall + 0.3, 0.5, 1.4 + rng:below(3) * 0.3, 1.0, 1.4 + rng:below(3) * 0.3, { rough = 0.4, blind = true })
    return schem.record_schematic(PRIORITY)
end
-- A broadleaf on the floor: a pale trunk twelve to eighteen blocks, a wide
-- crown of dark leaves.
local function tree(rng)
    schem.record_begin()
    local tall = 12 + rng:below(7)
    local d = schem.DIR16[rng:below(16) + 1]
    local trunk = { { 0.5, -1.5, 0.5, 0.6 }, { 0.5 + d[1] * 0.4, tall * 0.6, 0.5 + d[2] * 0.4, 0.45 }, { 0.5 + d[1] * 0.7, tall, 0.5 + d[2] * 0.7, 0.3 } }
    schem.push_path(blocks.kapok_log, trunk, BLIND)
    local top = trunk[#trunk]
    schem.push_ellipsoid(blocks.ironwood_leaves, top[1], top[2] + 0.6, top[3], 4.0 + rng:below(3) * 0.5, 2.0, 4.0 + rng:below(3) * 0.5, { rough = 0.35, blind = true })
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { scrub = {}, trees = {} }
    if game.schematic_shapes then
        for i = 1, 5 do out.scrub[i] = scrub(rng_for("scrub:" .. i)) end
        for i = 1, 5 do out.trees[i] = tree(rng_for("tree:" .. i)) end
    end
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

tdw.build_biome(ID, function(ctx)
    local function masked(field)
        local mask = tdw.biome_mask(n, ID)
        field = mask and n.min(field, mask) or field
        return shape.sea_exclude and shape.sea_exclude(field, 20.0) or field
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    local conditions = {
        -- 1: the forest floor: grass over loam.
        n.const(1.0),
        -- 2: mud pools.
        n.min(n.sub(n.noise("kt_pool", POOL_FREQ, 2, 1.0), n.const(POOL_MIN)), n.sub(n.const(0.05), tower_w())),
        -- 3: a tower: limestone, all the way down its walls.
        n.sub(tower_w(), n.const(0.03)),
        -- 4: moss streaks down the walls.
        n.min(n.min(n.sub(tower_w(), n.const(0.03)), n.sub(n.const(0.9), tower_w())), n.sub(n.noise("kt_streak", STREAK_FREQ, 1, 1.0, { y = 8 }), n.const(STREAK_MIN))),
        -- 5: a tower's top: moss.
        n.sub(tower_w(), n.const(0.97)),
        -- 6: scree on the apron, off the tower.
        n.min(n.sub(apron_w(), n.const(0.05)), n.sub(n.const(0.03), tower_w())),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    code = n.mul(code, step(masked(n.const(1.0))))
    local depth = shape.compile("biome.karst.depth", shape.terrain(false))
    local codes = shape.compile("biome.karst.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = shape.SKIN_TOP, material = blocks.grass },
        { code = 1, from = shape.SKIN_TOP, to = 5 * km, material = blocks.dirt },
        { code = 2, to = 3 * km, material = blocks.mud },
        -- The towers' 22, and some (80 when they stood fifty; 2026-09-18).
        { code = 3, to = 30 * km, material = blocks.stone },
        { code = 4, to = 1 * km, material = blocks.moss },
        { code = 4, from = 1 * km, to = 30 * km, material = blocks.stone },
        { code = 5, to = 1 * km, material = blocks.moss },
        { code = 5, from = 1 * km, to = 30 * km, material = blocks.stone },
        { code = 6, to = 1 * km, material = blocks.gravel },
        { code = 6, from = 1 * km, to = 4 * km, material = blocks.stone },
    }
    local ferns = shape.compile("biome.karst.ferns", masked(n.min(n.sub(n.const(0.02), apron_w()),
        n.sub(n.noise("kt_fern", FERN_FREQ, 1, 1.0), n.const(FERN_MIN)))))
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
        { cover = blocks.fern, cells = 3, take = ferns },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, above)
            fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                salt = salt, sink = 1, above = above, stand = shape.compile("biome.karst.stand_" .. name, masked(field)) }
        end
        scatter("scrub", built.scrub, n.sub(tower_w(), n.const(0.98)), SCRUB_CELL, SCRUB_SQUARES, 311, 0.005)
        scatter("tree", built.trees, n.sub(n.const(0.01), apron_w()), TREE_CELL, TREE_SQUARES, 312, 0.022)
    end
    return fills
end)
