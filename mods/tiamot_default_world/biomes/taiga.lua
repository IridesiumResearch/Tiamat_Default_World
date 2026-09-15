-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 2.2 Taiga: Firwold, the frost ring's wet half.
--
-- The brief (2026-09-15):
--
--   Topography: rolling, rugged uplands and hummocky glacial ridges broken by
--   sunken, water-logged peat depressions. Slopes moderate to steep,
--   stepping down into flat, stagnant basin hollows.
--   Surface: acidic rust-brown grass and mulch*, moss, mud around bogs, rough
--   grey granite boulders coated in moss.
--   Trees: a thick serrated wall of timber over the ridges and slopes,
--   opening into scattered dying dwarf trees in the soggy muskeg basins.
--   Tall conical spruces, straight slender trunks, branches angled steeply
--   down, needle-sharp crowns; rare ancient pines with thick trunks reaching
--   very high.
--   Drainage: sluggish black-water channels cut through soft peat, not
--   stone; saturated hollows pool stagnant runoff; frost-heave breaks the
--   bedrock on ridge crests into blocky rubble.
--   Accents: rare massive moss-covered fallen logs spanning murky peat
--   pools, dripping lichen hung from lower dead branches, misty fog settling
--   in the forest.
--
-- PLACEMENT is the catalogue's: Firwold, taken from the alpine, which keeps
-- the Crown. The ground is `shape.taiga_terms`, cross-faded into the
-- alpine's mountains across the Crown's edge and into the Frozen Wastes'
-- plains across the humidity split, in `cold_terms` (shape.lua).
--
-- Stand-ins until named: spruce and pine wood and needles are the alpine
-- fir's `fir_log` and `fir_needles`; peat is the rainforest's `black_mud`;
-- ridge rubble is `granite` and `creek_bed`. New: `mulch` (asked for by
-- name), `rust_grass` and `hanging_lichen` (named in the brief, with nothing
-- to stand in for a rust-brown tuft or a pale hanging strand).

local blocks = tdw.blocks
local shape = tdw.shape
local n = shape.node
local schem = tdw.schem

local ID = "taiga"
local WATER = "tiamot_default_world:water"

-- The ground, km. Thresholds against the measured noise: one octave over 0.35
-- on 22% of the ground and at the +0.5 clamp on 13%; two over 0.3 on 18%.
local UPLAND_FREQ, UPLAND_AMP = 1 / 650, 0.040          -- the rolling uplands: twenty blocks either way
local RIDGE_FREQ, RIDGE_W, RIDGE_H = 1 / 420, 18.0, 0.011 -- glacial ridges: eleven blocks over, eighteen either side of the crest
local HUMMOCK_FREQ, HUMMOCK_AMP = 1 / 9, 0.005           -- the hummocks: two or three blocks, heaviest on the ridges
local BASIN_FREQ, BASIN_MIN, BASIN_EDGE, BASIN_DROP = 1 / 300, 0.14, 7.0, 0.012
local CHANNEL_FREQ, CHANNEL_W, CHANNEL_D = 1 / 160, 1.3, 0.0025
local POOL_FILL = -0.0003                                -- the stagnant water's level against the basin's own floor: the dips and the channels hold it
-- The surface.
local MOSS_FREQ, MOSS_MIN = 1 / 16, 0.26
local RUBBLE_FREQ, RUBBLE_MIN = 1 / 6, 0.05
local TUFT_FREQ, TUFT_MIN = 1.5, 0.08
-- The structures: cell, share of squares, salt.
local SPRUCE_CELL, SPRUCE_SQUARES = 4, 0.55              -- a spruce every seven columns or so: a wall of timber
local PINE_CELL, PINE_SQUARES = 64, 0.22
local DWARF_CELL, DWARF_SQUARES = 9, 0.35
local BOULDER_CELL, BOULDER_SQUARES = 30, 0.35
local RUBBLE_CELL, RUBBLE_SQUARES = 7, 0.35
local LOG_CELL, LOG_SQUARES = 64, 0.3
-- The fog: how far one sees into it, and how far over the basins' floors it lies.
local FOG = { r = 0.70, g = 0.75, b = 0.74 }
local FOG_VISIBILITY, FOG_EDGE_VISIBILITY, FOG_ABOVE, FOG_READS = 42, 90, 14, 4

-- ------------------------------------------------------------ the ground

local function upland()
    return n.noise("tg_upland", UPLAND_FREQ, 2, UPLAND_AMP)
