-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.2 Echoing Black Marble (2026-09-26).
--
-- Monumental vaulted halls twenty-five to forty blocks across and sixteen
-- to twenty-six high, joined by tall slit galleries. Pitch-black marble
-- polished glass-smooth, run through with hairlines of white calcite and
-- the odd silver vein. Sterile: no life at all, only brittle clusters of
-- black tourmaline needles along the walls' seams. Obelisk slabs standing
-- upright on the floors; floors stepped in sheer ledges, black on black,
-- so a drop does not show until you are on it; pockets in the walls where
-- a sound goes and comes back.
--
-- THE HALLS: a footprint noise, flat in y, gives each hall's plan and F,
-- the blocks in from its wall. The ceiling rises with F — straight, to a
-- ridge seventeen blocks in — which is a pointed vault: the gothic arch
-- out of nothing but a line. The floor is flat and stepped: a second flat
-- noise past a hard clamp lifts it six blocks in terraces with vertical
-- faces. THE GALLERIES follow a contour line: three wide and fourteen
-- tall, a slit. THE POCKETS are blobs of a fine noise let a few blocks
-- into the rock at mid-height round a hall's edge.
--
-- Materials: **`black_marble`, the one new block**, lining everything six
-- deep; `calcite` for the hairlines and `silver_ore` for the silver veins
-- (thin sheets, laid in the lining at block resolution, so a hairline is a
-- block wide); `obsidian` for the tourmaline. The polish is the marble's
-- own friction, 0.6: walk carefully near the ledges.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "echoing_black_marble"
local FLAT = tdw.caves.DEEP_FLAT                     -- flat in y, all the way to y = 0.5 (caves.lua)

local STOREYS = { 2.10, 2.90, 3.60 }                    -- km under the dome
local STOREY_WANDER, WANDER_FREQ = 0.03, 1 / 3000   -- the halls' floors lie near level
local HALL_FREQ, HALL_MIN, HALL_K = 1 / 70, 0.10, 44.0  -- blocks of F per unit of the noise over its min
local FLOOR = 8.0                                       -- blocks under a storey's centre
local VAULT_SPRING, VAULT_RISE, VAULT_RIDGE = 2.0, 0.8, 17.0   -- the ceiling: spring + rise * min(F, ridge) over the centre
local VAULT_VARY_FREQ, VAULT_VARY = 1 / 40, 5.0
local LEDGE_FREQ, LEDGE_MIN, LEDGE_H = 1 / 28, 0.05, 6.0
local GALLERY_FREQ, GALLERY_W, GALLERY_HH, GALLERY_MID = 1 / 150, 1.6, 7.0, 2.0
local POCKET_FREQ, POCKET_MIN, POCKET_REACH, POCKET_HH, POCKET_MID = 1 / 9, 0.28, 5.0, 3.0, 4.0
local LINING = 6.0
local VEIN_FREQ, VEIN_W, VEIN_ZONE_FREQ, VEIN_ZONE_MIN = 1 / 20, 0.45, 1 / 50, -0.05
local SILVER_FREQ, SILVER_W, SILVER_ZONE_MIN = 1 / 26, 0.35, 0.22
local OBELISK_CELL, OBELISK_SQUARES, OBELISK_IN = 14, 0.35, 5.0
local NEEDLE_CELL, NEEDLE_SQUARES, NEEDLE_REACH = 5, 0.30, 4.0

-- ------------------------------------------------------------ the structures

local FULL = game.OCCUPANCY_FULL
local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "black_marble_template:" .. name)
end
-- An obelisk: a slab of marble a block thick, one or two wide, six to nine
-- tall, standing on the floor like a monolith. Its face along x or z.
local function obelisk(rng)
    schem.record_begin()
    local wide = 1 + rng:below(2)
    local tall = 6 + rng:below(4)
    local along_x = rng:below(2) == 0
    for w = 0, wide - 1 do
        for h = 1, tall do
            if along_x then
                schem.push_cells(blocks.black_marble, w, h, 0, FULL)
            else
                schem.push_cells(blocks.black_marble, 0, h, w, FULL)
            end
        end
    end
    return schem.record_schematic({})
end
-- Tourmaline: four to seven needles of black glass, half a block to a
-- block long, sprouting from one point at steep angles like iron filings.
local function needles(rng)
    schem.record_begin()
    for _ = 1, 4 + rng:below(4) do
        local d = schem.DIR16[rng:below(16) + 1]
        local lean = 0.2 + rng:below(4) * 0.12
        local len = 0.5 + rng:below(4) * 0.18
        schem.push_path(blocks.obsidian, { { 0.5, 1.05, 0.5, 0.11 },
            { 0.5 + d[1] * lean * len, 1.05 + len, 0.5 + d[2] * lean * len, 0.06 } }, BLIND)
    end
    return schem.record_schematic({})
end
local BUILT = nil
local function structures()
    if BUILT then return BUILT end
    BUILT = { obelisks = {}, needles = {} }
    if game.schematic_shapes then
        for i = 1, 6 do BUILT.obelisks[i] = obelisk(rng_for("obelisk:" .. i)) end
        for i = 1, 5 do BUILT.needles[i] = needles(rng_for("needles:" .. i)) end
    end
    return BUILT
