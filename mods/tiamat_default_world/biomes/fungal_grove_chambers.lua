-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 2.4 Fungal Grove Chambers (2026-09-18).
--
-- Expansive bulbous caverns twenty to thirty-five blocks across and twelve
-- to eighteen high under irregular domes; walls stepped in tiered shelves
-- and cupped with alcoves. Spongy loam and dark peat over the rock, white
-- mycelium matted through it; the walls slick and dark. Parasol mushrooms
-- five to eleven blocks tall with caps four to seven across; tiered
-- brackets out of the walls; carpets of glowing puffballs and slender
-- cap-clusters, cyan and amber; spore haze; hollow dead stalks lying as
-- tunnels; compost heaps; puffballs that burst when brushed.
--
-- THE CHAMBERS are two storeys of them, built as the Mossy Limestone's
-- rooms are (a footprint noise cut by the distance from a wandering
-- centre, which vaults them), wider and taller, with two things more:
-- TIERS, a noise drawn out flat so it changes only with height, added to
-- the wall — the wall steps in and out in bands a few blocks tall, the
-- shelves; and ALCOVES, the positive side of a fine blob noise scooped out
-- of it. A crawlway runs along a contour at each storey's floor.
--
-- Materials: the loam is `mulch`, the peat `black_mud`, the slick walls
-- `mud`, the rock the world's; the puffballs `glow_cap`. **One new
-- material, `mycelium`** (the mats, and the stalks); **one new plant,
-- `mushroom_cap`** (the parasols' caps, the brackets, the little caps; it
-- glows a low amber, the puffballs cyan).
--
-- **The Ghost-Cap Thicket** (2026-09-23, "one decoration variant of each
-- of the cave biomes", and no new blocks): the same chambers on the far
-- side of the `cave_variant` line (caves.lua), redecorated and nothing
-- else — the carve, the walls, the veins, the cap-clusters, the stalks,
-- the heaps and the puffballs are shared. The wide parasols keep to the
-- base side; over the line stand "tall, slender weeping-bell mushrooms
-- with translucent, milky white hoods that pulse with a faint cyan glow"
-- — a thin stalk under a hood of `clear_ice`, a heart of `glow_polyp`
-- hung inside it for the light (steady: the pulse is a tick's work,
-- deferred). The floor is laced whole with mycelium and threaded with a
-- one-cell film of `glow_algae`, the "fibrous lattice of luminescent
-- mycelium" — that it should brighten underfoot is runtime too, and
-- waits with the pulse. The brackets stay, and weep strands of glowing
-- sap (`glow_algae`, a droplet at each tip) over pools of the same slime
-- sunk into the loam; the slow drip is a particle for another round.
-- Every part is played by a block the world already has: the hood is the
-- Wastes' clear ice, the light the Trench's polyp, the sap the River's
-- algae.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "fungal_grove_chambers"
local FLAT = shape.HUMIDITY_STRETCH

local STOREYS = { 0.50, 1.12 }                          -- km under the dome, the centres' means
local STOREY_WANDER = 0.25
local ROOM_FREQ, ROOM_MIN, ROOM_W = 1 / 40, 0.03, 40.0  -- blobs twenty to thirty-five across
local HEIGHT, HEIGHT_VARY = 15.0, 3.0                   -- blocks: 12 to 18
local TIER_FREQ, TIER = 1 / 5, 1.6                      -- the shelves: bands ~5 tall, the wall in and out this much
local TIER_STRETCH = { x = 10, z = 10 }
local ALCOVE_FREQ, ALCOVE_MIN, ALCOVE_DEPTH = 1 / 7, 0.18, 9.0
local CRAWL_FREQ, CRAWL_W, CRAWL_H = 1 / 110, 2.0, 1.8
local MAT_FREQ, MAT_MIN = 1 / 9, 0.05                   -- the mycelium mats over the floor
local PEAT_FREQ, PEAT_MIN = 1 / 14, 0.10
local PUFF_FREQ, PUFF_MIN = 1 / 3, 0.02                 -- the puffball carpets
local PUFF_PATCH_FREQ, PUFF_PATCH_MIN = 1 / 16, -0.05
local SHELF_FREQ, SHELF_W = 1 / 6, 0.14                 -- the brackets: thin flat sheets out of the walls
local SHELF_PATCH_FREQ, SHELF_PATCH_MIN = 1 / 9, 0.08
local SHELF_REACH = 3.0                                 -- blocks out from the wall
local PARASOL_CELL, PARASOL_SQUARES = 11, 0.40
local CLUSTER_CELL, CLUSTER_SQUARES = 4, 0.30
local STALK_CELL, STALK_SQUARES = 48, 0.30              -- the hollow dead stalks
local HEAP_CELL, HEAP_SQUARES = 22, 0.30
-- The Ghost-Cap Thicket's own numbers. New streams are prefixed `gct_`;
-- where a Thicket field reads an `fg_` stream instead, that is on purpose
-- — the groves and the bracket patches are the CHAMBERS' features, and
-- they do not move when the dressing does.
local BELL_CELL, BELL_SQUARES = 8, 0.40                 -- the weeping bells, in the parasols' own groves
local STRAND_CELL, STRAND_SQUARES = 3, 0.45             -- the sap strands under the bracket patches
local WEB_FREQ, WEB_W = 1 / 4, 0.10                     -- the floor's glow film: |noise| under W is a thread
local SLIME_FREQ, SLIME_MIN = 1 / 7, 0.24               -- the slime pools sunk into the lattice
-- The spore haze: how far one sees into it, and its colour.
local FOG = { r = 0.66, g = 0.60, b = 0.44 }
local FOG_VISIBILITY = 56

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local AIR = game.AIR
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "fungal_template:" .. name)
end
-- Priorities: the stalk over the air that hollows the cap's underside,
-- the air over the cap.
local PRIORITY = { [blocks.mycelium] = 3, [AIR] = 2, [blocks.mushroom_cap] = 1 }