end
-- 1 on a ridge's crest, falling to 0 RIDGE_W out: a tent.
local function ridge_w()
    return n.clamp(n.add(n.mul(n.contour("tg_ridge", RIDGE_FREQ, 2), n.const(-1.0 / RIDGE_W)), n.const(1.0)), 0.0, 1.0)
end
local function hummock()
    return n.noise("tg_hummock", HUMMOCK_FREQ, 1, HUMMOCK_AMP)
end
-- 1 on a basin's floor, 0 outside it, steep between.
local function basin_w()
    return n.clamp(n.mul(n.sub(n.noise("tg_basin", BASIN_FREQ, 2, 1.0), n.const(BASIN_MIN)), n.const(BASIN_EDGE)), 0.0, 1.0)
end
local function channel_w()
    return n.clamp(n.mul(n.add(n.contour("tg_channel", CHANNEL_FREQ, 2), n.const(-CHANNEL_W)), n.const(-1.5)), 0.0, 1.0)
end

-- The Taiga's terms of the terrain, km, added to the depth. Written
-- deepest-first down a left-leaning chain: `cold_terms` evaluates it with
-- two buffers already held.
function shape.taiga_terms()
    -- The uplands, the ridges over them, hummocks everywhere and heaviest
    -- on the ridges.
    local acc = n.add(upland(), n.mul(ridge_w(), n.const(RIDGE_H)))
    acc = n.add(acc, n.mul(n.add(ridge_w(), n.const(0.5)), hummock()))
    -- The basins: the ground pulled down to a flat floor BASIN_DROP under
    -- the uplands, as `acc * (1 - w) + floor * w`, with the black-water
    -- channels cut into the peat of the floor.
    local w = basin_w()
    local floor = n.sub(n.add(upland(), n.mul(hummock(), n.const(0.4))),
        n.mul(n.mul(channel_w(), basin_w()), n.const(CHANNEL_D)))
    return n.add(n.mul(acc, n.add(n.mul(w, n.const(-1.0)), n.const(1.0))),
        n.mul(n.sub(floor, n.const(BASIN_DROP)), basin_w()))
end

tdw.biomes[ID].ring_mode = "alpine"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.dirt

-- ------------------------------------------------------------ where it is

-- Whether (x, z) is the Taiga's, by its placement field and the world's
-- seed, cached by eight-block square, as `tdw.frozen_at`: the alpine's
-- random tick and the HUD ask it of every block they look at.
local FIELD = nil
local cache, cached = {}, 0
function tdw.taiga_at(x, z)
    local only = tdw.config.everywhere
    if only then
        return only == ID
    end
    local u = (x * x + z * z) * 1e-6 / (shape.R_DISC * shape.R_DISC)
    local frost = tdw.layers.ring_by_id.frost
    if u < frost.u[1] - shape.RING_WOBBLE or u > frost.u[2] + shape.RING_WOBBLE then
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
        FIELD = FIELD or shape.compile("taiga.at", tdw.biome_mask(n, ID))
        local y = shape.Y0 + 1000 * shape.dome_at(u)
        hit = FIELD:at(x + 0.5, y + 0.5, z + 0.5, seed) > 0
        cache[key] = hit
        cached = cached + 1
    end
    return hit
end

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }

-- Lichen dripping from a point: a strand or two of pale cells hanging down.
local function lichen(x, y, z, rng)
    for _ = 1, 1 + rng:below(2) do
        local ox, oz = x + (rng:below(3) - 1) * 0.25, z + (rng:below(3) - 1) * 0.25
        schem.push_path(blocks.hanging_lichen, { { ox, y - 0.1, oz, 0.2 }, { ox, y - 0.9 - rng:below(4) * 0.35, oz, 0.12 } }, BLIND)
    end
end

-- The bare lower trunk: dead branches angled down, lichen hanging off them.
local function dead_branches(trunk_x, trunk_z, from, to, reach, rng)
    local h = from
    local turn = rng:below(16)
    while h < to do
        for k = 0, 1 + rng:below(2) do
            local d = schem.DIR16[(turn + k * 6) % 16 + 1]
            local len = reach * (0.6 + rng:below(4) * 0.15)
            local tip = { trunk_x + d[1] * len, h - len * 0.7, trunk_z + d[2] * len, 0.1 }
            schem.push_path(blocks.dead_wood, { { trunk_x, h, trunk_z, 0.16 }, tip }, BLIND)
            if rng:below(3) > 0 then
                lichen(tip[1], tip[2], tip[3], rng)
            end
        end
        turn = turn + 5
        h = h + 1.2 + rng:below(3) * 0.4
    end