end

-- ------------------------------------------------------------ the fields

local function centre(k)
    return n.add(n.noise("ebm_storey" .. k, WANDER_FREQ, 1, 2.0 * STOREY_WANDER, FLAT), n.const(STOREYS[k]))
end

tdw.cave_biome(ID, { -0.15, 0.15 }, function(ctx)
    local caves = ctx.caves
    -- Blocks above a storey's centre: the depth FIRST.
    local function up(k)
        return n.mul(n.sub(centre(k), caves.D()), n.const(1000.0))
    end
    -- F: blocks in from a hall's wall (negative in the rock outside it).
    local function footprint(k)
        return n.mul(n.sub(n.noise("ebm_hall" .. k, HALL_FREQ, 2, 1.0, FLAT), n.const(HALL_MIN)), n.const(HALL_K))
    end
    local function ledge()
        return n.mul(n.clamp(n.mul(n.sub(n.noise("ebm_ledge", LEDGE_FREQ, 1, 1.0, FLAT), n.const(LEDGE_MIN)), n.const(12.0)), 0.0, 1.0),
            n.const(LEDGE_H))
    end
    -- One storey: the hall under its vault, a gallery, and the pockets.
    local function storey(k)
        local u = up(k)
        local f = footprint(k)
        local over_floor = n.sub(n.add(u, n.const(FLOOR)), ledge())
        local vault = n.add(n.add(n.mul(n.clamp(footprint(k), 0.0, VAULT_RIDGE), n.const(VAULT_RISE)), n.const(VAULT_SPRING)),
            n.noise("ebm_vault", VAULT_VARY_FREQ, 1, VAULT_VARY, FLAT))
        local hall = n.min(n.min(over_floor, n.sub(vault, up(k))), f)
        local gallery = n.min(n.sub(n.const(GALLERY_W), n.contour("ebm_gallery", GALLERY_FREQ, 2)),
            n.sub(n.const(GALLERY_HH), n.abs(n.sub(up(k), n.const(GALLERY_MID)))))
        local pocket = n.min(n.min(n.mul(n.sub(n.noise("ebm_pocket", POCKET_FREQ, 1, 1.0), n.const(POCKET_MIN)), n.const(6.0)),
            n.add(footprint(k), n.const(POCKET_REACH))), n.sub(n.const(POCKET_HH), n.abs(n.sub(up(k), n.const(POCKET_MID)))))
        return n.max(n.max(hall, gallery), pocket)
    end
    local v = nil
    for k = 1, #STOREYS do
        v = v and n.max(v, storey(k)) or storey(k)
    end
    local void = ctx.mine(v)
    local carve = ctx.compile("carve", void)
    local function step(f) return n.clamp(n.mul(f, n.const(1e4)), 0.0, 1.0) end
    -- A thin sheet: within `w` blocks of a stretched noise's zero crossing,
    -- in the zones a slow noise gives it.
    local function sheet(stream, freq, w, zone_min)
        local s = n.sub(n.const(w), n.mul(n.abs(n.noise(stream, freq, 1, 1.0, { x = 3, z = 3 })), n.const(0.625 / freq)))
        return n.min(s, n.mul(n.sub(n.noise(stream .. "_zone", VEIN_ZONE_FREQ, 1, 1.0), n.const(zone_min)), n.const(20.0)))
    end
    local conditions = {
        n.const(1.0),                                                   -- 1 marble
        sheet("ebm_vein", VEIN_FREQ, VEIN_W, VEIN_ZONE_MIN),            -- 2 calcite hairlines
        sheet("ebm_silver", SILVER_FREQ, SILVER_W, SILVER_ZONE_MIN),    -- 3 silver veins
    }
    local code = n.const(0.0)
    for k, c in ipairs(conditions) do
        code = n.max(code, n.mul(step(c), n.const(k)))
    end
    local depth = ctx.compile("depth", n.mul(void, n.const(-1.0)))
    local fills = {
        { layers = true, depth = depth, code = ctx.compile("codes", code), entries = {
            { code = 1, to = LINING, material = blocks.black_marble },
            { code = 2, to = LINING, material = blocks.calcite },
            { code = 3, to = LINING, material = blocks.silver_ore },
        } },
        { carve = carve },
    }
    if game.schematic_shapes then
        local built = structures()
        -- The obelisks well out on a hall's floor; the needles along its
        -- foot, where the floor meets the wall.
        local f_any = nil
        for k = 1, #STOREYS do
            f_any = f_any and n.max(f_any, footprint(k)) or footprint(k)
        end
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.obelisks, cell = OBELISK_CELL, chance = OBELISK_SQUARES, salt = 481, sink = 1,
            stand = ctx.compile("stand_obelisks", ctx.mine(n.sub(f_any, n.const(OBELISK_IN)))) }
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.needles, cell = NEEDLE_CELL, chance = NEEDLE_SQUARES, salt = 482, sink = 1,
            stand = ctx.compile("stand_needles", ctx.mine(n.sub(n.const(NEEDLE_REACH), f_any))) }
    end
    return fills
end)