-- A parasol: a stalk five to eleven tall with a bulb at its foot, and a cap
-- four to seven across on top, domed, its underside hollowed so the cap is
-- a shell a block or so thick that a player can stand on.
local function parasol(rng)
    schem.record_begin()
    local tall = 5 + rng:below(7)
    local r = 2.0 + rng:below(4) * 0.5                  -- cap radius: 4 to 7 across
    local lean = schem.DIR16[rng:below(16) + 1]
    local lx, lz = lean[1] * 0.6, lean[2] * 0.6
    schem.push_path(blocks.mycelium, { { 0.5, -0.5, 0.5, 0.95 }, { 0.5, 1.0, 0.5, 0.6 }, { 0.5 + lx, tall, 0.5 + lz, 0.42 } }, BLIND)
    schem.push_ellipsoid(blocks.mushroom_cap, 0.5 + lx, tall + 0.3, 0.5 + lz, r, 1.3, r, { rough = 0.2, blind = true })
    schem.push_ellipsoid(AIR, 0.5 + lx, tall - 0.5, 0.5 + lz, r * 0.92, 1.0, r * 0.92, BLIND)
    return schem.record_schematic(PRIORITY)
end
-- A cluster of slender caps: two to five stalks a half to two blocks tall,
-- each with a little cap.
local function cluster(rng)
    schem.record_begin()
    for _ = 1, 2 + rng:below(4) do
        local d = schem.DIR16[rng:below(16) + 1]
        local off = rng:below(3) * 0.3
        local h = 0.5 + rng:below(4) * 0.5
        local x, z = 0.5 + d[1] * off, 0.5 + d[2] * off
        schem.push_path(blocks.mycelium, { { x, 0.9, z, 0.13 }, { x + d[1] * 0.15, 1.0 + h, z + d[2] * 0.15, 0.1 } }, BLIND)
        schem.push_ellipsoid(blocks.mushroom_cap, x + d[1] * 0.15, 1.0 + h, z + d[2] * 0.15, 0.3 + rng:below(2) * 0.1, 0.14, 0.3, BLIND)
    end
    return schem.record_schematic(PRIORITY)
