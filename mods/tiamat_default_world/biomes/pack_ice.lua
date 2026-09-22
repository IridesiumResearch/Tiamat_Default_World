-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.8 Pack Ice: the fourth sea lane's surface (2026-09-16), 49.8 to 57 km,
-- off the cold rim.
--
-- The sea frozen into floes: slabs of ice two and a half blocks thick lying
-- on the water with snow drifted on them, split by open leads of black
-- water, buckled into pressure ridges where floes met, and icebergs frozen
-- in among them — standing up to sixteen blocks over the water and forty
-- under it. The shelf and the deep floor under it are the Coastal Cliffs'
-- and the Deep Ocean's, as anywhere.
--
-- The ice is laid by the sea's own fill (`seas.fill` asks `tdw.pack_ice_into`
-- first, and the water takes the room it leaves), at the pool's level,
-- over the lane's water on the true radius, from 130 blocks off its shores. It
-- has no fills of its own: a chunk of sea surface is an air chunk to the
-- generator, which runs no biome fills in it. No new nodes: ice and snow.

local blocks = tdw.blocks
local shape = tdw.shape
local seas = tdw.seas
local n = shape.node
local ID = "pack_ice"

local R2 = shape.R_DISC * shape.R_DISC
local PACK_U = { 0.694, 1.0 }                            -- the fourth lane's water
local OFFSHORE = 130.0                                   -- blocks off any coastline or sill the pack starts: the level map ramps between pools there, and open water along the shores reads right
local FLOE_FREQ, FLOE_MIN = 1 / 70, -0.10                -- floes over about three fifths of the water
local LEAD_FREQ, LEAD_W = 1 / 110, 2.5                   -- open leads along a contour
local THICK_UNDER, THICK_OVER = 2.0, 0.5                 -- blocks under and over the level
local RIDGE_FREQ, RIDGE_W, RIDGE_H = 1 / 140, 2.0, 2.0   -- pressure ridges, two blocks up
local SNOW_FREQ, SNOW_MIN, SNOW_H = 1 / 25, -0.05, 1.0   -- a block of drift: at 0.6 it shared the floe's top block and did not show
local BERG_FREQ, BERG_MIN, BERG_EDGE = 1 / 300, 0.34, 6.0
local BERG_UP, BERG_DOWN = 16.0, 40.0
local BERG_LUMP_FREQ, BERG_LUMP = 1 / 12, 6.0

function tdw.pack_zone(x, z)
    local only = tdw.config.everywhere
    if only then
        return only == ID and ID or nil
    end
    local u = (x * x + z * z) * 1e-6 / R2
    return u >= PACK_U[1] and ID or nil
end
tdw.pack_u = { PACK_U[1], PACK_U[2] }

tdw.biomes[ID].ring_mode = "edge"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.ice
tdw.biomes[ID].present = function(pos)
    return false
end
tdw.biomes[ID].locate = function(px, pz, seed)
    return seas.locate(px, pz, seed, 260.0, seas.DIST_FAR, PACK_U[1], PACK_U[2])
end
tdw.build_biome(ID, function(ctx)
    return {}
end)

-- ------------------------------------------------------------ the ice

local ICE, SNOW = nil, nil
local function programs()
    if ICE then
        return ICE, SNOW
    end
    local y = n.Y()
    -- The pool's level from its map, world blocks: one operation, where the
    -- fluid's own stepped level is three hundred and would be read five
    -- times. The two differ only over a map sample of a sill.
    local level = n.add(n.mul(seas.level(), n.const(1000.0)), n.const(shape.Y0))
    local u = n.mul(n.add(n.mul(n.X(), n.X()), n.mul(n.Z(), n.Z())), n.const(1e-6 / R2))
    local where = n.min(n.sub(seas.d_map(), n.const(OFFSHORE)), n.mul(n.sub(u, n.const(PACK_U[1])), n.const(1e5)))
    -- A floe: the noise over its cut, off the leads, in blocks-ish units.
    local floe = n.min(n.mul(n.sub(n.noise("pi_floe", FLOE_FREQ, 2, 1.0), n.const(FLOE_MIN)), n.const(40.0)),
        n.sub(n.contour("pi_lead", LEAD_FREQ, 1), n.const(LEAD_W)))
    local ridge = n.clamp(n.add(n.mul(n.contour("pi_ridge", RIDGE_FREQ, 1), n.const(-1.0 / RIDGE_W)), n.const(1.0)), 0.0, 1.0)
    local top = n.add(level, n.add(n.mul(ridge, n.const(RIDGE_H)), n.const(THICK_OVER)))
    local slab = n.min(n.min(n.sub(top, y), n.sub(y, n.sub(level, n.const(THICK_UNDER)))), floe)
    -- A berg: `w` over the blob, standing BERG_UP over the level and
    -- BERG_DOWN under it at full weight, lumpy.
    local w = n.clamp(n.mul(n.min(n.sub(n.noise("pi_berg", BERG_FREQ, 2, 1.0), n.const(BERG_MIN)),
        n.sub(n.noise("pi_berg_b", BERG_FREQ, 2, 1.0), n.const(BERG_MIN))), n.const(BERG_EDGE)), 0.0, 1.0)
    local lump = n.noise("pi_lump", BERG_LUMP_FREQ, 2, BERG_LUMP)
    -- Deepest operands first throughout: the engine holds every pending one
    -- in one of its eight buffers.
    local berg = n.min(n.sub(n.add(n.add(n.mul(w, n.const(BERG_UP)), lump), level), y),
        n.add(n.mul(n.clamp(n.mul(n.min(n.sub(n.noise("pi_berg", BERG_FREQ, 2, 1.0), n.const(BERG_MIN)),
            n.sub(n.noise("pi_berg_b", BERG_FREQ, 2, 1.0), n.const(BERG_MIN))), n.const(BERG_EDGE)), 0.0, 1.0), n.const(BERG_DOWN)), n.sub(y, level)))
    ICE = shape.compile("pack_ice.ice", n.min(n.max(n.sub(berg, n.const(1.0)), slab), where))
    local snow = n.min(n.min(n.sub(n.add(top, n.const(SNOW_H)), y), n.sub(y, top)),
        n.min(floe, n.mul(n.sub(n.noise("pi_snow", SNOW_FREQ, 2, 1.0), n.const(SNOW_MIN)), n.const(40.0))))
    SNOW = shape.compile("pack_ice.snow", n.min(snow, where))
    return ICE, SNOW
end

local LEVEL = nil
-- Called by `seas.fill` before the water, for every chunk the sea fills.
function tdw.pack_ice_into(buf, pos)
    if tdw.config.everywhere then
        return
    end
    local cx, cz = pos.x * 16 + 8, pos.z * 16 + 8
    local u = (cx * cx + cz * cz) * 1e-6 / R2
    if u < PACK_U[1] - 0.004 then
        return
    end
    LEVEL = LEVEL or shape.compile("pack_ice.level", n.add(n.mul(seas.level(), n.const(1000.0)), n.const(shape.Y0)))
    local b = LEVEL:bounds(pos)
    local y0 = pos.y * 16
    if y0 + 16 < b.low - BERG_DOWN - 2 or y0 > b.high + BERG_UP + BERG_LUMP + 4 then
        return
    end
    local ice, snow = programs()
    buf:fill_density(ice, blocks.ice, shape.SURFACE_DETAIL)
    buf:fill_density(snow, blocks.snow, shape.SURFACE_DETAIL)
end
