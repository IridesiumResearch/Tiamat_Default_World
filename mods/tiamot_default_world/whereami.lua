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
-- (The name stayed up a second and went, until 2026-09-15: "for now at
-- least let's have the biome always displayed on the screen".)
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
OWNER[blocks.glow_cap] = "river_valleys"
-- The rainforest's own, which also decide: its tree ferns are oak, which
-- the woodland claims, and the moss under them is the rainforest's and
-- nobody else's. The clays are shared with the river and say nothing.
for _, material in ipairs({ blocks.moss, blocks.black_mud, blocks.ironwood_log, blocks.ironwood_leaves,
    blocks.climbing_ivy, blocks.monstera, blocks.pitcher_plant, blocks.kapok_wood, blocks.kapok_leaves }) do
    OWNER[material] = "jungle"
end
-- The mesa's own, which decide: its dirt, sand and clay are other biomes'.
for _, material in ipairs({ blocks.rust_red_sandstone, blocks.ochre_sandstone, blocks.pale_terracotta,
    blocks.juniper_wood, blocks.juniper_needles, blocks.columnar_cactus }) do
    OWNER[material] = "arid_mesa"
end
for _, material in ipairs({ blocks.volcanic_ash, blocks.charcoal, blocks.dried_mud, blocks.dead_sagebrush }) do
    OWNER[material] = "badlands"
end
for _, material in ipairs({ blocks.mulch, blocks.rust_grass, blocks.hanging_lichen }) do
    OWNER[material] = "taiga"
end
for _, material in ipairs({ blocks.white_sand, blocks.calcite, blocks.pink_algae, blocks.coral_magenta,
    blocks.coral_cyan, blocks.coral_amber, blocks.sea_anemone }) do
    OWNER[material] = "coral_fringed_shallows"
end
for _, material in ipairs({ blocks.apple_wood, blocks.apple_leaves, blocks.apple_blossom, blocks.cherry_wood,
    blocks.cherry_leaves, blocks.cherry_blossom, blocks.birch_leaves, blocks.allium, blocks.peony,
    blocks.poppy, blocks.bluebell }) do
    OWNER[material] = "flower_forest"
end
for _, material in ipairs({ blocks.lava_rock, blocks.pumice, blocks.lava }) do   -- not the sulfur: the mesa has spots of it
    OWNER[material] = "volcanic_foothills"
end
-- Whose ground answers at once, wherever in the column it is found.
local DECIDES = { alpine_highlands = true, river_valleys = true, jungle = true, arid_mesa = true, badlands = true,
    taiga = true, volcanic_foothills = true, coral_fringed_shallows = true, flower_forest = true }

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
    -- A shore or a sea floor: the sea map says (seas.lua).
    local sea = tdw.seas and tdw.seas.zone(x, z)
    if sea then
        return sea
    end
    -- Firwold's ground is fir, moss and peat, which the alpine and the
    -- rainforest claim, and the Ember Ridge's is the coast's basalt: the
    -- placement fields say first.
    if tdw.taiga_at and tdw.taiga_at(x, z) then
        return "taiga"
    end
    if tdw.volcanic_at and tdw.volcanic_at(x, z) then
        return "volcanic_foothills"
    end
    -- Goldwater's sand is the coast's and the mesa's too.
    if tdw.dunes_at and tdw.dunes_at(x, z) then
        return "dunes"
    end
    local owner = tdw.biome_under_ground(x, y, z)
    -- The alpine's snow, ice and permafrost are the Frozen Wastes' too:
    -- which of them a place is, is the placement field's to say.
    if owner == "alpine_highlands" and tdw.frozen_at and tdw.frozen_at(x, z) then
        return "frozen_wastes"
    end
    -- The Jungle's floor is moss, but its ravines are clay and its hollows
    -- mud, which say nothing: the placement field says.
    if owner == nil and tdw.jungle_at and tdw.jungle_at(x, z) then
        return "jungle"
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

local shown = {}               -- uuid -> { biome = id }

local function say(uuid, name)
    game.set_hud(uuid, name and { biome = name } or {})
end

local since = 0
tdw.on_tick(function(dt)
    since = since + dt
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
                state = { biome = nil }
                shown[uuid] = state
            end
            -- Only a CHANGE speaks, and unloaded ground says nothing rather
            -- than saying "nowhere": walking over a chunk that has not
            -- arrived must not blank the name and put it back again.
            if here and here ~= state.biome then
                state.biome = here
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
local LAND_BACK = 150.0        -- blocks back from a shore a land biome's landing must be
local R_BLOCKS = shape.R_DISC * 1000

-- What `/tp` understands (2026-09-15: "standardized ... /tp frozen wastes
-- if the name of the biome is frozen_wastes.lua"): a biome by its file's
-- name with spaces for the underscores — `/tp frozen wastes`, `/tp arid
-- mesa`, `/tp temperate woodlands` — and nothing else; a ring by its id.
-- Underscores are taken as spaces, and case and extra spaces are ignored.
local function spoken(id)
    return (string.gsub(id, "_", " "))
end
local function heard(words)
    local text = string.lower(table.concat(words, " "))
    text = string.gsub(text, "_", " ")
    text = string.gsub(text, "%s+", " ")
    return (string.match(text, "^%s*(.-)%s*$"))
end
-- The surface biomes, in the catalogue's order.
local function surface_biomes()
    local out = {}
    for _, biome in ipairs(tdw.biome_list) do
        if biome.area == "surface" then
            out[#out + 1] = biome
        end
    end
    return out
end

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
    local pu = u_at(px, pz)
    local shares = { 0.5, 0.3, 0.7, 0.15, 0.85, 0.05, 0.95 }
    -- Span by span, the nearest first, and the whole compass round in each
    -- before the next: the woodlands are the temperate ring's wet half and
    -- the Long Shore's, and the shares of the two together sent a player in
    -- the alpine forty kilometres out; the compass inside the spans still
    -- sent one in the mesa to the Shore on their own heading, past the
    -- temperate ring a quarter-turn round.
    local spans = {}
    for _, span in ipairs(tdw.biome_spans(id)) do
        local lo = tdw.layers.ring_by_id[span[1]].u[1]
        local hi = tdw.layers.ring_by_id[span[2]].u[2]
        spans[#spans + 1] = { lo = lo, hi = hi, away = math.max(lo - pu, pu - hi, 0.0) }
    end
    table.sort(spans, function(a, b) return a.away < b.away end)
    local headings = headings_from(px, pz)
    for _, span in ipairs(spans) do
        local radii = {}
        if pu > span.lo and pu < span.hi then
            radii[1] = math.sqrt(pu) * R_BLOCKS
        end
        for _, f in ipairs(shares) do
            radii[#radii + 1] = math.sqrt(span.lo + (span.hi - span.lo) * f) * R_BLOCKS
        end
        -- Well inside, for a span that has an inside that wide: the Crown
        -- alone (the alpine, since the Taiga took Firwold) is 0.0064 of u
        -- across, and its field never reaches MARGIN.
        local margin = math.min(MARGIN, (span.hi - span.lo) * 0.25)
        for _, d in ipairs(headings) do
            for _, r in ipairs(radii) do
                local x, z = d[1] * r, d[2] * r
                local y = shape.Y0 + 1000 * shape.dome_at(u_at(x, z))
                -- On dry land, well back from any shore (2026-09-15: the
                -- rainforest's field is positive under a sea as well, and
                -- `/tp` put a player on a pool's floor and called it the
                -- rainforest).
                local dry = not tdw.seas or not tdw.seas.on() or tdw.seas.at(x, z, seed) < -LAND_BACK
                if dry and field:at(x + 0.5, y + 0.5, z + 0.5, seed) > margin then
                    return math.floor(x), math.floor(z)
                end
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
    rec.landing = { ticks = 0, target = rec.pending }
end

-- **By trial, when the seed is not here.** An engine older than
-- `game.world_seed` (engine fec84db) — a client built before it runs its
-- own server, and that server's mods never hear the seed — cannot sample a
-- field. It can still look: the player is dropped at the middle of the
-- biome's rings on one heading after another, and each landing reads the
-- ground it came down on (`tdw.biome_under`). A wrong place sends them on
-- to the next heading; the right one ends it. Slower by a landing a try,
-- and it finds a band a fraction of the ring wide within a few.
local TRIAL_HEADINGS = 16
local TRIAL_SHARES = { 0.5, 0.25, 0.75 }

local function trial_places(id, px, pz)
    -- The biome's spans nearest the player first: the woodlands are the
    -- temperate ring's wet half AND the Long Shore's, and the middle of the
    -- two together was forty kilometres out.
    local pu = u_at(px, pz)
    local spans = {}
    for _, span in ipairs(tdw.biome_spans(id)) do
        local lo = tdw.layers.ring_by_id[span[1]].u[1]
        local hi = tdw.layers.ring_by_id[span[2]].u[2]
        spans[#spans + 1] = { lo = lo, hi = hi, away = math.max(lo - pu, pu - hi, 0.0) }
    end
    table.sort(spans, function(a, b) return a.away < b.away end)
    local places = {}
    local headings = headings_from(px, pz)
    for _, span in ipairs(spans) do
        for _, f in ipairs(TRIAL_SHARES) do
            local r = math.sqrt(span.lo + (span.hi - span.lo) * f) * R_BLOCKS
            for k = 1, TRIAL_HEADINGS do
                -- every fourth heading of the 64, nearest the player's first
                local d = headings[(k - 1) * 4 + 1]
                places[#places + 1] = { math.floor(d[1] * r), math.floor(d[2] * r) }
            end
        end
    end
    return places
end

local function trial_begin(uuid, rec, id, px, pz)
    local places = trial_places(id, px, pz)
    if #places == 0 then
        return nil
    end
    drop(uuid, rec, places[1][1], places[1][2])
    rec.seeking = { id = id, places = places, at = 1 }
    return places[1]
end

-- Sends a new player to a biome (tdw.config.spawn_biome). True if there is
-- somewhere to send them.
function tdw.seek_biome(uuid, id, rec)
    if not tdw.biomes[id] then
        return false
    end
    if world_seed() == nil then
        return trial_begin(uuid, rec, id, shape.SPAWN_X, shape.SPAWN_Z) ~= nil
    end
    local x, z = locate(id, shape.SPAWN_X, shape.SPAWN_Z)
    if x == nil then
        return false
    end
    drop(uuid, rec, x, z)
    return true
end

-- The landing asks this of a seeker: true when the search is over (found,
-- or out of places), false when the player has been sent on.
function tdw.seek_landed(uuid, rec, x, y, z)
    local seeking = rec.seeking
    if seeking == nil then
        return true
    end
    local biome = tdw.biomes[seeking.id]
    if tdw.biome_under(x, y, z) == seeking.id then
        rec.seeking = nil
        game.log(string.format("tiamot_default_world: %s found %s by trial at %d, %d (try %d)", uuid, biome.name, x, z, seeking.at))
        return true
    end
    -- The seed may have come since the search began: then aim properly.
    if world_seed() ~= nil then
        local fx, fz = locate(seeking.id, x, z)
        if fx ~= nil then
            drop(uuid, rec, fx, fz)
            return false
        end
    end
    seeking.at = seeking.at + 1
    local place = seeking.places[seeking.at]
    if place == nil then
        rec.seeking = nil
        game.log(string.format("tiamot_default_world: %s did not find %s by trial", uuid, biome.name))
        return true
    end
    drop(uuid, rec, place[1], place[2])
    rec.seeking = seeking
    return false
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

local TP_USAGE = "/tp <biome> (its file's name: /tp frozen wastes) or /tp <ring | spawn> or /tp <x> <z> or /tp <x> <y> <z> — /tp list for the names"

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
    local word = heard(args)
    if word == "list" then
        local placed, unplaced = {}, {}
        for _, biome in ipairs(surface_biomes()) do
            if biome.built then
                local list = biome.placed ~= false and placed or unplaced
                list[#list + 1] = spoken(biome.id)
            end
        end
        local rings = {}
        for _, ring in ipairs(tdw.layers.RINGS) do rings[#rings + 1] = ring.id end
        return "biomes: " .. table.concat(placed, ", ") .. " — built, not placed: " .. table.concat(unplaced, ", ")
            .. " — rings: " .. table.concat(rings, ", ") .. " — or spawn, or coordinates"
    end
    if word == "spawn" then
        drop(player, rec, shape.SPAWN_X, shape.SPAWN_Z)
        return "to the spawn"
    end
    -- A ring: its middle, on your own heading.
    local ring = tdw.layers.ring_by_id[word]
    if ring then
        local d = headings_from(p.x, p.z)[1]
        local r = math.sqrt((ring.u[1] + ring.u[2]) / 2) * R_BLOCKS
        local x, z = math.floor(d[1] * r), math.floor(d[2] * r)
        drop(player, rec, x, z)
        return string.format("to %s, at %d, %d (%s)", ring.name, x, z, distance_text(p.x, p.z, x, z))
    end
    -- A biome.
    local id = nil
    for _, candidate in ipairs(surface_biomes()) do
        if spoken(candidate.id) == word then
            id = candidate.id
        end
    end
    local biome = id and tdw.biomes[id]
    if biome == nil then
        return "no biome or ring called `" .. word .. "` — a biome is its file's name with spaces (/tp frozen wastes); /tp list for them all"
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
        if biome.locate then
            return biome.name .. " is found from the world's seed, and this engine has not told the mod it — rebuild the client (engine fec84db or later)"
        end
        local first = trial_begin(player, rec, id, p.x, p.z)
        if first == nil then
            return "found nowhere that is " .. biome.name
        end
        return string.format("looking for %s by landing, starting at %d, %d (%s) — this engine does not give the mod the world's seed, so each wrong landing moves you on; rebuild the client for a direct jump",
            biome.name, first[1], first[2], distance_text(p.x, p.z, first[1], first[2]))
    end
    local x, z = locate(id, p.x, p.z)
    if x == nil then
        return "found nowhere that is " .. biome.name
    end
    drop(player, rec, x, z)
    game.log(string.format("tiamot_default_world: %s teleported to %s at %d, %d", player, biome.name, x, z))
    return string.format("to %s, at %d, %d (%s)", biome.name, x, z, distance_text(p.x, p.z, x, z))
end)
