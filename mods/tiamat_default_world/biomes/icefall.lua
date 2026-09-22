-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 2.7 Icefall: the Crown's other half (2026-09-16) — the ice cap broken.
--
-- The designer's ask: the Crown is the Frozen Wastes now, "we don't need
-- very much frozen wastes and they can be a little more broken up". So the
-- Crown is split by the province noise, and this is the other side of it:
-- the same ice cap, but where the Frozen Wastes are a wind-scoured plain of
-- permafrost and snowfields, this is the glacier itself — blue ice sheet,
-- cracked into polygons of crevasse, standing in towers and seracs, with
-- bands of moraine gravel through it and the lakes frozen clear.
--
-- **No terms of its own.** It stands on the Frozen Wastes' ground
-- (`shape.frozen_terms`, weighted onto the Crown in shape.lua) and reads
-- the same feature fields (`shape.frozen_feature`), so its ice is where the
-- terrain's glaciers and crevasses are. A dressing biome costs the terrain
-- programs nothing — and the cold core's cross-fade band is at 980 of the
-- compiler's 1,024.
--
-- No new nodes: glacier ice, clear ice, snow and gravel are all here.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "icefall"

local CRACK_FREQ, CRACK_W = 1 / 13, 0.55                 -- the crevasse cracks: fine contour lines, half a block wide
local CRACK_B_FREQ = 1 / 19
local MORAINE_FREQ, MORAINE_W = 1 / 90, 2.5              -- moraine: gravel bands along a slow contour
local MORAINE_SEG_FREQ, MORAINE_SEG_MIN = 1 / 200, 0.10
local DRIFT_FREQ, DRIFT_MIN = 1 / 140, 0.32              -- snow only in a few deep drifts: the Wastes' snow weight saturates over half the cap, so a cut on it did nothing
local TOWER_CELL, TOWER_SQUARES = 9, 0.45                -- ice towers: dense, the cap standing on end
local BLOCK_CELL, BLOCK_SQUARES = 12, 0.40               -- fallen ice, half sunk
local HAZE = { r = 0.82, g = 0.89, b = 0.96 }
local HAZE_VISIBILITY, HAZE_EDGE_VISIBILITY = 140, 300  -- thinner than the Wastes' whiteout: the cap is clear and bright

tdw.biomes[ID].ring_mode = "alpine"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.ice

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local ROUGH = { rough = 0.3, blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "icefall_template:" .. name)
end
local PRIORITY = { [blocks.ice] = 1, [blocks.clear_ice] = 1 }

-- An ice tower: a serac standing four to nine blocks, wider at the foot,
-- leaning a little, with a cap of clear ice.
local function tower(rng)
    schem.record_begin()
    local tall = 4 + rng:below(6)
    local d = schem.DIR16[rng:below(16) + 1]
    local lean = 0.3 + rng:below(4) * 0.2
    schem.push_path(blocks.ice, {
        { 0.5, -1.5, 0.5, 1.4 + rng:below(3) * 0.3 },
        { 0.5 + d[1] * lean * 0.5, tall * 0.55, 0.5 + d[2] * lean * 0.5, 0.9 },
        { 0.5 + d[1] * lean, tall, 0.5 + d[2] * lean, 0.5 },
    }, ROUGH)
    schem.push_ellipsoid(blocks.clear_ice, 0.5 + d[1] * lean, tall + 0.6, 0.5 + d[2] * lean, 0.9, 0.7, 0.9, ROUGH)
    return schem.record_schematic(PRIORITY)
end

-- A fallen block of ice, two to four across, half swallowed, on its side.
local function fallen(rng)
    schem.record_begin()
    local r = 1.1 + rng:below(4) * 0.4
    schem.push_ellipsoid(blocks.ice, 0.5, r * 0.35, 0.5, r, r * 0.75, r * (0.7 + rng:below(4) * 0.12), ROUGH)
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { towers = {}, fallen = {} }
    if game.schematic_shapes then
        for i = 1, 6 do out.towers[i] = tower(rng_for("tower:" .. i)) end
        for i = 1, 4 do out.fallen[i] = fallen(rng_for("fallen:" .. i)) end
    end
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

