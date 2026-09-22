-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- Where a player is, remembered.
--
-- The engine saves a player's inventory between sessions and nothing else:
-- every join starts at its fixed spawn, which in this world is deep inside
-- the hot magical caves. So this file does two things the engine leaves to a
-- mod (charter rule 1):
--
--   * On a first visit, drops the player above the temperate woodlands and
--     walks them down onto the ground — the surface is under a relief field
--     nothing in Lua can evaluate, so it is FOUND, by reading blocks under
--     the player once the chunks there exist.
--   * Remembers where each player was, keyed on their UUID (charter rule 13)
--     in `game.storage`, and puts them back there when they return. The
--     position is sampled every half second and written every twenty, and
--     again when they leave, so a dropped connection loses at most a few
--     steps.

-- The plain: shape.lua scales the relief down around this radius, so the
-- ground is within about a hundred blocks of the base dome and one look down
-- from SPAWN_ABOVE finds it — no hopping through unloaded chunks.
local SPAWN_ABOVE = 30 + tdw.shape.spawn_extra_above()   -- the plain keeps the ground within ~22 of the base dome; the alpine dev world stands it higher
local SPAWN = {
    x = tdw.shape.SPAWN_X + 0.5,
    y = tdw.shape.spawn_base_y() + SPAWN_ABOVE,
    z = tdw.shape.SPAWN_Z + 0.5,
}
local SAMPLE_EVERY = 10        -- ticks between position samples
local SAVE_EVERY = 400         -- ticks between writes to storage
local SCAN_DOWN = 190          -- blocks searched below a landing player (within the vertical view)
local AIM_ABOVE = 6            -- blocks over the ground the field finds that a new player is put, before the blocks confirm it
local HOP = 160                -- blocks dropped when all of that is air
local FALL_THROUGH = 32        -- blocks of seen air (or rock) a waiting player steps down (or up) through when what is past them is unloaded
local GIVE_UP_AFTER = 1200     -- ticks (one minute) before a landing is abandoned

local online = {}              -- uuid -> { pos, pending, landing, seeking }
tdw.online = online            -- whereami.lua reads it: who is here, and who is looking for a biome
local tick = 0

local function key(uuid)
    return "pos:" .. uuid
end

local function encode(p)
    return string.format("%.2f %.2f %.2f", p.x, p.y, p.z)
end