end

-- A spruce: a straight slender trunk fourteen to twenty-six tall, the lowest
-- few blocks bare but for dead branches; then tier over tier of branches
-- angled steeply down, each shorter than the one under it, round a core of
-- needles, so the whole is a narrow cone; and a spike of needles at the top.
local function spruce(rng)
    schem.record_begin()
    local tall = 14 + rng:below(13)
    local bare = 2 + rng:below(3)
    local spread = 2.2 + rng:below(4) * 0.25
    schem.push_path(blocks.fir_log, { { 0.5, -1.0, 0.5, 0.48 }, { 0.5, tall * 0.55, 0.5, 0.36 }, { 0.5, tall - 0.5, 0.5, 0.14 } }, BLIND)
    dead_branches(0.5, 0.5, 1.2, bare, 1.4, rng)
    -- The core: needles close round the trunk all the way up.
    schem.push_path(blocks.fir_needles, { { 0.5, bare, 0.5, 1.1 }, { 0.5, tall * 0.7, 0.5, 0.7 }, { 0.5, tall + 0.6, 0.5, 0.18 } }, BLIND)
    local h, turn = bare + 0.5, rng:below(16)
    while h < tall - 1 do
        local left = 1.0 - (h - bare) / (tall - bare)
        local reach = 0.5 + spread * left
        local count = left > 0.4 and 6 or 4
        for k = 0, count - 1 do
            local d = schem.DIR16[(turn + k * (16 // count)) % 16 + 1]
            local len = reach * (0.85 + rng:below(3) * 0.1)
            schem.push_path(blocks.fir_needles, {
                { 0.5, h, 0.5, 0.45 },
                { 0.5 + d[1] * len, h - len * 0.75, 0.5 + d[2] * len, 0.3 },
            }, BLIND)
        end
        turn = turn + 3
        h = h + 0.9 + rng:below(2) * 0.3
    end
    schem.push_path(blocks.fir_needles, { { 0.5, tall - 1.0, 0.5, 0.35 }, { 0.5, tall + 1.8, 0.5, 0.05 } }, BLIND)
    return schem.record_schematic({ [blocks.fir_log] = 1 })
end

-- An ancient pine: a thick trunk forty to fifty-five tall, bare and stubbed
-- two thirds of the way, then a few great limbs up and out, each carrying a
-- flat heavy pad of needles, and a crown of them at the top.
local function ancient_pine(rng)
    schem.record_begin()
    local tall = 40 + rng:below(16)
    local lean = schem.DIR16[rng:below(16) + 1]
    local top = { 0.5 + lean[1] * 1.2, tall, 0.5 + lean[2] * 1.2 }
    local trunk = { { 0.5, -2.0, 0.5, 1.7 }, { 0.5, 4.0, 0.5, 1.35 }, { 0.5 + lean[1] * 0.5, tall * 0.6, 0.5 + lean[2] * 0.5, 0.95 },
        { top[1], top[2], top[3], 0.4 } }
    schem.push_path(blocks.fir_log, trunk, BLIND)
    -- Roots flaring at the foot.
    for k = 0, 4 do
        local d = schem.DIR16[(k * 3 + rng:below(2)) % 16 + 1]
        schem.push_path(blocks.fir_log, { { 0.5, 1.5, 0.5, 0.9 }, { 0.5 + d[1] * 3.2, -0.8, 0.5 + d[2] * 3.2, 0.35 } }, BLIND)
    end
    dead_branches(0.5, 0.5, 6.0, tall * 0.62, 2.6, rng)
    -- The limbs and their pads.
    local turn = rng:below(16)
    for k = 0, 3 + rng:below(3) do
        local d = schem.DIR16[(turn + k * 5) % 16 + 1]
        local px, py, pz = schem.path_point(trunk, tall * (0.64 + k * 0.06))
        local len = 5.0 + rng:below(4)
        local tip = { px + d[1] * len, py + len * 0.35, pz + d[2] * len }
        schem.push_path(blocks.fir_log, { { px, py, pz, 0.55 }, { tip[1], tip[2], tip[3], 0.22 } }, BLIND)
        schem.push_ellipsoid(blocks.fir_needles, tip[1], tip[2] + 0.6, tip[3], 3.0 + rng:below(3) * 0.4, 1.3, 3.0 + rng:below(3) * 0.4,
            { rough = 0.35, blind = true })
    end
    schem.push_ellipsoid(blocks.fir_needles, top[1], top[2] + 0.5, top[3], 3.4, 2.0, 3.4, { rough = 0.35, blind = true })
    return schem.record_schematic({ [blocks.fir_log] = 1 })
end

-- A dwarf tree dying in the muskeg: three to six tall, crooked, half of it
-- dead wood, a few thin tufts of needles left, lichen.
local function dwarf(rng)
    schem.record_begin()
    local tall = 3 + rng:below(4)
    local lean = schem.DIR16[rng:below(16) + 1]
    local trunk = { { 0.5, -1.0, 0.5, 0.3 }, { 0.5 + lean[1] * 0.4, tall * 0.5, 0.5 + lean[2] * 0.4, 0.22 },
        { 0.5 + lean[1] * 0.3, tall, 0.5 + lean[2] * 0.3, 0.1 } }
    schem.push_path(rng:below(2) == 0 and blocks.dead_wood or blocks.fir_log, trunk, BLIND)
    dead_branches(trunk[2][1], trunk[2][3], 1.0, tall * 0.7, 0.9, rng)
    for _ = 1, rng:below(3) do
        local px, py, pz = schem.path_point(trunk, tall * (0.5 + rng:below(4) * 0.12))
        schem.push_ellipsoid(blocks.fir_needles, px, py, pz, 0.7, 0.5, 0.7, { rough = 0.5, blind = true })
    end
    return schem.record_schematic({ [blocks.fir_log] = 1, [blocks.dead_wood] = 1 })
end

-- A boulder, rough grey granite with a coat of moss over its top.
local function boulder(rng)
    schem.record_begin()
    for i = 1, 1 + rng:below(2) do
        local r = 1.5 + rng:below(5) * 0.35
        local x, z = 0.5, 0.5
        if i > 1 then
            local d = schem.DIR16[rng:below(16) + 1]
            x, z = 0.5 + d[1] * (r + 1.0), 0.5 + d[2] * (r + 1.0)
            r = r * 0.65
        end
        local rx, ry, rz = r * (0.9 + rng:below(3) * 0.1), r * 0.8, r * (0.9 + rng:below(3) * 0.1)
        schem.push_ellipsoid(blocks.granite, x, ry * 0.3, z, rx, ry, rz, { rough = 0.35, blind = true })
        schem.push_ellipsoid(blocks.moss, x, ry * 0.3 + 0.45, z, rx + 0.25, ry + 0.1, rz + 0.25, { rough = 0.4, blind = true })
    end
    return schem.record_schematic({ [blocks.granite] = 2 })
end

-- Frost-heaved rubble: a scatter of blocky granite and gravel.
local function rubble(rng)
    schem.record_begin()
    for _ = 1, 3 + rng:below(5) do
        local x, z = 0.5 + rng:below(7) - 3, 0.5 + rng:below(7) - 3
        local r = 0.55 + rng:below(4) * 0.2
        schem.push_ellipsoid(rng:below(3) == 0 and blocks.creek_bed or blocks.granite, x, r * 0.3, z, r, r * 0.8, r,
            { rough = 0.5, blind = true })
    end
    return schem.record_schematic({})
end

-- A fallen giant: twenty-two to thirty-four blocks of trunk lying level,
-- sunk a little, a torn root plate at one end, broken stubs, and a coat of
-- moss along its top — laid over a basin's edge, so it spans the pool.
local function fallen_log(rng)
    schem.record_begin()
    local len = 22 + rng:below(13)
    local r = 1.2 + rng:below(4) * 0.2
    local d = schem.DIR16[rng:below(8) * 2 + 1]
    local ax, az = 0.5 - d[1] * len * 0.5, 0.5 - d[2] * len * 0.5
    local bx, bz = 0.5 + d[1] * len * 0.5, 0.5 + d[2] * len * 0.5
    local y = r * 0.6
    schem.push_path(blocks.fir_log, { { ax, y, az, r }, { bx, y - 0.2, bz, r * 0.55 } }, BLIND)
    schem.push_path(blocks.moss, { { ax, y + r * 0.55, az, r * 0.85 }, { bx, y + r * 0.3 - 0.2, bz, r * 0.5 } }, { rough = 0.3, blind = true })
    -- The root plate: a disc of earth and roots on end.
    local side = { -d[2], d[1] }
    schem.push_ellipsoid(blocks.dirt, ax - d[1] * 0.6, y + 0.5, az - d[2] * 0.6, 0.9 + math.abs(side[1]) * 2.4, r + 2.0,
        0.9 + math.abs(side[2]) * 2.4, { rough = 0.45, blind = true })
    for k = 1, 2 + rng:below(3) do
        local t = 0.3 + k * 0.15
        local px, pz = ax + (bx - ax) * t, az + (bz - az) * t
        local s = (rng:below(2) == 0) and 1 or -1
        schem.push_path(blocks.dead_wood, { { px, y, pz, 0.3 }, { px + side[1] * s * 2.2, y + 1.4, pz + side[2] * s * 2.2, 0.12 } }, BLIND)
    end
    return schem.record_schematic({ [blocks.fir_log] = 1 })
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { spruces = {}, pines = {}, dwarfs = {}, boulders = {}, rubble = {}, logs = {} }
    if not game.schematic_shapes then
        BUILT = out
        return out
    end
    local function rng_for(name)
        return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "taiga_template:" .. name)
    end
    for i = 1, 8 do out.spruces[i] = spruce(rng_for("spruce:" .. i)) end
    for i = 1, 3 do out.pines[i] = ancient_pine(rng_for("pine:" .. i)) end
    for i = 1, 5 do out.dwarfs[i] = dwarf(rng_for("dwarf:" .. i)) end
    for i = 1, 5 do out.boulders[i] = boulder(rng_for("boulder:" .. i)) end
    for i = 1, 4 do out.rubble[i] = rubble(rng_for("rubble:" .. i)) end
    for i = 1, 4 do out.logs[i] = fallen_log(rng_for("log:" .. i)) end
    local parts = {}
    for _, key in ipairs({ "spruces", "pines", "dwarfs", "boulders", "rubble", "logs" }) do
        local total = 0
        for _, one in ipairs(out[key]) do total = total + one:len() end
        parts[#parts + 1] = string.format("%d %s (%d blocks)", #out[key], key, total)
    end
    game.log("tiamot_default_world taiga: cut " .. table.concat(parts, ", "))
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

tdw.build_biome(ID, function(ctx)
    local function masked(field)
        local mask = tdw.biome_mask(n, ID)
        return mask and n.min(field, mask) or field
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    local conditions = {
        -- 1: rust-brown mulch over the forest floor.
        n.const(1.0),
        -- 2: moss in patches under the trees.
        n.min(n.sub(n.noise("tg_moss", MOSS_FREQ, 1, 1.0), n.const(MOSS_MIN)), n.sub(n.const(0.3), basin_w())),
        -- 3: a ridge's crest, heaved into rubble: gravel over granite.
        n.min(n.sub(ridge_w(), n.const(0.8)), n.sub(n.noise("tg_rubble", RUBBLE_FREQ, 1, 1.0), n.const(RUBBLE_MIN))),
        -- 4: the mud round a bog.
        n.sub(basin_w(), n.const(0.2)),
        -- 5: the basin's floor: peat.
        n.sub(basin_w(), n.const(0.75)),
        -- 6: moss on the floor's hummocks.
        n.min(n.sub(basin_w(), n.const(0.75)), n.sub(hummock(), n.const(HUMMOCK_AMP * 0.2))),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    local mask = tdw.biome_mask(n, ID)
    if mask then
        code = n.mul(code, step(mask))
    end
    local depth = shape.compile("biome.taiga.depth", shape.terrain(false))
    local codes = shape.compile("biome.taiga.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 1 * km, material = blocks.mulch },
        { code = 1, from = 1 * km, to = 5 * km, material = blocks.dirt },
        { code = 2, to = 1 * km, material = blocks.moss },
        { code = 2, from = 1 * km, to = 5 * km, material = blocks.dirt },
        { code = 3, to = 1 * km, material = blocks.creek_bed },
        { code = 3, from = 1 * km, to = 5 * km, material = blocks.granite },
        { code = 4, to = 2 * km, material = blocks.mud },
        { code = 4, from = 2 * km, to = 5 * km, material = blocks.black_mud },
        { code = 5, to = 5 * km, material = blocks.black_mud },
        { code = 6, to = 1 * km, material = blocks.moss },
        { code = 6, from = 1 * km, to = 5 * km, material = blocks.black_mud },
    }
    -- The rust-brown grass, off the basins' floors.
    local tufts = shape.compile("biome.taiga.tufts", masked(n.min(n.sub(n.noise("tg_tuft", TUFT_FREQ, 1, 1.0), n.const(TUFT_MIN)),
        n.sub(n.const(0.6), basin_w()))))
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
        { cover = blocks.rust_grass, cells = 2, take = tufts },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, above)
            fills[#fills + 1] = { scatter = true, depth = depth, stand = shape.compile("biome.taiga.stand_" .. name, masked(field)),
                schematics = list, cell = cell, chance = chance, salt = salt, sink = 1, above = above }
        end
        local function dry_ground()
            return n.sub(n.const(0.15), basin_w())
        end
        scatter("spruce", built.spruces, dry_ground(), SPRUCE_CELL, SPRUCE_SQUARES, 121, 0.03)
        scatter("pine", built.pines, dry_ground(), PINE_CELL, PINE_SQUARES, 122, 0.06)
        scatter("dwarf", built.dwarfs, n.sub(basin_w(), n.const(0.8)), DWARF_CELL, DWARF_SQUARES, 123, 0.008)
        scatter("boulder", built.boulders, dry_ground(), BOULDER_CELL, BOULDER_SQUARES, 124, 0.006)
        scatter("rubble", built.rubble, n.sub(ridge_w(), n.const(0.8)), RUBBLE_CELL, RUBBLE_SQUARES, 125, 0.003)
        scatter("log", built.logs, n.min(n.sub(basin_w(), n.const(0.3)), n.sub(n.const(0.7), basin_w())), LOG_CELL, LOG_SQUARES, 126, 0.006)
    end
    -- The stagnant pools: water to POOL_FILL over the basin's floor, where
    -- the floor's hummocks and channels dip under it, deep in a basin and
    -- only where the taiga is the whole of the ground (its cross-fades with
    -- the mountains and the wastes are not flat, and water there would stand
    -- on nothing). The level reads x and z only.
    local level = n.add(n.mul(n.add(n.add(n.add(shape.relief_node(), shape.dome_node()), upland()), n.const(POOL_FILL - BASIN_DROP)),
        n.const(1.0 / shape.SCALE)), n.const(shape.Y0))
    local within = masked(n.sub(basin_w(), n.const(0.9)))
    if not tdw.config.everywhere and shape.taiga_weight then
        within = n.min(within, n.sub(shape.taiga_weight(), n.const(0.97)))
    end
    fills[#fills + 1] = { fluid = WATER, level = shape.compile("biome.taiga.level", level), within = shape.compile("biome.taiga.within", within) }
    return fills
end)

-- ------------------------------------------------------------ the fog

-- Mist settling in the forest: in the Taiga's chunks, lying FOG_ABOVE over
-- the basins' floors, so it fills the hollows and the ridges stand out of
-- it. Thinner in a chunk the biome only partly covers.
local fog_mask, fog_floor = nil, nil
local fog_tops, fog_cached = {}, 0
if tdw.on_chunk_fog then
    tdw.on_chunk_fog(function(pos)
        local only = tdw.config.everywhere
        if only and only ~= ID then
            return nil
        end
        local visibility = FOG_VISIBILITY
        if not only then
            fog_mask = fog_mask or shape.compile("taiga.fog", tdw.biome_mask(n, ID))
            local b = fog_mask:bounds(pos)
            if b.high <= 0 then
                return nil
            elseif b.low <= 0 then
                visibility = FOG_EDGE_VISIBILITY
            end
        end
        fog_floor = fog_floor or shape.compile("taiga.fog_floor", n.add(n.add(shape.relief_node(), shape.dome_node()), upland()))
        -- The floor's height, once a column: the world's relief is a 3D noise
        -- a kilometre deep, and read at the base dome it was three hundred
        -- blocks off, so each read is taken at the height the last one gave.
        local key = pos.x * 65536 + pos.z
        local top = fog_tops[key]
        if top == nil then
            if fog_cached > 4096 then
                fog_tops, fog_cached = {}, 0
            end
            local x, z = pos.x * 16 + 8, pos.z * 16 + 8
            local u = (x * x + z * z) * 1e-6 / (shape.R_DISC * shape.R_DISC)
            local y = shape.Y0 + 1000 * shape.dome_at(u)
            for _ = 1, FOG_READS do
                y = shape.Y0 + (fog_floor:at(x, y, z, pos.seed) - BASIN_DROP) / shape.SCALE
            end
            top = math.floor(y) + FOG_ABOVE
            fog_tops[key] = top
            fog_cached = fog_cached + 1
        end
        return { r = FOG.r, g = FOG.g, b = FOG.b, visibility = visibility, top = top }
    end)
end
