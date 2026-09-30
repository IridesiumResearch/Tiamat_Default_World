-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 4.2 Silent Vertical Shafts (2026-09-30).
--
-- Near-perfectly cylindrical drop-shafts eight to fourteen blocks across
-- and sixty to a hundred deep, their tops and bottoms narrowing away into
-- black. Unbroken black basalt striated with iron-granite, glass-smooth,
-- cut top to bottom with parallel friction grooves. Barren but for rare
-- wire-thin pale mineral tendrils hanging where a drip condenses. No
-- sound at all (sounds.lua: this biome has no bed, and so no echoes). Dust
-- motes hanging in the still air. Lone ledges a block wide, the only
-- footholds.
--
-- THE SHAFTS: where two flat noises are BOTH over a cut, which leaves
-- small round blobs far apart (one noise's blobs run long; two crossing
-- are round), a radius of four to seven blocks. Each holds its width for a
-- reach of thirty to fifty blocks above and below its storey's centre,
-- then closes three blocks of radius to ten of height, so it narrows away
-- rather than ending on a floor. THE ADITS: low passages along a noise's
-- zero contours at the storey's centre, three wide and four high, which
-- run from shaft to shaft and are the way in. THE GROOVES: the shaft's
-- wall let back half a block where a noise drawn out in y is high, so
-- they run the height of it. THE LEDGES: rock left inside the wall's
-- first block, a block thick, at the zero crossings of a noise in y alone
-- and only where a small patch noise allows, so they are few and short.
--
-- Materials: `dark_basalt`, striated with `granite` (the iron-granite) in
-- vertical bands; the tendrils `calcite`. No new block.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "silent_vertical_shafts"
local FLAT = tdw.caves.DEEP_FLAT
local ALONG_Y = { x = 1000, z = 1000 }               -- varies in y alone
local UPRIGHT = { y = 1000 }                           -- varies in x and z only, over a shaft's height
local function k_of(freq) return 0.625 / freq end

local STOREYS = { 4.45, 5.25 }                         -- km under the dome
local STOREY_WANDER, WANDER_FREQ = 0.03, 1 / 3000
local SHAFT_FREQ, SHAFT_MIN, SHAFT_K = 1 / 55, 0.18, 28.0   -- radius to about seven at the heart of a blob
local REACH_FREQ, REACH_LO, REACH_SPAN = 1 / 80, 30.0, 20.0
local CLOSE = 0.3                                      -- radius lost a block past the reach
local ADIT_FREQ, ADIT_W, ADIT_H, ADIT_NEAR = 1 / 90, 1.5, 2.0, 30.0
local GROOVE_FREQ, GROOVE_MIN, GROOVE_D = 1 / 2.2, 0.18, 0.6
local STRIA_FREQ, STRIA_MIN = 1 / 3, 0.10
local LEDGE_FREQ, LEDGE_W, LEDGE_PATCH_FREQ, LEDGE_PATCH_MIN = 1 / 14, 0.5, 1 / 5, 0.22
local TENDRIL_CELL, TENDRIL_SQUARES = 6, 0.08

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "shaft_template:" .. name)
end
-- A mineral tendril: one wire of pale calcite a block to three long,
-- hanging dead straight down.
local function tendril(rng)
    schem.record_begin()
    local len = 1.0 + rng:below(5) * 0.5
    schem.push_path(blocks.calcite, { { 0.5, 0.98, 0.5, 0.14 }, { 0.5, 0.98 - len, 0.5, 0.14 } }, BLIND)
    return schem.record_schematic({})
end
local BUILT = nil
local function structures()
    if BUILT then return BUILT end
    BUILT = { tendrils = {} }
    if game.schematic_shapes then
        for i = 1, 5 do BUILT.tendrils[i] = tendril(rng_for("tendril:" .. i)) end
    end
    return BUILT
end

-- ------------------------------------------------------------ the fields

local function centre(k)
    return n.add(n.noise("svs_storey" .. k, WANDER_FREQ, 1, 2.0 * STOREY_WANDER, FLAT), n.const(STOREYS[k]))
end

