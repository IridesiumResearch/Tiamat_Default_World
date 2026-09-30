-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.4 Blind Fish Grottoes (2026-09-30).
--
-- Broad, low aquatic chambers fifteen to twenty-five blocks across and
-- five to nine high, most of the floor sprawling pools one to four deep of
-- crystal-clear, motionless water, with semi-submerged side-tunnels
-- branching off into flood-carved passages, some of them crawls under the
-- water. Water-smoothed pale limestone; soft white banks; silt, quartz
-- pebbles and water-carved grooves on the pool floors. Bleached threads
-- hanging from the ceilings in nets. Natural stone arches spanning the
-- pools a couple of blocks over the water; calcified ledges round the
-- pools' rims, a shelf just under the surface before the floor drops.
--
-- THE CHAMBERS: a footprint noise, flat in y, and a water level at each
-- storey's wandering centre, the Shadow Pools' shape. The floor is the
-- pool bed, one to four under the water, held up to a ledge just under
-- the surface near the chamber's rim and lifted out of the water where a
-- bank noise or a fine stepping-stone noise says. Grooves: thin lines of
-- a fine noise, cut half a block into the bed. The ceiling is four to
-- eight over the water. THE ARCHES: rock left in the void along the zero
-- lines of a slow noise, a band two to three blocks over the water, where
-- a patch noise lets one stand. THE SIDE-TUNNELS: the zero contours of
-- another noise, two to four wide, floored two and a half under the water;
-- their roofs stand a block and a half over it, or dip under it where a
-- noise says, which is a flooded crawl.
--
-- THE WATER is the world's own `water`, the clear one: laid full to each
-- storey's level, so every pool is a body at rest, dead still, until
-- somebody wades in. The blind fish are a creature, and creatures are
-- Life's: this biome gives them their water.
--
-- Materials: `calcite` for the limestone, `light_sediment` for the silt,
-- `white_sand` for the pale banks, `crystal` for the quartz pebbles,
-- `mycelium` for the pale threads. No new block (the `ghost_weed` and
-- `glass_algae` it was built with were taken out the same day, and the
-- stalks and the algae sheets with them).
--
-- 3.4.1 ALBINO CORAL CENOTE (2026-09-30), the variant: the same chambers
-- on the far side of the `cave_variant` line (caves.lua). The soft banks
-- give way to skeletal, bleached cave-coral (`bone`), branching one to
-- three blocks tall along the floors and the submerged ledges, the banks
-- under it bare `calcite`; the threads to calcified stone-vines
-- (`calcite`) hanging like pale ice drips; the pool bottoms to pearl
-- gravel, `white_sand` with the quartz (`crystal`) thick through it, whose
-- faint light is a halo in the clear water. No new block.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "blind_fish_grottoes"
local FLAT = tdw.caves.DEEP_FLAT                     -- flat in y, all the way to y = 0.5 (caves.lua)
local function k_of(freq) return 0.625 / freq end    -- blocks per unit of a noise near its zero (stone_labyrinth.lua)

local STOREYS = { 2.05, 2.75, 3.45 }                  -- km under the dome, between the Shadow Pools' three
local STOREY_WANDER, WANDER_FREQ = 0.015, 1 / 4000
local ROOM_FREQ, ROOM_MIN, ROOM_K = 1 / 42, 0.06, 30.0   -- fifteen to twenty-five across
local BED_FREQ, BED_TOP, BED_FALL = 1 / 16, 1.0, 3.0      -- the pools 1 to 4 deep
local LEDGE_W, LEDGE_D = 3.0, 0.7                         -- a shelf this far in from the rim, this far under the water
local BANK_FREQ, BANK_MIN = 1 / 26, 0.10                  -- the dry banks: about two fifths of the floor
local STONE_FREQ, STONE_MIN = 1 / 4, 0.32
local DRY = 0.7                                           -- a bank or a stone stands this far out of the water
local GROOVE_FREQ, GROOVE_W, GROOVE_D = 1 / 7, 0.35, 0.5
local CEIL_FREQ, CEIL_LOW, CEIL_SPAN = 1 / 15, 4.0, 4.0   -- the ceiling 4 to 8 over the water
local ARCH_FREQ, ARCH_W, ARCH_LO, ARCH_HI = 1 / 22, 1.1, 2.0, 3.1
local ARCH_PATCH_FREQ, ARCH_PATCH_MIN = 1 / 60, 0.05
local TUNNEL_FREQ, TUNNEL_W_LO, TUNNEL_W_SPAN = 1 / 70, 1.0, 1.0   -- two to four wide
local TUNNEL_FLOOR, TUNNEL_ROOF = 2.5, 1.5
local DIP_FREQ, DIP_MIN, DIP_DEPTH = 1 / 30, 0.12, 3.0    -- a roof dipped under the water: a crawl
local PEBBLE_FREQ, PEBBLE_MIN = 1 / 3, 0.36
local PEARL_MIN = 0.12                                    -- the cenote's quartz: several times as thick
local THREAD_CELL, THREAD_SQUARES = 4, 0.30
local CORAL_CELL, CORAL_SQUARES = 5, 0.40
local DRIP_CELL, DRIP_SQUARES = 4, 0.30

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "blind_fish_template:" .. name)
end
-- A net of hanging threads: three to six pale strands a block to three
-- long, dropped from one patch of ceiling a little apart, so they read as
-- a web of thread rather than a single string.
local function threads(rng)
    schem.record_begin()
    for _ = 1, 3 + rng:below(4) do
        local d = schem.DIR16[rng:below(16) + 1]
        local off = rng:below(4) * 0.35
        local x, z = 0.5 + d[1] * off, 0.5 + d[2] * off
        local len = 1.0 + rng:below(7) * 0.33
        schem.push_path(blocks.mycelium, { { x, 0.95, z, 0.1 }, { x, 0.95 - len, z, 0.08 } }, BLIND)
    end
    return schem.record_schematic({})
