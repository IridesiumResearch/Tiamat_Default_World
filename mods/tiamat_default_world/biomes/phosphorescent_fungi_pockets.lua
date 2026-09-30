-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.6 Phosphorescent Fungi Pockets (2026-09-30), rare.
--
-- Compact, rounded pocket-caverns eight to fourteen blocks across and six
-- to ten high, tucked behind narrow folds in the rock: the one place in the
-- Gloam with light of its own. Damp dark loam over slick basalt, a sticky
-- glowing sap on it. Mushrooms in neon teal and deep violet; spore-vines
-- draping four to eight blocks from the ceiling; great glowing spore-bulbs
-- a block to three across hung like lanterns; blankets of glowing moss;
-- mycelium veined through the walls. Shallow pools on the floor catch the
-- glow; clouds of spores drift through the air.
--
-- RARE by its band: the narrowest of the Gloam's province (caves.lua), and
-- inside it the pockets are sparse. THE POCKETS: two footprint noises,
-- flat in y, each over a cut, and a pocket only where both are: one
-- noise's blobs run long, and where two cross they are small, round and
-- far apart. The void
-- is that footprint less the square of the height from the pocket's
-- middle, which rounds it top and bottom into a squashed ball, cut flat
-- underneath by a floor with shallow dips in it. THE FOLDS: narrow
-- passages two wide and three high along the zero contours of a second
-- noise, only near a pocket, so a pocket is found by following one.
--
-- Materials: `dark_basalt` walls veined with `mycelium`, `mud` for the
-- loam, `glow_algae` for the moss, the sap and the glowing drapes, the
-- river's `glow_cap` for the teal mushrooms, `mushroom_cap` for the
-- bulbs, amber lanterns; one new block, `violet_glowcap` (blocks.lua).
-- (It was built with `spore_vine` and `spore_bulb` too, taken out the
-- same day.) The pools are the world's clear `water`.
--
-- 3.6.1 INDIGO SPORE GROTTO (2026-09-30), the variant: the same pockets on
-- the far side of the `cave_variant` line (caves.lua). The teal mushrooms
-- give way to fan-fungi three to six blocks across on short pale stalks,
-- their caps a deep violet-black (`obsidian`, nearest the indigo of
-- anything the world has) over golden gills (`mushroom_cap`) that light
-- them from underneath; the moss to star-points of `crystal` lichen
-- scattered over the loam; and amber sap-falls (`mushroom_cap`, thin)
-- hang from the ceilings over tiered shelf-fungi on the walls. The violet
-- mushrooms and the bulbs stay. No new block.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "phosphorescent_fungi_pockets"
local FLAT = tdw.caves.DEEP_FLAT
local function k_of(freq) return 0.625 / freq end

local STOREYS = { 2.20, 2.90, 3.60 }                  -- km under the dome
local STOREY_WANDER, WANDER_FREQ = 0.010, 1 / 3000
local POCKET_FREQ, POCKET_MIN, POCKET_K = 1 / 24, 0.13, 30.0   -- where two blob fields overlap: sparse, and compact, eight to fourteen across
local ROUND = 0.30                                    -- footprint lost per block of height squared: six to ten tall
local FLOOR_DOWN = 3.2                                -- the floor this far under the middle...
local DIP_FREQ, DIP_MIN, DIP_D = 1 / 6, 0.10, 1.5     -- ...with dips in it that hold the pools
local POOL = -0.5                                     -- the pools' surface, half a block under the floor's flat: water a block deep in the dips, the flat dry
local FOLD_FREQ, FOLD_W, FOLD_H, FOLD_NEAR = 1 / 32, 1.0, 1.5, 6.0   -- footprint units: a fold runs only in the fringe round a pocket
local MOSS_FREQ, MOSS_MIN = 1 / 7, -0.25            -- blankets: most of the floor the mushrooms leave
local TEAL_FREQ, TEAL_MIN = 1 / 5, 0.14
local VIOLET_FREQ, VIOLET_MIN = 1 / 5, 0.14
local VEIN_FREQ, VEIN_W = 1 / 8, 0.5
local VINE_CELL, VINE_SQUARES = 3, 0.35
local BULB_CELL, BULB_SQUARES = 7, 0.30
local FAN_CELL, FAN_SQUARES = 8, 0.55                 -- the grotto's fan-fungi
local STAR_FREQ, STAR_MIN = 1 / 2, 0.10               -- its star-lichen: a speck here and there, thick in places
local SHELF_FREQ, SHELF_W, SHELF_REACH = 1 / 9, 0.06, 2.4   -- its tiered shelves, the Fungal Grove's brackets' way
local SHELF_TIERS = { x = 6, z = 6 }
local FALL_CELL, FALL_SQUARES = 4, 0.30

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "fungi_pocket_template:" .. name)
end
-- A glowing drape: two or three strands of `glow_algae` four to eight
-- blocks long, from one patch of ceiling.
local function vine(rng)
    schem.record_begin()
    for _ = 1, 2 + rng:below(2) do
        local d = schem.DIR16[rng:below(16) + 1]
        local x, z = 0.5 + d[1] * rng:below(3) * 0.3, 0.5 + d[2] * rng:below(3) * 0.3
        local len = 4.0 + rng:below(5)
        schem.push_path(blocks.glow_algae, { { x, 0.95, z, 0.14 }, { x, 0.95 - len, z, 0.14 } }, BLIND)
    end
    return schem.record_schematic({})
