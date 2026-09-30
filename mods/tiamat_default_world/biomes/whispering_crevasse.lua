-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.5 Whispering Crevasse (2026-09-30).
--
-- Razor-thin vertical chasms two to five blocks wide and forty to eighty
-- high, their tops and bottoms pinching away into black. Sheer, jagged
-- slate and dark basalt fluted by stress, dry and brittle, scabbed with
-- metallic iron crust. A narrow ledge path along the walls that drops
-- twenty blocks without warning; fragile rock bridges across the gap;
-- wind-slots in the stone that the draft whistles through; dust and soot
-- carried up on it. Almost nothing lives: black root-threads, dead, hung
-- like cobweb from the overhangs.
--
-- THE CHASMS follow the zero contours of a slow 2D noise (engine
-- `contour`: the distance to the line in blocks), so each is a wandering
-- vertical slot, flat in y. Its half-width wanders from one block to two
-- and a half. It keeps that width for a reach above and below its storey's
-- centre, then pinches in, a block of width to eight of height, so it ends
-- in a sliver rather than a floor. THE PATH is rock left in the void a
-- block thick, at a level that holds for a stretch and then steps down
-- twenty-two blocks where a noise along the chasm crosses its line, broken
-- where a gap noise says. THE BRIDGES are the same at a second level, along
-- the zero lines of a finer noise that crosses the chasm. THE SLOTS are
-- thin horizontal cuts up to two blocks into the walls, at the zero lines
-- of a noise in y alone, where a patch noise allows.
--
-- Materials: `slate`, fluted with `dark_basalt` in vertical bands (a noise
-- drawn out in y), crusted with `rust_red_sandstone` for the iron; dust
-- `volcanic_ash`. New: `dead_roots` (blocks.lua).

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "whispering_crevasse"
local FLAT = tdw.caves.DEEP_FLAT
local ALONG_Y = { x = 1000, z = 1000 }               -- varies in y alone
local FLUTE = { y = 40 }                               -- vertical bands
local function k_of(freq) return 0.625 / freq end

local STOREYS = { 1.95, 2.55, 3.20, 3.75 }             -- km under the dome
local STOREY_WANDER = 0.04
local CRACK_FREQ = 1 / 75                              -- chasms fifty to eighty blocks apart
local W_FREQ, W_LO, W_SPAN = 1 / 30, 1.0, 1.5          -- half-width 1 to 2.5: two to five across
local REACH_FREQ, REACH_LO, REACH_SPAN = 1 / 50, 12.0, 14.0   -- full width this far above and below the centre
local PINCH = 0.125                                    -- then a block of width lost to eight of height
local PATH_FREQ, PATH_HI, PATH_DROP = 1 / 45, 4.0, 22.0
local GAP_FREQ, GAP_MIN = 1 / 9, -0.30                 -- the path runs where this is over its min: most of it
local BRIDGE_FREQ, BRIDGE_W, BRIDGE_HI = 1 / 18, 0.5, 14.0
local BRIDGE_PATCH_FREQ, BRIDGE_PATCH_MIN = 1 / 40, 0.10
local SLOT_FREQ, SLOT_W, SLOT_REACH = 1 / 11, 0.35, 2.0
local SLOT_PATCH_FREQ, SLOT_PATCH_MIN = 1 / 20, 0.12
local FLUTE_FREQ, FLUTE_MIN = 1 / 3, 0.12
local CRUST_FREQ, CRUST_MIN = 1 / 9, 0.26
local DUST_FREQ, DUST_MIN = 1 / 5, 0.05
local ROOT_CELL, ROOT_SQUARES = 4, 0.35

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "crevasse_template:" .. name)
end
-- Dead root-threads: two to four black strands a block to three long,
-- crooked, hanging from one crack.
local function roots(rng)
    schem.record_begin()
    for _ = 1, 2 + rng:below(3) do
        local d = schem.DIR16[rng:below(16) + 1]
        local x, z = 0.5 + d[1] * rng:below(3) * 0.3, 0.5 + d[2] * rng:below(3) * 0.3
        local len = 1.0 + rng:below(7) * 0.33
        schem.push_path(blocks.dead_roots, { { x, 0.95, z, 0.13 }, { x + d[1] * 0.2, 0.95 - len, z + d[2] * 0.2, 0.13 } }, BLIND)
    end
    return schem.record_schematic({})