tdw.build_biome(ID, function(ctx)
    local F = shape.frozen_feature
    local function masked(field)
        local mask = tdw.biome_mask(n, ID)
        return mask and n.min(field, mask) or field
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    local function cracks()
        local a = n.clamp(n.mul(n.add(n.contour("if_crack", CRACK_FREQ, 1), n.const(-CRACK_W)), n.const(-3.0)), 0.0, 1.0)
        return n.max(a, n.clamp(n.mul(n.add(n.contour("if_crack_b", CRACK_B_FREQ, 1), n.const(-CRACK_W)), n.const(-3.0)), 0.0, 1.0))
    end
    local function moraine()
        return n.min(n.clamp(n.add(n.mul(n.contour("if_moraine", MORAINE_FREQ, 2), n.const(-1.0 / MORAINE_W)), n.const(1.0)), 0.0, 1.0),
            n.sub(n.noise("if_moraine_seg", MORAINE_SEG_FREQ, 1, 1.0), n.const(MORAINE_SEG_MIN)))
    end
    local conditions = {
        -- 1: the cap: glacier ice, everywhere.
        n.const(1.0),
        -- 2: snow, only in a few deep drifts.
        n.sub(n.noise("if_drift", DRIFT_FREQ, 2, 1.0), n.const(DRIFT_MIN)),
        -- 3: the crevasse cracks, and the terrain's own crevasses: clear ice
        -- down into blue.
        n.max(n.sub(cracks(), n.const(0.5)), n.sub(F.crevasse(), n.const(0.3))),
        -- 4: moraine: bands of gravel through the ice.
        n.sub(moraine(), n.const(0.5)),
        -- 5: a frozen lake: clear ice, deep.
        n.sub(F.lake(), n.const(0.4)),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    local mask = tdw.biome_mask(n, ID)
    if mask then
        code = n.mul(code, step(mask))
    end
    local depth = shape.compile("biome.icefall.depth", shape.terrain(false))
    local codes = shape.compile("biome.icefall.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 24 * km, material = blocks.ice },
        { code = 2, to = 1 * km, material = blocks.snow },
        { code = 2, from = 1 * km, to = 24 * km, material = blocks.ice },
        { code = 3, to = 6 * km, material = blocks.clear_ice },
        { code = 3, from = 6 * km, to = 24 * km, material = blocks.ice },
        { code = 4, to = 1 * km, material = blocks.gravel },
        { code = 4, from = 1 * km, to = 24 * km, material = blocks.ice },
        { code = 5, to = 4 * km, material = blocks.clear_ice },
        { code = 5, from = 4 * km, to = 24 * km, material = blocks.ice },
    }
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, sink)
            if #list > 0 then
                fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                    salt = salt, sink = sink, stand = shape.compile("biome.icefall.stand_" .. name, masked(field)) }
            end
        end
        -- Towers where the ice is broken — off the lakes and the moraine.
        local firm = n.min(n.sub(n.const(0.3), F.lake()), n.sub(n.const(0.4), moraine()))
        scatter("tower", built.towers, firm, TOWER_CELL, TOWER_SQUARES, 171, 1)
        scatter("fallen", built.fallen, firm, BLOCK_CELL, BLOCK_SQUARES, 172, 1)
    end
    return fills
end)

-- ------------------------------------------------------------ the haze

if tdw.on_chunk_fog then
    local place = nil
    tdw.on_chunk_fog(function(pos)
        local only = tdw.config.everywhere
        if only then
            if only ~= ID then
                return nil
            end
            return { r = HAZE.r, g = HAZE.g, b = HAZE.b, visibility = HAZE_VISIBILITY }
        end
        place = place or shape.compile("icefall.place", tdw.biome_mask(n, ID))
        local b = place:bounds(pos)
        if b.high <= 0 then
            return nil
        end
        return { r = HAZE.r, g = HAZE.g, b = HAZE.b, visibility = b.low > 0 and HAZE_VISIBILITY or HAZE_EDGE_VISIBILITY }
    end)
end

-- The colour of its grass, dirt and lichen (2026-09-16): the chunk tint.
tdw.biome_tint("icefall", { 0.82, 0.94, 1.0 })