end
-- A spore-bulb: a glowing amber ball of `mushroom_cap` a block to three
-- across, hung from the ceiling on a short stalk of mycelium.
local function bulb(rng)
    schem.record_begin()
    local r = 0.5 + rng:below(3) * 0.5
    local stalk = 0.6 + rng:below(3) * 0.4
    schem.push_path(blocks.mycelium, { { 0.5, 0.95, 0.5, 0.18 }, { 0.5, 0.95 - stalk, 0.5, 0.16 } }, BLIND)
    schem.push_ellipsoid(blocks.mushroom_cap, 0.5, 0.95 - stalk - r * 0.9, 0.5, r, r * 0.9, r, BLIND)
    return schem.record_schematic({})
end
-- A fan-fungus (the grotto): a pale stalk a block or two tall under a
-- flat, slightly domed cap three to six blocks across, violet-black, with
-- a layer of golden gills just under it, a little narrower.
local function fan(rng)
    schem.record_begin()
    local r = 1.5 + rng:below(4) * 0.5
    local tall = 1.2 + rng:below(3) * 0.4
    local lean = schem.DIR16[rng:below(16) + 1]
    local cx, cz = 0.5 + lean[1] * 0.3, 0.5 + lean[2] * 0.3
    schem.push_path(blocks.mycelium, { { 0.5, 0.9, 0.5, 0.3 }, { cx, 1.0 + tall, cz, 0.24 } }, BLIND)
    schem.push_ellipsoid(blocks.mushroom_cap, cx, 1.0 + tall, cz, r * 0.9, 0.22, r * 0.9, BLIND)
    schem.push_ellipsoid(blocks.obsidian, cx, 1.0 + tall + 0.3, cz, r, 0.3, r, BLIND)
    return schem.record_schematic({})
end
-- A sap-fall (the grotto): a thin amber strand four to eight blocks long,
-- dropping from the ceiling with a kink where it spills off a ledge.
local function sap_fall(rng)
    schem.record_begin()
    local d = schem.DIR16[rng:below(16) + 1]
    local len = 4.0 + rng:below(5)
    schem.push_path(blocks.mushroom_cap, { { 0.5, 0.95, 0.5, 0.16 }, { 0.5 + d[1] * 0.35, 0.95 - len * 0.4, 0.5 + d[2] * 0.35, 0.15 },
        { 0.5 + d[1] * 0.35, 0.95 - len, 0.5 + d[2] * 0.35, 0.14 } }, BLIND)
    return schem.record_schematic({})
end
local BUILT = nil
local function structures()
    if BUILT then return BUILT end
    BUILT = { vines = {}, bulbs = {}, fans = {}, falls = {} }
    if game.schematic_shapes then
        for i = 1, 5 do BUILT.vines[i] = vine(rng_for("vine:" .. i)) end
        for i = 1, 5 do BUILT.bulbs[i] = bulb(rng_for("bulb:" .. i)) end
        for i = 1, 6 do BUILT.fans[i] = fan(rng_for("fan:" .. i)) end
        for i = 1, 5 do BUILT.falls[i] = sap_fall(rng_for("fall:" .. i)) end
    end
    return BUILT
end

-- ------------------------------------------------------------ the fields

local function centre(k)
    return n.add(n.noise("pfp_storey" .. k, WANDER_FREQ, 1, 2.0 * STOREY_WANDER, FLAT), n.const(STOREYS[k]))
end