end
local BUILT = nil
local function structures()
    if BUILT then return BUILT end
    BUILT = { roots = {} }
    if game.schematic_shapes then
        for i = 1, 6 do BUILT.roots[i] = roots(rng_for("roots:" .. i)) end
    end
    return BUILT
end

-- ------------------------------------------------------------ the fields

local function centre(k)
    return n.add(n.noise("wc_storey" .. k, 1 / 1200, 1, 2.0 * STOREY_WANDER, FLAT), n.const(STOREYS[k]))
end

tdw.cave_biome(ID, { -1, -0.33 }, function(ctx)
    local caves = ctx.caves
    local function step(f, k) return n.clamp(n.mul(f, n.const(k)), 0.0, 1.0) end
    -- Blocks over the storey's centre: the depth FIRST.
    local function up(k)
        return n.mul(n.sub(centre(k), caves.D()), n.const(1000.0))
    end
    -- How far into the chasm a place is, in blocks from its wall, for all
    -- its height: the half-width less the distance to the line.
    local width = n.add(n.mul(step(n.add(n.mul(n.noise("wc_w", W_FREQ, 1, 1.0, FLAT), n.const(3.0)), n.const(0.5)), 1.0), n.const(W_SPAN)), n.const(W_LO))
    local open = n.sub(width, n.contour("wc_crack", CRACK_FREQ, 1))
    local reach = n.add(n.mul(step(n.add(n.mul(n.noise("wc_reach", REACH_FREQ, 1, 1.0, FLAT), n.const(3.0)), n.const(0.5)), 1.0), n.const(REACH_SPAN)),
        n.const(REACH_LO))
    -- The path's level over the centre: high, or a drop's depth under it.
    local path = n.sub(n.const(PATH_HI), n.mul(step(n.noise("wc_path", PATH_FREQ, 1, 1.0, FLAT), 12.0), n.const(PATH_DROP)))
    local gap = n.mul(n.sub(n.noise("wc_gap", GAP_FREQ, 1, 1.0, FLAT), n.const(GAP_MIN)), n.const(k_of(GAP_FREQ)))
    local bridge_line = n.min(n.sub(n.const(BRIDGE_W), n.mul(n.abs(n.noise("wc_bridge", BRIDGE_FREQ, 1, 1.0, FLAT)), n.const(k_of(BRIDGE_FREQ)))),
        n.mul(n.sub(n.noise("wc_bridge_patch", BRIDGE_PATCH_FREQ, 1, 1.0, FLAT), n.const(BRIDGE_PATCH_MIN)), n.const(40.0)))
    local slot_line = n.min(n.sub(n.const(SLOT_W), n.mul(n.abs(n.noise("wc_slot", SLOT_FREQ, 1, 1.0, ALONG_Y)), n.const(k_of(SLOT_FREQ)))),
        n.mul(n.sub(n.noise("wc_slot_patch", SLOT_PATCH_FREQ, 1, 1.0, FLAT), n.const(SLOT_PATCH_MIN)), n.const(40.0)))
    local function storey(k)
        local u = up(k)
        -- The chasm, pinched past its reach.
        local chasm = n.sub(open, n.mul(n.max(n.sub(n.abs(u), reach), n.const(0.0)), n.const(PINCH)))
        -- Rock left in it: the path, a block thick at its level, and the bridges.
        local ledge = n.min(n.sub(n.const(0.5), n.abs(n.sub(u, path))), gap)
        local bridge = n.min(n.sub(n.const(0.5), n.abs(n.sub(u, n.add(path, n.const(BRIDGE_HI - PATH_HI))))), bridge_line)
        local kept = n.max(ledge, bridge)
        -- The wind-slots, cut up to SLOT_REACH into the walls, within the
        -- chasm's height.
        local slot = n.min(n.min(slot_line, n.add(chasm, n.const(SLOT_REACH))), n.sub(n.const(0.0), n.sub(n.abs(u), reach)))
        return n.max(n.min(chasm, n.mul(kept, n.const(-1.0))), slot)
    end
    local v = nil
    for k = 1, #STOREYS do
        v = v and n.max(v, storey(k)) or storey(k)
    end
    local void = ctx.mine(v)
    local carve = ctx.compile("carve", void)
    -- 1 slate; 2 a basalt flute; 3 an iron crust (a block deep, over whichever).
    local code = n.max(n.max(n.const(1.0), n.mul(step(n.sub(n.noise("wc_flute", FLUTE_FREQ, 1, 1.0, FLUTE), n.const(FLUTE_MIN)), 1e4), n.const(2.0))),
        n.mul(step(n.sub(n.noise("wc_crust", CRUST_FREQ, 1, 1.0), n.const(CRUST_MIN)), 1e4), n.const(3.0)))
    local depth = ctx.compile("depth", n.mul(void, n.const(-1.0)))
    local fills = {
        { layers = true, depth = depth, code = ctx.compile("codes", code), entries = {
            { code = 1, to = 3.0, material = blocks.slate },
            { code = 2, to = 3.0, material = blocks.dark_basalt },
            { code = 3, to = 1.0, material = blocks.rust_red_sandstone },
            { code = 3, from = 1.0, to = 3.0, material = blocks.slate },
        } },
        { carve = carve },
        -- The dust on the path and the bridges, in patches.
        { cover = blocks.volcanic_ash, cells = 1, take = ctx.compile("take_dust",
            ctx.mine(n.sub(n.noise("wc_dust", DUST_FREQ, 1, 1.0, FLAT), n.const(DUST_MIN)))) },
    }
    if game.schematic_shapes then
        local built = structures()
        -- The root-threads hang from the overhangs: the depth positive in the VOID.
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.roots, cell = ROOT_CELL, chance = ROOT_SQUARES, salt = 521, sink = 0,
            stand = ctx.compile("stand_roots", ctx.mine(n.const(1.0))) }
    end
    return fills
