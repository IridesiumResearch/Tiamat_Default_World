-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- The area and biome registry.
--
-- AGENTS.md is right that a biome registry needs nothing from the engine: it is
-- a Lua table. What a biome IS here:
--
--   * metadata  - id, name, which area, and where in that area it lives
--                 (a surface ring and a humidity band; a depth band; a shell;
--                 a stretch of the tail). This is what every biome has from
--                 the day it is listed.
--   * build()   - optional. Called once at load; returns the native fills the
--                 generator runs for chunks that can touch this biome. A biome
--                 without one is REGISTERED BUT NOT BUILT: the catalogue lists
--                 it, the log names it, and the ground under it stays the
--                 area's default material until someone writes the file.
--
-- Building one biome at a time is the plan, so the registry is designed to
-- make an unbuilt biome cheap to list and a built one one file to add.

local M = {}
tdw.areas = {}
tdw.area_list = {}
tdw.biomes = {}
tdw.biome_list = {}

-- An area is a division of the world: the surface, a depth band, a shell,
-- a stretch of the tail. `kind` says which coordinate bounds it.
---@param spec { id: string, name: string, kind: "surface"|"depth"|"shell"|"tail", note: string? }
function tdw.register_area(spec)
    assert(spec.id and spec.name and spec.kind, "register_area needs id, name and kind")
    assert(not tdw.areas[spec.id], "area registered twice: " .. spec.id)
    spec.biomes = {}
    tdw.areas[spec.id] = spec
    tdw.area_list[#tdw.area_list + 1] = spec
    return spec
end

-- A biome inside an area. Surface biomes name a `ring` from layers.RINGS and
-- optionally a `humidity` band in the noise's +/-0.42 range; `build` is the
-- function that makes it real.
---@param spec { id: string, name: string, area: string, ring: string?, humidity: number[]?, note: string?, build: (fun(ctx: table): table)? }
function tdw.register_biome(spec)
    assert(spec.id and spec.name and spec.area, "register_biome needs id, name and area")
    local area = tdw.areas[spec.area]
    assert(area, "biome " .. spec.id .. " names an unknown area " .. tostring(spec.area))
    assert(not tdw.biomes[spec.id], "biome registered twice: " .. spec.id)
    if spec.ring then
        assert(tdw.layers.ring_by_id[spec.ring], "biome " .. spec.id .. " names an unknown ring " .. spec.ring)
    end
    -- `spans` is where a biome stands: a list of { innermost, outermost,
    -- half, province }, each a run of rings (they are contiguous in u, so a
    -- run is one band and one test), which humidity half of it — "wet",
    -- "dry", or nil for the whole width — and which side of the province
    -- noise, "a" or "b", or nil for both (shape.province_mask).
    if spec.spans then
        for _, span in ipairs(spec.spans) do
            assert(tdw.layers.ring_by_id[span[1]] and tdw.layers.ring_by_id[span[2]],
                "biome " .. spec.id .. " names an unknown ring in a span")
            assert(span[3] == nil or span[3] == "wet" or span[3] == "dry",
                "biome " .. spec.id .. ": a span's half is \"wet\", \"dry\" or nothing")
            assert(span[4] == nil or span[4] == "a" or span[4] == "b",
                "biome " .. spec.id .. ": a span's province is \"a\", \"b\" or nothing")
            assert(span[5] == nil or type(span[5]) == "number",
                "biome " .. spec.id .. ": a span's province split is a number or nothing")
            assert(span[6] == nil or (type(span[6]) == "number" and span[4] ~= nil),
                "biome " .. spec.id .. ": a span's sixth entry is an upper province split, with a side")
        end
    end
    spec.fills = nil
    tdw.biomes[spec.id] = spec
    tdw.biome_list[#tdw.biome_list + 1] = spec
    area.biomes[#area.biomes + 1] = spec
    return spec
end

-- Attaches the native fills to an already-listed biome. Kept separate from
-- registration so the catalogue can list everything first and each biome's
-- own file can build it later, in load order.
---@param id string
---@param build fun(ctx: table): table  -- returns { { field = Density, material = integer } | { cover = integer, cells = integer, take = Density }, ... }
function tdw.build_biome(id, build)
    local biome = tdw.biomes[id]
    assert(biome, "build_biome: no biome called " .. tostring(id))
    assert(not biome.fills, "biome built twice: " .. id)
    local ctx = {
        shape = tdw.shape, blocks = tdw.blocks, layers = tdw.layers,
        node = tdw.shape.node, sub = tdw.shape.sub,
        -- True when this biome is being put over the whole surface: leave
        -- the ring and humidity masks out of the fills.
        everywhere = tdw.config.everywhere == id,
    }
    -- The same builder, run once per terrain mode the biome's fills are
    -- needed in (shape.lua, "terrain MODES"): its own ring's mode for the
    -- chunks wholly in its ring, and "all" for the band where rings meet —
    -- a fill has the terrain inside it, and must carry the same terms the
    -- chunk's surface was made from or it paints at the wrong height.
    local function compile_fills(mode)
        tdw.shape.terrain_mode = mode
        -- Under pcall so the message reaches the log: the engine reports a
        -- generation failure as "errored in on_generate" and no more, and
        -- a program past the eight buffers or an unknown node in a lazy
        -- build was a chunk of air with nothing to read.
        local ok, fills = pcall(build, ctx)
        tdw.shape.terrain_mode = nil
        if not ok then
            game.log("tiamot_default_world: building the fills of " .. id .. " in mode " .. tostring(mode) .. " failed: " .. tostring(fills))
            error(fills, 0)
        end
        assert(type(fills) == "table", "build for " .. id .. " must return a list of fills")
        for i, fill in ipairs(fills) do
            -- A fill paints where its field is positive; a cover stands a
            -- run of cells on the surface the fills made, where its take is.
            assert((fill.field and fill.material) or (fill.cover and fill.take)
                or (fill.layers and fill.depth and fill.code and fill.entries)
                or (fill.scatter and fill.depth and fill.schematics)
                or (fill.fluid and fill.level),
                "fill " .. i .. " of " .. id .. " needs field and material, cover and take, layers with depth, code and entries, scatter with depth and schematics, or fluid with level")
        end
        return fills
    end
    local own = tdw.config.everywhere and tdw.shape.default_mode() or biome.ring_mode or "temperate"
    biome.built = true
    biome.own_mode = own
    biome.compile_fills = compile_fills
    -- What is compiled now and what waits for the first chunk. A lazy
    -- biome's programs read maps the world pre-pass builds, which do not
    -- exist at load; the cross-faded ("all") fills of EVERY biome read them
    -- too, since they carry the alpine terms; and a biome that is not the
    -- one the dev switch puts everywhere is never asked for fills at all.
    -- The rest compiles here, where `--check-mods` sees it.
    local only = tdw.config.everywhere
    if only and only ~= id then
        game.log(string.format("tiamot_default_world biome %-24s built, fills not compiled (%s is everywhere)", id, only))
        return
    end
    if biome.lazy then
        game.log(string.format("tiamot_default_world biome %-24s built lazily, mode %s", id, own))
        return
    end
    biome.fills = compile_fills(own)
    game.log(string.format("tiamot_default_world biome %-24s built, %d fill(s), mode %s", id, #biome.fills, own))
end

-- A biome's fills for the CHUNK's terrain mode, compiled on first use.
-- Called per chunk by the generator. Keyed by the chunk's mode, not the
-- biome's own (2026-09-14): a fill carries the terrain inside it, and the
-- woodland in the Verdant Belt's chunks stands on ground the rainforest's
-- terms have moved — compiled in its own mode, its turf was the shape of
-- the ground without them, which is the roof-of-turf fault again.
function tdw.fills_for(biome, mode)
    biome.fills_by_mode = biome.fills_by_mode or {}
    local set = biome.fills_by_mode[mode]
    if set == nil then
        if biome.fills and mode == biome.own_mode then
            set = biome.fills
        else
            set = biome.compile_fills(mode)
            game.log(string.format("tiamot_default_world biome %-24s compiled %d fill(s), mode %s", biome.id, #set, mode))
        end
        biome.fills_by_mode[mode] = set
    end
    return set
end

-- A surface biome's placement mask for its fills: its ring, and its side
-- of the humidity split. Nil when a biome is put everywhere (nothing to
-- mask), so a builder does `field = mask and n.min(field, mask) or field`.
---@param n table The node builders (ctx.node).
---@param ring_id string
---@param wet boolean Which side of the split.
-- Where a biome stands, as a field: the union of its spans, each a band of
-- rings narrowed to one humidity half. `id` is the biome's own id; the
-- second argument is ignored and kept so the older call reads the same.
--
-- Written union-first so the deepest term is evaluated with the least
-- held: a band is the radius (three buffers) and a half is the humidity
-- noise, and a mask is itself the shallow half of `min(field, mask)` in
-- every fill that uses one.
--
-- **Only the spans the program can meet.** A fill is compiled per terrain
-- mode (`compile_fills`), and a mode covers a known range of the radius
-- (`shape.mode_u_ranges`): a span that cannot overlap it is left out of the
-- mask, since a band is twenty-odd operations and every program is near
-- the thousand. The grasslands' temperate-ring span is not in the
-- "verdant" programs, nor the woodlands'.
function tdw.biome_mask(n, id, _)
    if tdw.config.everywhere then
        return nil
    end
    local spans = tdw.biome_spans(id)
    local ranges = tdw.shape.mode_u_ranges and tdw.shape.mode_u_ranges(tdw.shape.terrain_mode)
    local acc = nil
    for _, span in ipairs(spans) do
        local first, last = tdw.layers.ring_by_id[span[1]], tdw.layers.ring_by_id[span[2]]
        local reachable = ranges == nil
        if ranges then
            for _, range in ipairs(ranges) do
                local w = tdw.shape.wobble(math.max(last.u[2], range[2]))
                if first.u[1] - w <= range[2] and last.u[2] + w >= range[1] then
                    reachable = true
                end
            end
        end
        local inner = first.u[1] <= 0 and -last.u[2] or first.u[1]
        local band = reachable and tdw.shape.ring(inner, last.u[2]) or nil
        if band and span[3] then
            band = n.min(band, tdw.shape.humidity_mask(span[3] == "wet"))
        end
        if band and span[4] then
            band = n.min(band, tdw.shape.province_mask(span[4], span[5]))
            if span[6] then
                -- An upper split: the province noise between the two
                -- (the Heather Moor, 2026-09-16).
                band = n.min(band, tdw.shape.province_mask(span[4] == "b" and "a" or "b", span[6]))
            end
        end
        if band then
            acc = acc and n.max(acc, band) or band
        end
    end
    -- Nothing reachable: a mask that is never positive, so the fill paints
    -- nothing rather than everything.
    return acc or n.const(-1.0)
end

-- A biome's spans, defaulting to the one ring it names; a ring's id works
-- too, for a caller that wants a bare ring.
function tdw.biome_spans(id)
    local biome = tdw.biomes[id]
    if biome and biome.spans then
        return biome.spans
    end
    local ring = biome and biome.ring or id
    assert(tdw.layers.ring_by_id[ring], "no rings for " .. tostring(id))
    return { { ring, ring } }
end

-- The biomes of a chunk: those whose rings reach it, less any that says it
-- is not in THIS chunk. A biome that covers its rings only here and there —
-- a river, which is a line across them — answers `present(pos)` with one
-- sample of its own course, and a chunk it is not near does not evaluate
-- its fills at all. Without it a river's terrain and code fields would be
-- evaluated in every chunk of six rings to paint nothing.
function tdw.present_biomes_in(u_lo, u_hi, pos)
    local found = tdw.surface_biomes_in(u_lo, u_hi)
    local kept = {}
    for _, biome in ipairs(found) do
        if biome.present == nil or biome.present(pos) then
            kept[#kept + 1] = biome
        end
    end
    return kept
end

-- **The meadow flowers** (2026-09-14: "add more grass as well as rare Roman
-- chamomile and fairly common blue lunaria everywhere"): two cover fills a
-- grassy biome adds after its grass, from the SAME noise as its grass. The
-- grass takes a cell column where that noise is over its cut (0.12 and
-- up); the flowers only where it is under -FLOWER_MIN, so a flower never
-- stands on a tuft or a tuft on a flower — the engine's cover fill would
-- stack a second run on the first inside a block. A second fine noise
-- thins those columns to one in forty or so — a block has nine, and at one
-- in seven nearly every block held a flower. Then a slow patch noise picks
-- the lunaria on its high side and the chamomile on its low one, the
-- chamomile thinned again by a finer noise into clumps. Measured headless
-- over 65-block squares of grass: lunaria in one block in seven to
-- fifteen, chamomile in one in sixty to a hundred.
-- No terrain in these fields: a cover is only asked in blocks that hold a
-- surface, and in the grassy rings the first caves are a hundred blocks
-- down, so the woodlands' near-ground guard would cost a full terrain per
-- cell for nothing here.
--   `noise_name`, `freq`: the biome's grass noise, exactly as its grass has it.
--   `gate(field)`: the biome's own limits (its mask, off the river, off ferns).
local FLOWER_MIN = 0.45               -- about one column in seven off the grass side
local BLOOM_FREQ, BLOOM_MIN = 1.5, 0.45  -- the second fine noise: one column in seven again
local FLOWER_PATCH_FREQ = 1 / 40
local LUNARIA_PATCH = 0.10            -- two fifths of the ground or so
local CHAMOMILE_PATCH = 0.30          -- about a quarter of the ground...
local CHAMOMILE_FREQ, CHAMOMILE_MIN = 1 / 9, 0.30   -- ...and a quarter of that, in clumps a few blocks across
function tdw.flower_covers(prefix, noise_name, freq, gate)
    local n, shape, blocks = tdw.shape.node, tdw.shape, tdw.blocks
    local function off_grass()
        return n.min(n.sub(n.mul(n.noise(noise_name, freq, 1, 1.0), n.const(-1.0)), n.const(FLOWER_MIN)),
            n.sub(n.noise("bloom", BLOOM_FREQ, 1, 1.0), n.const(BLOOM_MIN)))
    end
    local function patch()
        return n.noise("flower_patch", FLOWER_PATCH_FREQ, 1, 1.0)
    end
    local lunaria = n.min(off_grass(), n.sub(patch(), n.const(LUNARIA_PATCH)))
    local chamomile = n.min(n.min(off_grass(), n.sub(n.mul(patch(), n.const(-1.0)), n.const(CHAMOMILE_PATCH))),
        n.sub(n.noise("chamomile", CHAMOMILE_FREQ, 1, 1.0), n.const(CHAMOMILE_MIN)))
    return { cover = blocks.blue_lunaria, cells = 3, take = shape.compile(prefix .. ".lunaria", gate(lunaria)) },
        { cover = blocks.roman_chamomile, cells = 1, take = shape.compile(prefix .. ".chamomile", gate(chamomile)) }
end

-- The whole u range a biome can be found in, over all its spans.
function tdw.biome_span_u(id)
    local lo, hi = nil, nil
    for _, span in ipairs(tdw.biome_spans(id)) do
        local first, last = tdw.layers.ring_by_id[span[1]], tdw.layers.ring_by_id[span[2]]
        lo = lo and math.min(lo, first.u[1]) or first.u[1]
        hi = hi and math.max(hi, last.u[2]) or last.u[2]
    end
    return lo, hi
end

-- Which biome a grass block belongs to, at runtime, from what is under the
-- turf: the first block below that is not grass. Woodlands sit on loam,
-- grasslands on dirt, and each biome lays its own soil under its own grass,
-- so this is exact even in a chunk where the two meet. Nil when the column
-- is unloaded or the block under the turf is mixed.
---@return integer? material
function tdw.soil_under(x, y, z)
    local grass = tdw.blocks.grass
    for dy = 1, 5 do
        local b = game.get_block{ x = x, y = y - dy, z = z }
        if b == nil then
            return nil
        end
        if b.material ~= grass then
            return b.material
        end
    end
    return nil
end

function tdw.built_count()
    local n = 0
    for _, biome in ipairs(tdw.biome_list) do
        if biome.built then n = n + 1 end
    end
    return n
end

-- The soil under a chunk's skin: the biome's own when one built biome is
-- the only one in reach, plain dirt otherwise. Called per surface chunk.
function tdw.surface_soil(u_lo, u_hi)
    local found = tdw.surface_biomes_in(u_lo, u_hi)
    if #found == 1 and found[1].soil then
        return found[1].soil
    end
    return tdw.blocks.dirt
end

-- Built surface biomes whose ring overlaps [u_lo, u_hi]. Called per chunk by
-- the generator, so it walks a short list and allocates one table.
function tdw.surface_biomes_in(u_lo, u_hi)
    local found = {}
    local only = tdw.config.everywhere
    if only then
        local biome = tdw.biomes[only]
        if biome and biome.built then
            found[1] = biome
        end
        return found
    end
    -- Widened by the wobble, as `rings_overlapping` is: a biome's band has
    -- a wandering edge, so a chunk this close to one may be inside it.
    local w = tdw.shape.wobble(u_hi)
    for _, biome in ipairs(tdw.areas.surface.biomes) do
        if biome.built and biome.placed ~= false and (biome.spans or biome.ring) then
            for _, span in ipairs(tdw.biome_spans(biome.id)) do
                local first, last = tdw.layers.ring_by_id[span[1]], tdw.layers.ring_by_id[span[2]]
                if first.u[1] - w <= u_hi and last.u[2] + w >= u_lo then
                    found[#found + 1] = biome
                    break
                end
            end
        end
    end
    return found
end

return M