tdw.cave_biome(ID, { 0.05, 0.12 }, function(ctx)
    local caves = ctx.caves
    local function step(f, k) return n.clamp(n.mul(f, n.const(k)), 0.0, 1.0) end
    -- Blocks over a pocket's middle: the depth FIRST.
    local function up(k)
        return n.mul(n.sub(centre(k), caves.D()), n.const(1000.0))
    end
    local footprint = n.mul(n.min(n.sub(n.noise("pfp_pocket", POCKET_FREQ, 1, 1.0, FLAT), n.const(POCKET_MIN)),
        n.sub(n.noise("pfp_pocket_b", POCKET_FREQ, 1, 1.0, FLAT), n.const(POCKET_MIN))), n.const(POCKET_K))
    -- The floor's height over the middle, with its dips.
    local floor_at = n.sub(n.const(-FLOOR_DOWN), n.mul(step(n.sub(n.noise("pfp_dip", DIP_FREQ, 1, 1.0, FLAT), n.const(DIP_MIN)), 6.0), n.const(DIP_D)))
    local fold_line = n.sub(n.const(FOLD_W), n.contour("pfp_fold", FOLD_FREQ, 1))
    local function pocket(k)
        local u = up(k)
        local ball = n.sub(footprint, n.mul(n.mul(u, u), n.const(ROUND)))
        local room = n.min(ball, n.sub(u, floor_at))
        -- A fold: along its line, from the floor's level up FOLD_H * 2,
        -- only within FOLD_NEAR of a pocket.
        local fold = n.min(n.min(fold_line, n.sub(n.const(FOLD_H), n.abs(n.sub(u, n.const(-FLOOR_DOWN + FOLD_H))))),
            n.add(footprint, n.const(FOLD_NEAR)))
        return n.max(room, fold)
    end
    local v, floors, wet = nil, nil, nil
    for k = 1, #STOREYS do
        v = v and n.max(v, pocket(k)) or pocket(k)
        local f = n.min(n.sub(floor_at, up(k)), n.add(footprint, n.const(2.0)))
        floors = floors and n.max(floors, f) or f
        -- How far under the pools' surface a place is, in a pocket.
        local w = n.min(n.sub(n.const(-FLOOR_DOWN + POOL), up(k)), n.add(footprint, n.const(1.0)))
        wet = wet and n.max(wet, w) or w
    end
    local void = ctx.mine(v)
    local carve = ctx.compile("carve", void)
    -- 1 basalt; 2 a mycelium vein in it; 3 a floor (the loam).
    local vein = n.sub(n.const(VEIN_W), n.mul(n.abs(n.noise("pfp_vein", VEIN_FREQ, 1, 1.0)), n.const(k_of(VEIN_FREQ))))
    local code = n.max(n.max(n.const(1.0), n.mul(step(vein, 1e4), n.const(2.0))), n.mul(step(floors, 1e4), n.const(3.0)))
    local depth = ctx.compile("depth", n.mul(void, n.const(-1.0)))
    local dry = n.mul(wet, n.const(-1.0))
    local fills = {
        { layers = true, depth = depth, code = ctx.compile("codes", code), entries = {
            { code = 1, to = 3.0, material = blocks.dark_basalt },
            { code = 2, to = 1.0, material = blocks.mycelium },
            { code = 2, from = 1.0, to = 3.0, material = blocks.dark_basalt },
            { code = 3, to = 1.5, material = blocks.mud },
            { code = 3, from = 1.5, to = 3.0, material = blocks.dark_basalt },
        } },
        { carve = carve },
        -- On the dry loam: the mushrooms in their colours' patches, then the
        -- moss and the sap over most of what is left. Out of the pools.
        { cover = blocks.glow_cap, cells = 2, side = "base", take = ctx.compile("take_teal",
            ctx.base(n.min(dry, n.sub(n.noise("pfp_teal", TEAL_FREQ, 1, 1.0, FLAT), n.const(TEAL_MIN))))) },
        { cover = blocks.violet_glowcap, cells = 2, take = ctx.compile("take_violet",
            ctx.mine(n.min(dry, n.sub(n.noise("pfp_violet", VIOLET_FREQ, 1, 1.0, FLAT), n.const(VIOLET_MIN))))) },
        { cover = blocks.glow_algae, cells = 1, side = "base", take = ctx.compile("take_moss",
            ctx.base(n.min(dry, n.sub(n.noise("pfp_moss", MOSS_FREQ, 1, 1.0, FLAT), n.const(MOSS_MIN))))) },
        -- The grotto's star-lichen: single cells of crystal, a fine noise
        -- over a cut, thicker where the moss's own patches would be.
        { cover = blocks.crystal, cells = 1, side = "variant", take = ctx.compile("take_stars",
            ctx.variant(n.min(dry, n.sub(n.add(n.noise("pfp_star", STAR_FREQ, 1, 1.0, FLAT), n.mul(n.noise("pfp_moss", MOSS_FREQ, 1, 1.0, FLAT), n.const(0.4))),
                n.const(STAR_MIN))))) },
    }
    -- The grotto's shelf-fungi: thin tiers of cap in the air within
    -- SHELF_REACH of a wall, where a noise drawn out flat is near zero, two
    -- blocks and more over the floor (the Fungal Grove's brackets). The
    -- void first, read once.
    local near_wall = n.add(n.mul(n.abs(n.sub(void, n.const(SHELF_REACH * 0.5))), n.const(-1.0)), n.const(SHELF_REACH * 0.5))
    local sheet = n.mul(n.sub(n.const(SHELF_W), n.abs(n.noise("pfp_shelf", SHELF_FREQ, 1, 1.0, SHELF_TIERS))), n.const(8.0))
    local over_floor = nil
    for k = 1, #STOREYS do
        local o = n.min(n.sub(n.sub(up(k), floor_at), n.const(2.0)), n.add(footprint, n.const(2.0)))
        over_floor = over_floor and n.max(over_floor, o) or o
    end
    fills[#fills + 1] = { field = ctx.compile("shelves", ctx.variant(n.min(n.min(near_wall, sheet), over_floor))),
        material = blocks.mushroom_cap, side = "variant" }
    if game.schematic_shapes then
        local built = structures()
        -- Both hang from the ceilings: the depth positive in the VOID.
        local anywhere = ctx.compile("stand_ceiling", ctx.mine(n.const(1.0)))
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.vines, cell = VINE_CELL, chance = VINE_SQUARES, salt = 531, sink = 0,
            side = "base", stand = ctx.compile("stand_vines", ctx.base(n.const(1.0))) }
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.bulbs, cell = BULB_CELL, chance = BULB_SQUARES, salt = 532, sink = 0, stand = anywhere }
        -- The grotto's sap-falls from the ceiling, and its fans on the dry loam.
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.falls, cell = FALL_CELL, chance = FALL_SQUARES, salt = 533, sink = 0,
            side = "variant", stand = ctx.compile("stand_falls", ctx.variant(n.const(1.0))) }
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.fans, cell = FAN_CELL, chance = FAN_SQUARES, salt = 534, sink = 1,
            side = "variant", stand = ctx.compile("stand_fans", ctx.variant(dry)) }
    end
    -- The reflecting pools: clear water half a block under the floor's
    -- flat, so it stands only in the dips, a block deep.
    for k = 1, #STOREYS do
        local level_y = n.add(n.mul(n.sub(shape.dome_node(), centre(k)), n.const(1000.0)), n.const(shape.Y0 - FLOOR_DOWN + POOL))
        local reach = STOREY_WANDER + 0.02
        fills[#fills + 1] = { fluid = "tiamat_default_world:water", lip = blocks.mud,
            reach = { STOREYS[k] - reach, STOREYS[k] + reach },
            level = ctx.compile("water_level" .. k, level_y),
            within = ctx.compile("water_within" .. k, ctx.mine_flat(n.sub(footprint, n.const(1.5)))) }
    end
    return fills