end)

-- ------------------------------------------------------------ the draft

-- Dust and soot carried up past each player the HUD's cave test puts in a
-- crevasse: a few grey motes drifting upward, now and then.
local DRAFT_EVERY = 8
local draft_tick, draft_n = 0, 0
if game.emit_particles then
    tdw.on_tick(function(dt)
        draft_tick = draft_tick + dt
        if draft_tick < DRAFT_EVERY or not tdw.online or not tdw.cave_under then
            return
        end
        draft_tick = 0
        for uuid in pairs(tdw.online) do
            local body = game.player_entity(uuid)
            local e = body and game.entity(body)
            local p = e and e.pos
            if p and tdw.cave_under(math.floor(p.x), math.floor(p.y), math.floor(p.z)) == ID then
                draft_n = draft_n + 1
                local d = schem.DIR16[(draft_n * 7) % 16 + 1]
                local r = 1 + (draft_n * 3) % 4
                local soot = draft_n % 3 == 0
                game.emit_particles{ pos = { x = p.x + d[1] * r, y = p.y - 3.0, z = p.z + d[2] * r }, count = 6, size = soot and 0.10 or 0.06,
                    lifetime = 5.0, colour = soot and { r = 0.10, g = 0.10, b = 0.11, a = 0.7 } or { r = 0.55, g = 0.53, b = 0.50, a = 0.45 },
                    velocity = { y = 1.3 }, spread = 0.25, gravity = 0.0, area = { x = 1.2, y = 1.0, z = 1.2 }, collide = false }
            end
        end
    end)
end