local function decode(text)
    local x, y, z = string.match(text, "^(%S+) (%S+) (%S+)$")
    if x == nil then
        return nil
    end
    return { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
end

local function where(uuid)
    local body = game.player_entity(uuid)
    if body == nil then
        return nil
    end
    local entity = game.entity(body)
    return entity and entity.pos or nil
end

local function save(uuid, rec)
    if rec.pos and not rec.landing then
        game.storage.set(key(uuid), encode(rec.pos))
    end
end

-- One step of finding the ground under a landing player. Returns nothing;
-- called every tick until `rec.landing` is cleared.
local function land(uuid, rec)
    rec.landing.ticks = rec.landing.ticks + 1
    if rec.landing.ticks > GIVE_UP_AFTER then
        game.log("tiamat_default_world: gave up landing " .. uuid .. " — check the spawn column")
        rec.landing = nil
        return
    end
    local p = where(uuid)
    if p == nil then
        return
    end
    -- **Not until the body is there.** `game.move_player` writes the body the
    -- tick steps, and where a player IS (`game.entity`) is a mirror of it
    -- taken during the tick — so on the tick after a teleport this still
    -- reads the old place. The aim below then put the player on the ground
    -- THERE, which undid every `/tp` the moment the world's seed reached this
    -- VM and the aim began to run (2026-09-14: "it tells me where the biome
    -- is but does not bring me there"). So a landing that knows where it is
    -- going waits until the player is within a few blocks of it, and asks for
    -- the move again once a second in case one did not take.
    local target = rec.landing.target
    if target and (math.abs(p.x - target.x) > 4 or math.abs(p.z - target.z) > 4) then
        if rec.landing.ticks % 20 == 0 then
            game.move_player(uuid, target)
        end
        return
    end
    local x, z = math.floor(p.x), math.floor(p.z)
    -- First, aim: the ground under the spawn from the terrain field itself
    -- (`shape.ground_at_column`), the moment the seed is known — the first
    -- chunk to generate sets it, which is the first tick the player exists.
    -- The player is put AIM_ABOVE over it and the block reads below take
    -- it from there: a fall of a few blocks, where the alpine spawn was a
    -- thousand blocks over the dome and a new player fell the whole way.
    local seed = tdw.seed or game.world_seed              -- the generator's, or the engine's when it sets one (engine-asks 21)
    if not rec.landing.aimed and seed ~= nil then
        rec.landing.aimed = true
        local ground = tdw.shape.ground_at_column(x, z, seed, p.y)
        if ground ~= nil and ground + AIM_ABOVE < p.y then
            game.move_player(uuid, { x = x + 0.5, y = ground + AIM_ABOVE + 0.01, z = z + 0.5 })
            game.log(string.format("tiamat_default_world: %s aimed at the ground the field puts at %d, %d, %d", uuid, x, ground, z))
            return
        end
    end
    local feet_y = math.floor(p.y)
    local function at(y)
        return game.get_block{ x = x, y = y, z = z }
    end

    local feet = at(feet_y)
    if feet == nil then
        return          -- not loaded yet; the player is held still until it is
    end

    if feet.occupancy ~= 0 then
        -- Inside rock: climb until there is headroom.
        local clear, y = 0, feet_y + 1
        for _ = 1, 200 do
            local block = at(y)
            if block == nil then
                -- Rock up to the edge of what is loaded: a seedless drop
                -- inside a peak. Rise through what has been seen; the view
                -- follows, as for the fall below.
                if y - feet_y > FALL_THROUGH then
                    game.move_player(uuid, { x = p.x, y = y - 1 + 0.01, z = p.z })
                end
                return
            end
            clear = block.occupancy == 0 and clear + 1 or 0
            if clear >= 3 then
                game.move_player(uuid, { x = x + 0.5, y = y - 2 + 0.01, z = z + 0.5 })
                return
            end
            y = y + 1
        end
        return
    end

    -- In air: look for ground below.
    for y = feet_y - 1, feet_y - SCAN_DOWN, -1 do
        local block = at(y)
        if block == nil then
            -- The chunk below is still on its way — or past the vertical
            -- view, and never coming while the player hangs this high. With
            -- no seed to aim by (an engine before `game.world_seed`), a drop
            -- over the alpine peaks waited out the minute that way. So
            -- step down through the air already seen, and the view follows.
            if feet_y - y > FALL_THROUGH then
                game.move_player(uuid, { x = p.x, y = y + 2.01, z = p.z })
            end
            return
        end
        if block.occupancy ~= 0 then
            local landed = { x = x + 0.5, y = y + 1.01, z = z + 0.5 }
            if game.move_player(uuid, landed) then
                -- A player looking for a biome has landed somewhere: the
                -- ground says whether it is the right one, and if it is not
                -- `seek_landed` sends them round to the next azimuth and
                -- leaves the landing running.
                if rec.seeking and tdw.seek_landed and not tdw.seek_landed(uuid, rec, x, y + 1, z) then
                    return
                end
                rec.landing = nil
                rec.pos = landed
                game.log(string.format("tiamat_default_world: %s landed at %d, %d, %d", uuid, x, y + 1, z))
            end
            return
        end
    end
    -- Nothing but air for the whole scan: drop, and look again next tick.
    game.move_player(uuid, { x = p.x, y = p.y - HOP, z = p.z })
end

game.register_on_player_join(function(event)
    local rec = { pos = nil, pending = nil, landing = nil }
    online[event.player] = rec
    local saved = game.storage.get(key(event.player))
    local pos = saved and decode(saved) or nil
    if pos then
        rec.pending = pos
        rec.pos = pos
        game.log(string.format("tiamat_default_world: %s returns to %s", event.name, saved))
    elseif tdw.config.spawn_biome and tdw.seek_biome
        and tdw.seek_biome(event.player, tdw.config.spawn_biome, rec) then
        -- The dev switch picks where a new player starts: they are dropped
        -- into that biome and the landing hunts for it, rather than at the
        -- fixed spawn (tdw.config.spawn_biome).
        game.log(string.format("tiamat_default_world: %s is new here; looking for %s",
            event.name, tdw.config.spawn_biome))
    else
        rec.pending = SPAWN
        rec.landing = { ticks = 0, target = SPAWN }
        game.log(string.format("tiamat_default_world: %s is new here; dropping them at the woodlands", event.name))
    end
end)

game.register_on_player_leave(function(event)
    local rec = online[event.player]
    if rec then
        save(event.player, rec)
        online[event.player] = nil
    end
end)

tdw.on_tick(function(dt_ticks)
    tick = tick + dt_ticks
    for uuid, rec in pairs(online) do
        -- A move asked for during the join lands once the body exists.
        if rec.pending and game.move_player(uuid, rec.pending) then
            rec.pending = nil
        end
        if rec.landing then
            land(uuid, rec)
        elseif tick % SAMPLE_EVERY == 0 then
            local p = where(uuid)
            if p then
                rec.pos = p
            end
        end
    end
    if tick % SAVE_EVERY == 0 then
        for uuid, rec in pairs(online) do
            save(uuid, rec)
        end
    end
end)

-- `/where`: where you are, in the Spindle's own terms, in chat and the log.
tdw.on_command("where", "/where — where you are: the biome, the ring, how far under the dome", function(player)
    local p = where(player)
    if p == nil then
        return "you are not anywhere yet"
    end
    local shape = tdw.shape
    local r2 = (p.x * p.x + p.z * p.z) * 1e-6
    local u = r2 / (shape.R_DISC * shape.R_DISC)
    local Y = (p.y - shape.Y0) * shape.SCALE
    local ring = tdw.layers.rings_overlapping(u, u)[1]
    local depth = shape.dome_at(u) - Y
    local line = string.format(
        "y=%.0f, Spindle Y=%.2f km, u=%.4f (ring %s), %.2f km below the base dome",
        p.y, Y, u, ring and ring.id or "beyond the rim", depth)
    local here = tdw.biome_under and tdw.biome_under(math.floor(p.x), math.floor(p.y), math.floor(p.z))
    local biome = here and tdw.biomes[here]
    game.log("tiamat_default_world where: " .. line)
    return (biome and (biome.name .. " — ") or "") .. line
end)

game.log("tiamat_default_world: player positions are remembered")
