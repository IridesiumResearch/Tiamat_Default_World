-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 2.3 Volcanic Foothills: the Ember Ridge, the only surface sign of the
-- magma shell.
--
-- The brief (2026-09-15):
--
--   Topography: steep, stepped basalt terraces and jagged cinder cones
--   flanked by inclined stone aprons. Low undulating foothills rising into
--   sharp ridges broken by solidified lava levees and deep gouges.
--   Surface: dark basalt, porous dark lava rock*, drifts of fine slate-grey
--   volcanic ash*, scattered pumice* pebbles, bright orange-yellow sulfur*
--   crusts ringing thermal fissures.
--   Trees: very sparse to patchy; none on fresh lava lobes; clustering in
--   sheltered ash pockets and weathered foothill hollows. Charred snags
--   (of charcoal*) and hardy fire-scarred pines.
--   Erosion: loose ash and cinders in unstable scree slopes; rain-carved
--   ash gullies through soft tuff; thermal fissures venting steam rather
--   than pooling water.
--   Accents: columnar basalt clusters, hollow lava-tube blisters under thin
--   crusts, smouldering fumaroles with magma in them, jagged lava boulders
--   in the ash flats.
--
-- WHERE: the Ember Ridge, both halves (20.7 to 24.8 km), taken from the
-- grassland, which stood in for it. Its terms are added to the temperate
-- pair's in the "ember" terrain mode (shape.lua), weighted in across the
-- ring's inner edge and OUT again over its outer third: the Glass Waste's
-- own programs begin at the ring's outer edge and could not carry these
-- terms beside the mesa's, so the ridges stand on the inner side and the
-- outer third is the foothills, which is the brief's shape read from the
-- temperate ring outward. The sea lanes keep off the ring.
--
-- Stand-ins until named: volcanic ash is the badlands' node (already
-- named there), the charred snags are the badlands' charcoal, the pines'
-- needles the fir's. New: lava rock, pumice, sulfur.

local blocks = tdw.blocks
local shape = tdw.shape
local n = shape.node
local schem = tdw.schem

local ID = "volcanic_foothills"

-- The ground, km. Thresholds against the measured noise: one octave over
-- 0.35 on 22% of the ground, at the +0.5 clamp on 13%; two over 0.3 on 18%.
local UNDULATE_FREQ, UNDULATE_AMP = 1 / 260, 0.006        -- the foothills: three blocks either way
local RIDGE_FREQ, RIDGE_W, RIDGE_H = 1 / 420, 22.0, 0.042 -- the ridges: tents forty-two blocks over, twenty-two either side of a contour
local TERRACE_STEP, TERRACE_K = 0.007, 260.0              -- the ridges climb in steps seven blocks tall, each a couple of blocks wide
local CONE_FREQ, CONE_MIN, CONE_EDGE, CONE_H = 1 / 700, 0.30, 4.0, 0.055   -- cinder cones: two noises both high, fifty-five blocks, a crater in the top
local APRON_EDGE, APRON_H = 1.2, 0.012                    -- the same blobs at a softer edge: the inclined aprons round the cones
local LEVEE_FREQ, LEVEE_W, LEVEE_H = 1 / 230, 5.0, 0.004  -- lava levees: low ridges along a contour, in stretches
local LEVEE_SEG_FREQ, LEVEE_SEG_MIN = 1 / 300, 0.05
local GOUGE_FREQ, GOUGE_W, GOUGE_D = 1 / 380, 5.0, 0.016  -- the gouges: sixteen deep, in stretches
local GOUGE_SEG_FREQ, GOUGE_SEG_MIN = 1 / 450, 0.12
local GULLY_FREQ, GULLY_W, GULLY_D = 1 / 60, 2.5, 0.004   -- rain-carved ash gullies through the tuff
local TUFF_FREQ, TUFF_MIN = 1 / 150, 0.05
local FISSURE_FREQ, FISSURE_W, FISSURE_D = 1 / 210, 0.9, 0.006   -- thermal fissures: a block wide, six deep, in stretches
local FISSURE_SEG_FREQ, FISSURE_SEG_MIN = 1 / 260, 0.18
-- The surface.
local LOBE_FREQ, LOBE_MIN = 1 / 90, 0.28                 -- fresh lava lobes: nothing grows
local ASH_FREQ, ASH_MIN = 1 / 45, 0.08                   -- ash drifts
local PUMICE_FREQ, PUMICE_MIN = 1.4, 0.34                -- pumice pebbles in the ash
local SULFUR_RING = 4.0                                  -- blocks either side of a live fissure
local SCREE_LO, SCREE_HI = 0.25, 0.7                     -- the cone weight band that is scree: the flanks
-- The structures: cell, share of squares, salt.
local COLUMNS_CELL, COLUMNS_SQUARES = 24, 0.3
local BLISTER_CELL, BLISTER_SQUARES = 40, 0.25
local FUMAROLE_CELL, FUMAROLE_SQUARES = 30, 0.35
local BOULDER_CELL, BOULDER_SQUARES = 12, 0.3
local SNAG_CELL, SNAG_SQUARES = 14, 0.25
local PINE_CELL, PINE_SQUARES = 10, 0.35
local HOLLOW = -0.0025                                   -- km: a foothill hollow is the undulation under this