end
-- A dead stalk lying on the floor, hollow: twelve to twenty blocks of it,
-- two across the bore, a walk-through tunnel. It runs on into the wall
-- where it meets one, which is the "natural tunnel".
local function stalk(rng)
    schem.record_begin()
    local len = 12 + rng:below(9)
    local d = schem.DIR16[rng:below(16) + 1]
    local half = len / 2
    local r = 1.9 + rng:below(3) * 0.2
    local a = { 0.5 - d[1] * half, r * 0.7, 0.5 - d[2] * half }
    local b = { 0.5 + d[1] * half, r * 0.6, 0.5 + d[2] * half }
    schem.push_path(blocks.mycelium, { { a[1], a[2], a[3], r }, { b[1], b[2], b[3], r * 0.9 } }, { rough = 0.15, blind = true })
    -- The bore: air over the mycelium, a block and a third either side,
    -- out past both ends so the ends are open.
    schem.push_path(AIR, { { a[1] - d[1], a[2], a[3] - d[2], r - 0.6 }, { b[1] + d[1], b[2], b[3] + d[2], r * 0.9 - 0.6 } }, BLIND)
    return schem.record_schematic({ [AIR] = 4, [blocks.mycelium] = 1 })
end
-- A compost heap: a mound of rotting loam, peat at its heart, threads of
-- mycelium through the top.
local function heap(rng)
    schem.record_begin()
    local r = 1.8 + rng:below(3) * 0.5
    schem.push_ellipsoid(blocks.mulch, 0.5, 0.7, 0.5, r, 1.1 + rng:below(2) * 0.3, r * 0.85, { rough = 0.4, blind = true })
    schem.push_ellipsoid(blocks.black_mud, 0.5, 0.5, 0.5, r * 0.6, 0.8, r * 0.5, BLIND)
    schem.push_ellipsoid(blocks.mycelium, 0.5, 1.5, 0.5, r * 0.5, 0.35, r * 0.45, { rough = 0.6, blind = true })
    return schem.record_schematic({ [blocks.mycelium] = 2, [blocks.black_mud] = 1 })
