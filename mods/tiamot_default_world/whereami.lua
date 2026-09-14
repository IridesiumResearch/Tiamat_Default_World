-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- Which biome a player is standing in: named on their HUD for a second when
-- they walk into a new one, and reachable by name from chat.
--
-- **The biome is read from the GROUND, not computed.** Which biome a place
-- belongs to is a density field of the radius and the humidity noise, and
-- the seed those need is not in this VM (engine-asks 21): terrain generates
-- in worker VMs now, and nothing on the main thread carries the seed. But
-- every biome lays its own materials, so the ground says whose it is — the
-- same trick that tells two biomes apart at a random tick on a shared grass
-- block.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem

local SAMPLE_EVERY = 10        -- ticks between looks at where a player is
local SHOW_TICKS = 20          -- how long the name stays up: a second at 20 Hz
local SCAN = 8                 -- blocks below the feet the ground is looked for
local SEEK_TRIES = 20          -- steps tried before a search settles for what it found
local SEEK_SKY = 220           -- blocks over the base dome a seeker is dropped from

-- What each biome's ground is made of. The alpine's entries win over the
-- rest: it lays thin dirt in its hollows, and dirt is the grassland's own
-- soil, so a column with granite or snow anywhere in it is the alpine's
-- whatever else is in it.
local ALPINE_GROUND = { blocks.granite, blocks.slate, blocks.permafrost, blocks.snow,
    blocks.ice, blocks.alpine_turf, blocks.alpine_grass, blocks.fir_log, blocks.fir_needles }
-- The river's own, which win for the same reason the alpine's do: a valley
-- is cut through another biome, and its floor is sand and gravel that
-- belong to half the world. A willow or an iris belongs to one river.
local RIVER_GROUND = { blocks.willow_wood, blocks.willow_leaves, blocks.water_iris, blocks.wild_mint }
local OWNER = {
    [blocks.loam] = "temperate_woodlands",
    [blocks.leaf_litter] = "temperate_woodlands",
    [blocks.oak_log] = "temperate_woodlands",
    [blocks.birch_log] = "temperate_woodlands",
    [blocks.dirt] = "rolling_grasslands",
    [blocks.packed_dirt] = "rolling_grasslands",
    [blocks.dead_coral] = "coastal_cliffs",
    [blocks.dark_basalt] = "coastal_cliffs",
    [blocks.coast_turf] = "coastal_cliffs",
    [blocks.barnacles] = "coastal_cliffs",
    [blocks.bone] = "deep_ocean",
    [blocks.clear_ice] = "frozen_wastes",
}
for _, material in ipairs(ALPINE_GROUND) do
    OWNER[material] = "alpine_highlands"
end
for _, material in ipairs(RIVER_GROUND) do
    OWNER[material] = "river_valleys"
end
-- The rainforest's own, which also decide: its tree ferns are oak, which
-- the woodland claims, and the moss under them is the rainforest's and
-- nobody else's. The clays are shared with the river and say nothing.
for _, material in ipairs({ blocks.moss, blocks.black_mud, blocks.ironwood_log, blocks.ironwood_leaves,
    blocks.climbing_ivy, blocks.monstera, blocks.pitcher_plant, blocks.kapok_wood, blocks.kapok_leaves }) do
    OWNER[material] = "dense_rainforest_canopy"
end
-- Whose ground answers at once, wherever in the column it is found.
local DECIDES = { alpine_highlands = true, river_valleys = true, dense_rainforest_canopy = true }

