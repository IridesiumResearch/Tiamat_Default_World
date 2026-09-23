-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 2.6 Stalactite Forests (2026-09-18).
--
-- Cathedral caverns sixteen to twenty-eight blocks across and twenty to
-- thirty-five high, crowded top to bottom so the way through winds between
-- pillars. Fluted flowstone over every surface; a floor of slick calcite
-- stepped with rimstone dams holding water. Stalactites in clusters from
-- the ceiling, two to twelve long and razor-tipped; stalagmites three to
-- fifteen tall; thin draperies along the ceiling's ridges; columns two to
-- four thick fused floor to ceiling; soda straws on the low ceilings;
-- shattered debris on the floor; water dripping.
--
-- THE HALLS are two storeys of them: a footprint noise, flat in y, for the
-- plan, and a flat ceiling and floor HH either side of a wandering centre,
-- so the walls stand straight and the halls are tall. Everything that
-- crowds them is cut out of the void as a field, not stamped:
--   STALACTITES: a fine noise, flat in y, whose blobs hang a length from the
--   ceiling that grows with the noise over its threshold — the blob's
--   middle hangs longest and its edge shortest, which is a cone.
--   STALAGMITES: the same up from the floor, on a noise of their own.
--   COLUMNS: a coarser flat noise, over a higher threshold: rock right
--   through.
--   DRAPERIES: a flat noise's zero line — a thin wall seen from above —
--   hanging a few blocks from the ceiling, in patches.
--
-- Materials: `calcite` (the pavement, the dams, the straws), the water the
-- world's. **One new material, `flowstone`; no plant.**
--
-- 2.6.1 WEEPING DRAPERY CHAMBER (2026-09-23), the decoration variant: the
-- same halls past the cave_variant line (caves.lua, "the variants"),
-- redecorated and nothing recarved. The knobby columns and the thick-coned
-- stalactites fade out across the seam; in their place, sheets of
-- flowstone a block thick and four to eight long hang like frozen fabric
-- along the same ridge lines the base's thin draperies follow, hems
-- wavering column to column, the odd crystal drip off a fold for the glint
-- the brief's "translucent" asks of a palette with no see-through stone.
-- The soda straws stay and crowd until they own the ceiling. The floor
-- trades its shattered debris for terraced rimstone: the dam threshold all
-- but drops away, pools stand stepped over most of it in calcite-lined
-- basins, and tiny cave pearls — a cell of calcite, the odd one pyrite —
-- lie strewn in the beds. **No new block and no plant; the round's rule.**

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "stalactite_forests"
local FLAT = shape.HUMIDITY_STRETCH

local STOREYS = { 0.60, 1.20 }                          -- km under the dome
local STOREY_WANDER = 0.22
local ROOM_FREQ, ROOM_MIN, ROOM_W = 1 / 36, 0.04, 34.0  -- sixteen to twenty-eight across
local HH, HH_VARY = 13.75, 3.75                         -- half the height: 20 to 35
local SCOOP_FREQ, SCOOP = 1 / 6, 1.2
local CRAWL_FREQ, CRAWL_W, CRAWL_H = 1 / 120, 2.0, 1.8
local TITE_FREQ, TITE_MIN, TITE_K, TITE_MAX = 1 / 5, 0.12, 36.0, 12.0   -- stalactites: 2 to 12 long
local MITE_FREQ, MITE_MIN, MITE_K, MITE_MAX = 1 / 6, 0.12, 45.0, 15.0   -- stalagmites: 3 to 15 tall
local COLUMN_FREQ, COLUMN_MIN = 1 / 14, 0.30            -- columns: 2 to 4 thick
local DRAPE_FREQ, DRAPE_W, DRAPE_K = 1 / 12, 0.04, 25.0 -- draperies: a thin line from above
local DRAPE_PATCH_FREQ, DRAPE_PATCH_MIN, DRAPE_MAX = 1 / 20, 0.10, 6.0
local DAM_FREQ, DAM_MIN = 1 / 8, 0.18                   -- the rimstone pools
local STRAW_CELL, STRAW_SQUARES = 3, 0.25
local DEBRIS_CELL, DEBRIS_SQUARES = 7, 0.30
-- The variant's numbers (2.6.1). The dams' threshold all but gone: pools
-- over most of the variant's floor rather than a sixth of it. The straws'
-- second helping reads the SAME sf_straws noise past a looser threshold,
-- so the crowds thicken around the base's clumps rather than beside them.
local WDC_DAM_MIN = 0.02                                -- 0.18 on the base side
local WDC_STRAW_MIN, WDC_STRAW_SQUARES = -0.12, 0.85    -- 0.05 and 0.25 on the base side
local WDC_RIDGE_W = 0.22                                -- |sf_drape| under this: the corridor round a ceiling ridge the fabric hangs in
local WDC_SHEET_CELL, WDC_SHEET_SQUARES = 4, 0.55
local WDC_PEARL_CELL, WDC_PEARL_SQUARES = 3, 0.45

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "stalactite_template:" .. name)
end
-- Soda straws: three to eight hollow-looking thin tubes of calcite a block
-- or two long, hanging in a clump.
local function straws(rng)
    schem.record_begin()
    for _ = 1, 3 + rng:below(6) do
        local x, z = 0.5 + (rng:below(5) - 2) * 0.28, 0.5 + (rng:below(5) - 2) * 0.28
        local len = 0.8 + rng:below(5) * 0.35
        schem.push_path(blocks.calcite, { { x, 0.9, z, 0.13 }, { x, 0.9 - len, z, 0.1 } }, BLIND)
    end
    return schem.record_schematic({})