end
-- A weeping bell (the Thicket's parasol): a stalk seven to eleven tall
-- and thin as a wrist under a hood taller than it is wide — `clear_ice`
-- for the milky translucent shell, a heart of `glow_polyp` in it for the
-- cyan light, the mouth hollowed from below so the heart hangs into it
-- like a clapper. A drip or two of ice weeps off the rim: the bell
-- mid-weep. The stalk over everything, then the heart, then the air,
-- then the shell, so the hollowing spares the light and the stem.
local PRIORITY_BELL = { [blocks.mycelium] = 4, [blocks.glow_polyp] = 3, [AIR] = 2, [blocks.clear_ice] = 1 }
local function bell(rng)
    schem.record_begin()
    local tall = 7 + rng:below(5)
    local r = 1.0 + rng:below(3) * 0.3                  -- hood: 2 to 3 across, half a parasol's
    local lean = schem.DIR16[rng:below(16) + 1]
    local lx, lz = lean[1] * 0.4, lean[2] * 0.4
    schem.push_path(blocks.mycelium, { { 0.5, -0.5, 0.5, 0.6 }, { 0.5, 1.0, 0.5, 0.4 }, { 0.5 + lx, tall, 0.5 + lz, 0.3 } }, BLIND)
    schem.push_ellipsoid(blocks.clear_ice, 0.5 + lx, tall + 0.6, 0.5 + lz, r, 1.8, r, { rough = 0.15, blind = true })
    schem.push_ellipsoid(blocks.glow_polyp, 0.5 + lx, tall + 0.6, 0.5 + lz, r * 0.55, 1.0, r * 0.55, BLIND)
    schem.push_ellipsoid(AIR, 0.5 + lx, tall - 0.9, 0.5 + lz, r * 0.7, 1.2, r * 0.7, BLIND)
    for _ = 1, 1 + rng:below(2) do
        local d = schem.DIR16[rng:below(16) + 1]
        local wx, wz = 0.5 + lx + d[1] * r * 0.8, 0.5 + lz + d[2] * r * 0.8
        schem.push_path(blocks.clear_ice, { { wx, tall + 0.2, wz, 0.22 }, { wx, tall - 1.4 - rng:below(3) * 0.5, wz, 0.16 } }, BLIND)
    end
    return schem.record_schematic(PRIORITY_BELL)
end
-- A sap strand: two to five blocks of `glow_algae` down from the root,
-- barely thicker than a finger, a swollen droplet at the tip — the drip
-- held mid-fall, as the Grotto holds its condensation.
local function strand(rng)
    schem.record_begin()
    local drop = 2 + rng:below(4)
    local tx, tz = 0.5 + (rng:below(3) - 1) * 0.2, 0.5 + (rng:below(3) - 1) * 0.2
    schem.push_path(blocks.glow_algae, { { 0.5, 0.2, 0.5, 0.24 }, { tx, -drop, tz, 0.17 } }, BLIND)
    schem.push_ellipsoid(blocks.glow_algae, tx, -drop - 0.3, tz, 0.38, 0.5, 0.38, BLIND)
    return schem.record_schematic({})
end
local BUILT = nil
local function structures()
    if BUILT then return BUILT end
    BUILT = { parasols = {}, clusters = {}, stalks = {}, heaps = {}, bells = {}, strands = {} }
    if game.schematic_shapes then
        for i = 1, 6 do BUILT.parasols[i] = parasol(rng_for("parasol:" .. i)) end
        for i = 1, 5 do BUILT.clusters[i] = cluster(rng_for("cluster:" .. i)) end
        for i = 1, 4 do BUILT.stalks[i] = stalk(rng_for("stalk:" .. i)) end
        for i = 1, 3 do BUILT.heaps[i] = heap(rng_for("heap:" .. i)) end
        for i = 1, 5 do BUILT.bells[i] = bell(rng_for("bell:" .. i)) end
        for i = 1, 4 do BUILT.strands[i] = strand(rng_for("strand:" .. i)) end
    end
    return BUILT
end

-- ------------------------------------------------------------ the fields

local function centre(k)
    return n.add(n.noise("fg_storey" .. k, 1 / 900, 1, 2.0 * STOREY_WANDER, FLAT), n.const(STOREYS[k]))
end
local function height(k)
    return n.add(n.noise("fg_height" .. k, 1 / 60, 1, HEIGHT_VARY, FLAT), n.const(HEIGHT))
end

tdw.cave_biome(ID, { 0.15, 0.33 }, function(ctx)
    local caves = ctx.caves
    local function off(k)
        return n.abs(n.mul(n.sub(caves.D(), centre(k)), n.const(1000.0)))
    end
    local function footprint(k)
        return n.mul(n.sub(n.noise("fg_room" .. k, ROOM_FREQ, 2, 1.0, FLAT), n.const(ROOM_MIN)), n.const(ROOM_W))
    end
    -- The chamber: the vault as the Limestone's, the wall stepped by the
    -- tiers and cupped by the alcoves. The distance FIRST (the deepest).
    local function room(k)
        local box = n.min(footprint(k), n.mul(height(k), n.const(0.5)))
        local r = n.sub(n.mul(off(k), n.const(-1.0)), n.mul(box, n.const(-1.0)))     -- box - off, the distance first
        r = n.add(r, n.clamp(n.mul(n.noise("fg_tier", TIER_FREQ, 1, 1.0, TIER_STRETCH), n.const(TIER * 4.0)), -TIER, TIER))
        return n.add(r, n.mul(n.clamp(n.sub(n.noise("fg_alcove", ALCOVE_FREQ, 1, 1.0), n.const(ALCOVE_MIN)), 0.0, 1.0), n.const(ALCOVE_DEPTH)))
    end
    local function crawl(k)
        local floor_off = n.sub(n.mul(n.sub(caves.D(), centre(k)), n.const(1000.0)), n.mul(height(k), n.const(0.5)))
        return n.min(n.sub(n.const(CRAWL_H), n.abs(floor_off)), n.sub(n.const(CRAWL_W), n.contour("fg_crawl" .. k, CRAWL_FREQ, 2)))
    end
    local void = nil
    for k = 1, #STOREYS do
        local storey = n.max(room(k), crawl(k))
        void = void and n.max(void, storey) or storey
    end
    void = ctx.mine(void)
    local carve = ctx.compile("carve", void)
    local function step(f) return n.clamp(n.mul(f, n.const(1e4)), 0.0, 1.0) end
    -- The floor: the lower part of a chamber.
    local floorish = nil
    for k = 1, #STOREYS do
        local f = n.min(n.sub(n.sub(caves.D(), centre(k)), n.mul(height(k), n.const(0.00025))), n.sub(footprint(k), n.const(1.0)))
        floorish = floorish and n.max(floorish, f) or f
    end
    local conditions = {
        n.const(1.0),                                                                             -- 1 the walls: slick mud
        floorish,                                                                                 -- 2 the floor: loam over peat
        n.min(floorish, n.sub(n.noise("fg_peat", PEAT_FREQ, 1, 1.0), n.const(PEAT_MIN))),        -- 3 bare peat
        n.min(floorish, n.sub(n.noise("fg_mat", MAT_FREQ, 2, 1.0), n.const(MAT_MIN))),           -- 4 mycelium mats
    }
    -- The Thicket's floors (2026-09-23): a higher code wins, so on the
    -- variant side of the line (`ctx.side(1)` positive) the lattice takes
    -- the whole floor from the loam, the peat and the mats — the brief
    -- coats it entire — and the slime pools sink into the lattice where a
    -- blob noise and the brackets' own `fg_shelf_patch` agree (on
    -- purpose: the slime lies under the shelves that weep into it).
    local latticed = n.min(floorish, ctx.side(1))
    conditions[5] = latticed                                                                      -- 5 the lattice floor
    conditions[6] = n.min(latticed, n.min(n.sub(n.noise("gct_slime", SLIME_FREQ, 1, 1.0), n.const(SLIME_MIN)),
        n.sub(n.noise("fg_shelf_patch", SHELF_PATCH_FREQ, 1, 1.0), n.const(SHELF_PATCH_MIN))))    -- 6 slime pools
    local code = n.const(0.0)
    for k, c in ipairs(conditions) do
        code = n.max(code, n.mul(step(c), n.const(k)))
    end
    local depth = ctx.compile("depth", n.mul(void, n.const(-1.0)))
    local codes = ctx.compile("codes", code)
    local entries = {
        { code = 1, to = 1.0, material = blocks.mud },
        { code = 1, from = 1.0, to = 2.0, material = blocks.black_mud },
        { code = 2, to = 1.3, material = blocks.mulch },
        { code = 2, from = 1.3, to = 3.5, material = blocks.black_mud },
        { code = 3, to = 3.5, material = blocks.black_mud },
        { code = 4, to = 0.7, material = blocks.mycelium },
        { code = 4, from = 0.7, to = 1.6, material = blocks.mulch },
        { code = 4, from = 1.6, to = 3.5, material = blocks.black_mud },
        { code = 5, to = 0.9, material = blocks.mycelium },
        { code = 5, from = 0.9, to = 2.0, material = blocks.mulch },
        { code = 5, from = 2.0, to = 3.5, material = blocks.black_mud },
        { code = 6, to = 0.8, material = blocks.glow_algae },
        { code = 6, from = 0.8, to = 3.5, material = blocks.black_mud },
    }
    -- The brackets: thin flat sheets of cap in the air within SHELF_REACH of
    -- a wall, where a noise drawn out flat is near zero (so they come in
    -- tiers) and a patch noise allows. The air's distance from the rock is
    -- the void, read ONCE: `R/2 - |void - R/2|` is positive for 0 < void < R.
    -- The void FIRST: a constant pushed ahead of it held a buffer the whole
    -- way down (nine, past the engine's eight).
    local near_wall = n.add(n.mul(n.abs(n.sub(void, n.const(SHELF_REACH * 0.5))), n.const(-1.0)), n.const(SHELF_REACH * 0.5))
    local sheet = n.mul(n.sub(n.const(SHELF_W), n.abs(n.noise("fg_shelf", SHELF_FREQ, 1, 1.0, TIER_STRETCH))), n.const(8.0))
    -- Only on the walls: 3.5 blocks or more off a chamber's floor and
    -- ceiling (near those the air is as close to rock, and the sheets lay
    -- roofs over the floor), and in a chamber's own footprint (not across
    -- a crawlway, which is all "near a wall").
    local walls = nil
    for k = 1, #STOREYS do
        local w = n.min(n.sub(n.sub(n.mul(height(k), n.const(0.5)), n.const(3.5)), off(k)), n.add(footprint(k), n.const(3.0)))
        walls = walls and n.max(walls, w) or w
    end
    local brackets = ctx.compile("brackets", ctx.mine(n.min(n.min(n.min(near_wall, sheet),
        n.mul(n.sub(n.noise("fg_shelf_patch", SHELF_PATCH_FREQ, 1, 1.0), n.const(SHELF_PATCH_MIN)), n.const(10.0))), walls)))
    local function on_floor(f) return ctx.mine(f) end
    local puffs = ctx.compile("puffs", on_floor(n.min(n.sub(n.noise("fg_puff", PUFF_FREQ, 1, 1.0), n.const(PUFF_MIN)),
        n.sub(n.noise("fg_puff_patch", PUFF_PATCH_FREQ, 1, 1.0), n.const(PUFF_PATCH_MIN)))))
    -- The lattice's own light: a one-cell film of `glow_algae` laid in
    -- threads over the Thicket's floors, where a fine noise is near zero
    -- — lines, the way the veins are lines — so the web reads as fibres
    -- rather than as patches. Steady; the footstep flare is a tick's job,
    -- deferred with the bells' pulse.
    local web = ctx.compile("web", ctx.variant(n.sub(n.const(WEB_W), n.abs(n.noise("gct_web", WEB_FREQ, 1, 1.0)))))
    -- The carve AFTER the lining and the veins (2026-09-23): the vein
    -- field no longer cuts the void out of itself, so the carve's air —
    -- which evaluates anyway — clears every vein cell inside it
    -- (caves.lua, `vein_fill`). The brackets and the covers below want
    -- the void already open, so the carve sits between.
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries },
        caves.vein_fill(ctx, 0.0),                    -- the crystal veins through the rock (caves.lua)
        { carve = carve },
        -- Smooth since 2026-09-23: the sampled speckle traded for most of
        -- the fill's cost — the field re-emits the carve — and the smooth
        -- edge keeps the sheet.
        { field = brackets, material = blocks.mushroom_cap, detail = { detail = "smooth" } },
        { cover = blocks.glow_cap, cells = 2, take = puffs },
        { cover = blocks.glow_algae, cells = 1, take = web, side = "variant" },
    }
    if game.schematic_shapes then
        local built = structures()
        -- Since the Ghost-Cap Thicket (2026-09-23) a scatter names the
        -- dressing whose ground it keeps to: `ctx.base` for what the
        -- brief replaces, `ctx.variant` for what replaces it, and the
        -- default `ctx.mine` for what both dressings share. The cut also
        -- names the fill's `side` tag, so a chunk clear of the variant
        -- line skips the far dressing's scatters whole (caves.lua, "the
        -- variants").
        local function scatter(list, cell, chance, salt, stand, cut)
            local side = cut == ctx.base and "base" or cut == ctx.variant and "variant" or nil
            fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance, salt = salt, sink = 1, side = side,
                stand = ctx.compile("stand_" .. salt, (cut or ctx.mine)(stand)) }
        end
        -- The parasols keep to the base side; the bells take the
        -- variant's, and read the SAME `fg_grove` noise on purpose, so
        -- the Thicket's bells stand in the very groves the parasols
        -- would have.
        scatter(built.parasols, PARASOL_CELL, PARASOL_SQUARES, 431, n.sub(n.noise("fg_grove", 1 / 30, 1, 1.0), n.const(-0.15)), ctx.base)
        scatter(built.bells, BELL_CELL, BELL_SQUARES, 531, n.sub(n.noise("fg_grove", 1 / 30, 1, 1.0), n.const(-0.15)), ctx.variant)
        scatter(built.clusters, CLUSTER_CELL, CLUSTER_SQUARES, 432, n.sub(n.noise("fg_puff_patch", PUFF_PATCH_FREQ, 1, 1.0), n.const(0.0)))
        scatter(built.stalks, STALK_CELL, STALK_SQUARES, 433, n.const(1.0))
        scatter(built.heaps, HEAP_CELL, HEAP_SQUARES, 434, n.sub(n.noise("fg_heap", 1 / 25, 1, 1.0), n.const(0.0)))
        -- The sap strands hang under the brackets: the depth positive in
        -- the VOID (as the Limestone hangs its vines), rooted in the
        -- walls' band where the bracket patches are — `fg_shelf_patch`
        -- again, on purpose, so a strand weeps from a shelf and not from
        -- bare rock.
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.strands, cell = STRAND_CELL, chance = STRAND_SQUARES, salt = 532, sink = 0, side = "variant",
            stand = ctx.compile("stand_strand", ctx.variant(n.min(walls,
                n.sub(n.noise("fg_shelf_patch", SHELF_PATCH_FREQ, 1, 1.0), n.const(SHELF_PATCH_MIN))))) }
    end
    return fills
