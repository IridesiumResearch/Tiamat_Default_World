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

-- -------------------------------------------------------------- the search

-- Where to look for a biome: a radius its spans cover, preferring one no
-- humidity split can take away.
-- Biomes that are lines rather than bands, and are looked for by walking
-- outward on one heading instead of round the ring.
local SWEEP = { river_valleys = true }
local FIND_AT = {
    alpine_highlands = 0.015,      -- u: the cold core, seven kilometres out
    rolling_grasslands = 0.149,    -- the middle of the hot rings, which are all grassland
    temperate_woodlands = 0.067,   -- the temperate ring, at the spawn's own radius
    coastal_cliffs = 0.50,         -- the Long Shore, where it WOULD be if it were placed
    river_valleys = 0.067,         -- the temperate ring: a course crosses every ring, so any will do
    dense_rainforest_canopy = 0.295, -- the middle of the Verdant Belt, thirty-two kilometres out
}

-- Sends a player looking for a biome. Which humidity half a place is in is a
-- noise this VM cannot evaluate, so the search is by trial: drop on one
-- azimuth, land, read the ground, and go round again if it is the wrong
-- biome. Sixteen azimuths, each a different stretch of the same ring.
function tdw.seek_biome(uuid, id, rec)
    local u = FIND_AT[id]
    if u == nil then
        return false
    end
    rec.seeking = rec.seeking or { id = id, tries = 0, heading = nil }
    local seeking = rec.seeking
    local d, r
    if SWEEP[id] then
        -- A river is a LINE, not a band: turning round the same ring lands
        -- between courses more often than not. One heading, stepped outward,
        -- crosses every course there is — they are two and a half
        -- kilometres apart, so a few steps of four hundred metres finds one.
        seeking.heading = seeking.heading or (schem.hash(id:len(), seeking.tries, 7) % 16) + 1
        d = schem.DIR16[seeking.heading]
        r = math.sqrt(u) * shape.R_DISC * 1000 + seeking.tries * 400
    else
        d = schem.DIR16[(seeking.tries % 16) + 1]
        r = math.sqrt(u) * shape.R_DISC * 1000
    end
    rec.pending = {
        x = r * d[1] + 0.5,
        y = shape.Y0 + 1000.0 * shape.dome_at(u) + SEEK_SKY,
        z = r * d[2] + 0.5,
    }
    rec.landing = { ticks = 0 }
    return true
end

-- Called by the landing when a seeker touches ground. Returns whether to
-- keep the landing: false sends them round to the next azimuth.
function tdw.seek_landed(uuid, rec, x, y, z)
    local seeking = rec.seeking
    if seeking == nil then
        return true
    end
    local here = tdw.biome_under(x, y, z)
    if here == seeking.id or seeking.tries >= SEEK_TRIES then
        rec.seeking = nil
        local biome = tdw.biomes[seeking.id]
        game.log(string.format("tiamot_default_world: %s looked for %s and stopped in %s at %d, %d after %d tries",
            uuid, biome and biome.name or seeking.id, tostring(here), x, z, seeking.tries))
        return true
    end
    seeking.tries = seeking.tries + 1
    tdw.seek_biome(uuid, seeking.id, rec)
    return false
end

-- One chat word per placed biome. The dispatcher matches a whole message,
-- so these are words rather than a command with an argument.
for word, id in pairs({
    alpine = "alpine_highlands",
    woodlands = "temperate_woodlands",
    grasslands = "rolling_grasslands",
    coast = "coastal_cliffs",
    river = "river_valleys",
    rainforest = "dense_rainforest_canopy",
}) do
    tdw.on_chat(word, function(player)
        local rec = tdw.online[player]
        if rec == nil then
            return "you are not anywhere yet"
        end
        local biome = tdw.biomes[id]
        local name = biome and biome.name or id
        if not tdw.seek_biome(player, id, rec) then
            return "there is nowhere to look for " .. name
        end
        if SWEEP[id] then
            return "looking for " .. name .. ": walking outward until one turns up"
        end
        return "looking for " .. name .. ": trying the ring a stretch at a time"
    end)
end