end
-- Debris: three to six shards of a fallen stalactite, lying about.
local function debris(rng)
    schem.record_begin()
    for _ = 1, 3 + rng:below(4) do
        local d = schem.DIR16[rng:below(16) + 1]
        local off = rng:below(4) * 0.5
        local len = 0.6 + rng:below(4) * 0.3
        local e = schem.DIR16[rng:below(16) + 1]
        local x, z = 0.5 + d[1] * off, 0.5 + d[2] * off
        schem.push_path(blocks.flowstone, { { x - e[1] * len / 2, 1.15, z - e[2] * len / 2, 0.25 }, { x + e[1] * len / 2, 1.1, z + e[2] * len / 2, 0.12 } }, BLIND)
    end
    return schem.record_schematic({})
end
-- A drapery (2.6.1): a sheet of flowstone hanging from the ceiling — four
-- to seven columns of path a block apart along one of the sixteen
-- headings, each half a block round, fused at the top and parting into
-- fingers lower down. The hem wanders column to column and swings a
-- little off the sheet's plane (the template's own rng, at load), which
-- is the frozen-fabric wave. The brief's "translucent" has nothing to
-- play it — the one see-through block is `crystal` and a whole sheet of
-- it would read as a crystal seam, not fabric — so the sheet is flowstone
-- and every seventh column or so hangs a thin crystal drip off its hem
-- for the glassy glint, sparingly.
local function drapery(rng)
    schem.record_begin()
    local d = schem.DIR16[rng:below(16) + 1]
    local len = 4 + rng:below(4)
    local drop = 5 + rng:below(3)
    local wave = 0.0
    for i = 0, len - 1 do
        local x = 0.5 + d[1] * (i - (len - 1) * 0.5)
        local z = 0.5 + d[2] * (i - (len - 1) * 0.5)
        wave = wave + (rng:below(5) - 2) * 0.6
        local fall = drop + wave
        if fall < 4.0 then fall = 4.0 elseif fall > 8.0 then fall = 8.0 end
        local sway = (rng:below(5) - 2) * 0.25
        schem.push_path(blocks.flowstone,
            { { x, 0.9, z, 0.5 }, { x + d[2] * sway, 0.9 - fall, z - d[1] * sway, 0.28 } }, BLIND)
        if rng:below(7) == 0 then
            schem.push_path(blocks.crystal,
                { { x, 0.9 - fall, z, 0.15 }, { x, 0.9 - fall - 1.4, z, 0.1 } }, BLIND)
        end
    end
    return schem.record_schematic({})
end
-- Cave pearls (2.6.1): four to eight beads of calcite — the odd first one
-- pyrite, for the lustre — strewn a block or two round the root, each
-- centred on a cell of the block over the floor (y = 7/6 is that block's
-- bottom cell row), so a bead is one cell, two at most. They lie in the
-- pool beds; the water is laid after and fills the room they leave.
local function pearls(rng)
    schem.record_begin()
    for i = 1, 4 + rng:below(5) do
        local d = schem.DIR16[rng:below(16) + 1]
        local off = rng:below(5) * 0.45
        local r = 0.24 + rng:below(3) * 0.02
        local bead = (i == 1 and rng:below(3) == 0) and blocks.pyrite or blocks.calcite
        schem.push_ellipsoid(bead, 0.5 + d[1] * off, 7 / 6, 0.5 + d[2] * off, r, 0.2, r, BLIND)
    end
    return schem.record_schematic({})