end
-- Cave-coral (the cenote): a bleached stem a block to three tall that
-- forks two or three times on the way up, the branches thinning, like a
-- bone candelabrum.
local function coral(rng)
    schem.record_begin()
    local tall = 1.0 + rng:below(5) * 0.5
    local lean = schem.DIR16[rng:below(16) + 1]
    local top = { 0.5 + lean[1] * 0.2, 1.0 + tall * 0.55, 0.5 + lean[2] * 0.2 }
    schem.push_path(blocks.bone, { { 0.5, 0.9, 0.5, 0.2 }, { top[1], top[2], top[3], 0.15 } }, BLIND)
    for _ = 1, 2 + rng:below(2) do
        local d = schem.DIR16[rng:below(16) + 1]
        local reach = 0.4 + rng:below(4) * 0.2
        local rise = tall * (0.35 + rng:below(3) * 0.15)
        local mid = { top[1] + d[1] * reach * 0.5, top[2] + rise * 0.5, top[3] + d[2] * reach * 0.5 }
        local tip = { top[1] + d[1] * reach, top[2] + rise, top[3] + d[2] * reach }
        schem.push_path(blocks.bone, { { top[1], top[2], top[3], 0.13 }, { mid[1], mid[2], mid[3], 0.1 }, { tip[1], tip[2], tip[3], 0.07 } }, BLIND)
    end
    return schem.record_schematic({})
end
-- A stone-vine (the cenote): a pale drip of calcite a block to two and a
-- half long, thick at the ceiling and tapering, a second beside it now
-- and then.
local function stone_vine(rng)
    schem.record_begin()
    for i = 1, 1 + rng:below(2) do
        local d = schem.DIR16[rng:below(16) + 1]
        local x, z = 0.5 + d[1] * (i - 1) * 0.4, 0.5 + d[2] * (i - 1) * 0.4
        local len = 1.0 + rng:below(4) * 0.5
        schem.push_path(blocks.calcite, { { x, 0.98, z, 0.22 }, { x, 0.98 - len * 0.6, z, 0.14 }, { x, 0.98 - len, z, 0.06 } }, BLIND)
    end
    return schem.record_schematic({})
end
local BUILT = nil
local function structures()
    if BUILT then return BUILT end
    BUILT = { threads = {}, corals = {}, drips = {} }
    if game.schematic_shapes then
        for i = 1, 6 do BUILT.threads[i] = threads(rng_for("threads:" .. i)) end
        for i = 1, 6 do BUILT.corals[i] = coral(rng_for("coral:" .. i)) end
        for i = 1, 5 do BUILT.drips[i] = stone_vine(rng_for("drip:" .. i)) end
    end
    return BUILT
end

-- ------------------------------------------------------------ the fields

local function centre(k)
    return n.add(n.noise("bfg_storey" .. k, WANDER_FREQ, 1, 2.0 * STOREY_WANDER, FLAT), n.const(STOREYS[k]))
end