tdw.cave_biome(ID, { -1, -0.2 }, function(ctx)
    local caves = ctx.caves
    local function step(f, k) return n.clamp(n.mul(f, n.const(k)), 0.0, 1.0) end
    local function up(k)
        return n.mul(n.sub(centre(k), caves.D()), n.const(1000.0))
    end
    -- The shafts' plan: blocks in from a shaft's wall, both blob fields over the cut.
    local plan = n.mul(n.min(n.sub(n.noise("svs_shaft_a", SHAFT_FREQ, 1, 1.0, FLAT), n.const(SHAFT_MIN)),
        n.sub(n.noise("svs_shaft_b", SHAFT_FREQ, 1, 1.0, FLAT), n.const(SHAFT_MIN))), n.const(SHAFT_K))
    local reach = n.add(n.mul(step(n.add(n.mul(n.noise("svs_reach", REACH_FREQ, 1, 1.0, FLAT), n.const(3.0)), n.const(0.5)), 1.0), n.const(REACH_SPAN)),
        n.const(REACH_LO))
    -- The grooves: the wall let back GROOVE_D where an upright noise is high.
    local groove = n.mul(step(n.sub(n.noise("svs_groove", GROOVE_FREQ, 1, 1.0, UPRIGHT), n.const(GROOVE_MIN)), 8.0), n.const(GROOVE_D))
    local adit_line = n.sub(n.const(ADIT_W), n.contour("svs_adit", ADIT_FREQ, 1))
    local ledge_level = n.sub(n.const(LEDGE_W), n.mul(n.abs(n.noise("svs_ledge", LEDGE_FREQ, 1, 1.0, ALONG_Y)), n.const(k_of(LEDGE_FREQ))))
    local ledge_patch = n.mul(n.sub(n.noise("svs_ledge_patch", LEDGE_PATCH_FREQ, 1, 1.0), n.const(LEDGE_PATCH_MIN)), n.const(10.0))
    local function storey(k)
        local u = up(k)
        local open = n.sub(n.add(plan, groove), n.mul(n.max(n.sub(n.abs(u), reach), n.const(0.0)), n.const(CLOSE)))
        -- A ledge: the first block inside the wall, at a level, in a patch.
        local ledge = n.min(n.min(n.sub(n.const(1.0), plan), ledge_level), ledge_patch)
        local shaft = n.min(open, n.mul(ledge, n.const(-1.0)))
        local adit = n.min(n.min(adit_line, n.sub(n.const(ADIT_H), n.abs(n.sub(u, n.const(ADIT_H))))), n.add(plan, n.const(ADIT_NEAR)))
        return n.max(shaft, adit)
    end
    local v = nil
    for k = 1, #STOREYS do
        v = v and n.max(v, storey(k)) or storey(k)
    end
    local void = ctx.mine(v)
    local carve = ctx.compile("carve", void)
    -- 1 basalt; 2 a striation of iron-granite (upright bands).
    local code = n.max(n.const(1.0), n.mul(step(n.sub(n.noise("svs_stria", STRIA_FREQ, 1, 1.0, UPRIGHT), n.const(STRIA_MIN)), 1e4), n.const(2.0)))
    local fills = {
        { layers = true, depth = ctx.compile("depth", n.mul(void, n.const(-1.0))), code = ctx.compile("codes", code), entries = {
            { code = 1, to = 3.0, material = blocks.dark_basalt },
            { code = 2, to = 3.0, material = blocks.granite },
        } },
        { carve = carve },
    }
    if game.schematic_shapes then
        local built = structures()
        -- The tendrils hang from a ledge's underside or a shaft's closing
        -- roof: the depth positive in the VOID.
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.tendrils, cell = TENDRIL_CELL, chance = TENDRIL_SQUARES, salt = 551, sink = 0,
            stand = ctx.compile("stand_tendrils", ctx.mine(n.const(1.0))) }
    end
    return fills
end)

-- ------------------------------------------------------------ the dust

-- Motes hanging in the still air round each player the HUD's cave test
-- puts in a shaft: many, tiny, faint, barely moving, long-lived.
local DUST_EVERY = 40
local dust_tick = 0
if game.emit_particles then
    tdw.on_tick(function(dt)
        dust_tick = dust_tick + dt
        if dust_tick < DUST_EVERY or not tdw.online or not tdw.cave_under then
            return
        end
        dust_tick = 0
        for uuid in pairs(tdw.online) do
            local body = game.player_entity(uuid)
            local e = body and game.entity(body)
            local p = e and e.pos
            if p and tdw.cave_under(math.floor(p.x), math.floor(p.y), math.floor(p.z)) == ID then
                game.emit_particles{ pos = { x = p.x, y = p.y + 1.5, z = p.z }, count = 24, size = 0.04, lifetime = 8.0,
                    colour = { r = 0.62, g = 0.60, b = 0.56, a = 0.35 }, velocity = { y = 0.0 }, spread = 0.03, gravity = 0.0,
                    area = { x = 4.0, y = 3.0, z = 4.0 }, collide = false, player = uuid }
            end
        end
    end)
end
