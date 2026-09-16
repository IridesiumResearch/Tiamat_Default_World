-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 2.0 Arid Mesa: the Glass Waste's dry half.
--
-- The brief (2026-09-14):
--
--   Topography: expansive elevated tablelands bounded by sheer vertical
--   cliffs, stepping down in benches to flat canyon floors; deep narrow box
--   canyons and isolated flat-topped buttes.
--   Surface: horizontal strata of rust-red*, ochre*, terracotta and pale tan
--   sandstone; mesa tops capped with pale terracotta* and wind-swept desert
--   sandstone, rare dirt; cliff bases banked with talus of loose red sand,
--   gravel and dirt.
--   Trees: extremely sparse — in sheltered cliff-base hollows, or singly on
--   the tops: short, crooked, split, weathered-grey junipers* and pines with
--   flat sparse crowns of dark needles.
--   Flora: columnar cacti* 5 to 9 tall with right-angle arms, round barrel
--   cacti in rock crevices, prickly pear clumps, brittle sagebrush.
--   Hydrology: bone-dry arroyos and wash channels on the canyon floors, lined
--   with dry clay, sand and gravel, rare muddy puddles, a palm or two.
--   Accents: rare hoodoos and spire pinnacles, natural stone arches over
--   narrow canyon cuts, wind-carved alcoves in cliff faces, and high raptor
--   nest ledges scattered with bleached bone.
--
-- THE GROUND is terms of the terrain, not a map: a map is at most 1,024
-- samples a side, and the Glass Waste is a ring a hundred and fifty
-- kilometres round, so no map covers it at any useful grain. The forms are
-- the ones erosion leaves and a field of one position can say exactly:
--
--   * BENCHES: a staircase of five levels on a slow plateau noise, each a
--     sheer cliff (a clamp a block and a bit wide) over a talus apron (a
--     quarter of the step's height, ramped over six blocks or so), so
--     every cliff stands on a slope of its own debris. Where the noise peaks
--     it saturates, so the highest ground is flat: the buttes.
--   * BOX CANYONS: a contour in stretches, whose ends are the box ends;
--     inside it the plateau's whole height is taken away, so the floor is
--     the plain's and the walls are sheer.
--   * ARCHES: where a rare blob crosses a canyon, the top five blocks of the
--     plateau are left standing over the cut.
--   * ALCOVES: hollows of air stamped at the feet of the lower cliffs,
--     a couple of blocks up, where a patch noise says: they carve into
--     whatever face is within reach (a structure, not a term, because a
--     term needs the ground's height twice and the program has a thousand
--     operations).
--   * ARROYOS: shallow washes along a fine contour on the plains and the
--     canyon floors.
--
-- THE STRATA are horizontal over the smooth ground (the dome and the
-- world's relief), so they run parallel to the benches. Stand-ins until the
-- designer names nodes: terracotta is `dry_clay`, pale tan sandstone
-- `stone`, desert sandstone and red sand `sand`, sagebrush `bramble`,
-- and the barrel cacti and prickly pear are cut from the columnar cactus.

local blocks = tdw.blocks
local shape = tdw.shape
local n = shape.node
local schem = tdw.schem

local ID = "arid_mesa"

-- The plateau. Thresholds against the measured noise (two octaves over 0.3
-- on 18% of the ground, at the +0.5 clamp on 6%).
local PLATEAU_FREQ, PLATEAU_OCTAVES = 1 / 900, 3                  -- the third octave wanders the benches' edges
-- The benches: { plateau value where the cliff stands, km of height }.
local LEVELS = { { -0.25, 0.010 }, { -0.12, 0.012 }, { 0.00, 0.012 }, { 0.12, 0.014 }, { 0.26, 0.016 } }   -- most of the ground stands up on the tablelands
local CLIFF_K = 150.0                                   -- a cliff a block and a bit wide
-- The walls' ledges (2026-09-15: "the mesa walls slightly more detailed on
-- the vertical axis"): the plateau value AT A CLIFF nudged by a noise
-- stretched flat — features FACE_FREQ apart up the wall and FACE_STRETCH
-- times that along it — so each face steps in and out a block or two every
-- few blocks of height, the harder beds standing proud of the softer, as
-- in the strata. Only the cliffs take it: the aprons, the zones and the
-- structures read the plain plateau value.
local FACE_FREQ, FACE_STRETCH, FACE_AMP = 1 / 4, 10, 0.006              -- 0.010 until 2026-09-15: the ledges cut the little mesas through and left their caps floating
local CANYON_FACE_AMP = 2.0                              -- the same on a box canyon's walls, in blocks of the contour: a block and a half either way
local TALUS_REACH, TALUS_SHARE = 0.03, 0.25              -- an apron a quarter of the step high, six blocks or so out
local CANYON_FREQ, CANYON_W, CANYON_SEG_FREQ, CANYON_SEG_MIN = 1 / 350, 6.0, 1 / 500, 0.0
local ARCH_FREQ, ARCH_MIN, ARCH_T = 1 / 70, 0.28, 0.005
local ALCOVE_CELL, ALCOVE_SQUARES, ALCOVE_FOOT = 10, 0.5, 0.015
local ARROYO_FREQ, ARROYO_W, ARROYO_BANK, ARROYO_D = 1 / 140, 2.2, 4.0, 0.002
-- The surface.
local CAP_FREQ, CAP_MIN = 1 / 40, 0.25                   -- desert sandstone patches in the pale terracotta cap
local DIRT_FREQ, DIRT_MIN = 1 / 30, 0.46                 -- rare dirt
local GRAVEL_FREQ, GRAVEL_MIN, TDIRT_FREQ, TDIRT_MIN = 1 / 9, 0.30, 1 / 13, 0.40
local PUDDLE_FREQ, PUDDLE_MIN = 1 / 20, 0.45
local SAGE_THIN = 0.29                                   -- a third noise over this: 60% fewer sagebrush cells, measured against none (the fine noises are not independent, so not the 30% it is at random points)
-- The strata: the height over the smooth ground folded by nested absolute
-- values into a zig-zag, which the code field rounds to 1..4 and back —
-- rust-red, ochre, terracotta, pale tan, pale tan, terracotta, ochre,
-- rust-red, and again. One evaluation of the ground, where a step per band
-- was eleven and past the thousand operations. The fold points are not
-- halves, so the bands come out of uneven thickness.
local STRATA_FOLDS = { 0.036, 0.0165, 0.0092 }
-- The structures: cell, share of squares, salt.
local CACTUS_CELL, CACTUS_SQUARES = 14, 0.125        -- 0.25 until "half the amount of big cactuses" (2026-09-15)
local SULFUR_FREQ, SULFUR_MIN = 1 / 55, 0.36              -- very rare spots of sulfur on the flats (2026-09-15)
local CRANNY_CELL, CRANNY_SQUARES = 6, 0.15
local TREE_TALUS_CELL, TREE_TALUS_SQUARES = 18, 0.2
local TREE_TOP_CELL, TREE_TOP_SQUARES = 40, 0.12
local PALM_CELL, PALM_SQUARES = 64, 0.35
local HOODOO_CELL, HOODOO_SQUARES = 48, 0.3
local NEST_CELL, NEST_SQUARES = 40, 0.3

-- ------------------------------------------------------------ the ground

local function ys()
    return n.mul(n.sub(n.Y(), n.const(shape.Y0)), n.const(shape.SCALE))
end
-- The plateau value.
local function p()
    return n.noise("ms_plateau", PLATEAU_FREQ, PLATEAU_OCTAVES, 1.0)
end
-- The walls' ledges: a noise stretched flat (FACE_FREQ).
local function face()
    return n.noise("ms_face", FACE_FREQ, 1, 1.0, { x = FACE_STRETCH, z = FACE_STRETCH })
end
-- One bench: its talus apron and its cliff.
local function bench(level, height)
    local talus = n.clamp(n.mul(n.add(p(), n.const(TALUS_REACH - level)), n.const(1.0 / TALUS_REACH)), 0.0, 1.0)
    local cliff = n.clamp(n.mul(n.add(p(), n.add(n.mul(face(), n.const(FACE_AMP)), n.const(-level))), n.const(CLIFF_K)), 0.0, 1.0)
    return n.add(n.mul(talus, n.const(height * TALUS_SHARE)), n.mul(cliff, n.const(height * (1.0 - TALUS_SHARE))))
end
-- The plateau's height, km: the benches summed.
local function height()
    local acc = bench(LEVELS[1][1], LEVELS[1][2])
    for i = 2, #LEVELS do
        acc = n.add(acc, bench(LEVELS[i][1], LEVELS[i][2]))
    end
    return acc
end
-- Km over the smooth ground (the dome and the world's relief).
local function rel()
    return n.mul(n.add(shape.depth(), shape.relief_node()), n.const(-1.0))
end
local function both(stream, freq, min, edge)
    return n.clamp(n.mul(n.min(n.sub(n.noise(stream, freq, 2, 1.0), n.const(min)),
        n.sub(n.noise(stream .. "_b", freq, 2, 1.0), n.const(min))), n.const(edge)), 0.0, 1.0)
end
-- `faced`: the walls' ledges too (FACE_FREQ), for the terrain's cut; the
-- zones and the structures read the smooth line.
local function canyon_w(faced)
    local d = n.contour("ms_canyon", CANYON_FREQ, 2)
    if faced then
        d = n.add(d, n.mul(face(), n.const(CANYON_FACE_AMP)))
    end
    local line = n.clamp(n.mul(n.add(d, n.const(-CANYON_W)), n.const(-1.2)), 0.0, 1.0)
    return n.mul(line, n.clamp(n.mul(n.sub(n.noise("ms_canyon_seg", CANYON_SEG_FREQ, 1, 1.0), n.const(CANYON_SEG_MIN)), n.const(6.0)), 0.0, 1.0))
end
-- The plains: below the lowest bench's apron.
local function plains_w()
    return n.clamp(n.mul(n.add(p(), n.const(TALUS_REACH - LEVELS[1][1])), n.const(-10.0)), 0.0, 1.0)
end
local function arroyo_d()
    return n.contour("ms_arroyo", ARROYO_FREQ, 2)
end
-- Where washes run: the plains and the canyon floors.
local function lowland()
    return n.max(canyon_w(), plains_w())
end

-- The mesa's terms of the terrain, km, added to the depth.
function shape.mesa_terms()
    -- The arches: in a canyon, where a rare blob is, the top ARCH_T of the
    -- plateau's height left standing.
    local slab = n.clamp(n.mul(n.sub(n.abs(n.add(n.sub(rel(), height()), n.const(ARCH_T / 2))), n.const(ARCH_T / 2)),
        n.const(-2000.0)), 0.0, 1.0)
    local arch = n.mul(slab, both("ms_arch", ARCH_FREQ, ARCH_MIN, 12.0))
    -- The canyon's cut, less the arch; the plateau's height, less the cut.
    local cut = n.mul(n.add(n.mul(arch, n.const(-1.0)), n.const(1.0)), canyon_w(true))
    local acc = n.mul(n.add(n.mul(cut, n.const(-1.0)), n.const(1.0)), height())
    -- The arroyos.
    local wash = n.clamp(n.mul(n.add(arroyo_d(), n.const(-ARROYO_W)), n.const(-0.8)), 0.0, 1.0)
    return n.sub(acc, n.mul(n.mul(wash, lowland()), n.const(ARROYO_D)))
end

tdw.biomes[ID].ring_mode = "verdant"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.rust_red_sandstone
-- `/tp` keeps off the Salt Pan (2.9), which paints over a third of this ring.
tdw.biomes[ID].locate_field = function(field)
    return shape.salt_exclude and shape.salt_exclude(field) or field
end

-- The dust (2026-09-15, "add that same fog to the mesa biome"): the
-- badlands' haze at the same strength, thinner in a chunk the biome only
-- partly covers.
local DUST = { r = 0.78, g = 0.68, b = 0.56 }
local DUST_VISIBILITY, DUST_EDGE_VISIBILITY = 440, 880
local place_mask = nil
if tdw.on_chunk_fog then
    tdw.on_chunk_fog(function(pos)
        local only = tdw.config.everywhere
        local c
        if only then
            c = only == ID and 1.0 or 0.0
        else
            place_mask = place_mask or shape.compile("mesa.place", tdw.biome_mask(n, ID))
            local b = place_mask:bounds(pos)
            c = b.high <= 0 and 0.0 or (b.low > 0 and 1.0 or 0.5)
        end
        if c == 0.0 then
            return nil
        end
        return { r = DUST.r, g = DUST.g, b = DUST.b, visibility = c == 1.0 and DUST_VISIBILITY or DUST_EDGE_VISIBILITY }
    end)
end

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local ROUGH = { rough = 0.3, blind = true }
local DIR4 = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- A columnar cactus: a trunk five to nine tall and up to three arms, each
-- straight out and then straight up — the right-angle branch.
local function saguaro(rng)
    schem.record_begin()
    local tall = 5 + rng:below(5)
    schem.push_path(blocks.cactus, { { 0.5, -1.0, 0.5, 0.45 }, { 0.5, tall, 0.5, 0.4 } }, BLIND)
    local first = rng:below(4)
    for i = 0, rng:below(4) - 1 do
        local d = DIR4[(first + i) % 4 + 1]
        local at = 2 + rng:below(math.max(1, tall - 3))
        local out = 1.3 + rng:below(2) * 0.5
        local x, z = 0.5 + d[1] * out, 0.5 + d[2] * out
        schem.push_path(blocks.cactus, { { 0.5, at, 0.5, 0.36 }, { x, at, z, 0.34 } }, BLIND)
        schem.push_path(blocks.cactus, { { x, at, z, 0.34 }, { x, at + 1.5 + rng:below(3) * 0.5, z, 0.3 } }, BLIND)
    end
    return schem.record_schematic({})
end

-- In a cranny at a cliff's foot: a round barrel cactus, or a clump of
-- prickly pear pads stacked up and out of each other.
local function cranny(rng)
    schem.record_begin()
    if rng:below(2) == 0 then
        schem.push_ellipsoid(blocks.cactus, 0.5, 0.45, 0.5, 0.45, 0.48, 0.45, BLIND)
    else
        local x, y, z = 0.5, 0.35, 0.5
        for _ = 1, 3 + rng:below(4) do
            local flat_x = rng:below(2) == 0
            schem.push_ellipsoid(blocks.cactus, x, y, z, flat_x and 0.14 or 0.45, 0.45, flat_x and 0.45 or 0.14, BLIND)
            local d = DIR4[rng:below(4) + 1]
            x, y, z = x + d[1] * 0.35, y + 0.5, z + d[2] * 0.35
        end
    end
    return schem.record_schematic({})
end

-- A desert juniper or pine: short, crooked, often split into two stems,
-- weathered grey, with a few flat sparse pads of dark needles.
local function juniper(rng)
    schem.record_begin()
    local tall = 3 + rng:below(4)
    local stems = rng:below(2) == 0 and 2 or 1
    for s = 1, stems do
        local d = schem.DIR16[rng:below(16) + 1]
        local x, z = 0.5, 0.5
        local points = { { x, -1.0, z, 0.45 } }
        for i = 1, 3 do
            local t = i / 3
            x = x + d[1] * 0.5 * t + (rng:below(3) - 1) * 0.35
            z = z + d[2] * 0.5 * t + (rng:below(3) - 1) * 0.35
            points[#points + 1] = { x, t * tall * (s == 1 and 1.0 or 0.8), z, 0.4 - 0.22 * t }
        end
        schem.push_path(blocks.juniper_log, points, BLIND)
        local top = points[#points]
        for _ = 1, 1 + rng:below(3) do
            local w = schem.DIR16[rng:below(16) + 1]
            local r = 1.1 + rng:below(3) * 0.35
            schem.push_ellipsoid(blocks.juniper_needles, top[1] + w[1] * 0.8, top[2] + 0.3, top[3] + w[2] * 0.8, r, 0.45, r,
                { rough = 0.45, blind = true })
        end
    end
    return schem.record_schematic({ [blocks.juniper_log] = 1 })
end

-- A palm by a wash: a bowing stem and a spray of drooping fronds.
local function palm(rng)
    schem.record_begin()
    local tall = 7 + rng:below(5)
    local lean = DIR4[rng:below(4) + 1]
    local stem = {}
    for i = 0, 4 do
        local t = i / 4
        local bow = t * t * 1.2
        stem[#stem + 1] = { 0.5 + lean[1] * bow, -1.0 + t * (tall + 1), 0.5 + lean[2] * bow, 0.55 - 0.2 * t }
    end
    schem.push_path(blocks.willow_log, stem, BLIND)
    local tip = stem[#stem]
    local fronds = 6 + rng:below(3)
    for f = 1, fronds do
        local d = schem.DIR16[(f * 16 // fronds + rng:below(2)) % 16 + 1]
        local reach = 2.8 + rng:below(4) * 0.4
        schem.push_path(blocks.oak_leaves, {
            { tip[1], tip[2], tip[3], 0.45 },
            { tip[1] + d[1] * reach * 0.5, tip[2] + 0.8, tip[3] + d[2] * reach * 0.5, 0.35 },
            { tip[1] + d[1] * reach, tip[2] - 1.0, tip[3] + d[2] * reach, 0.18 },
        }, BLIND)
    end
    return schem.record_schematic({ [blocks.willow_log] = 1 })
end

-- A hoodoo or a spire: a column of banded rock six to eighteen tall,
-- pinched and swelling as it climbs, under a wider cap of pale terracotta.
local function hoodoo(rng)
    schem.record_begin()
    local tall = 6 + rng:below(13)
    local spire = rng:below(3) == 0
    local r0 = spire and 1.1 or 1.5
    local bands = { blocks.rust_red_sandstone, blocks.ochre_sandstone, blocks.stone }
    local y, k = -1.0, 0
    while y < tall do
        local next_y = math.min(tall, y + 2 + rng:below(3))
        local t0, t1 = (y + 1) / (tall + 1), (next_y + 1) / (tall + 1)
        local pinch = (k % 2 == 0) and 1.0 or 0.75
        schem.push_path(bands[k % #bands + 1], {
            { 0.5, y, 0.5, r0 * (1.0 - 0.45 * t0) * pinch },
            { 0.5, next_y, 0.5, r0 * (1.0 - 0.45 * t1) * pinch },
        }, ROUGH)
        y, k = next_y, k + 1
    end
    if not spire then
        schem.push_ellipsoid(blocks.pale_terracotta, 0.5, tall + 0.6, 0.5, r0 * 1.2, 0.9, r0 * 1.2, ROUGH)
    end
    return schem.record_schematic({})
end

-- A raptor's nest on a high ledge: a ring of dead sticks, and bleached bone
-- scattered round it.
local function nest(rng)
    schem.record_begin()
    for k = 0, 7 do
        local d = schem.DIR16[(k * 2 + rng:below(2)) % 16 + 1]
        local e = schem.DIR16[(k * 2 + 5) % 16 + 1]
        schem.push_path(blocks.dead_log, {
            { 0.5 + d[1] * 1.1, 0.15, 0.5 + d[2] * 1.1, 0.16 },
            { 0.5 + d[1] * 1.1 + e[1] * 1.2, 0.35, 0.5 + d[2] * 1.1 + e[2] * 1.2, 0.14 },
        }, BLIND)
    end
    for _ = 1, 4 + rng:below(5) do
        local d = schem.DIR16[rng:below(16) + 1]
        local r = 1.5 + rng:below(4) * 0.6
        local x, z = 0.5 + d[1] * r, 0.5 + d[2] * r
        local e = schem.DIR16[rng:below(16) + 1]
        schem.push_path(blocks.bone, { { x, 0.1, z, 0.13 }, { x + e[1] * 0.8, 0.12, z + e[2] * 0.8, 0.11 } }, BLIND)
    end
    return schem.record_schematic({})
end

-- An alcove: a hollow of air a couple of blocks up, carving into whatever
-- cliff face is within its reach.
local function alcove(rng)
    schem.record_begin()
    local rx, rz = 2.2 + rng:below(3) * 0.4, 2.2 + rng:below(3) * 0.4
    schem.push_ellipsoid(game.AIR, 0.5, 3.4, 0.5, rx, 1.8 + rng:below(3) * 0.3, rz, ROUGH)
    return schem.record_schematic({ [game.AIR] = 1 })
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { saguaros = {}, crannies = {}, junipers = {}, palms = {}, hoodoos = {}, nests = {}, alcoves = {} }
    if not game.schematic_shapes then
        BUILT = out
        return out
    end
    local function rng_for(name)
        return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "mesa_template:" .. name)
    end
    for i = 1, 6 do out.saguaros[i] = saguaro(rng_for("saguaro:" .. i)) end
    for i = 1, 6 do out.crannies[i] = cranny(rng_for("cranny:" .. i)) end
    for i = 1, 6 do out.junipers[i] = juniper(rng_for("juniper:" .. i)) end
    for i = 1, 2 do out.palms[i] = palm(rng_for("palm:" .. i)) end
    for i = 1, 5 do out.hoodoos[i] = hoodoo(rng_for("hoodoo:" .. i)) end
    for i = 1, 3 do out.nests[i] = nest(rng_for("nest:" .. i)) end
    for i = 1, 4 do out.alcoves[i] = alcove(rng_for("alcove:" .. i)) end
    local parts = {}
    for _, key in ipairs({ "saguaros", "crannies", "junipers", "palms", "hoodoos", "nests", "alcoves" }) do
        local total = 0
        for _, one in ipairs(out[key]) do total = total + one:len() end
        parts[#parts + 1] = string.format("%d %s (%d blocks)", #out[key], key, total)
    end
    game.log("tiamot_default_world mesa: cut " .. table.concat(parts, ", "))
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

tdw.build_biome(ID, function(ctx)
    local function masked(field)
        local mask = tdw.biome_mask(n, ID)
        field = mask and n.min(field, mask) or field
        -- Not on the Salt Pan (2.9), which paints over this ring's third:
        -- its covers and structures keep off the crust (2026-09-16).
        return shape.salt_exclude and shape.salt_exclude(field) or field
    end
    local function off_river(field, blocks_out)
        return shape.river_exclude and shape.river_exclude(field, blocks_out) or field
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    -- The talus aprons: under any cliff, within its reach.
    local function talus()
        local acc = nil
        for _, level in ipairs(LEVELS) do
            local band = n.min(n.add(p(), n.const(TALUS_REACH - level[1])), n.add(n.mul(p(), n.const(-1.0)), n.const(level[1])))
            acc = acc and n.max(acc, band) or band
        end
        return n.min(acc, n.sub(n.const(0.5), canyon_w()))
    end
    local function wash_bed()
        return n.min(n.add(n.mul(arroyo_d(), n.const(-1.0)), n.const(ARROYO_W)), n.sub(lowland(), n.const(0.5)))
    end

    -- The strata: 1..4 by the fold (see STRATA_FOLDS), rounded by the
    -- engine; then the cap's variant over them (4 more for desert
    -- sandstone, 8 more for dirt); then the zones by the greatest code.
    local fold = rel()
    for _, at in ipairs(STRATA_FOLDS) do
        fold = n.abs(n.sub(fold, n.const(at)))
    end
    local code = n.add(n.mul(fold, n.const(3.0 / STRATA_FOLDS[#STRATA_FOLDS])), n.const(1.0))
    code = n.clamp(code, 1.0, 4.0)
    code = n.add(code, n.mul(step(n.sub(n.noise("ms_cap", CAP_FREQ, 1, 1.0), n.const(CAP_MIN))), n.const(4)))
    code = n.add(code, n.mul(step(n.sub(n.noise("ms_dirt", DIRT_FREQ, 1, 1.0), n.const(DIRT_MIN))), n.const(4)))
    -- The zones, each evaluated once, its variants chosen inside it.
    -- 13: the plains and the canyon floors: red sand.
    code = n.max(code, n.mul(step(n.max(n.sub(plains_w(), n.const(0.5)), n.sub(canyon_w(), n.const(0.5)))), n.const(13)))
    -- 14: the talus aprons, loose red sand; +1 gravel, +2 dirt (17: both, dirt).
    code = n.max(code, n.mul(step(talus()), n.add(n.add(n.mul(step(n.sub(n.noise("ms_tdirt", TDIRT_FREQ, 1, 1.0), n.const(TDIRT_MIN))),
        n.const(2)), step(n.sub(n.noise("ms_gravel", GRAVEL_FREQ, 1, 1.0), n.const(GRAVEL_MIN)))), n.const(14))))
    -- 18: an arroyo's clay banks.
    code = n.max(code, n.mul(step(n.min(n.min(n.add(n.mul(arroyo_d(), n.const(-1.0)), n.const(ARROYO_BANK)), n.add(arroyo_d(), n.const(-ARROYO_W))),
        n.sub(lowland(), n.const(0.5)))), n.const(18)))
    -- 19: its gravel bed; 20: a rare muddy puddle in it.
    code = n.max(code, n.mul(step(wash_bed()), n.add(step(n.sub(n.noise("ms_puddle", PUDDLE_FREQ, 1, 1.0), n.const(PUDDLE_MIN))), n.const(19))))
    -- 21: a very rare spot of sulfur on the flats: two noises both high.
    code = n.max(code, n.mul(step(n.min(lowland(), n.sub(both("ms_sulfur", SULFUR_FREQ, SULFUR_MIN, 12.0), n.const(0.5)))), n.const(21)))
    local mask = tdw.biome_mask(n, ID)
    if mask then
        code = n.mul(code, step(mask))
    end
    local depth = shape.compile("biome.mesa.depth", shape.terrain(false))
    local codes = shape.compile("biome.mesa.codes", code)
    local km = 0.001
    local deep = 400 * km
    local STRATUM = { blocks.rust_red_sandstone, blocks.ochre_sandstone, blocks.dry_clay, blocks.stone }
    local entries = {}
    for s = 1, 4 do
        entries[#entries + 1] = { code = s, to = 2 * km, material = blocks.pale_terracotta }
        entries[#entries + 1] = { code = s, from = 2 * km, to = deep, material = STRATUM[s] }
        entries[#entries + 1] = { code = s + 4, to = 2 * km, material = blocks.sand }
        entries[#entries + 1] = { code = s + 4, from = 2 * km, to = deep, material = STRATUM[s] }
        entries[#entries + 1] = { code = s + 8, to = 1 * km, material = blocks.dirt }
        entries[#entries + 1] = { code = s + 8, from = 1 * km, to = deep, material = STRATUM[s] }
    end
    local more = {
        { code = 13, to = 3 * km, material = blocks.sand },
        { code = 13, from = 3 * km, to = deep, material = blocks.rust_red_sandstone },
        { code = 14, to = 3 * km, material = blocks.sand },
        { code = 14, from = 3 * km, to = deep, material = blocks.rust_red_sandstone },
        { code = 15, to = 2 * km, material = blocks.gravel },
        { code = 15, from = 2 * km, to = deep, material = blocks.rust_red_sandstone },
        { code = 16, to = 1 * km, material = blocks.dirt },
        { code = 16, from = 1 * km, to = deep, material = blocks.rust_red_sandstone },
        { code = 17, to = 1 * km, material = blocks.dirt },
        { code = 17, from = 1 * km, to = deep, material = blocks.rust_red_sandstone },
        { code = 18, to = 2 * km, material = blocks.dry_clay },
        { code = 18, from = 2 * km, to = deep, material = blocks.rust_red_sandstone },
        { code = 19, to = 1 * km, material = blocks.gravel },
        { code = 19, from = 1 * km, to = 3 * km, material = blocks.sand },
        { code = 19, from = 3 * km, to = deep, material = blocks.rust_red_sandstone },
        { code = 20, to = 1 * km, material = blocks.mud },
        { code = 20, from = 1 * km, to = 2 * km, material = blocks.wet_clay },
        { code = 20, from = 2 * km, to = deep, material = blocks.rust_red_sandstone },
        { code = 21, to = 1 * km, material = blocks.sulfur },
        { code = 21, from = 1 * km, to = deep, material = blocks.rust_red_sandstone },
    }
    for _, e in ipairs(more) do entries[#entries + 1] = e end

    -- Sagebrush, brittle and sparse, on the flats. 60% less of it
    -- (2026-09-15: "reduce the grass by 60%"): a third noise, as fine as
    -- the first, over SAGE_THIN.
    local sage = shape.compile("biome.mesa.sage", masked(off_river(n.min(n.min(n.sub(n.noise("ms_sage", 1.4, 1, 1.0), n.const(0.38)),
        n.sub(n.noise("ms_sage_patch", 1 / 30, 1, 1.0), n.const(0.1))),
        n.sub(n.noise("ms_sage_thin", 1.4, 1, 1.0), n.const(SAGE_THIN))), shape.RIVER_BAR or 0)))
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
        { cover = blocks.bramble, cells = 2, take = sage },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, above)
            fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance, salt = salt, sink = 1,
                above = above, stand = shape.compile("biome.mesa.stand_" .. name, masked(off_river(field, (shape.RIVER_BAR or 0) + 6))) }
        end
        -- The tops: on a bench, off the aprons and out of the canyons.
        local function tops()
            return n.min(n.sub(p(), n.const(LEVELS[1][1] + 0.01)), n.sub(n.const(0.3), canyon_w()))
        end
        local function flats()
            return n.max(tops(), n.sub(plains_w(), n.const(0.5)))
        end
        -- Just over the top of one of the two highest cliffs.
        local function ledge()
            local acc = nil
            for i = #LEVELS - 1, #LEVELS do
                local l = LEVELS[i][1]
                local band = n.min(n.sub(p(), n.const(l)), n.add(n.mul(p(), n.const(-1.0)), n.const(l + 0.012)))
                acc = acc and n.max(acc, band) or band
            end
            return acc
        end
        scatter("saguaro", built.saguaros, flats(), CACTUS_CELL, CACTUS_SQUARES, 101, 0.012)
        scatter("cranny", built.crannies, talus(), CRANNY_CELL, CRANNY_SQUARES, 102, 0.003)
        scatter("juniper_talus", built.junipers, talus(), TREE_TALUS_CELL, TREE_TALUS_SQUARES, 103, 0.009)
        scatter("juniper_top", built.junipers, tops(), TREE_TOP_CELL, TREE_TOP_SQUARES, 104, 0.009)
        scatter("palm", built.palms, n.min(n.add(n.mul(arroyo_d(), n.const(-1.0)), n.const(ARROYO_BANK + 2)), n.sub(lowland(), n.const(0.5))),
            PALM_CELL, PALM_SQUARES, 105, 0.014)
        scatter("hoodoo", built.hoodoos, n.max(n.sub(plains_w(), n.const(0.5)), n.sub(canyon_w(), n.const(0.5))), HOODOO_CELL, HOODOO_SQUARES, 106, 0.022)
        scatter("nest", built.nests, ledge(), NEST_CELL, NEST_SQUARES, 107, 0.003)
        -- The alcoves: at the foot of one of the three lower cliffs.
        local foot = nil
        for i = 1, 3 do
            local l = LEVELS[i][1]
            local band = n.min(n.add(p(), n.const(ALCOVE_FOOT - l)), n.add(n.mul(p(), n.const(-1.0)), n.const(l)))
            foot = foot and n.max(foot, band) or band
        end
        scatter("alcove", built.alcoves, foot, ALCOVE_CELL, ALCOVE_SQUARES, 108, 0.008)
    end
    return fills
end)