end)
tdw.cave_variant(ID, "Indigo Spore Grotto")

-- ------------------------------------------------------------ the spores

-- Clouds of glowing spores drifting past each player the HUD's cave test
-- puts in a pocket: large, faint, slow, in the two colours.
local SPORE_EVERY = 10
local spore_tick, spore_n = 0, 0
if game.emit_particles then
    tdw.on_tick(function(dt)
        spore_tick = spore_tick + dt
        if spore_tick < SPORE_EVERY or not tdw.online or not tdw.cave_under then
            return
        end
        spore_tick = 0
        for uuid in pairs(tdw.online) do
            local body = game.player_entity(uuid)
            local e = body and game.entity(body)
            local p = e and e.pos
            if p and tdw.cave_under(math.floor(p.x), math.floor(p.y), math.floor(p.z)) == ID then
                spore_n = spore_n + 1
                local d = schem.DIR16[(spore_n * 5) % 16 + 1]
                local violet = spore_n % 2 == 0
                game.emit_particles{ pos = { x = p.x + d[1] * 2.5, y = p.y + 1.5, z = p.z + d[2] * 2.5 }, count = 10, size = 0.12, lifetime = 6.0,
                    colour = violet and { r = 0.62, g = 0.36, b = 0.95, a = 0.35 } or { r = 0.36, g = 0.90, b = 0.84, a = 0.35 },
                    velocity = { y = 0.05 }, spread = 0.18, gravity = 0.0, area = { x = 2.5, y = 1.5, z = 2.5 }, collide = false }
            end
        end
    end)
end
