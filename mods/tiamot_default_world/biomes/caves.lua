-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- The normal caves (2026-09-18): the framework the cave biomes hang on.
--
-- WHERE. The depth band from CAVE_TOP to the Gloam (layers.lua: 100 to
-- 1,600 blocks under the base dome), measured from the smooth depth D. The
-- top is pushed down under the world's relief and a margin, so no cave
-- breaks the floor of a valley or a sea: 120 blocks under the SMOOTH ground
-- wherever that is (`top()`), and only in chunks that are rock throughout
-- (generate.lua), so a cave never opens into a biome's soil.
--
-- WHICH. A slow noise, flat in y, is the caves' province (`province()`):
-- each cave biome takes a band of its value, so the caves change kind
-- every few hundred blocks across. A chunk asks once, at its centre, which biome it is (`biomes_in`),
-- and runs that biome's fills alone; a chunk on the line runs both, each
-- cut to its own side by `weight`.
--
-- HOW A BIOME IS BUILT. `tdw.cave_biome(id, function(ctx) ... end)` returns
-- a list of fills in the order they run, in the biome's own terms:
--   { carve = Density }             air where positive (blocks, distance-like)
--   { layers, depth, code, entries }  the linings, `depth` positive INTO the rock
--   { cover, cells, take }            covers on the floors
--   { scatter, depth, schematics, ... }  structures: `depth` positive in rock
--                                     roots on floors; positive in AIR roots on
--                                     ceilings (engine `scatter` stamps at any
--                                     rock-over-air crossing, whichever way up)
--   { fluid, level, within, lip }     pools and rivers
-- Every field a biome builds is already cut to its province by
-- `ctx.mine(field)`; a biome need not think about its neighbours.
--
-- THE HUD. `tdw.cave_under(x, y, z)` answers the cave biome a player is in
-- when they stand in, or within a couple of blocks of, one of its voids.
-- `/tp <cave biome>` (whereami.lua) drops them into the nearest void.

local shape = tdw.shape
local n = shape.node
local M = {}
tdw.caves = M

M.TOP = 0.10                    -- km under the base dome: the band's top...
M.BOTTOM = shape.GLOAM_D        -- ...and its bottom (the Gloam takes over)
M.MARGIN = 0.12                 -- km under the smooth ground a cave may begin
M.EDGE = 0.03                   -- km: the band's ends fade over this
M.PROVINCE_FREQ = 1 / 700
-- Flat in y (2026-09-18): a terraced fluid fill reads its `level` and
-- `within` on ONE slice of the world, at y = 0.5 — not on the chunk's
-- floor — so a province that varied with depth put a cave's pools and
-- rivers in the wrong biome's ground and they were never laid. The
-- caves change kind across the map, not down it.
M.PROVINCE_STRETCH = shape.HUMIDITY_STRETCH
M.BLEND = 0.04                  -- the province noise's units: a biome fades out over this at its line
-- The biomes' bands of the province noise, low to high. A biome is
-- registered with its band; the list is what `biomes_in` walks.
-- Six since 2026-09-18, a sixth of the ground each (the noise runs about
-- normal, sd 0.34), neighbours kin: Crystal Seam under -0.33, Mineral Vein
-- Tunnels to -0.15, Stalactite Forests to 0, Mossy Limestone to 0.15,
-- Fungal Grove Chambers to 0.33, Underground River over it.
M.bands = {}

-- The smooth depth in km, positive down (shape.depth), and the band.
function M.D()
    return shape.depth()
end
-- The band's top under THIS column: TOP under the dome, or MARGIN under the
-- smooth ground where the relief lifts or sinks it. `relief_node` is km
-- over the dome, so the ground is at depth -relief.
function M.top()
    return n.max(n.const(M.TOP), n.add(n.mul(shape.relief_node(), n.const(-1.0)), n.const(M.MARGIN)))
end
-- Positive inside the band, in km, fading at both ends. The depth FIRST.
function M.band()
    local d = M.D()
    return n.min(n.sub(d, M.top()), n.sub(n.const(M.BOTTOM), M.D()))
end
function M.province()
    return n.noise("cave_province", M.PROVINCE_FREQ, 2, 1.0, M.PROVINCE_STRETCH)