end
local BUILT = nil
local function structures()
    if BUILT then return BUILT end
    BUILT = { straws = {}, debris = {}, draperies = {}, pearls = {} }
    if game.schematic_shapes then
        for i = 1, 5 do BUILT.straws[i] = straws(rng_for("straws:" .. i)) end
        for i = 1, 4 do BUILT.debris[i] = debris(rng_for("debris:" .. i)) end
        for i = 1, 5 do BUILT.draperies[i] = drapery(rng_for("drapery:" .. i)) end
        for i = 1, 4 do BUILT.pearls[i] = pearls(rng_for("pearls:" .. i)) end
    end
    return BUILT
end

-- ------------------------------------------------------------ the fields

local function centre(k)
    return n.add(n.noise("sf_storey" .. k, 1 / 900, 1, 2.0 * STOREY_WANDER, FLAT), n.const(STOREYS[k]))
end
local function hh(k)
    return n.add(n.noise("sf_height" .. k, 1 / 70, 1, HH_VARY, FLAT), n.const(HH))
end

tdw.cave_biome(ID, { -0.15, 0.0 }, function(ctx)
    local caves = ctx.caves
    -- Blocks above a storey's centre.
    local function up_c(k)
        return n.mul(n.sub(centre(k), caves.D()), n.const(1000.0))
    end
    -- Blocks under the ceiling, and over the floor: the height FIRST.
    local function ceil_dist(k)
        return n.add(n.mul(up_c(k), n.const(-1.0)), hh(k))
    end
    local function floor_dist(k)
        return n.add(up_c(k), hh(k))
    end
    local function footprint(k)
        return n.mul(n.sub(n.noise("sf_room" .. k, ROOM_FREQ, 2, 1.0, FLAT), n.const(ROOM_MIN)), n.const(ROOM_W))
    end
    local function hanging(stream, freq, min, k_len, max)
        return n.clamp(n.mul(n.sub(n.noise(stream, freq, 1, 1.0, FLAT), n.const(min)), n.const(k_len)), 0.0, max)
    end
    -- The hall, with the ceiling and the floor each read ONCE (they carry
    -- the dome's polynomial and two noises; read at every use, the veins'
    -- program was 1,082 operations, past the engine's 1,024). What hangs
    -- is one length from the ceiling — the longer of a stalactite's and a
    -- drapery's, the drapery's only on its line — and what stands one from
    -- the floor. A length is 0 where nothing hangs, so the ceiling is the
    -- ceiling there.
    local function hall(k)
        local on_line = n.clamp(n.mul(n.sub(n.const(DRAPE_W), n.abs(n.noise("sf_drape", DRAPE_FREQ, 1, 1.0, FLAT))), n.const(DRAPE_K)), 0.0, 1.0)
        local drape = n.mul(n.clamp(n.mul(n.sub(n.noise("sf_drape_patch", DRAPE_PATCH_FREQ, 1, 1.0, FLAT), n.const(DRAPE_PATCH_MIN)), n.const(40.0)), 0.0, DRAPE_MAX), on_line)
        -- The cones' length is scaled by a 0..1 gate on the BASE side of
        -- the cave_variant noise (caves.lua, "the variants"): on the
        -- Weeping Drapery Chamber's ground the ceiling belongs to the
        -- straws and the fabric, and a gated LENGTH thins a cone to
        -- nothing over the seam's few tens of blocks instead of shearing
        -- it flat at the line.
        local cones = n.mul(hanging("sf_tite", TITE_FREQ, TITE_MIN, TITE_K, TITE_MAX), n.clamp(ctx.side(-1), 0.0, 1.0))
        local hangs = n.max(cones, drape)
        local v = n.min(n.sub(ceil_dist(k), hangs), n.sub(floor_dist(k), hanging("sf_mite", MITE_FREQ, MITE_MIN, MITE_K, MITE_MAX)))
        return n.min(v, n.add(footprint(k), n.noise("sf_scoop", SCOOP_FREQ, 1, SCOOP)))
    end
    local function crawl(k)
        return n.min(n.sub(n.const(CRAWL_H), n.abs(n.sub(floor_dist(k), n.const(CRAWL_H)))),
            n.sub(n.const(CRAWL_W), n.contour("sf_crawl" .. k, CRAWL_FREQ, 2)))
    end
    -- The columns, cut out of the halls ONCE over both storeys — min
    -- distributes over the storeys' max, the term is storey-blind, and it
    -- never applied to the crawls, so hoisting it halves its sf_column
    -- reads and changes no base terrain — and lifted clear on the
    -- variant's ground: the max opens the term wherever the base's
    -- side-cut goes negative, so the same rooms stand there with fabric
    -- where the columns were. -side(-1) rather than side(1), so the last
    -- columns reach INTO the seam's overlap and mingle with the first
    -- sheets rather than stopping short of them.
    local columns = n.mul(n.sub(n.const(COLUMN_MIN), n.noise("sf_column", COLUMN_FREQ, 1, 1.0, FLAT)), n.const(20.0))
    local halls, crawls = nil, nil
    for k = 1, #STOREYS do
        halls = halls and n.max(halls, hall(k)) or hall(k)
        crawls = crawls and n.max(crawls, crawl(k)) or crawl(k)
    end
    local void = n.max(n.min(halls, n.max(columns, n.mul(ctx.side(-1), n.const(-1.0)))), crawls)
    void = ctx.mine(void)
    local carve = ctx.compile("carve", void)
    local function step(f) return n.clamp(n.mul(f, n.const(1e4)), 0.0, 1.0) end
    -- The pavement: rock under a hall's floor.
    local floorish = nil
    for k = 1, #STOREYS do
        local f = n.min(n.mul(floor_dist(k), n.const(-1.0)), n.add(footprint(k), n.const(2.0)))
        floorish = floorish and n.max(floorish, f) or f
    end
    local conditions = {
        n.const(1.0),                                                                          -- 1 flowstone over everything
        floorish,                                                                              -- 2 calcite pavement
        -- 3 the variant's pool beds: calcite right down — a rimstone basin
        -- rather than pavement over flowstone — where the variant's denser
        -- dam field will stand water (ctx.side raw, the lining idiom).
        n.min(floorish, n.min(n.sub(n.noise("sf_dam", DAM_FREQ, 2, 1.0, FLAT), n.const(WDC_DAM_MIN)), ctx.side(1))),
    }
    local code = n.const(0.0)
    for k, c in ipairs(conditions) do
        code = n.max(code, n.mul(step(c), n.const(k)))
    end
    local depth = ctx.compile("depth", n.mul(void, n.const(-1.0)))
    local codes = ctx.compile("codes", code)
    local entries = {
        { code = 1, to = 2.0, material = blocks.flowstone },
        { code = 2, to = 1.2, material = blocks.calcite },
        { code = 2, from = 1.2, to = 2.5, material = blocks.flowstone },
        { code = 3, to = 3.0, material = blocks.calcite },
    }
    local fills = {
        { carve = carve },
        { layers = true, depth = depth, code = codes, entries = entries },
        caves.vein_fill(ctx, void, 0.0),              -- the crystal veins through the rock (caves.lua)
    }
    if game.schematic_shapes then
        local built = structures()
        -- The straws hang from ceilings: the depth positive in the VOID.
        -- Both dressings keep them — the brief replaces no straw.
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.straws, cell = STRAW_CELL, chance = STRAW_SQUARES, salt = 451, sink = 0,
            stand = ctx.compile("stand_straws", ctx.mine(n.sub(n.noise("sf_straws", 1 / 10, 1, 1.0), n.const(0.05)))) }
        -- The debris only on the base's floors (ctx.base, not ctx.mine):
        -- the variant trades its drop-zones for pools.
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.debris, cell = DEBRIS_CELL, chance = DEBRIS_SQUARES, salt = 452, sink = 1,
            stand = ctx.compile("stand_debris", ctx.base(n.const(1.0))) }
        -- The variant's second helping of straws, on the SAME sf_straws
        -- noise on purpose: a looser threshold and a fatter chance thicken
        -- the crowds AROUND the base's clumps rather than beside them, and
        -- with the cones gated off this is what "dominated by soda straws"
        -- comes out as. A fresh salt, so the passes' squares differ.
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.straws, cell = STRAW_CELL, chance = WDC_STRAW_SQUARES, salt = 453, sink = 0,
            stand = ctx.compile("wdc_stand_straws", ctx.variant(n.sub(n.noise("sf_straws", 1 / 10, 1, 1.0), n.const(WDC_STRAW_MIN)))) }
        -- The fabric: sheets on the ceilings, in a corridor round the SAME
        -- sf_drape zero line on purpose — that line is the ceiling's
        -- ridges, the ones the base's thin carve draperies follow, so the
        -- variant hangs its fabric along the ridges rather than anywhere
        -- the roof happens to be flat.
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.draperies, cell = WDC_SHEET_CELL, chance = WDC_SHEET_SQUARES, salt = 454, sink = 0,
            stand = ctx.compile("wdc_stand_sheets", ctx.variant(n.sub(n.const(WDC_RIDGE_W), n.abs(n.noise("sf_drape", DRAPE_FREQ, 1, 1.0, FLAT))))) }
        -- The pearls, on the SAME sf_dam noise on purpose: they lie where
        -- the variant's water will stand, and the water is laid after and
        -- fills the room the beads leave, so they read as a pool bed's
        -- scatter of pearls rather than beads on dry rock.
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.pearls, cell = WDC_PEARL_CELL, chance = WDC_PEARL_SQUARES, salt = 455, sink = 1,
            stand = ctx.compile("wdc_stand_pearls", ctx.variant(n.sub(n.noise("sf_dam", DAM_FREQ, 2, 1.0, FLAT), n.const(WDC_DAM_MIN)))) }
    end
    -- The rimstone pools: a block of water over each hall's floor where the
    -- dam noise says, held in by calcite lips — the dams. The floor is flat
    -- (HH under the centre), so the level is the floor's height and a block.
    -- Split by dressing (the *_flat cuts: a fluid's level and within are
    -- read on y = 0.5): the base keeps its own threshold, and the variant
    -- drops its to nearly nothing — the SAME sf_dam noise, so every pool
    -- the base would have had is still a pool there and most of the floor
    -- between them is too, terraced over the scoops by the lips. One level
    -- for both, so the seam's overlap lays the same water twice rather
    -- than two levels.
    for k = 1, #STOREYS do
        local floor_y = n.sub(n.add(n.mul(n.sub(shape.dome_node(), centre(k)), n.const(1000.0)), n.const(shape.Y0)), hh(k))
        local level = ctx.compile("pool_level" .. k, n.add(floor_y, n.const(1.3)))
        local function pooled(dam_min)
            return n.min(n.sub(footprint(k), n.const(3.0)),
                n.sub(n.noise("sf_dam", DAM_FREQ, 2, 1.0, FLAT), n.const(dam_min)))
        end
        fills[#fills + 1] = { fluid = "tiamat_default_world:water", lip = blocks.calcite, level = level,
            within = ctx.compile("pool_within" .. k, ctx.base_flat(pooled(DAM_MIN))) }
        fills[#fills + 1] = { fluid = "tiamat_default_world:water", lip = blocks.calcite, level = level,
            within = ctx.compile("wdc_pool_within" .. k, ctx.variant_flat(pooled(WDC_DAM_MIN))) }
    end
    return fills