-- ------------------------------------------------------------ the ground

local function seg(stream, freq, min, edge)
    return n.clamp(n.mul(n.sub(n.noise(stream, freq, 1, 1.0), n.const(min)), n.const(edge)), 0.0, 1.0)
end
local function both(stream, freq, min, edge)
    return n.clamp(n.mul(n.min(n.sub(n.noise(stream, freq, 2, 1.0), n.const(min)),
        n.sub(n.noise(stream .. "_b", freq, 2, 1.0), n.const(min))), n.const(edge)), 0.0, 1.0)
end
-- A tent along a contour: 1 on the line, 0 `w` blocks out.
local function tent(stream, freq, w)
    return n.clamp(n.add(n.mul(n.contour(stream, freq, 2), n.const(-1.0 / w)), n.const(1.0)), 0.0, 1.0)
end
local function cut(stream, freq, w, steep)
    return n.clamp(n.mul(n.add(n.contour(stream, freq, 2), n.const(-w)), n.const(-steep)), 0.0, 1.0)
end
local function undulate()
    return n.noise("vf_undulate", UNDULATE_FREQ, 2, UNDULATE_AMP)
end
local function cone_w()
    return both("vf_cone", CONE_FREQ, CONE_MIN, CONE_EDGE)
end
local function lobe_w()
    return seg("vf_lobe", LOBE_FREQ, LOBE_MIN, 6.0)
end
local function fissure_live()
    return seg("vf_fissure_seg", FISSURE_SEG_FREQ, FISSURE_SEG_MIN, 8.0)
end
local function fissure_d()
    return n.contour("vf_fissure", FISSURE_FREQ, 2)
end
-- The ridges' height, terraced: the tent's height climbed in TERRACE_STEP
-- steps, each a hard clamp, so the flanks are stepped basalt.
local function ridges()
    local acc = nil
    local steps = math.floor(RIDGE_H / TERRACE_STEP)
    for k = 1, steps do
        local at = (k - 0.5) / steps
        local step = n.mul(n.clamp(n.mul(n.sub(tent("vf_ridge", RIDGE_FREQ, RIDGE_W), n.const(at)), n.const(TERRACE_K)), 0.0, 1.0),
            n.const(TERRACE_STEP))
        acc = acc and n.add(acc, step) or step
    end
    return acc
end

-- The Volcanic Foothills' terms of the terrain, km, added to the depth.
function shape.volcanic_terms()
    local acc = n.add(undulate(), ridges())
    -- The cones: `H * w * (1.2 - w)` peaks short of the middle and dips
    -- back into a crater; the apron round each on a softer gate.
    local w = cone_w()
    acc = n.add(acc, n.mul(n.mul(w, n.add(n.mul(cone_w(), n.const(-1.0)), n.const(1.2))), n.const(CONE_H)))
    acc = n.add(acc, n.mul(both("vf_cone", CONE_FREQ, CONE_MIN - 0.12, APRON_EDGE), n.const(APRON_H)))
    -- Levees along a contour, in stretches.
    acc = n.add(acc, n.mul(n.mul(tent("vf_levee", LEVEE_FREQ, LEVEE_W), seg("vf_levee_seg", LEVEE_SEG_FREQ, LEVEE_SEG_MIN, 6.0)), n.const(LEVEE_H)))
    -- The gouges, the gullies through the tuff, the fissures.
    acc = n.sub(acc, n.mul(n.mul(cut("vf_gouge", GOUGE_FREQ, GOUGE_W, 0.5), seg("vf_gouge_seg", GOUGE_SEG_FREQ, GOUGE_SEG_MIN, 6.0)), n.const(GOUGE_D)))
    acc = n.sub(acc, n.mul(n.mul(cut("vf_gully", GULLY_FREQ, GULLY_W, 1.0), seg("vf_tuff", TUFF_FREQ, TUFF_MIN, 5.0)), n.const(GULLY_D)))
    return n.sub(acc, n.mul(n.mul(n.clamp(n.mul(n.add(fissure_d(), n.const(-FISSURE_W)), n.const(-2.0)), 0.0, 1.0), fissure_live()), n.const(FISSURE_D)))
