-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.2 The Rime Wall: the last two hundred blocks of the world (2026-09-16)
-- — "until an ice wall is hit right at the last couple hundred blocks of
-- the edge".
--
-- Walking out: the tundra's snow deepens into drifts that climb fifteen
-- blocks over a hundred and fifty, and then the wall — a face of glacier
-- ice some seventy blocks high, ragged along its length, standing twelve to
-- seventy blocks in from the edge. Its top is snow, cracked by crevasses of
-- clear ice, with ice spires standing on it, and past the top the world
-- ends: the body's wall, straight down.
--
-- The wall is a TERM of the "edge" programs (`shape.wall_lift`), on the
-- Rime Tundra's ground, measured in blocks from the edge of the wobbled
-- radius — which is the body's edge at the surface since 2026-09-16
-- (shape.lua, the body), so the wall follows the rim however it wanders.
--
-- No new nodes: snow, glacier ice and clear ice.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "rime_wall"
local BAND = shape.RIM.wall
local PER_U = shape.RIM.blocks_per_u

local FACE_AT = 44.0                                     -- blocks in from the edge the face stands, on average
local FACE_WANDER_FREQ, FACE_WANDER = 1 / 70, 56.0       -- +/- 28 blocks along its length
local FACE_JAG_FREQ, FACE_JAG = 1 / 9, 8.0               -- +/- 4: the face's buttresses and flutes
local FACE_W = 5.0                                       -- blocks the face climbs over: all but sheer
local WALL_H = 0.070                                     -- km
local TOP_FREQ, TOP_AMP = 1 / 40, 0.014                  -- the top's own lumps, +/- 7 blocks
local DRIFT_FROM, DRIFT_H = 200.0, 0.016                 -- the drifts: from the band's inner edge, climbing to this at the face
local DRIFT_STEEP_FROM = 90.0                            -- the drift's last stretch is steeper
local DRIFT_RIPPLE_FREQ, DRIFT_RIPPLE = 1 / 25, 0.002
local CREVASSE_FREQ, CREVASSE_W = 1 / 30, 1.2
local SPIRE_CELL, SPIRE_SQUARES = 11, 0.35
local WHITEOUT = { r = 0.90, g = 0.93, b = 0.97 }

-- Blocks in from the edge of the wobbled radius.
local function from_edge()
    return n.mul(n.add(shape.u_biome_node(), n.const(-shape.EDGE_U)), n.const(-PER_U))
end
-- Where the face stands, blocks in from the edge.
local function face_at()
    return n.add(n.noise("rw_face", FACE_WANDER_FREQ, 2, FACE_WANDER, { y = 1000 }),
        n.add(n.noise("rw_jag", FACE_JAG_FREQ, 1, FACE_JAG, { y = 4 }), n.const(FACE_AT)))
end
-- 0 outside the face, 1 on the wall: the distance first, the deeper operand.
local function wall_w()
    return n.clamp(n.mul(n.sub(from_edge(), face_at()), n.const(-1.0 / FACE_W)), 0.0, 1.0)
end
local function drift_w()
    local long = n.clamp(n.mul(n.add(from_edge(), n.const(-DRIFT_FROM)), n.const(-1.0 / (DRIFT_FROM - DRIFT_STEEP_FROM))), 0.0, 1.0)
    local steep = n.clamp(n.mul(n.add(from_edge(), n.const(-DRIFT_STEEP_FROM)), n.const(-1.0 / DRIFT_STEEP_FROM)), 0.0, 1.0)
    return n.add(n.mul(long, n.const(0.55)), n.mul(steep, n.const(0.45)))
end

-- The wall's terms, km, on top of the tundra's.
function shape.wall_lift()
    local wall = n.mul(wall_w(), n.add(n.noise("rw_top", TOP_FREQ, 2, TOP_AMP, { y = 1000 }), n.const(WALL_H)))
    local drift = n.mul(drift_w(), n.add(n.noise("rw_ripple", DRIFT_RIPPLE_FREQ, 1, DRIFT_RIPPLE, { y = 1000 }), n.const(DRIFT_H)))
    return n.add(wall, drift)
end

tdw.biomes[ID].ring_mode = "edge"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.snow
tdw.biomes[ID].present = shape.rim_present(BAND)
-- `/tp rime wall` lands in the drifts, looking at the face: not on its top
-- by the void.
tdw.biomes[ID].locate = shape.rim_locate(shape.EDGE_U - 150 / PER_U)

-- ------------------------------------------------------------ the structures

local ROUGH = { rough = 0.35, blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "rime_wall_template:" .. name)
end
local PRIORITY = { [blocks.ice] = 1, [blocks.clear_ice] = 1 }