end)
tdw.cave_variant(ID, "Weeping Drapery Chamber")

-- ------------------------------------------------------------ the drips

-- Water dripping from the ceiling: now and then, near each player the HUD's
-- cave test puts in these halls, a drop falls from a few blocks over them
-- and to one side.
local DRIP_EVERY = 16
local drip_tick, drip_n = 0, 0
if game.emit_particles then
    tdw.on_tick(function(dt)
        drip_tick = drip_tick + dt
        if drip_tick < DRIP_EVERY or not tdw.online or not tdw.cave_under then
            return
        end
        drip_tick = 0
        for uuid in pairs(tdw.online) do
            local body = game.player_entity(uuid)
            local e = body and game.entity(body)
            local p = e and e.pos
            if p and tdw.cave_under(math.floor(p.x), math.floor(p.y), math.floor(p.z)) == ID then
                drip_n = drip_n + 1
                local d = schem.DIR16[(drip_n * 7) % 16 + 1]
                local r = 2 + (drip_n * 5) % 7
                game.emit_particles{ pos = { x = p.x + d[1] * r, y = p.y + 7.0, z = p.z + d[2] * r }, count = 1, size = 0.12, lifetime = 1.6,
                    colour = { r = 0.70, g = 0.82, b = 0.95, a = 0.8 }, velocity = { y = -1.0 }, spread = 0.0, gravity = 1.0,
                    area = { x = 0.1, y = 0.0, z = 0.1 }, collide = true }
            end
        end
    end)
end