end

tdw.biomes[ID].ring_mode = "ember"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.dark_basalt

-- Whether (x, z) is the Ember Ridge's, by its placement field, cached by
-- eight-block square as the cold biomes' tests are: the HUD asks, because
-- the ridge's basalt is the coast's material too.
local FIELD = nil
local cache, cached = {}, 0
function tdw.volcanic_at(x, z)
    local only = tdw.config.everywhere
    if only then
        return only == ID
    end
    local u = (x * x + z * z) * 1e-6 / (shape.R_DISC * shape.R_DISC)
    if u < shape.EMBER_U[1] - shape.RING_WOBBLE or u > shape.EMBER_U[2] + shape.RING_WOBBLE then
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
        FIELD = FIELD or shape.compile("volcanic.at", tdw.biome_mask(n, ID))
        local y = shape.Y0 + 1000 * shape.dome_at(u)
        hit = FIELD:at(x + 0.5, y + 0.5, z + 0.5, seed) > 0
        cache[key] = hit
        cached = cached + 1
    end
    return hit
end

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local ROUGH = { rough = 0.35, blind = true }

-- A cluster of basalt columns: five to twelve, packed on a hexagon-ish
-- footprint, each a block across and three to nine tall, the tallest in
-- the middle.
local function columns(rng)
    schem.record_begin()
    local count = 5 + rng:below(8)
    local ring = { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 } }
    for i = 1, count do
        local at = ring[i]
        local far = math.abs(at[1]) + math.abs(at[2])
        local tall = 3 + rng:below(4) + math.max(0, 3 - far) * 2
        local x, z = at[1] + 0.5, at[2] + 0.5
        schem.push_path(blocks.dark_basalt, { { x, -2.0, z, 0.5 }, { x, tall, z, 0.5 } }, BLIND)
    end
    return schem.record_schematic({})
end

-- A lava-tube blister: a hollow under a thin crust of the ground, three
-- to five blocks across and a couple deep, its top a block under the
-- surface, with a floor of lava rock.
local function blister(rng)
    schem.record_begin()
    local rx, rz = 3.0 + rng:below(5) * 0.5, 3.0 + rng:below(5) * 0.5
    local ry = 1.6 + rng:below(4) * 0.25
    schem.push_ellipsoid(blocks.lava_rock, 0.5, -ry - 1.6, 0.5, rx + 0.6, ry + 0.6, rz + 0.6, ROUGH)
    schem.push_ellipsoid(game.AIR, 0.5, -ry - 1.4, 0.5, rx, ry, rz, { rough = 0.25, blind = true })
    return schem.record_schematic({ [game.AIR] = 1 })
end

-- A fumarole: a low cone of basalt with a throat of magma, sulfur crusted
-- round its foot.
local function fumarole(rng)
    schem.record_begin()
    local r = 1.4 + rng:below(3) * 0.3
    schem.push_ellipsoid(blocks.sulfur, 0.5, 0.15, 0.5, r + 1.8, 0.45, r + 1.8, { rough = 0.4, blind = true })
    schem.push_ellipsoid(blocks.dark_basalt, 0.5, 0.6, 0.5, r, r * 1.1, r, ROUGH)
    schem.push_path(blocks.magma, { { 0.5, 0.3, 0.5, 0.45 }, { 0.5, r * 1.1 + 0.9, 0.5, 0.35 } }, BLIND)
    return schem.record_schematic({ [blocks.magma] = 2, [blocks.dark_basalt] = 1 })
end

-- A jagged lava boulder, half sunk in the ash.
local function boulder(rng)
    schem.record_begin()
    local r = 1.0 + rng:below(5) * 0.3
    schem.push_ellipsoid(blocks.lava_rock, 0.5, r * 0.25, 0.5, r * (0.8 + rng:below(3) * 0.15), r * 0.8, r * (0.8 + rng:below(3) * 0.15),
        { rough = 0.5, blind = true })
    if rng:below(2) == 0 then
        local d = schem.DIR16[rng:below(16) + 1]
        schem.push_ellipsoid(blocks.lava_rock, 0.5 + d[1] * r, r * 0.2, 0.5 + d[2] * r, r * 0.55, r * 0.5, r * 0.55, { rough = 0.5, blind = true })
    end
    return schem.record_schematic({})
end

