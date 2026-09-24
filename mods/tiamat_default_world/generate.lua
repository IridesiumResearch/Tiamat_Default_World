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
-- Nothing here samples a field — except the ore gate's one point per lode
-- (2026-09-23, below), the sanctioned few-per-chunk kind. Everything else
-- in Lua is a BOUND on a chunk, computed with + - * / on doubles, which is
-- IEEE-exact everywhere.

local shape = tdw.shape
local layers = tdw.layers
local blocks = tdw.blocks
local P = shape.programs
local AIR = game.AIR
local DETAIL = shape.SURFACE_DETAIL

local SCALE = shape.SCALE
local R2_DISC = shape.R_DISC * shape.R_DISC
local SAFETY = 0.05               -- km, added to every bound
local WARP_HI = shape.WARP_HI     -- the rim's wander, either way (shape.lua, the body)
local STACK_Y_BLOCKS = shape.STACK_Y * 1000 + shape.Y0
local HOLLOW_IN = (shape.HOLLOW_R - SAFETY) * (shape.HOLLOW_R - SAFETY)
-- The gloam's light sediment (2026-09-16): flat beds through the dark, a
-- noise stretched wide in x and z so its positive side lies in sheets a few
-- blocks thick. Laid only in chunks wholly of the gloam's rock, so no bed
-- runs into the stone above or out past the body's wall.
local SEDIMENT_BEDS = shape.compile("sediment.beds", shape.node.sub(shape.node.noise("sediment_beds", 1 / 24, 2, 1.0, { x = 10, z = 10 }), shape.node.const(0.12)))
-- The body's own code field: a constant, because its two bands are code -1
-- and take every block whatever the code says. Engine 92267e7 evaluates a
-- layered fill's terrain only where a block's code matches one of that
-- call's layers — so a -1 band in a BIOME's call would force that biome's
-- terrain evaluation everywhere. The body's bands go in a call of their
-- own (the engine agent's note, 2026-09-17).
local BODY_CODE = shape.compile("body.code", shape.node.const(0.0))

-- THE ORES (2026-09-17): veins and clusters of cells inside whatever rock a
-- chunk is made of, each ore from its own depth downward. A field per ore
-- — the smooth depth D past the ore's level (exact, so a chunk above it is
-- skipped for nothing) and a vein noise over a threshold — laid by a smooth
-- `fill_density`, which samples the field per block and carries the edge
-- to the cells: a vein is whole blocks of ore in its middle and a few cells
-- in the rock at its edge. The noise clamps at +/-0.5 and sits at the clamp
-- an eighth of the time, so a single noise can be no rarer than that: the
-- rarer ores are where two or three independent noises are ALL high, and
-- the finer their frequency the smaller the vein and the rarer a whole
-- block of it. Only in chunks that are solid throughout (`tmin > 0`), so
-- an ore never stands in air or in a biome's soil: the ores begin a chunk
-- under the ground.
--   level  km below the base dome    freq   blocks per vein feature
--   min    the noise's threshold     n      independent noises, all over it
--   stretch the vein drawn out along an axis: seams and lodes
--   lode   the ore lies in lode fields, forty blocks across, where a slow
--          noise is over this; between them the rock is bare. Measured
--          without it, every ore was three to seven per cent of the rock
--          — a third of the underground would have been ore.
-- The lodes also GATE the fills (2026-09-23). At these thresholds 70 to 80
-- per cent of chunks are outside a given ore's lodes and paid the whole
-- field's noise to write nothing — `bounds` cannot prune them, because a
-- 16-block box cannot bound a feature forty blocks across. So `ores_into`
-- samples each ore's bare lode noise ONCE, at the chunk's centre (the
-- `biomes_in` idiom, biomes/caves.lua), and skips the fill outright where
-- the sample sits more than LODE_MARGIN under the ore's threshold.
local LODE_FREQ = 1 / 40
-- The gate's safety margin. The lode noise is one octave, amplitude 1.0
-- (so clamped to +/-0.5), frequency 1/40: a 16-block chunk spans about 0.4
-- of a feature wavelength, so the value can move a few tenths between the
-- chunk's centre and its corners. 0.45 — nine tenths of the noise's whole
-- half-range — is chosen so a skipped chunk cannot plausibly hold
-- lode-positive ground (not a proof: a quarter-wavelength swing can
-- exceed it in principle, and the visible symptom below is the check on
-- that choice): the gate is a skip with a wide margin, and the
-- in-field lode term still decides the exact edge wherever the fill runs,
-- so it can only save time, never change the world. The one risk is a
-- margin too tight, and its symptom would be visible: ore veins clipped
-- flat at chunk faces, where a skipped chunk abuts a generated one.
local LODE_MARGIN = 0.45
local ORES = {
    { "copper_ore",   level = 0.00, freq = 1 / 5,   min = 0.42, n = 2, lode = 0.15, stretch = { x = 3 } },
    { "iron_ore",     level = 0.00, freq = 1 / 5,   min = 0.43, n = 2, lode = 0.15, stretch = { z = 3 } },
    { "flint",        level = 0.00, freq = 1 / 3,   min = 0.44, n = 2, lode = 0.15 },
    { "coal",         level = 0.06, freq = 1 / 8,   min = 0.40, n = 2, lode = 0.15, stretch = { x = 4, z = 3 } },
    { "salt",         level = 0.06, freq = 1 / 6,   min = 0.44, n = 2, lode = 0.15, stretch = { x = 3, z = 3 } },
    { "tin_ore",      level = 0.20, freq = 1 / 4,   min = 0.48, n = 2, lode = 0.15, stretch = { y = 2 } },
    { "silver_ore",   level = 0.20, freq = 1 / 3.5, min = 0.46, n = 2, lode = 0.15, stretch = { x = 2 } },
    { "chromium_ore", level = 0.42, freq = 1 / 4,   min = 0.46, n = 2, lode = 0.15, stretch = { z = 2 } },
    { "lead_ore",     level = 0.42, freq = 1 / 4,   min = 0.48, n = 2, lode = 0.15, stretch = { x = 2 } },
    { "gold_ore",     level = 0.75, freq = 1 / 3,   min = 0.42, n = 3, lode = 0.25 },
    { "diamond",      level = 1.20, freq = 1 / 2.5, min = 0.45, n = 3, lode = 0.25 },
    { "orichalcum",   level = 2.00, freq = 1 / 2.5, min = 0.46, n = 3, lode = 0.32 },
}
local ORE_FIELDS = nil
local function ore_fields()
    if ORE_FIELDS then
        return ORE_FIELDS
    end
    local n = shape.node
    ORE_FIELDS = {}
    for i, ore in ipairs(ORES) do
        -- The depth FIRST (the deepest operand: the dome's polynomial), then
        -- the noises, each a fresh buffer released as it is min'd in.
        local lode_node = n.noise("lode_" .. ore[1], LODE_FREQ, 1, 1.0)
        local field = n.sub(shape.depth(), n.const(ore.level))
        field = n.min(field, n.sub(lode_node, n.const(ore.lode)))
        for k = 1, ore.n do
            field = n.min(field, n.sub(n.noise("ore_" .. ore[1] .. "_" .. k, ore.freq, 1, 1.0, ore.stretch), n.const(ore.min)))
        end
        ORE_FIELDS[i] = { field = shape.compile("ore." .. ore[1], field), material = blocks[ore[1]], level = ore.level,
            -- The SAME lode node compiled bare, for the gate's one point
            -- sample per chunk, and the threshold it is measured against.
            gate = shape.compile("ore." .. ore[1] .. ".lode", lode_node), lode = ore.lode }
    end
    return ORE_FIELDS
end
tdw.ORES = ORES
tdw.ore_fields = ore_fields
-- `dmax` is the chunk's greatest smooth depth: an ore whose level is under
-- it cannot reach the chunk, and costs it nothing. Then the lode gate: one
-- point sample of the bare lode noise at the chunk's centre skips the fill
-- where the ore's lodes provably cannot reach (LODE_MARGIN, above). Up to
-- one sample per ore a solid chunk — microseconds, against the
-- milliseconds each skipped fill's noise over the whole chunk volume cost.
local function ores_into(buf, pos, dmax)
    local cx, cy, cz = pos.x * 16 + 8.5, pos.y * 16 + 8.5, pos.z * 16 + 8.5
    for _, ore in ipairs(ore_fields()) do
        if dmax > ore.level and ore.gate:at(cx, cy, cz, pos.seed) >= ore.lode - LODE_MARGIN then
            buf:fill_density(ore.field, ore.material, DETAIL)
        end
    end
end

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
        game.log("tiamat_default_world: everything under the surface band is white — no biome claims it yet (tdw.config.white_unbuilt)")
    end
end
-- The material for a part of the world no biome has claimed.
local function unclaimed(material)
    return WHITE or material
end

local DEEP_D = shape.SURFACE_BAND_D

local function band_for(dmin)
    if dmin > shape.ABYSS_D + SAFETY then return unclaimed(blocks.morphic_rock), 2 end
    if dmin > shape.GLOAM_D + SAFETY then return unclaimed(blocks.dark_sediment), 1 end
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
local function sea_into(buf, pos, inside_body)
    local seas = tdw.seas
    if inside_body and seas and seas.on() then
        seas.fill(buf, pos)
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
                tdw.fill_terraced(buf, { level = fill.level, within = fill.within, fluid = fill.fluid, lip = fill.lip }, biome.id)
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
local STRUCTURE_ABOVE = 0.30               -- km: the tallest reach of any fill that says (0.08 until the redwoods grew to 270 blocks, 2026-09-17)
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
            "tiamat_default_world chunks: %d total — air %d, hollow %d, filled %d, carved %d (%d by the layers alone; surface %d, %d structures stamped), shells %d",
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
    local w_lo = shape.half_width_at(Ylo) * shape.warp_lo_at(Ylo) - SAFETY
    local outside_body = r2lo > w_hi * w_hi
    local inside_body = w_lo > 0 and r2hi < w_lo * w_lo
    -- A rim chunk is painted whether or not the gate can prove it inside:
    -- its programs carry the body's wall themselves (shape.CLIPPED), so
    -- every fill clips at the wall and the flank set is not wanted
    -- (2026-09-16; until then nothing past 54 km had a biome on it).
    local painted = inside_body or shape.CLIPPED[mode] == true

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
        if painted and tmax > -math.max(WATER_ABOVE, STRUCTURE_ABOVE) then
            found = tdw.present_biomes_in(ulo, uhi, pos)
            structures_into(buf, found, mode, tmax)
        end
        sea_into(buf, pos, painted)
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
    local V = painted and T or P.flank
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

    -- **The body by the layered fill.** A surface chunk's body — the soil
    -- to SKIN_DIRT and the stone below — is two bands of the terrain, and
    -- one `fill_layers` call lays both from ONE evaluation where the
    -- generator's own body fill and its stone fill were two.
    --
    -- The bands are code -1, which takes every block whatever the code
    -- says. They ride in the FIRST fill that paints the chunk when that is
    -- a body-capable layered fill: that call evaluates the terrain anyway,
    -- so the body is free. Only where the chunk's first paint cannot carry
    -- them do they go in a call of their own — one evaluation rather than
    -- the two the old body and stone fills took. (Measured on engine
    -- 92267e7, which skips a layered fill whose codes match nothing: a
    -- separate call for every chunk was 75.7 ms a surface chunk against
    -- 69.3 riding along, because it is one more evaluation where a biome's
    -- call was already paying for one.)
    --
    -- Not where a deep band shares the chunk: the -1 stone would overwrite
    -- the gloam. Then the old path, two evaluations.
    local found = (skin and painted and tmin < shape.SKIN_TOP) and tdw.present_biomes_in(ulo, uhi, pos) or nil
    local deep_bands = (WHITE and dmin <= DEEP_D + SAFETY and dmax > DEEP_D - SAFETY)
        or (level < 1 and dmax > shape.GLOAM_D - SAFETY)
        or (level < 2 and dmax > shape.ABYSS_D - SAFETY)
    local body_rides = nil          -- the fill whose call carries the -1 bands
    local body_by_layers = (found ~= nil and not tail and not deep_bands) and buf.fill_layers ~= nil
    if body_by_layers then
        -- The first fill that paints the ground, in the order below: were a
        -- later one moved in front, two biomes' paint where their masks
        -- overlap would land in the other order.
        for _, biome in ipairs(found) do
            local first = nil
            for _, fill in ipairs(tdw.fills_for(biome, mode)) do
                if fill.layers or fill.field then
                    first = fill
                    break
                end
            end
            if first then
                if first.layers and first.body then
                    body_rides = first
                end
                break
            end
        end
    end

    if painted and tmin > 0 then
        buf:fill_all(base)
        if level == 1 then
            buf:fill_density(SEDIMENT_BEDS, unclaimed(blocks.light_sediment), DETAIL)
        end
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
            buf:fill_density(V.gloam, unclaimed(blocks.dark_sediment), DETAIL)
        end
        if level < 2 and dmax > shape.ABYSS_D - SAFETY then
            buf:fill_density(V.abyss, unclaimed(blocks.morphic_rock), DETAIL)
        end
        -- The ores, into rock that is solid throughout, under the bands
        -- they sit in and before the core stack, which overwrites them.
        if painted and tmin > 0 and not WHITE then
            ores_into(buf, pos, dmax)
        end
        if skin and painted and tmin < shape.SKIN_TOP then
            -- The biome's own top.
            local function fills_of(biome)
                return tdw.fills_for(biome, mode)
            end
            -- The body first, under every biome's paint: in the first
            -- painting fill's own call where it can ride, else its own.
            local BODY = { { code = -1, to = shape.SKIN_DIRT, material = base },
                { code = -1, from = shape.SKIN_DIRT, to = math.huge, material = blocks.stone } }
            if body_by_layers and not body_rides then
                buf:fill_layers(V.solid, BODY_CODE, BODY)
            end
            for _, biome in ipairs(found) do
                for _, fill in ipairs(fills_of(biome)) do
                    if fill.layers then
                        -- Every layer of the surface from one evaluation of
                        -- the terrain and one of a code field (engine
                        -- `fill_layers`); eight fills were eight evaluations.
                        -- Since engine 92267e7 a call whose code can match no
                        -- layer costs its code's bound alone.
                        local entries = fill.entries
                        if fill == body_rides then
                            entries = {}
                            for _, e in ipairs(fill.entries) do entries[#entries + 1] = e end
                            entries[#entries + 1] = BODY[1]
                            entries[#entries + 1] = BODY[2]
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
            -- A cave's mouth where one comes up through this ground
            -- (biomes/caves.lua), after the paint, the plants and the trees.
            if tdw.caves then
                tdw.caves.mouths_into(buf, pos, dmin)
            end
            -- The sea, after the terrain AND the structures: the fluid fill
            -- takes only the room they leave (it was before the structures,
            -- which put water inside every kelp stand and boulder).
            sea_into(buf, pos, painted)
            -- Then rivers and brine pools, which take the sea's place.
            waters_into(buf, found, mode)
        end
    end
    if not (skin and painted and tmin < shape.SKIN_TOP) then
        -- A chunk of rock under a sea's floor is still under its water: the
        -- flooded caves and tunnels, and the deep water over a trench.
        sea_into(buf, pos, painted)
        -- The caves (biomes/caves.lua), carved out of rock that is solid
        -- throughout, ore and all, AFTER the sea: the sea's fill puts water
        -- in every open space under its level inside its area, so a cave
        -- carved before it under a sea was flooded a hundred blocks under
        -- the sea floor. (Not, as first written here, because a terraced
        -- fill empties the columns outside its `within` — it leaves them
        -- alone; the caves' own water was lost to engine-asks 35.)
        if painted and tmin > 0 and not tail and not WHITE and tdw.caves then
            tdw.caves.into(buf, pos, dmin, dmax)
            tdw.caves.mouths_into(buf, pos, dmin)
        end
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
        game.log(string.format("tiamat_default_world: generating chunk %d, %d, %d failed: %s", pos.x, pos.y, pos.z, tostring(err)))
        error(err, 0)
    end
end)

game.log("tiamat_default_world: registered the generator")
