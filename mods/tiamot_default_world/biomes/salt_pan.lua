-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 2.9 Salt Pan: a third of the Glass Waste (2026-09-16) — "break up the
-- arid mesa ring with at least one more biome".
--
-- A dead-flat white crust cracked into polygons, with brine pools in its
-- lowest hollows, salt pillars standing out of it, and a rim of dried mud
-- where it meets the mesa's benches and the badlands' fins. Nothing grows.
-- Flat is the point: the mesa is benches and canyons, the badlands are
-- fins and gullies, and between them a pan is the one thing that is
-- level to the horizon.
--
-- HOW IT IS FLAT. The pan does not add terms; it CAPS them. In the "glass"
-- programs (shape.lua) the ring's terms are taken under `floor + off`,
-- where `off` is SALT_RAMP where the pan's weight is 0 (a hundred blocks:
-- nothing is touched) and 0 where it is 1: the benches and the fins are
-- cut down to the floor. The ring's cuts BELOW its base are shallow (an
-- arroyo two blocks, a piping void six) and the pan keeps them as its own
-- low spots — capping from below as well cost another fifty operations,
-- and the ring was at 1,020 of the compiler's 1,024. One evaluation of the
-- terms; a cross-fade would have cost them twice.
--
-- WHERE. The province noise's "b" side of the Glass Waste, past a split
-- of 0.2 (about a third of the ring), and inset from the ring's outer edge
-- so it stays inside the "glass" programs — the outer strip runs in the
-- "verdant" ones, which are at 983 and have no room for the clamps. The
-- mesa and the badlands keep their whole spans and this paints over them;
-- their own structures keep off it (`shape.salt_exclude`).
--
-- New node: `salt`. The pools are the ocean's brine.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "salt_pan"
local BRINE = "tiamot_default_world:brine"

local SPLIT = 0.2                                        -- the province's line: side "b" past this is the pan
local FLOOR = -0.003                                     -- km: the pan's floor, three blocks under the ring's base
local RIPPLE_FREQ, RIPPLE_AMP = 1 / 60, 0.0006           -- the crust is not a plane: a third of a block either way
local POOL_FREQ, POOL_MIN, POOL_EDGE, POOL_D = 1 / 70, 0.24, 6.0, 0.0016   -- the brine pools: a slow noise's high side, a block and a half down
local POOL_FILL = 0.0010                                 -- km: the brine stands a block deep in them
local CRACK_FREQ, CRACK_W = 1 / 9, 0.45                  -- the polygon cracks: two fine contours
local CRACK_B_FREQ = 1 / 13
local RIM_W = 0.35                                       -- the pan's weight under this is its edge: dried mud
local PILLAR_CELL, PILLAR_SQUARES = 14, 0.30
local SNAG_CELL, SNAG_SQUARES = 60, 0.15

-- The pan's own band of the radius: the Glass Waste inset from its outer
-- edge, so every chunk that has it runs the "glass" programs.
local reach = shape.reach()
local IN_U = shape.GLASS_U[1] + shape.GLASS_INSET_U + 0.002
local OUT_U = shape.GLASS_U[2] - reach - 0.004
local function band()
    return n.clamp(n.mul(shape.ring(IN_U, OUT_U), n.const(1.0 / 0.006)), 0.0, 1.0)
end
local function ripple()
    return n.noise("sp_ripple", RIPPLE_FREQ, 2, RIPPLE_AMP)
end
local function pool_w()
    return n.clamp(n.mul(n.sub(n.noise("sp_pool", POOL_FREQ, 2, 1.0), n.const(POOL_MIN)), n.const(POOL_EDGE)), 0.0, 1.0)
end

-- The pan's floor, km, as a term: the flat, rippled, with the pools sunk
-- into it. What the ring's terms are clamped to where the weight is 1.
function shape.salt_floor()
    return n.sub(n.add(ripple(), n.const(FLOOR)), n.mul(pool_w(), n.const(POOL_D)))
end
-- 0 to 1: the band times the province's side.
function shape.salt_weight()
    return n.mul(band(), shape.province_weight("b", SPLIT))
end
-- For the mesa and the badlands: positive where the pan is NOT.
function shape.salt_exclude(field)
    return n.min(field, n.sub(n.const(0.5), shape.salt_weight()))
end

-- Whether (x, z) is the pan's, for the HUD: its mask AND its band, cached
-- by eight-block square as the cold biomes' tests are. The mesa's and the
-- badlands' spans cover the pan, so their ground says nothing here.
local FIELD = nil
local cache, cached = {}, 0
function tdw.salt_at(x, z)
    local only = tdw.config.everywhere
    if only then
        return only == ID
    end
    local u = (x * x + z * z) * 1e-6 / (shape.R_DISC * shape.R_DISC)
    if u < IN_U - shape.wobble(u) or u > OUT_U + shape.wobble(u) then
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
        FIELD = FIELD or shape.compile("salt.at", n.min(tdw.biome_mask(n, ID), n.sub(band(), n.const(0.5))))
        local y = shape.Y0 + 1000 * shape.dome_at(u)
        hit = FIELD:at(x + 0.5, y + 0.5, z + 0.5, seed) > 0
        cache[key] = hit
        cached = cached + 1
    end
    return hit
end