end)
tdw.cave_variant(ID, "Ghost-Cap Thicket")

-- ------------------------------------------------------------ the spore haze

-- Spores hanging in the air like fog, in the chambers' columns: the fog
-- lies under the upper storey's ceiling, so everything under it in the
-- column is hazed (rock, mostly, and the lower storey) and the surface far
-- over it is clear — a fog thins by e every four blocks above its top.
-- Asked after the surface biomes (this file loads after them), so a
-- surface fog in the same column answers first.
local fog_prov, fog_ceiling = nil, nil
if tdw.on_chunk_fog then
    tdw.on_chunk_fog(function(pos)
        local caves = tdw.caves
        fog_prov = fog_prov or shape.compile("fungal.fog_prov", caves.province())
        local x, z = pos.x * 16 + 8.5, pos.z * 16 + 8.5
        local p = fog_prov:at(x, 0.5, z, pos.seed)
        local band = caves.bands[ID]
        if p < band[1] or p > band[2] then
            return nil
        end
        fog_ceiling = fog_ceiling or shape.compile("fungal.fog_ceiling",
            n.add(n.mul(n.sub(shape.dome_node(), centre(1)), n.const(1000.0)), n.mul(height(1), n.const(0.5))))
        local top = shape.Y0 + fog_ceiling:at(x, 0.5, z, pos.seed)
        return { r = FOG.r, g = FOG.g, b = FOG.b, visibility = FOG_VISIBILITY, top = math.floor(top) }
    end)