-- An ice spire on the wall's top: five to twelve blocks, leaning outward.
local function spire(rng)
    schem.record_begin()
    local tall = 5 + rng:below(8)
    local d = schem.DIR16[rng:below(16) + 1]
    schem.push_path(blocks.ice, { { 0.5, -1.5, 0.5, 1.3 + rng:below(3) * 0.3 }, { 0.5 + d[1] * 0.4, tall * 0.6, 0.5 + d[2] * 0.4, 0.8 },
        { 0.5 + d[1] * 0.9, tall, 0.5 + d[2] * 0.9, 0.3 } }, ROUGH)
    schem.push_ellipsoid(blocks.clear_ice, 0.5 + d[1] * 0.3, tall * 0.35, 0.5 + d[2] * 0.3, 0.9, tall * 0.3, 0.9, ROUGH)
    return schem.record_schematic(PRIORITY)
end
-- A block of ice fallen off the face into the drifts, half buried.
local function calved(rng)
    schem.record_begin()
    local r = 1.4 + rng:below(4) * 0.45
    schem.push_ellipsoid(blocks.ice, 0.5, r * 0.2, 0.5, r, r * 0.8, r * 0.85, ROUGH)
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { spires = {}, calved = {} }
    if game.schematic_shapes then
        for i = 1, 6 do out.spires[i] = spire(rng_for("spire:" .. i)) end
        for i = 1, 4 do out.calved[i] = calved(rng_for("calved:" .. i)) end
    end
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

tdw.build_biome(ID, function(ctx)
    local function masked(field)
        local mask = tdw.biome_mask(n, ID)
        field = mask and n.min(field, mask) or field
        return n.min(field, shape.rim_band(BAND))
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    local conditions = {
        -- 1: the drifts: snow over glacier ice.
        n.const(1.0),
        -- 2: the face and its foot: bare ice, all the way down.
        n.sub(wall_w(), n.const(0.02)),
        -- 3: the top, back from the face's lip: snow again.
        n.sub(n.add(face_at(), n.const(-(FACE_W + 4.0))), from_edge()),
        -- 4: crevasses across the top, on the lines of a contour: clear ice.
        n.min(n.sub(n.add(face_at(), n.const(-(FACE_W + 8.0))), from_edge()),
            n.sub(n.const(CREVASSE_W), n.contour("rw_crevasse", CREVASSE_FREQ, 1))),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    code = n.mul(code, step(masked(n.const(1.0))))
    local depth = shape.compile("biome.rime_wall.depth", shape.terrain(false))
    local codes = shape.compile("biome.rime_wall.codes", code)
    local km = 0.001
    -- Ice to a hundred and twenty blocks down: the face is a column's
    -- depth under the top, and stone must not show on it.
    local entries = {
        { code = 1, to = 3 * km, material = blocks.snow },
        { code = 1, from = 3 * km, to = 120 * km, material = blocks.ice },
        { code = 2, to = 120 * km, material = blocks.ice },
        { code = 3, to = 2 * km, material = blocks.snow },
        { code = 3, from = 2 * km, to = 120 * km, material = blocks.ice },
        { code = 4, to = 8 * km, material = blocks.clear_ice },
        { code = 4, from = 8 * km, to = 120 * km, material = blocks.ice },
    }
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, above)
            fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                salt = salt, sink = 1, above = above, stand = shape.compile("biome.rime_wall.stand_" .. name, masked(field)) }
        end
        -- Spires on the top, back from its lip and from the void.
        scatter("spire", built.spires, n.min(n.sub(n.add(face_at(), n.const(-(FACE_W + 6.0))), from_edge()),
            n.sub(from_edge(), n.const(6.0))), SPIRE_CELL, SPIRE_SQUARES, 221, 0.014)
        -- Calved blocks in the drifts below the face.
        scatter("calved", built.calved, n.min(n.sub(from_edge(), n.add(face_at(), n.const(FACE_W + 2.0))),
            n.sub(n.const(120.0), from_edge())), 16, 0.30, 222, 0.004)
    end
    return fills
end)

-- ------------------------------------------------------------ the whiteout

if tdw.on_chunk_fog then
    tdw.on_chunk_fog(function(pos)
        local only = tdw.config.everywhere
        if only then
            return only == ID and { r = WHITEOUT.r, g = WHITEOUT.g, b = WHITEOUT.b, visibility = 110 } or nil
        end
        if not tdw.biomes[ID].present(pos) then
            return nil
        end
        return { r = WHITEOUT.r, g = WHITEOUT.g, b = WHITEOUT.b, visibility = 160 }
    end)
end
