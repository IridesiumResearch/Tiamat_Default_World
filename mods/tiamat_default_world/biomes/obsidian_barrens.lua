-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.3 Obsidian Barrens: the Ember Ridge's other province, dry side
-- (2026-09-16) — "the volcanic foothills needs to be broken up with ... a
-- couple more biomes that are still vaguely in the same theme".
--
-- Where the Foothills are ridges and cones, this is what a flow leaves when
-- it cools too fast to crystallise: sheets of black glass laid in lobes
-- with steep fronts, the sheets buckled into razor pressure ridges, fields
-- of shards standing where a crust shattered, and grey ash drifted in the
-- lows between the flows. Nothing grows.
--
-- Its terms (`shape.obsidian_terms`) stand in the "ember" programs in place
-- of the Foothills' where the province is "b", on the dry side; the Geyser
-- Basin's on the wet (shape.lua). New node: `obsidian`.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "obsidian_barrens"

local FLOW_FREQ, FLOW_MIN, FLOW_EDGE, FLOW_H = 1 / 170, 0.02, 14.0, 0.007   -- the broad sheets: seven blocks, steep fronts
local LOBE_FREQ, LOBE_MIN, LOBE_EDGE, LOBE_H = 1 / 80, 0.18, 12.0, 0.004    -- the lobes on them: four more
local RAZOR_FREQ, RAZOR_W, RAZOR_H = 1 / 130, 3.5, 0.007                   -- pressure ridges: seven blocks, three and a half either side
local RAZOR_SEG_FREQ, RAZOR_SEG_MIN = 1 / 240, 0.0
local GRAIN_FREQ, GRAIN_AMP = 1 / 11, 0.0012
local SHEEN_FREQ, SHEEN_MIN = 1 / 30, -0.05              -- glass bare on the sheets; basalt crust elsewhere on them
local ASH_FREQ, ASH_MIN = 1 / 40, 0.0
local PUMICE_FREQ, PUMICE_MIN = 1.3, 0.34
local SHARD_FIELD_FREQ, SHARD_FIELD_MIN = 1 / 60, 0.12
local SHARD_CELL, SHARD_SQUARES = 5, 0.45
local BOULDER_CELL, BOULDER_SQUARES = 22, 0.30
local SPIRE_CELL, SPIRE_SQUARES = 50, 0.30

-- ------------------------------------------------------------ the ground

local function clamp01(field, lo, edge)
    return n.clamp(n.mul(n.sub(field, n.const(lo)), n.const(edge)), 0.0, 1.0)
end
local function flow_w()
    return clamp01(n.noise("ob_flow", FLOW_FREQ, 2, 1.0), FLOW_MIN, FLOW_EDGE)
end
local function lobe_w()
    return clamp01(n.noise("ob_lobe", LOBE_FREQ, 1, 1.0), LOBE_MIN, LOBE_EDGE)
end
local function razor_w()
    local tent = n.clamp(n.add(n.mul(n.contour("ob_razor", RAZOR_FREQ, 2), n.const(-1.0 / RAZOR_W)), n.const(1.0)), 0.0, 1.0)
    return n.mul(tent, clamp01(n.noise("ob_razor_seg", RAZOR_SEG_FREQ, 1, 1.0), RAZOR_SEG_MIN, 8.0))
end

-- The Barrens' terms, km. The sheets first, the deepest.
function shape.obsidian_terms()
    local acc = n.add(n.mul(flow_w(), n.const(FLOW_H)), n.mul(lobe_w(), n.const(LOBE_H)))
    acc = n.add(acc, n.mul(razor_w(), n.const(RAZOR_H)))
    return n.add(acc, n.noise("ob_grain", GRAIN_FREQ, 1, GRAIN_AMP))
end

tdw.biomes[ID].ring_mode = "ember"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.dark_basalt

-- ------------------------------------------------------------ the structures

local ROUGH = { rough = 0.25, blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "obsidian_template:" .. name)
end
local PRIORITY = { [blocks.obsidian] = 1, [blocks.dark_basalt] = 1 }

-- A shard: a thin blade of glass two to five blocks, tilted.
local function shard(rng)
    schem.record_begin()
    local tall = 2 + rng:below(4)
    local d = schem.DIR16[rng:below(16) + 1]
    local lean = 0.3 + rng:below(4) * 0.25
    schem.push_path(blocks.obsidian, { { 0.5, -1.0, 0.5, 0.45 }, { 0.5 + d[1] * lean, tall, 0.5 + d[2] * lean, 0.12 } }, { blind = true })
    if rng:below(2) == 0 then
        local e = schem.DIR16[rng:below(16) + 1]
        schem.push_path(blocks.obsidian, { { 0.5 + e[1], -1.0, 0.5 + e[2], 0.35 }, { 0.5 + e[1] * 1.6, tall * 0.5, 0.5 + e[2] * 1.6, 0.1 } }, { blind = true })
    end
    return schem.record_schematic(PRIORITY)