-- A charred snag: a trunk of charcoal three to seven tall, split and
-- leaning, a stub or two.
local function snag(rng)
    schem.record_begin()
    local tall = 3 + rng:below(5)
    local lean = schem.DIR16[rng:below(16) + 1]
    local trunk = { { 0.5, -1.0, 0.5, 0.42 }, { 0.5 + lean[1] * 0.3, tall * 0.6, 0.5 + lean[2] * 0.3, 0.3 },
        { 0.5 + lean[1] * 0.6, tall, 0.5 + lean[2] * 0.6, 0.18 } }
    schem.push_path(blocks.charcoal, trunk, BLIND)
    for _ = 1, rng:below(3) do
        local px, py, pz = schem.path_point(trunk, tall * (0.4 + rng:below(4) * 0.12))
        local d = schem.DIR16[rng:below(16) + 1]
        schem.push_path(blocks.charcoal, { { px, py, pz, 0.18 }, { px + d[1] * 1.4, py + 0.7, pz + d[2] * 1.4, 0.1 } }, BLIND)
    end
    return schem.record_schematic({ [blocks.charcoal] = 1 })
end

-- A fire-scarred pine: charcoal for the lower third of the trunk, fir
-- above, sparse pads of needles on the side away from the scar.
local function pine(rng)
    schem.record_begin()
    local tall = 6 + rng:below(6)
    local lean = schem.DIR16[rng:below(16) + 1]
    local scar = tall * (0.25 + rng:below(3) * 0.08)
    schem.push_path(blocks.charcoal, { { 0.5, -1.0, 0.5, 0.45 }, { 0.5, scar, 0.5, 0.36 } }, BLIND)
    local trunk = { { 0.5, scar - 0.2, 0.5, 0.36 }, { 0.5 + lean[1] * 0.4, tall * 0.7, 0.5 + lean[2] * 0.4, 0.28 },
        { 0.5 + lean[1] * 0.7, tall, 0.5 + lean[2] * 0.7, 0.15 } }
    schem.push_path(blocks.fir_log, trunk, BLIND)
    local away = (rng:below(16) + 8) % 16
    for i = 1, 2 + rng:below(3) do
        local px, py, pz = schem.path_point(trunk, scar + (tall - scar) * i / 4)
        local d = schem.DIR16[(away + (rng:below(5) - 2)) % 16 + 1]
        local reach = 1.0 + rng:below(3) * 0.4
        schem.push_path(blocks.fir_log, { { px, py, pz, 0.18 }, { px + d[1] * reach, py + 0.2, pz + d[2] * reach, 0.12 } }, BLIND)
        schem.push_ellipsoid(blocks.fir_needles, px + d[1] * reach, py + 0.5, pz + d[2] * reach, 1.1, 0.5, 1.1, { rough = 0.45, blind = true })
    end
    local top = trunk[3]
    schem.push_ellipsoid(blocks.fir_needles, top[1], top[2] + 0.5, top[3], 0.9, 0.9, 0.9, { rough = 0.45, blind = true })
    return schem.record_schematic({ [blocks.fir_log] = 1, [blocks.charcoal] = 1 })
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { columns = {}, blisters = {}, fumaroles = {}, boulders = {}, snags = {}, pines = {} }
    if not game.schematic_shapes then
        BUILT = out
        return out
    end
    local function rng_for(name)
        return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "volcanic_template:" .. name)
    end
    for i = 1, 5 do out.columns[i] = columns(rng_for("columns:" .. i)) end
    for i = 1, 4 do out.blisters[i] = blister(rng_for("blister:" .. i)) end
    for i = 1, 4 do out.fumaroles[i] = fumarole(rng_for("fumarole:" .. i)) end
    for i = 1, 6 do out.boulders[i] = boulder(rng_for("boulder:" .. i)) end
    for i = 1, 5 do out.snags[i] = snag(rng_for("snag:" .. i)) end
    for i = 1, 6 do out.pines[i] = pine(rng_for("pine:" .. i)) end
    local parts = {}
    for _, key in ipairs({ "columns", "blisters", "fumaroles", "boulders", "snags", "pines" }) do
        local total = 0
        for _, one in ipairs(out[key]) do total = total + one:len() end
        parts[#parts + 1] = string.format("%d %s (%d blocks)", #out[key], key, total)
    end
    game.log("tiamot_default_world volcanic foothills: cut " .. table.concat(parts, ", "))
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
    local function ash()
        return n.sub(n.noise("vf_ash", ASH_FREQ, 2, 1.0), n.const(ASH_MIN))
    end
    local conditions = {
        -- 1: dark basalt, everywhere.
        n.const(1.0),
        -- 2: ash drifts, and the gully floors.
        n.max(ash(), n.sub(cut("vf_gully", GULLY_FREQ, GULLY_W, 1.0), n.const(0.5))),
        -- 3: pumice pebbles in the ash.
        n.min(ash(), n.sub(n.noise("vf_pumice", PUMICE_FREQ, 1, 1.0), n.const(PUMICE_MIN))),
        -- 4: a cone's flanks: scree of ash and cinders.
        n.min(n.sub(cone_w(), n.const(SCREE_LO)), n.sub(n.const(SCREE_HI), cone_w())),
        -- 5: a fresh lava lobe: porous lava rock.
        n.sub(lobe_w(), n.const(0.5)),
        -- 6: sulfur crust ringing a live fissure.
        n.min(n.add(n.mul(fissure_d(), n.const(-1.0)), n.const(SULFUR_RING)), n.sub(fissure_live(), n.const(0.4))),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    local mask = tdw.biome_mask(n, ID)
    if mask then
        code = n.mul(code, step(mask))
    end
    local depth = shape.compile("biome.volcanic.depth", shape.terrain(false))
    local codes = shape.compile("biome.volcanic.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 6 * km, material = blocks.dark_basalt },
        { code = 2, to = 2 * km, material = blocks.volcanic_ash },
        { code = 2, from = 2 * km, to = 6 * km, material = blocks.dark_basalt },
        { code = 3, to = 1 * km, material = blocks.pumice },
        { code = 3, from = 1 * km, to = 3 * km, material = blocks.volcanic_ash },
        { code = 3, from = 3 * km, to = 6 * km, material = blocks.dark_basalt },
        { code = 4, to = 2 * km, material = blocks.volcanic_ash },
        { code = 4, from = 2 * km, to = 6 * km, material = blocks.lava_rock },
        { code = 5, to = 4 * km, material = blocks.lava_rock },
        { code = 5, from = 4 * km, to = 6 * km, material = blocks.dark_basalt },
        { code = 6, to = 1 * km, material = blocks.sulfur },
        { code = 6, from = 1 * km, to = 6 * km, material = blocks.dark_basalt },
    }
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, sink, above)
            fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance, salt = salt,
                sink = sink, above = above, stand = shape.compile("biome.volcanic.stand_" .. name, masked(field)) }
        end
        local function off_lobes(field)
            return n.min(field, n.sub(n.const(0.2), lobe_w()))
        end
        local function flats()
            return n.min(n.sub(n.const(0.3), cone_w()), n.sub(n.const(0.3), tent("vf_ridge", RIDGE_FREQ, RIDGE_W)))
        end
        scatter("columns", built.columns, n.sub(tent("vf_ridge", RIDGE_FREQ, RIDGE_W), n.const(0.55)), COLUMNS_CELL, COLUMNS_SQUARES, 131, 1, 0.012)
        scatter("blister", built.blisters, flats(), BLISTER_CELL, BLISTER_SQUARES, 132, 0, nil)
        scatter("fumarole", built.fumaroles, flats(), FUMAROLE_CELL, FUMAROLE_SQUARES, 133, 1, 0.005)
        scatter("boulder", built.boulders, n.min(flats(), ash()), BOULDER_CELL, BOULDER_SQUARES, 134, 1, 0.004)
        -- The trees: snags in the ash pockets, pines in the foothill hollows;
        -- neither on a lobe.
        scatter("snag", built.snags, off_lobes(n.min(flats(), n.sub(ash(), n.const(0.15)))), SNAG_CELL, SNAG_SQUARES, 135, 1, 0.008)
        scatter("pine", built.pines, off_lobes(n.min(flats(), n.sub(n.const(HOLLOW), undulate()))), PINE_CELL, PINE_SQUARES, 136, 1, 0.014)
    end
    return fills
end)

-- ------------------------------------------------------------ the steam

-- A thermal fissure vents steam: a random tick on a sulfur block with air
-- over it sends up a puff (engine `game.emit_particles`, 985997a).
if game.emit_particles then
    local FULL = game.OCCUPANCY_FULL
    tdw.on_random_tick(blocks.sulfur, function(x, y, z)
        local above = schem.at(x, y + 1, z)
        if above == nil or above.occupancy == FULL then
            return true
        end
        game.emit_particles{ pos = { x = x + 0.5, y = y + 1.2, z = z + 0.5 }, count = 10, size = 0.6, lifetime = 3.0,
            colour = { r = 0.92, g = 0.92, b = 0.9, a = 0.45 }, velocity = { y = 2.5 }, spread = 0.6, gravity = -0.8,
            area = { x = 0.6, y = 0.2, z = 0.6 }, collide = false }
        return true
    end)
end