-- `/tp salt pan` lands inside the band as well as the province: the mask
-- alone put a player on the ring's outer strip, where the pan is not.
tdw.biomes[ID].locate_field = function(field)
    field = n.min(field, n.sub(band(), n.const(0.5)))
    -- And off the rivers, which cross the pan as they cross everything:
    -- the first landing was in one, on grass.
    return shape.river_exclude and shape.river_exclude(field, shape.RIVER_RIM or 150) or field
end
tdw.biomes[ID].ring_mode = "glass"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.salt

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "salt_template:" .. name)
end
local PRIORITY = { [blocks.salt] = 1, [blocks.dead_log] = 1 }

-- A salt pillar: a crusted column two to six blocks tall with a wider
-- foot and a knobbed top.
local function pillar(rng)
    schem.record_begin()
    local tall = 2 + rng:below(5)
    schem.push_path(blocks.salt, { { 0.5, -1.0, 0.5, 0.9 + rng:below(3) * 0.2 }, { 0.5, tall * 0.6, 0.5, 0.5 }, { 0.5, tall, 0.5, 0.42 } }, { rough = 0.3, blind = true })
    schem.push_ellipsoid(blocks.salt, 0.5, tall + 0.4, 0.5, 0.8, 0.6, 0.8, { rough = 0.4, blind = true })
    return schem.record_schematic(PRIORITY)
end
-- A dead snag crusted to the knees in salt.
local function snag(rng)
    schem.record_begin()
    local tall = 3 + rng:below(3)
    local d = schem.DIR16[rng:below(16) + 1]
    schem.push_path(blocks.dead_log, { { 0.5, -1.5, 0.5, 0.5 }, { 0.5 + d[1] * 0.4, tall, 0.5 + d[2] * 0.4, 0.22 } }, BLIND)
    schem.push_ellipsoid(blocks.salt, 0.5, 0.2, 0.5, 1.1, 0.5, 1.1, { rough = 0.4, blind = true })
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { pillars = {}, snags = {} }
    if game.schematic_shapes then
        for i = 1, 5 do out.pillars[i] = pillar(rng_for("pillar:" .. i)) end
        for i = 1, 3 do out.snags[i] = snag(rng_for("snag:" .. i)) end
    end
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

tdw.build_biome(ID, function(ctx)
    local function masked(field)
        local mask = tdw.biome_mask(n, ID)
        field = mask and n.min(field, mask) or field
        return n.min(field, n.sub(band(), n.const(0.5)))
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    local function cracks()
        local a = n.clamp(n.mul(n.add(n.contour("sp_crack", CRACK_FREQ, 1), n.const(-CRACK_W)), n.const(-3.0)), 0.0, 1.0)
        return n.max(a, n.clamp(n.mul(n.add(n.contour("sp_crack_b", CRACK_B_FREQ, 1), n.const(-CRACK_W)), n.const(-3.0)), 0.0, 1.0))
    end
    local conditions = {
        -- 1: the crust.
        n.const(1.0),
        -- 2: the polygon cracks: dark seams of clay in it.
        n.sub(cracks(), n.const(0.5)),
        -- 3: a pool's bed: mud under the brine.
        n.sub(pool_w(), n.const(0.5)),
        -- 4: the pan's edge, where its weight falls off: dried mud.
        n.sub(n.const(RIM_W), shape.province_weight("b", SPLIT)),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    code = n.mul(code, step(masked(n.const(1.0))))
    local depth = shape.compile("biome.salt.depth", shape.terrain(false))
    local codes = shape.compile("biome.salt.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 2 * km, material = blocks.salt },
        { code = 1, from = 2 * km, to = 6 * km, material = blocks.dry_clay },
        { code = 2, to = 1 * km, material = blocks.dry_clay },
        { code = 2, from = 1 * km, to = 2 * km, material = blocks.salt },
        { code = 2, from = 2 * km, to = 6 * km, material = blocks.dry_clay },
        { code = 3, to = 1 * km, material = blocks.mud },
        { code = 3, from = 1 * km, to = 6 * km, material = blocks.wet_clay },
        { code = 4, to = 2 * km, material = blocks.dried_mud },
        { code = 4, from = 2 * km, to = 6 * km, material = blocks.dry_clay },
    }
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt)
            if #list > 0 then
                fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                    salt = salt, sink = 1, stand = shape.compile("biome.salt.stand_" .. name, masked(field)) }
            end
        end
        -- On the crust, off the pools and the edge.
        local crust = n.min(n.sub(n.const(0.3), pool_w()), n.sub(shape.province_weight("b", SPLIT), n.const(0.7)))
        scatter("pillar", built.pillars, crust, PILLAR_CELL, PILLAR_SQUARES, 191)
        scatter("snag", built.snags, crust, SNAG_CELL, SNAG_SQUARES, 192)
    end
    -- The brine, last: a block deep in the pools, at the pan's floor less
    -- what the pool is sunk, by the terraced fluid fill.
    fills[#fills + 1] = {
        fluid = BRINE,
        level = shape.compile("biome.salt.brine_level", n.add(n.mul(n.add(n.add(shape.relief_node(), shape.dome_node()), ripple()),
            n.const(1.0 / shape.SCALE)), n.const(shape.Y0 + (FLOOR - POOL_D + POOL_FILL) / shape.SCALE))),
        within = shape.compile("biome.salt.brine_within", masked(n.sub(pool_w(), n.const(0.75)))),
    }
    return fills
end)