end
-- A glassy boulder, half basalt.
local function boulder(rng)
    schem.record_begin()
    local r = 1.0 + rng:below(4) * 0.35
    schem.push_ellipsoid(blocks.dark_basalt, 0.5, r * 0.2, 0.5, r, r * 0.7, r * 0.9, ROUGH)
    schem.push_ellipsoid(blocks.obsidian, 0.5 + r * 0.3, r * 0.5, 0.5, r * 0.6, r * 0.5, r * 0.6, ROUGH)
    return schem.record_schematic(PRIORITY)
end
-- A spire of glass where a vent squeezed it up: six to eleven blocks.
local function spire(rng)
    schem.record_begin()
    local tall = 6 + rng:below(6)
    schem.push_path(blocks.obsidian, { { 0.5, -1.5, 0.5, 1.4 }, { 0.5, tall * 0.5, 0.5, 0.8 }, { 0.5 + (rng:below(3) - 1) * 0.5, tall, 0.5, 0.2 } }, ROUGH)
    schem.push_ellipsoid(blocks.dark_basalt, 0.5, 0.0, 0.5, 2.0, 0.9, 2.0, ROUGH)
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { shards = {}, boulders = {}, spires = {} }
    if game.schematic_shapes then
        for i = 1, 8 do out.shards[i] = shard(rng_for("shard:" .. i)) end
        for i = 1, 4 do out.boulders[i] = boulder(rng_for("boulder:" .. i)) end
        for i = 1, 3 do out.spires[i] = spire(rng_for("spire:" .. i)) end
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
    local function ash()
        return n.min(n.sub(n.const(0.15), flow_w()), n.sub(n.noise("ob_ash", ASH_FREQ, 2, 1.0), n.const(ASH_MIN)))
    end
    local conditions = {
        -- 1: basalt crust.
        n.const(1.0),
        -- 2: bare glass on the sheets.
        n.min(n.sub(flow_w(), n.const(0.6)), n.sub(n.noise("ob_sheen", SHEEN_FREQ, 2, 1.0), n.const(SHEEN_MIN))),
        -- 3: the razor ridges: glass.
        n.sub(razor_w(), n.const(0.3)),
        -- 4: ash in the lows.
        ash(),
        -- 5: pumice in the ash.
        n.min(ash(), n.sub(n.noise("ob_pumice", PUMICE_FREQ, 1, 1.0), n.const(PUMICE_MIN))),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    code = n.mul(code, step(masked(n.const(1.0))))
    local depth = shape.compile("biome.obsidian.depth", shape.terrain(false))
    local codes = shape.compile("biome.obsidian.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 6 * km, material = blocks.dark_basalt },
        { code = 2, to = 3 * km, material = blocks.obsidian },
        { code = 2, from = 3 * km, to = 6 * km, material = blocks.dark_basalt },
        { code = 3, to = 8 * km, material = blocks.obsidian },
        { code = 4, to = 2 * km, material = blocks.volcanic_ash },
        { code = 4, from = 2 * km, to = 6 * km, material = blocks.dark_basalt },
        { code = 5, to = 1 * km, material = blocks.pumice },
        { code = 5, from = 1 * km, to = 6 * km, material = blocks.volcanic_ash },
    }
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, above)
            fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                salt = salt, sink = 1, above = above, stand = shape.compile("biome.obsidian.stand_" .. name, masked(field)) }
        end
        local field = n.sub(n.noise("ob_shards", SHARD_FIELD_FREQ, 2, 1.0), n.const(SHARD_FIELD_MIN))
        scatter("shard", built.shards, n.min(field, n.sub(n.const(0.3), razor_w())), SHARD_CELL, SHARD_SQUARES, 231, 0.006)
        scatter("boulder", built.boulders, n.sub(n.const(0.5), flow_w()), BOULDER_CELL, BOULDER_SQUARES, 232, 0.004)
        scatter("spire", built.spires, n.sub(flow_w(), n.const(0.8)), SPIRE_CELL, SPIRE_SQUARES, 233, 0.012)
    end
    return fills
end)
