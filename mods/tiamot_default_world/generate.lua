-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- The generator: one callback, a gate, and a short list of native fills.
--
-- Most of a 120,000-block world is solid rock or open air that no noise can
-- change. The gate classifies each chunk from its integer bounds — always
-- conservatively, so a chunk near a boundary can only pay MORE than it needed,
-- never generate differently — and runs only the fills that can matter.
--
-- Two depths drive it. T is the noisy terrain field: where the real surface
-- is, known to within the relief — and the engine says how far, exactly:
-- `Density:bounds` is an interval extension of the program (since engine
-- 9f01f67), so T's range over a chunk is read off the compiled field rather
-- than derived by hand here, and cannot drift from it. D is the smooth
-- depth below the base dome, known exactly. The skin (the soil, the biome's
-- block) follows T; the deep bands (gloam, abyss) follow D, so a chunk two
-- kilometres down pays for no noise at all.
--
-- **The first fill at a surface gives it its shape**, and sub-node fills
-- only ADD cells (see shape.lua), so the order is: the whole solid body as
-- DIRT, smooth — that is the surface; then stone from five blocks down, the
-- deep bands, and the biome's own top, each writing only where it is
-- positive and leaving the surface's shape alone. Then the core stack over
-- the middle, and the Hollow carved out of it. Rocks, trees and pools are
-- not generated at all: they are grown afterwards, by random tick, where the
-- surface can be read (biomes/temperate_woodlands.lua).
--
-- Nothing here samples a field. Everything in Lua is a BOUND on a chunk,
-- computed with + - * / on doubles, which is IEEE-exact everywhere.

local shape = tdw.shape
local layers = tdw.layers
local blocks = tdw.blocks
local P = shape.programs
local AIR = game.AIR
local DETAIL = shape.SURFACE_DETAIL