end
-- **The crystal veins** (2026-09-18: "reduce the amount of random Crystal
-- and Crystal seams. Rather let's have veins of it running through the
-- rock around and also through the caves"). A vein is where two stretched
-- noises are BOTH near zero: the line two wandering sheets cross along, a
-- tube VEIN.W blocks either side of it, drawn out flat (VEIN.STRETCH) so a
-- vein runs along the rock for tens of blocks rather than up through it.
-- Only in vein fields, where a slow noise is over `zone_min`; each cave
-- biome passes its own, and its own frequency: how many veins there are
-- goes with the square of it (measured, at 1/48: a quarter of one per
-- cent of the rock; the Crystal Seam's 1/30 is some three times that).
-- Blocks: positive inside the vein.
--
-- Every cave biome lays the veins itself, AFTER its lining and with its
-- own void cut out (`vein_fill`): the linings paint the last few blocks of
-- rock round a void, and veins laid before them were painted over at the
-- very walls where a vein should show; laid after, and not into the void,
-- a vein runs through the rock and out across every wall, floor and
-- ceiling a cave cuts through it.
local VEIN = {
    FREQ = 1 / 48, STRETCH = { x = 2.5, z = 2.5 },
    W = 1.1, K = 30.0,                    -- blocks either side of the line; the noise's blocks per unit near zero
    W_FREQ = 1 / 20, W_VARY = 0.5,       -- the vein's thickness wanders
    ZONE_FREQ = 1 / 260,
}
M.VEIN = VEIN
function M.vein_node(zone_min, freq)
    freq = freq or VEIN.FREQ
    local w = n.add(n.noise("crystal_vein_w", VEIN.W_FREQ, 1, VEIN.W_VARY), n.const(VEIN.W))
    local a = n.sub(w, n.mul(n.abs(n.noise("crystal_vein_a", freq, 1, 1.0, VEIN.STRETCH)), n.const(VEIN.K * VEIN.FREQ / freq)))
    local b = n.sub(n.add(n.noise("crystal_vein_w", VEIN.W_FREQ, 1, VEIN.W_VARY), n.const(VEIN.W)),
        n.mul(n.abs(n.noise("crystal_vein_b", freq, 1, 1.0, VEIN.STRETCH)), n.const(VEIN.K * VEIN.FREQ / freq)))
    local zone = n.mul(n.sub(n.noise("crystal_vein_zone", VEIN.ZONE_FREQ, 1, 1.0), n.const(zone_min)), n.const(40.0))
    return n.min(n.min(a, b), zone)
end
-- The fill a cave biome lays its veins with: into its own province and
-- band, not into `void` (its void field, blocks, positive in the air). The
-- void FIRST: it is the deepest operand.
function M.vein_fill(ctx, void, zone_min, freq)
    return {
        field = ctx.compile("veins", ctx.mine(n.min(n.mul(void, n.const(-1.0)), M.vein_node(zone_min, freq)))),
        material = tdw.blocks.crystal,
        detail = shape.SURFACE_DETAIL,
    }
end

-- 0 to 1: how much of this place is biome `id`'s — its band of the
-- province, and the depth band.
function M.weight(id)
    local band = M.bands[id]
    assert(band, "no cave biome called " .. tostring(id))
    local w = n.clamp(n.mul(M.band(), n.const(1.0 / M.EDGE)), 0.0, 1.0)
    local p = M.province()
    if band[1] > -1 then
        w = n.min(w, n.clamp(n.mul(n.sub(p, n.const(band[1])), n.const(1.0 / M.BLEND)), 0.0, 1.0))
    end
    if band[2] < 1 then
        w = n.min(w, n.clamp(n.mul(n.sub(n.const(band[2]), M.province()), n.const(1.0 / M.BLEND)), 0.0, 1.0))
    end
    return w
end
-- A biome's field cut to its own ground: positive only where its weight is
-- over a half, so two biomes on the line never carve the same block. The
-- line is a wall of rock between two caves, steep at twenty blocks of
-- field per block of ground (a hundred left a razor edge the smooth
-- carve rendered as stray cells in the void).
function M.mine(id, field)
    return n.min(field, n.mul(n.sub(M.weight(id), n.const(0.5)), n.const(20.0)))
end
-- The same cut WITHOUT the depth band, for a fluid fill's `level` and
-- `within`: the engine reads those on the slice at y = 0.5, where the
-- depth band is nothing, and a field that reads y there is wrong by the
-- whole height of the world. The province is flat, so it agrees.
function M.mine_flat(id, field)
    local band = M.bands[id]
    local w = n.const(1.0)
    if band[1] > -1 then
        w = n.min(w, n.clamp(n.mul(n.sub(M.province(), n.const(band[1])), n.const(1.0 / M.BLEND)), 0.0, 1.0))
    end
    if band[2] < 1 then
        w = n.min(w, n.clamp(n.mul(n.sub(n.const(band[2]), M.province()), n.const(1.0 / M.BLEND)), 0.0, 1.0))
    end
    return n.min(field, n.mul(n.sub(w, n.const(0.5)), n.const(20.0)))
end

-- ------------------------------------------------------------ registration

local built = {}       -- id -> { fills = {...}, cavity = Density (positive in the void) }
local order = {}

---@param id string  a biome of the normal_caves area (biomes/catalogue.lua)
---@param band number[]  { low, high } of the province noise; -1 and 1 are open ends
---@param build fun(ctx: table): table
function tdw.cave_biome(id, band, build)
    local biome = tdw.biomes[id]
    assert(biome and biome.area == "normal_caves", "cave_biome: " .. tostring(id) .. " is not a normal-caves biome")
    M.bands[id] = band
    order[#order + 1] = id
    biome.cave = true
    biome.built = true
    biome.placed = true
    local ctx = {
        node = n, shape = shape, blocks = tdw.blocks, schem = tdw.schem, caves = M,
        mine = function(field) return M.mine(id, field) end,
        mine_flat = function(field) return M.mine_flat(id, field) end,
        compile = function(name, spec) return shape.compile("cave." .. id .. "." .. name, spec) end,
    }
    -- Built on the first chunk that needs it: the fields read nothing the
    -- pre-pass makes, but the schematics need `game.schematic_shapes`, which
    -- is the same either way, and a cave nobody visits costs nothing.
    built[id] = { build = build, ctx = ctx }
end

local function fills_of(id)
    local entry = built[id]
    if entry.fills == nil then
        local ok, fills = pcall(entry.build, entry.ctx)
        if not ok then
            game.log("tiamot_default_world: building the cave " .. id .. " failed: " .. tostring(fills))
            error(fills, 0)
        end
        entry.fills = fills
        for _, fill in ipairs(fills) do
            if fill.carve then
                entry.cavity = fill.carve
            end
        end
        game.log(string.format("tiamot_default_world cave %-20s compiled %d fill(s)", id, #fills))
    end
    return entry.fills
end
M.fills_of = fills_of
function M.cavity_of(id)
    fills_of(id)
    return built[id].cavity
end

-- ------------------------------------------------------------ the chunk

local PROVINCE = nil
-- The cave biomes a chunk may hold: those whose band the province noise at
-- the chunk's centre is in or within BLEND of. Empty above or below the
-- band, which `dmin`/`dmax` (the chunk's smooth-depth bounds) decide.
function M.biomes_in(pos, dmin, dmax)
    if dmax < M.TOP or dmin > M.BOTTOM then
        return nil
    end
    PROVINCE = PROVINCE or shape.compile("cave.province", M.province())
    local p = PROVINCE:at(pos.x * 16 + 8.5, pos.y * 16 + 8.5, pos.z * 16 + 8.5, pos.seed)
    local found = nil
    for _, id in ipairs(order) do
        local band = M.bands[id]
        if p > band[1] - M.BLEND and p < band[2] + M.BLEND then
            found = found or {}
            found[#found + 1] = id
        end
    end
    return found
end

local DETAIL = shape.SURFACE_DETAIL
local AIR = game.AIR
local stats = { chunks = 0, carved = 0, stamped = 0 }
M.stats = stats
-- Runs the cave fills of a chunk that is rock throughout. `tmax` is the
-- terrain's greatest depth over the chunk (positive: rock), for the
-- structures' reach.
function M.into(buf, pos, dmin, dmax)
    local found = M.biomes_in(pos, dmin, dmax)
    if found == nil then
        return
    end
    stats.chunks = stats.chunks + 1
    for _, id in ipairs(found) do
        for _, fill in ipairs(fills_of(id)) do
            if fill.carve then
                buf:fill_density(fill.carve, AIR, DETAIL)
                stats.carved = stats.carved + 1
            elseif fill.layers then
                buf:fill_layers(fill.depth, fill.code, fill.entries)
            elseif fill.field then
                buf:fill_density(fill.field, fill.material, fill.detail or DETAIL)
            elseif fill.cover then
                buf:fill_cover(fill.cover, { cells = fill.cells, take = fill.take })
            elseif fill.scatter and buf.scatter then
                stats.stamped = stats.stamped + buf:scatter({ depth = fill.depth, stand = fill.stand,
                    schematics = fill.schematics, cell = fill.cell, chance = fill.chance, salt = fill.salt, sink = fill.sink })
            elseif fill.fluid and buf.fill_fluid_terraced then
                buf:fill_fluid_terraced({ level = fill.level, within = fill.within, fluid = fill.fluid, lip = fill.lip })
            end
        end
    end
    if stats.chunks % 512 == 0 then
        game.log(string.format("tiamot_default_world caves: %d chunks, %d carves, %d structures", stats.chunks, stats.carved, stats.stamped))
    end
end

-- ------------------------------------------------------------ the mouths

-- **Where the caves come to the surface** (2026-09-18, "be sure they
-- sometimes come to the surface so you can stumble across one"). A mouth is
-- a winding tunnel along a contour line, MOUTH.W either side of it and
-- MOUTH.H tall, whose depth under the SMOOTH ground follows a slow noise
-- along the way: from MOUTH.LIFT blocks over it down to MOUTH.DEEPEST, at
-- about a block per block at the steepest. Where the descending tube
-- crosses the real ground -- which the biomes' hills put anywhere within
-- tens of blocks of the smooth one -- it opens there; below, it runs on
-- down into the caves' band, where the cave biomes' voids meet it.
--
-- Only in mouth zones (a slow noise over MOUTH.ZONE_MIN), off the seas and
-- out of the river valleys, whose water would pour into it and stand as a
-- wall where its fill stops. Carved in the surface chunks after the biome's
-- paint, its plants and its trees, and in the chunks of rock under them.
-- Bare rock: a mouth has no biome.
local MOUTH = {
    ZONE_FREQ = 1 / 900, ZONE_MIN = 0.04,   -- 0.30 in the first cut: a mouth every four km2
    LINE_FREQ = 1 / 160, W = 2.5, H = 5.0,  -- 1/300 in the first cut
    -- The depth: CENTRE + K times a slow noise (most of it within 0.15 of
    -- zero), so the tube is within a few tens of blocks of the ground for
    -- a stretch in every few hundred (the first cut, (s + 0.5) * 900 - 40,
    -- kept it some 400 down nearly everywhere: 0.25 mouths a km2).
    SLOPE_FREQ = 1 / 4000, K = 2400.0, CENTRE = 80.0, LIFT = 40.0, DEEPEST = 500.0,
    ROUGH_FREQ = 1 / 6, ROUGH = 0.8,
    OFF_SEA = 150.0,
}
M.MOUTH = MOUTH
local MOUTH_FIELD, MOUTH_ZONE = nil, nil
function M.mouth_node()
    local flat = shape.HUMIDITY_STRETCH
    -- Blocks under the smooth ground: the dome's depth plus the relief
    -- (km over the dome), the depth FIRST.
    local under = n.mul(n.add(M.D(), shape.relief_node()), n.const(1000.0))
    local target = n.clamp(n.add(n.mul(n.noise("cave_mouth_slope", MOUTH.SLOPE_FREQ, 1, 1.0, flat), n.const(MOUTH.K)),
        n.const(MOUTH.CENTRE)), -MOUTH.LIFT, MOUTH.DEEPEST)
    -- Within H/2 of the tube's middle height, and W of the line.
    local tall = n.sub(n.const(MOUTH.H / 2), n.abs(n.sub(n.sub(under, target), n.const(MOUTH.H / 2))))
    local void = n.min(tall, n.sub(n.const(MOUTH.W), n.contour("cave_mouth_line", MOUTH.LINE_FREQ, 1)))
    void = n.add(void, n.noise("cave_mouth_rough", MOUTH.ROUGH_FREQ, 1, MOUTH.ROUGH))
    -- The zone, faded over a little of the noise's edge.
    void = n.min(void, n.mul(n.sub(n.noise("cave_mouth_zone", MOUTH.ZONE_FREQ, 1, 1.0, flat), n.const(MOUTH.ZONE_MIN)), n.const(60.0)))
    local seas = tdw.seas
    if seas and seas.on() then
        void = n.min(void, n.mul(n.sub(n.mul(seas.d_map(), n.const(-1.0)), n.const(MOUTH.OFF_SEA)), n.const(0.2)))
    end
    if shape.river_exclude then
        void = shape.river_exclude(void, (shape.RIVER_REACH or 174) + 10)
    end
    return void
end
function M.mouth_field()
    MOUTH_FIELD = MOUTH_FIELD or shape.compile("cave.mouth", M.mouth_node())
    return MOUTH_FIELD
end
-- Whether a chunk may hold a mouth: its centre in or near a zone, and not
-- deeper than the deepest a mouth goes under the highest the smooth ground
-- stands (the relief is never more than RELIEF_MAX km over the dome).
local RELIEF_MAX = 0.45
function M.mouth_chunk(pos, dmin)
    if dmin > (MOUTH.DEEPEST + MOUTH.H) / 1000 + RELIEF_MAX then
        return false
    end
    MOUTH_ZONE = MOUTH_ZONE or shape.compile("cave.mouth_zone",
        n.noise("cave_mouth_zone", MOUTH.ZONE_FREQ, 1, 1.0, shape.HUMIDITY_STRETCH))
    return MOUTH_ZONE:at(pos.x * 16 + 8.5, 0.5, pos.z * 16 + 8.5, pos.seed) > MOUTH.ZONE_MIN - 0.03
end
function M.mouths_into(buf, pos, dmin)
    if M.mouth_chunk(pos, dmin) then
        buf:fill_density(M.mouth_field(), AIR, DETAIL)
    end
end

-- ------------------------------------------------------------ the HUD and /tp

local CAVITY = {}
-- The cave biome at a place, or nil: the first whose void this is in or
-- within two blocks of. Cheap — one province read and one cavity read per
-- candidate — so the HUD may ask every tick.
function tdw.cave_under(x, y, z)
    local seed = game.world_seed or tdw.seed
    if seed == nil or #order == 0 then
        return nil
    end
    PROVINCE = PROVINCE or shape.compile("cave.province", M.province())
    local p = PROVINCE:at(x + 0.5, y + 0.5, z + 0.5, seed)
    for _, id in ipairs(order) do
        local band = M.bands[id]
        if p > band[1] - M.BLEND and p < band[2] + M.BLEND then
            local cavity = M.cavity_of(id)
            if cavity and cavity:at(x + 0.5, y + 0.5, z + 0.5, seed) > -2.0 then
                return id
            end
        end
    end
    return nil
end

-- A place in the void of cave biome `id` near (px, pz): the nearest column
-- whose province is the biome's, and the highest void in its band. x, y, z
-- or nil. Coarse steps out to eight kilometres, then the column.
function M.locate(id, px, pz, seed)
    PROVINCE = PROVINCE or shape.compile("cave.province", M.province())
    local cavity = M.cavity_of(id)
    if cavity == nil then
        return nil
    end
    local band = M.bands[id]
    -- How far inside the band to look: three blends, or a third of the band
    -- where that is less (the six bands of 2026-09-18 are 0.18 wide, and an
    -- inset of 0.12 either side left no ground at all to find).
    local inset = math.min(3 * M.BLEND, (math.min(band[2], 1) - math.max(band[1], -1)) * 0.3)
    local best = nil
    for ring = 0, 40 do
        local r = ring * 200
        local steps = ring == 0 and 1 or 16
        for k = 0, steps - 1 do
            local a = k * 2 * math.pi / steps
            local x, z = math.floor(px + r * math.cos(a)), math.floor(pz + r * math.sin(a))
            local u = (x * x + z * z) * 1e-6 / (shape.R_DISC * shape.R_DISC)
            if u < 0.93 then
                local dome_y = shape.Y0 + 1000 * shape.dome_at(u)
                -- The province at the band's middle, then the column.
                local y_mid = math.floor(dome_y - 1000 * (M.TOP + M.BOTTOM) / 2)
                local p = PROVINCE:at(x + 0.5, y_mid + 0.5, z + 0.5, seed)
                -- Well inside the band, or the first void found is the
                -- wall on the province line.
                if p > band[1] + inset and p < band[2] - inset then
                    for y = math.floor(dome_y - 1000 * M.TOP - 60), math.floor(dome_y - 1000 * M.BOTTOM), -2 do
                        if cavity:at(x + 0.5, y + 0.5, z + 0.5, seed) > 1.0 then
                            return x, y, z
                        end
                    end
                end
            end
        end
    end
    return best
end