end

-- ------------------------------------------------------------ the puffballs

-- A puffball bursts when brushed: a player in the chambers who walks into
-- one (the `glow_cap` in the block at their feet or beside it) breaks it
-- and it goes up in a puff of spores. Looked at every PUFF_EVERY ticks for
-- each player the HUD's cave test puts in these chambers.
local PUFF_EVERY = 4
local puff_tick = 0
tdw.on_tick(function(dt)
    puff_tick = puff_tick + dt
    if puff_tick < PUFF_EVERY or not tdw.online or not tdw.cave_under then
        return
    end
    puff_tick = 0
    for uuid, rec in pairs(tdw.online) do
        local body = game.player_entity(uuid)
        local e = body and game.entity(body)
        local p = e and e.pos
        if p and tdw.cave_under(math.floor(p.x), math.floor(p.y), math.floor(p.z)) == ID then
            local x0, y0, z0 = math.floor(p.x), math.floor(p.y), math.floor(p.z)
            for dx = -1, 1 do
                for dz = -1, 1 do
                    for dy = 0, 1 do
                        local q = { x = x0 + dx, y = y0 + dy, z = z0 + dz }
                        local b = game.get_block(q)
                        if b and b.material == blocks.glow_cap then
                            game.set_block(q, "engine:air")
                            if game.emit_particles then
                                game.emit_particles{ pos = { x = q.x + 0.5, y = q.y + 0.4, z = q.z + 0.5 }, count = 24, size = 0.35, lifetime = 4.0,
                                    colour = { r = 0.80, g = 0.86, b = 0.62, a = 0.55 }, velocity = { y = 0.8 }, spread = 1.4, gravity = -0.05,
                                    area = { x = 0.4, y = 0.2, z = 0.4 }, collide = false }
                            end
                        end
                    end
                end
            end
        end
    end
end)