tdw.cave_biome(ID, { 0.33, 1 }, function(ctx)
    local caves = ctx.caves
    -- Blocks above the water: the depth FIRST.
    local function up(k)
        return n.mul(n.sub(centre(k), caves.D()), n.const(1000.0))
    end
    local function footprint(k)
        return n.mul(n.sub(n.noise("bfg_room" .. k, ROOM_FREQ, 2, 1.0, FLAT), n.const(ROOM_MIN)), n.const(ROOM_K))
    end
    local function tunnel()
        local w = n.add(n.mul(n.clamp(n.add(n.mul(n.noise("bfg_tunnel_w", 1 / 25, 1, 1.0, FLAT), n.const(3.0)), n.const(0.5)), 0.0, 1.0),
            n.const(TUNNEL_W_SPAN)), n.const(TUNNEL_W_LO))
        return n.sub(w, n.contour("bfg_tunnel", TUNNEL_FREQ, 1))
    end
    local function step(f, k) return n.clamp(n.mul(f, n.const(k)), 0.0, 1.0) end
    -- The floor's height over the water (negative: under it).
    local function floor_at(k)
        local bed = n.sub(n.mul(step(n.add(n.mul(n.noise("bfg_bed", BED_FREQ, 1, 1.0, FLAT), n.const(3.0)), n.const(0.5)), 1.0),
            n.const(-BED_FALL)), n.const(BED_TOP))
        -- The grooves, cut into the bed along a fine noise's zero lines.
        bed = n.sub(bed, n.mul(step(n.sub(n.const(GROOVE_W), n.mul(n.abs(n.noise("bfg_groove", GROOVE_FREQ, 1, 1.0, FLAT)),
            n.const(k_of(GROOVE_FREQ)))), 4.0), n.const(GROOVE_D)))
        -- The ledge: the rim held to a shelf just under the water.
        bed = n.max(bed, n.sub(n.const(-LEDGE_D), n.mul(n.max(n.sub(footprint(k), n.const(LEDGE_W)), n.const(0.0)), n.const(6.0))))
        -- And a dry lip against the wall, where the water's `within` stops
        -- a block short: without it the rim was a dry trench.
        bed = n.max(bed, n.sub(n.const(DRY), n.mul(footprint(k), n.const(2.0))))
        local s = n.max(step(n.sub(n.noise("bfg_bank", BANK_FREQ, 1, 1.0, FLAT), n.const(BANK_MIN)), 8.0),
            step(n.sub(n.noise("bfg_stone", STONE_FREQ, 1, 1.0, FLAT), n.const(STONE_MIN)), 10.0))
        return n.add(n.mul(n.sub(bed, n.const(DRY)), n.sub(n.const(1.0), s)), n.const(DRY))
    end
    local function ceiling_at()
        return n.add(n.mul(step(n.add(n.mul(n.noise("bfg_ceil", CEIL_FREQ, 2, 1.0, FLAT), n.const(1.4)), n.const(0.6)), 1.0),
            n.const(CEIL_SPAN)), n.const(CEIL_LOW))
    end
    -- The arches: rock kept in a band over the water along a slow noise's
    -- zero lines, where a patch noise lets one stand.
    local function arch(k)
        local line = n.sub(n.const(ARCH_W), n.mul(n.abs(n.noise("bfg_arch", ARCH_FREQ, 1, 1.0, FLAT)), n.const(k_of(ARCH_FREQ))))
        local band = n.min(n.sub(up(k), n.const(ARCH_LO)), n.sub(n.const(ARCH_HI), up(k)))
        local patch = n.mul(n.sub(n.noise("bfg_arch_patch", ARCH_PATCH_FREQ, 1, 1.0, FLAT), n.const(ARCH_PATCH_MIN)), n.const(40.0))
        return n.min(n.min(line, band), patch)
    end
    local function side_tunnel(k)
        local roof = n.sub(n.const(TUNNEL_ROOF), n.mul(step(n.sub(n.noise("bfg_dip", DIP_FREQ, 1, 1.0, FLAT), n.const(DIP_MIN)), 8.0),
            n.const(DIP_DEPTH)))
        return n.min(n.min(tunnel(), n.add(up(k), n.const(TUNNEL_FLOOR))), n.sub(roof, up(k)))
    end
    local function chamber(k)
        local room = n.min(n.min(n.sub(up(k), floor_at(k)), n.sub(ceiling_at(), up(k))), footprint(k))
        return n.max(n.min(room, n.mul(arch(k), n.const(-1.0))), side_tunnel(k))
    end
    local v, floors, wet = nil, nil, nil
    for k = 1, #STOREYS do
        v = v and n.max(v, chamber(k)) or chamber(k)
        -- The rock under a chamber's floor, for the silt.
        local f = n.min(n.sub(floor_at(k), up(k)), n.add(footprint(k), n.const(2.0)))
        floors = floors and n.max(floors, f) or f
        -- How far under the water a place is, in a chamber's or a tunnel's reach.
        local w = n.min(n.mul(up(k), n.const(-1.0)), n.add(n.max(footprint(k), tunnel()), n.const(1.0)))
        wet = wet and n.max(wet, w) or w
    end
    local void = ctx.mine(v)
    local carve = ctx.compile("carve", void)
    -- 1 the limestone; 2 a floor under the water (silt); 3 a floor out of
    -- it (the banks); 4 the cenote's pool floor (pearl gravel); 5 its
    -- banks (bare calcite, under the coral). A higher code wins.
    local dry = n.min(floors, n.mul(wet, n.const(-1.0)))
    local conditions = { n.const(1.0), floors, dry, n.min(floors, ctx.side(1)), n.min(dry, ctx.side(1)) }
    local code = n.const(0.0)
    for k, c in ipairs(conditions) do
        code = n.max(code, n.mul(step(c, 1e4), n.const(k)))
    end
    local depth = ctx.compile("depth", n.mul(void, n.const(-1.0)))
    local fills = {
        { layers = true, depth = depth, code = ctx.compile("codes", code), entries = {
            { code = 1, to = 3.0, material = blocks.calcite },
            { code = 2, to = 1.0, material = blocks.light_sediment },
            { code = 2, from = 1.0, to = 3.0, material = blocks.calcite },
            { code = 3, to = 1.0, material = blocks.white_sand },
            { code = 3, from = 1.0, to = 3.0, material = blocks.calcite },
            { code = 4, to = 1.0, material = blocks.white_sand },
            { code = 4, from = 1.0, to = 3.0, material = blocks.calcite },
            { code = 5, to = 3.0, material = blocks.calcite },
        } },
        { carve = carve },
        -- Before the water, which takes the room they leave: the quartz
        -- pebbles, a cell here and there, and thick through the cenote's
        -- pearl gravel.
        { cover = blocks.crystal, cells = 1, side = "base", take = ctx.compile("take_pebbles",
            ctx.base(n.min(n.sub(wet, n.const(0.3)), n.sub(n.noise("bfg_pebble", PEBBLE_FREQ, 1, 1.0, FLAT), n.const(PEBBLE_MIN))))) },
        { cover = blocks.crystal, cells = 1, side = "variant", take = ctx.compile("take_pearls",
            ctx.variant(n.min(n.sub(wet, n.const(0.3)), n.sub(n.noise("bfg_pebble", PEBBLE_FREQ, 1, 1.0, FLAT), n.const(PEARL_MIN))))) },
    }
    if game.schematic_shapes then
        local built = structures()
        -- The threads hang from the ceilings: the depth positive in the VOID.
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.threads, cell = THREAD_CELL, chance = THREAD_SQUARES, salt = 511, sink = 0,
            side = "base", stand = ctx.compile("stand_threads", ctx.base(n.const(1.0))) }
        -- The cenote's stone-vines where the threads were; its coral on the
        -- floors, dry or under the water, but not in the pools' depths.
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.drips, cell = DRIP_CELL, chance = DRIP_SQUARES, salt = 512, sink = 0,
            side = "variant", stand = ctx.compile("stand_drips", ctx.variant(n.const(1.0))) }
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.corals, cell = CORAL_CELL, chance = CORAL_SQUARES, salt = 513, sink = 1,
            side = "variant", stand = ctx.compile("stand_corals", ctx.variant(n.sub(n.const(1.6), wet))) }
    end
    -- The pools: clear water to each storey's level, within its chambers
    -- and its tunnels, held by calcite where the rock leaves a block less
    -- than whole.
    for k = 1, #STOREYS do
        local level_y = n.add(n.mul(n.sub(shape.dome_node(), centre(k)), n.const(1000.0)), n.const(shape.Y0))
        local reach = STOREY_WANDER + 0.02
        fills[#fills + 1] = { fluid = "tiamat_default_world:water", lip = blocks.calcite,
            reach = { STOREYS[k] - reach, STOREYS[k] + reach },
            level = ctx.compile("water_level" .. k, level_y),
            within = ctx.compile("water_within" .. k, ctx.mine_flat(n.max(n.sub(footprint(k), n.const(1.0)), tunnel()))) }
    end
    return fills
end)
tdw.cave_variant(ID, "Albino Coral Cenote")