local SCALE = shape.SCALE
local R2_DISC = shape.R_DISC * shape.R_DISC
local NOISE_BOUND = 0.5           -- the fractal stays within +/-0.42 (the body warp's bound)
local SAFETY = 0.05               -- km, added to every bound
local WARP_HI = 1.0 + shape.FLANK_WARP * NOISE_BOUND
local WARP_LO = 1.0 - shape.FLANK_WARP * NOISE_BOUND
local STACK_Y_BLOCKS = shape.STACK_Y * 1000 + shape.Y0
local HOLLOW_IN = (shape.HOLLOW_R - SAFETY) * (shape.HOLLOW_R - SAFETY)

-- Chunk-class counters, logged now and then so the cost mix is visible.
local stats = { air = 0, hollow = 0, filled = 0, carved = 0, surface = 0, shells = 0, total = 0, stamped = 0, by_layers = 0 }
local LOG_EVERY = 1024        -- was 4096: a ninety-second headless run never reached one line

-- Smallest and largest |value| over the integer range [a0, a1].
local function axis_bounds(a0, a1)
    local lo
    if a0 <= 0 and a1 >= 0 then
        lo = 0
    else
        lo = math.min(math.abs(a0), math.abs(a1))
    end
    return lo, math.max(math.abs(a0), math.abs(a1))
end

-- The deepest band a chunk is guaranteed to be in, from the smooth depth:
-- its material and how many of the band fills it already implies.
-- The white placeholder, and what it stands for: see tdw.config. Nil when
-- the switch is off or the core mod is not in the set, and then every
-- material below is the one the layer table names.
local WHITE = nil
if tdw.config.white_unbuilt then
    local ok, id = pcall(game.get_block_id, "core:white")
    if ok and id then
        WHITE = id
        game.log("tiamot_default_world: everything under the surface band is white — no biome claims it yet (tdw.config.white_unbuilt)")
    end
end
-- The material for a part of the world no biome has claimed.
local function unclaimed(material)
    return WHITE or material
end

local DEEP_D = shape.SURFACE_BAND_D

local function band_for(dmin)
    if dmin > shape.ABYSS_D + SAFETY then return unclaimed(blocks.abyss_stone), 2 end
    if dmin > shape.GLOAM_D + SAFETY then return unclaimed(blocks.gloam_stone), 1 end
    -- The surface band is the one depth band whose area has biomes; below
    -- it the normal caves begin, and nothing is built there.
    if dmin > DEEP_D + SAFETY then return unclaimed(blocks.stone), 0 end
    return blocks.stone, 0
end

-- The world seed reaches Lua as an integer when it fits one and as a FLOAT
-- when it does not (half of all seeds), and a float in a bitwise expression
-- is an error that disables the mod. So a hashable integer is derived once,
-- from the low bits, and that is what the random-tick handlers mix in.
local function seed_int(seed)
    local whole = math.tointeger(seed)
    if whole then
        return whole
    end
    return math.tointeger(seed % 4294967296.0) or 0
end

-- The seas: the engine's terraced fluid at each pool's level, wherever the
-- sea maps say (seas.lua). Asked of every chunk inside the body; the fill
-- answers from the maps' bounds and costs nothing where no sea reaches.
local function sea_into(buf, pos, u_lo, u_hi, inside_body)
    local seas = tdw.seas
    if inside_body and seas and seas.on() then
        seas.fill(buf, pos, u_lo, u_hi)
    end
end

-- The rivers' water: a biome's `fluid` fill, laid per column at its own
-- level and held up by lips (engine `fill_fluid_terraced`; see
-- biomes/river_valleys.lua). After the structures, so it takes the room
-- they leave.
local WATER_ABOVE = 0.008                  -- km: how far over the ground a river's surface can stand
local function waters_into(buf, found, mode)
    if not buf.fill_fluid_terraced then
        return
    end
    for _, biome in ipairs(found) do
        for _, fill in ipairs(tdw.fills_for(biome, mode)) do
            if fill.fluid then
                buf:fill_fluid_terraced({ level = fill.level, within = fill.within, fluid = fill.fluid, lip = fill.lip })
            end
        end
    end
end

-- The structures: every biome's `scatter` fills. `tmax` is the terrain's
-- bound over the chunk, and a chunk of AIR over the ground (a negative
-- tmax) runs only the fills that say how far above the ground they reach
-- (`above`, km) and reach it. **Before this a chunk wholly over the ground
-- stamped nothing**, since the generator returns early for air — so a
-- rainforest megatree was cut off at the first chunk boundary above its
-- roots, and seventy blocks of tree were fifteen.
local STRUCTURE_ABOVE = 0.08               -- km: the tallest reach of any fill that says
local function structures_into(buf, found, mode, tmax)
    if not buf.scatter then
        return
    end
    for _, biome in ipairs(found) do
        for _, fill in ipairs(tdw.fills_for(biome, mode)) do
            if fill.scatter and (tmax >= 0 or (fill.above and tmax > -fill.above)) then
                stats.stamped = stats.stamped + buf:scatter({ depth = fill.depth, stand = fill.stand,
                    schematics = fill.schematics, cell = fill.cell, chance = fill.chance, salt = fill.salt, sink = fill.sink })
            end
        end
    end
end

-- The world seed in THIS VM. The generator runs in worker VMs now (engine:
-- terrain generates off the tick), so the seed it records there never
-- reaches the main VM, and the spawn's aim (`shape.ground_at_column`)
-- reads nil and stands down. The chunk tint is asked in the workers too.
-- Nothing on the main thread carries the seed today — engine-asks 21 —
-- so `game.world_seed` is read wherever the seed is wanted, for the day
-- the engine sets it.
local function generate(buf, pos)
    if tdw.seed ~= pos.seed then
        tdw.seed = pos.seed
        tdw.seed_int = seed_int(pos.seed)
    end
    stats.total = stats.total + 1
    if stats.total % LOG_EVERY == 0 then
        game.log(string.format(
            "tiamot_default_world chunks: %d total — air %d, hollow %d, filled %d, carved %d (%d by the layers alone; surface %d, %d structures stamped), shells %d",
            stats.total, stats.air, stats.hollow, stats.filled, stats.carved, stats.by_layers, stats.surface, stats.stamped, stats.shells))
    end

    -- Order-independent with any other overworld generator: start empty.
    buf:fill_all(AIR)

    -- Integer bounds of the chunk, in blocks.
    local x0, z0, y0 = pos.x * 16, pos.z * 16, pos.y * 16
    local x1, z1, y1 = x0 + 15, z0 + 15, y0 + 15
    local xlo, xhi = axis_bounds(x0, x1)
    local zlo, zhi = axis_bounds(z0, z1)
    local r2lo = (xlo * xlo + zlo * zlo) * 1e-6     -- km^2
    local r2hi = (xhi * xhi + zhi * zhi) * 1e-6
    local ulo, uhi = r2lo / R2_DISC, r2hi / R2_DISC
    local Ylo, Yhi = (y0 - shape.Y0) * SCALE, (y1 - shape.Y0) * SCALE   -- Spindle km

    -- D, the smooth depth below the base dome: exact bounds.
    local dmax = shape.dome_at(ulo) - Ylo
    local dmin = shape.dome_at(uhi) - Yhi
    -- Which ring's programs: one ring's own away from the bands where
    -- rings meet, the cross-faded ones in them (shape.lua, "terrain MODES").
    local mode = shape.terrain_mode_for(ulo, uhi, pos)
    local T = shape.top_for(mode)
    -- T, the real depth: the engine's bound on the terrain field over this
    -- chunk. Wrong in one direction only — it may say "maybe" about a chunk
    -- that turns out to be air, never "air" about one that is not.
    local t = T.solid:bounds(pos)
    local tmin, tmax = t.low, t.high
    -- A sea floor's deep bands are measured from the terrain (shape.lua,
    -- `BANDS_BY_TERRAIN`): the gate's depths are the terrain's there too.
    if shape.BANDS_BY_TERRAIN[mode] then
        dmin, dmax = tmin, tmax
    end

    -- Bounds on the body: W is non-decreasing in Y.
    local w_hi = shape.half_width_at(Yhi) * WARP_HI + SAFETY
    local w_lo = shape.half_width_at(Ylo) * WARP_LO - SAFETY
    local outside_body = r2lo > w_hi * w_hi
    local inside_body = w_lo > 0 and r2hi < w_lo * w_lo

    -- Bounds on the squared ellipsoidal distance from the stack centre.
    local dylo, dyhi = axis_bounds(y0 - STACK_Y_BLOCKS, y1 - STACK_Y_BLOCKS)
    local ks = shape.K * SCALE
    local e2lo = r2lo + (dylo * ks) * (dylo * ks)
    local e2hi = r2hi + (dyhi * ks) * (dyhi * ks)

    -- Air: above the surface, beyond the body, or wholly inside the Hollow.
    if tmax < 0 or outside_body then
        stats.air = stats.air + 1
        -- The tops of tall structures standing on ground under this chunk;
        -- then the sea, which a chunk of air over the seabed still gets;
        -- then a river's or a pool's, whose surface stands over a bed that
        -- may be in the chunk below.
        local found = nil
        if inside_body and tmax > -math.max(WATER_ABOVE, STRUCTURE_ABOVE) then
            found = tdw.present_biomes_in(ulo, uhi, pos)
            structures_into(buf, found, mode, tmax)
        end
        sea_into(buf, pos, ulo, uhi, inside_body)
        if found and tmax > -WATER_ABOVE then
            waters_into(buf, found, mode)
        end
        return
    end
    if e2hi < HOLLOW_IN then
        stats.hollow = stats.hollow + 1
        return
    end

    -- Rock. Which programs, and what it is made of.
    local V = inside_body and T or P.flank
    local base, level = band_for(dmin)
    local tail = false
    if Yhi < shape.APEX_Y then
        base, tail = unclaimed(blocks.apex_stone), true
    elseif Yhi < shape.TAIL_Y then
        base, tail = unclaimed(blocks.marrow), true
    end
    -- Within reach of the skin, the body is painted as the biome's soil
    -- first and stone is put back from five blocks down: that keeps the
    -- surface's shape in one smooth fill.
    local skin = not tail and tmin < shape.SKIN_DIRT
    if skin then
        base = tdw.surface_soil(ulo, uhi)
    end

    -- **The body by the biome's layered fill, where there is one.** A chunk
    -- wholly in one biome whose surface is a layered fill gets its body —
    -- the soil to SKIN_DIRT, the stone below — from the same evaluation
    -- that lays the layers (the engine's wildcard layer, code -1), and the
    -- generator's own body fill and its stone fill are not run: three
    -- evaluations of the terrain a chunk were one, and the coast at
    -- forty-eight milliseconds a chunk asked for it. A chunk two biomes
    -- share keeps the old path: a wildcard cannot know whose ground it is.
    local found = (skin and inside_body and tmin < shape.SKIN_TOP) and tdw.present_biomes_in(ulo, uhi, pos) or nil
    local body_by_layers = nil
    if found and #found == 1 then
        for _, fill in ipairs(tdw.fills_for(found[1], mode)) do
            if fill.layers and fill.body then
                body_by_layers = fill
            end
        end
    end

    if inside_body and tmin > 0 then
        buf:fill_all(base)
        stats.filled = stats.filled + 1
    elseif body_by_layers then
        stats.carved = stats.carved + 1
        stats.by_layers = stats.by_layers + 1
    else
        buf:fill_density(V.solid, base, DETAIL)
        stats.carved = stats.carved + 1
    end

    if not tail then
        if skin then
            stats.surface = stats.surface + 1
            if tmax > shape.SKIN_DIRT and not body_by_layers then
                buf:fill_density(V.stone, blocks.stone, DETAIL)
            end
        end
        -- The deep bands, exact and free of noise. The first of them is the
        -- top of what no biome claims: a chunk wholly below it took the
        -- placeholder as its base, and one straddling it takes this fill.
        if WHITE and dmin <= DEEP_D + SAFETY and dmax > DEEP_D - SAFETY then
            buf:fill_density(V.deep, WHITE, DETAIL)
        end
        if level < 1 and dmax > shape.GLOAM_D - SAFETY then
            buf:fill_density(V.gloam, unclaimed(blocks.gloam_stone), DETAIL)
        end
        if level < 2 and dmax > shape.ABYSS_D - SAFETY then
            buf:fill_density(V.abyss, unclaimed(blocks.abyss_stone), DETAIL)
        end
        if skin and inside_body and tmin < shape.SKIN_TOP then
            -- The biome's own top.
            local found = tdw.present_biomes_in(ulo, uhi, pos)
            local function fills_of(biome)
                return tdw.fills_for(biome, mode)
            end
            for _, biome in ipairs(found) do
                for _, fill in ipairs(fills_of(biome)) do
                    if fill.layers then
                        -- Every layer of the surface from one evaluation of
                        -- the terrain and one of a code field (engine
                        -- `fill_layers`); eight fills were eight evaluations.
                        -- And the body too, where this chunk is the biome's
                        -- alone: the wildcard bands after the coded ones.
                        local entries = fill.entries
                        if fill == body_by_layers then
                            entries = {}
                            for _, e in ipairs(fill.entries) do entries[#entries + 1] = e end
                            entries[#entries + 1] = { code = -1, to = shape.SKIN_DIRT, material = base }
                            entries[#entries + 1] = { code = -1, from = shape.SKIN_DIRT, to = math.huge, material = blocks.stone }
                        end
                        buf:fill_layers(fill.depth, fill.code, entries)
                    elseif fill.field and (not fill.shared_only or #found > 1) then
                        -- A fill may ask for its own detail.
                        buf:fill_density(fill.field, fill.material, fill.detail or DETAIL)
                    end
                end
            end
            -- The covers, after EVERY biome's fills: a cover reads the
            -- surface the fills wrote, and where two biomes share a chunk
            -- the second's turf must be down before the first's grass
            -- stands on it. The engine keeps a run inside one block and
            -- never stands one on another (`fill_cover`).
            for _, biome in ipairs(found) do
                for _, fill in ipairs(fills_of(biome)) do
                    if fill.cover then
                        buf:fill_cover(fill.cover, { cells = fill.cells, take = fill.take })
                    end
                end
            end
            -- The structures, after the covers: a trunk's base merges into
            -- the surface block over the grass cells stood in it. The
            -- engine's `scatter` does the whole neighbourhood pass — every
            -- chunk within reach derives the same trees and keeps its slice.
            structures_into(buf, found, mode, math.huge)
            -- The sea, after the terrain AND the structures: the fluid fill
            -- takes only the room they leave (it was before the structures,
            -- which put water inside every kelp stand and boulder).
            sea_into(buf, pos, ulo, uhi, inside_body)
            -- Then rivers and brine pools, which take the sea's place.
            waters_into(buf, found, mode)
        end
    end
    if not (skin and inside_body and tmin < shape.SKIN_TOP) then
        -- A chunk of rock under a sea's floor is still under its water: the
        -- flooded caves and tunnels, and the deep water over a trench.
        sea_into(buf, pos, ulo, uhi, inside_body)
    end

    -- The core stack, outermost first, only the shells this chunk can touch.
    local touched = false
    for _, shell in ipairs(shape.SHELLS) do
        local id, outer, inner = shell[1], shell[2], shell[3]
        if e2lo < outer * outer and e2hi > inner * inner then
            buf:fill_density(P.shells[id], unclaimed(blocks[layers.SHELL_MATERIAL[id]]), DETAIL)
            touched = true
        end
    end
    if e2lo < shape.HOLLOW_R * shape.HOLLOW_R then
        buf:fill_density(P.hollow, AIR, DETAIL)
        touched = true
    end
    if touched then
        stats.shells = stats.shells + 1
    end
end
-- Under pcall so the message reaches the log: the engine reports a
-- generation failure as "errored in on_generate" and no more, and the
-- chunk is air — a program past the eight buffers, compiled at the first
-- alpine chunk, was a world of air with nothing to read.
game.register_on_generate(function(buf, pos)
    local ok, err = pcall(generate, buf, pos)
    if not ok then
        game.log(string.format("tiamot_default_world: generating chunk %d, %d, %d failed: %s", pos.x, pos.y, pos.z, tostring(err)))
        error(err, 0)
    end
end)

game.log("tiamot_default_world: registered the generator")