-- Every material in a block, appended to `out`: a surface block is usually
-- cells of two materials and names neither.
local function materials_of(b, out)
    if b == nil or b.occupancy == 0 then
        return
    end
    if b.material ~= nil then
        out[#out + 1] = b.material
        return
    end
    if b.cells then
        for i = 1, 27 do
            local m = b.cells[i]
            if m ~= game.AIR then
                out[#out + 1] = m
            end
        end
    end
end

-- The biome whose ground is under (x, y, z), or nil when the column is
-- unloaded or made of nothing anybody claims.
function tdw.biome_under(x, y, z)
    local owner = tdw.biome_under_ground(x, y, z)
    -- The alpine's snow, ice and permafrost are the Frozen Wastes' too:
    -- which of them a place is, is the placement field's to say.
    if owner == "alpine_highlands" and tdw.frozen_at and tdw.frozen_at(x, z) then
        return "frozen_wastes"
    end
    return owner
end
function tdw.biome_under_ground(x, y, z)
    local first = nil
    for dy = 2, -SCAN, -1 do
        local list = {}
        materials_of(game.get_block{ x = x, y = y + dy, z = z }, list)
        for _, m in ipairs(list) do
            local owner = OWNER[m]
            if owner and DECIDES[owner] then
                return owner
            end
            if owner and first == nil then
                first = owner
            end
        end
    end
    return first
end

-- ----------------------------------------------------------------- the HUD

local shown = {}               -- uuid -> { biome = id, ticks = n }

local function say(uuid, name)
    game.set_hud(uuid, name and { biome = name } or {})
end

local since = 0
tdw.on_tick(function(dt)
    since = since + dt
    for uuid, state in pairs(shown) do
        if state.ticks > 0 then
            state.ticks = state.ticks - dt
            if state.ticks <= 0 then
                say(uuid, nil)
            end
        end
    end
    if since < SAMPLE_EVERY then
        return
    end
    since = 0
    for uuid in pairs(tdw.online) do
        local body = game.player_entity(uuid)
        local entity = body and game.entity(body)
        if entity then
            local here = tdw.biome_under(math.floor(entity.pos.x), math.floor(entity.pos.y), math.floor(entity.pos.z))
            local state = shown[uuid]
            if state == nil then
                state = { biome = nil, ticks = 0 }
                shown[uuid] = state
            end
            -- Only a CHANGE speaks, and unloaded ground says nothing rather
            -- than saying "nowhere": walking over a chunk that has not
            -- arrived must not blank the name and put it back again.
            if here and here ~= state.biome then
                state.biome = here
                state.ticks = SHOW_TICKS
                local biome = tdw.biomes[here]
                say(uuid, biome and biome.name or here)
            end
        end
    end
end)

-- -------------------------------------------------------------- teleporting

-- `/tp` (2026-09-14: "make it so I can teleport to areas on the Spindle").
-- **Where a biome is, is worked out, not searched for.** The world's seed is
-- in this VM now (`game.world_seed`, engine-asks 21), so a biome's own
-- placement field — its rings and its humidity half, the same field its
-- fills are masked by — can be sampled here. The search walks out from the
-- player's own heading round the compass and across the biome's rings, and
-- stops at the first place well inside it; the player is dropped over it
-- and the landing puts them on the ground. A biome that is a line rather
-- than a band (the river) answers `locate` itself.

local SEEK_ABOVE = 220         -- blocks over the base dome a teleport drops from
local MARGIN = 0.01            -- how far inside a biome's field a place must be
local R_BLOCKS = shape.R_DISC * 1000

-- What `/tp` understands: a biome's short name (or its id), a ring's id.
local BIOME_WORDS = {
    alpine = "alpine_highlands", mountains = "alpine_highlands",
    woodlands = "temperate_woodlands", woodland = "temperate_woodlands", forest = "temperate_woodlands",
    grasslands = "rolling_grasslands", grassland = "rolling_grasslands",
    river = "river_valleys", rivers = "river_valleys",
    rainforest = "dense_rainforest_canopy", jungle = "dense_rainforest_canopy",
    coast = "coastal_cliffs", cliffs = "coastal_cliffs",
    ocean = "deep_ocean", sea = "deep_ocean",
    frozen = "frozen_wastes", wastes = "frozen_wastes", tundra = "frozen_wastes", frostmoor = "frozen_wastes",
}
local RING_WORDS = { greensward = "temperate", firwold = "frost" }

local function world_seed()
    return game.world_seed or tdw.seed
end

local function u_at(x, z)
    return (x * x + z * z) * 1e-6 / (shape.R_DISC * shape.R_DISC)
end

-- Sixty-four headings round the compass, as unit vectors: the sixteen and
-- three between each pair, normalised. No trigonometry.
local HEADINGS = {}
for i = 1, 16 do
    local a, b = schem.DIR16[i], schem.DIR16[i % 16 + 1]
    for k = 0, 3 do
        local t = k / 4
        local x, z = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
        local len = math.sqrt(x * x + z * z)
        HEADINGS[#HEADINGS + 1] = { x / len, z / len }
    end
end
-- The headings in the order to try them: the player's own first, then out
-- either side of it.
local function headings_from(px, pz)
    local best, best_dot = 1, -2
    local r = math.sqrt(px * px + pz * pz)
    local hx, hz = 1.0, 0.0
    if r > 1 then
        hx, hz = px / r, pz / r
    end
    for i, d in ipairs(HEADINGS) do
        local dot = d[1] * hx + d[2] * hz
        if dot > best_dot then
            best, best_dot = i, dot
        end
    end
    local out = { HEADINGS[best] }
    for k = 1, 32 do
        out[#out + 1] = HEADINGS[(best - 1 + k) % 64 + 1]
        if k < 32 then
            out[#out + 1] = HEADINGS[(best - 1 - k) % 64 + 1]
        end
    end
    return out
end

-- The biome's placement field, compiled once here.
local FIELDS = {}
local function field_of(id)
    if FIELDS[id] == nil then
        local mask = tdw.biome_mask(shape.node, id)
        FIELDS[id] = mask and shape.compile("tp." .. id, mask) or false
    end
    return FIELDS[id]
end

-- A place well inside biome `id`, starting from (px, pz): x, z, or nil.
local function locate(id, px, pz)
    local biome = tdw.biomes[id]
    local seed = world_seed()
    if biome.locate then
        return biome.locate(px, pz, seed)
    end
    local field = field_of(id)
    if not field then
        return nil
    end
    local lo, hi = tdw.biome_span_u(id)
    local pu = u_at(px, pz)
    local shares = { 0.5, 0.3, 0.7, 0.15, 0.85, 0.05, 0.95 }
    local radii = {}
    if pu > lo and pu < hi then
        radii[1] = math.sqrt(pu) * R_BLOCKS
    end
    for _, f in ipairs(shares) do
        radii[#radii + 1] = math.sqrt(lo + (hi - lo) * f) * R_BLOCKS
    end
    for _, d in ipairs(headings_from(px, pz)) do
        for _, r in ipairs(radii) do
            local x, z = d[1] * r, d[2] * r
            local y = shape.Y0 + 1000 * shape.dome_at(u_at(x, z))
            if field:at(x + 0.5, y + 0.5, z + 0.5, seed) > MARGIN then
                return math.floor(x), math.floor(z)
            end
        end
    end
    return nil
end

-- Drops a player over (x, z) and lets the landing find the ground. The
-- drop is over the highest thing that could be there: the alpine peaks in
-- the cold core, SEEK_ABOVE over the dome elsewhere.
local function drop(uuid, rec, x, z)
    local u = u_at(x, z)
    local above = SEEK_ABOVE
    if u < shape.ALPINE_EDGE_U + shape.ALPINE_BLEND_U then
        above = math.max(above, math.ceil((shape.ALPINE_PEAK or 0.4) * 1000) + 40)
    end
    rec.seeking = nil
    rec.pending = { x = x + 0.5, y = shape.Y0 + 1000.0 * shape.dome_at(u) + above, z = z + 0.5 }
    rec.landing = { ticks = 0 }
end

-- Sends a new player to a biome (tdw.config.spawn_biome). True if there is
-- somewhere to send them.
function tdw.seek_biome(uuid, id, rec)
    if not tdw.biomes[id] or world_seed() == nil then
        return false
    end
    local x, z = locate(id, shape.SPAWN_X, shape.SPAWN_Z)
    if x == nil then
        return false
    end
    drop(uuid, rec, x, z)
    return true
end
-- The landing asks this of a seeker; nobody seeks by trial any more.
function tdw.seek_landed()
    return true
end

local function here_of(uuid)
    local body = game.player_entity(uuid)
    local entity = body and game.entity(body)
    return entity and entity.pos
end

local function distance_text(px, pz, x, z)
    local d = math.sqrt((x - px) * (x - px) + (z - pz) * (z - pz))
    return d >= 1000 and string.format("%.1f km", d / 1000) or string.format("%d blocks", math.floor(d))
end

local TP_USAGE = "/tp <biome | ring | spawn> or /tp <x> <z> or /tp <x> <y> <z> — /tp list for the names"

tdw.on_command("tp", TP_USAGE, function(player, args)
    local rec = tdw.online[player]
    local p = here_of(player)
    if rec == nil or p == nil then
        return "you are not anywhere yet"
    end
    if #args == 0 then
        return TP_USAGE
    end
    local numbers = {}
    for i, a in ipairs(args) do
        numbers[i] = tonumber(a)
    end
    -- Coordinates.
    if #args == 3 and numbers[1] and numbers[2] and numbers[3] then
        rec.seeking, rec.landing = nil, nil
        rec.pending = { x = numbers[1], y = numbers[2], z = numbers[3] }
        return string.format("to %.0f, %.0f, %.0f", numbers[1], numbers[2], numbers[3])
    end
    if #args == 2 and numbers[1] and numbers[2] then
        drop(player, rec, math.floor(numbers[1]), math.floor(numbers[2]))
        return string.format("to %d, %d — landing on the ground there", math.floor(numbers[1]), math.floor(numbers[2]))
    end
    local word = string.lower(args[1])
    if word == "list" then
        local placed, unplaced = {}, {}
        for _, short in ipairs({ "alpine", "frozen", "woodlands", "grasslands", "river", "rainforest", "coast", "ocean" }) do
            local biome = tdw.biomes[BIOME_WORDS[short]]
            if biome then
                local list = (biome.built and biome.placed ~= false) and placed or unplaced
                list[#list + 1] = short
            end
        end
        local rings = {}
        for _, ring in ipairs(tdw.layers.RINGS) do rings[#rings + 1] = ring.id end
        return "biomes: " .. table.concat(placed, ", ") .. " — not placed yet: " .. table.concat(unplaced, ", ")
            .. " — rings: " .. table.concat(rings, ", ") .. " — or spawn, or coordinates"
    end
    if word == "spawn" then
        drop(player, rec, shape.SPAWN_X, shape.SPAWN_Z)
        return "to the spawn"
    end
    -- A ring: its middle, on your own heading.
    local ring = tdw.layers.ring_by_id[RING_WORDS[word] or word]
    if ring then
        local d = headings_from(p.x, p.z)[1]
        local r = math.sqrt((ring.u[1] + ring.u[2]) / 2) * R_BLOCKS
        local x, z = math.floor(d[1] * r), math.floor(d[2] * r)
        drop(player, rec, x, z)
        return string.format("to %s, at %d, %d (%s)", ring.name, x, z, distance_text(p.x, p.z, x, z))
    end
    -- A biome.
    local id = BIOME_WORDS[word] or (tdw.biomes[word] and word)
    local biome = id and tdw.biomes[id]
    if biome == nil then
        return "no biome or ring called `" .. args[1] .. "` — /tp list"
    end
    local only = tdw.config.everywhere
    if only and only ~= id then
        return biome.name .. " is not in this world: the dev switch puts " .. only .. " everywhere"
    end
    if not biome.built then
        return biome.name .. " is not built yet"
    end
    if only == id then
        return biome.name .. " is everywhere in this world — you are in it"
    end
    if biome.placed == false then
        return biome.name .. " is built but not placed in the world; tdw.config.everywhere = \"" .. id .. "\" shows it"
    end
    if world_seed() == nil then
        return "the world's seed is not known yet — try again in a moment"
    end
    local x, z = locate(id, p.x, p.z)
    if x == nil then
        return "found nowhere that is " .. biome.name
    end
    drop(player, rec, x, z)
    game.log(string.format("tiamot_default_world: %s teleported to %s at %d, %d", player, biome.name, x, z))
    return string.format("to %s, at %d, %d (%s)", biome.name, x, z, distance_text(p.x, p.z, x, z))
end)
