-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- What the world sounds like (2026-09-24, from the designer's recordings in
-- `Tiamat Sounds`): a BED per place and a LAYER over it at night, each a
-- loop per player, plus the one-shots the world's own events make.
--
-- **Ambience is a loop, not a repeated clip** (the stubs' own words), and a
-- loop is per PLAYER here: two players in two biomes hear two worlds, so
-- every loop is started with `player = uuid` and never `everywhere` alone.
-- The director below runs on the shared tick, reads where each player is
-- the same way the HUD does (`tdw.biome_under`), and only speaks on a
-- CHANGE — `play_loop` replaces a running loop under the same id, and a
-- fade carries one bed into the next at a biome line.
--
-- The rest of the sound table lives where its event lives: the step pair
-- is registered in blocks.lua beside the blocks that name it, the rose
-- pick's peel in the grassland, the teleport's chime in player.lua. The
-- break and place noises stay core_tools' for now: that mod plays its own
-- fixtures on every dig, and a second noise from here would double every
-- strike — replacing them properly means a tools mod of our own. The same
-- is true, and ACCEPTED for now, of core_sky's day/night ambience: it is
-- a dependency, so `conflicts` cannot retire it, and its quiet fixtures
-- (gain 0.25/0.3) play under these beds until the Spindle registers a sky
-- of its own and stops depending on it — a decision for the designer, not
-- this file. The designer's music tracks are over the engine's one-minute
-- cap (streaming does not exist yet) and wait on it.

local M = {}
tdw.sounds = M

-- The loops. Files normalized to about -26 dB mean (the one-shots hotter);
-- the mix lives in the play gains below, not in the files.
game.register_sound{ id = "cave", file = "sounds/cave.ogg" }
game.register_sound{ id = "underworld", file = "sounds/underworld.ogg" }
game.register_sound{ id = "canopy", file = "sounds/canopy.ogg" }
game.register_sound{ id = "wind", file = "sounds/wind.ogg" }
game.register_sound{ id = "undersea", file = "sounds/undersea.ogg" }
game.register_sound{ id = "crickets", file = "sounds/crickets.ogg" }
game.register_sound{ id = "frogs", file = "sounds/frogs.ogg" }
game.register_sound{ id = "ember", file = "sounds/ember.ogg" }
-- The one-shots that are the world's own.
game.register_sound{ id = "echo_dark", file = "sounds/echo_dark.ogg", pitch_variance = 0.2 }
game.register_sound{ id = "peel", file = "sounds/peel.ogg", pitch_variance = 0.1 }
game.register_sound{ id = "portal", file = "sounds/portal.ogg" }

-- The bed each surface biome lies under. A biome not named here defaults
-- by kind below: caves to the cave bed, anything under the surface band to
-- the underworld's, an unnamed surface biome to open wind — so a new biome
-- is never silent, only unparticular.
local BEDS = {
    -- Under leaves: the soft treetop wind.
    temperate_woodlands = "canopy", flower_forest = "canopy", jungle = "canopy",
    taiga = "canopy", silverwood = "canopy", redwood_stands = "canopy",
    karst_towers = "canopy", frostpine_coast = "canopy", mangrove_coast = "canopy",
    peat_fen = "canopy",
    -- The Ember Ridge: the fire underfoot.
    volcanic_foothills = "ember", obsidian_barrens = "ember",
    geyser_basin = "ember", cinder_coast = "ember",
    -- Everything open: the slow wind. (The explicit names are the ones a
    -- reader might wrongly guess; the default catches the rest.)
    rolling_grasslands = "wind", savanna = "wind", alpine_highlands = "wind",
    heather_moor = "wind", river_valleys = "wind",
}
-- The night layer, where one belongs: crickets in the grass and under the
-- broadleaves, frogs where the ground is wet. Nothing at night on ice, in
-- the caves or over the fire — their beds are the whole of it.
local NIGHT = {
    rolling_grasslands = "crickets", temperate_woodlands = "crickets",
    flower_forest = "crickets", savanna = "crickets", heather_moor = "crickets",
    peat_fen = "frogs", river_valleys = "frogs", mangrove_coast = "frogs",
    jungle = "frogs",
}
local DAWN, DUSK = 0.25, 0.75
local GAIN = { bed = 0.55, layer = 0.5 }
local FADE = 80                -- ticks a bed takes to cross-fade at a line
local SAMPLE_EVERY = 10        -- ticks between looks, the HUD's own cadence
-- The dark's punctuation: a far echo now and then, only in a cave's bed.
local ECHO_LEAST, ECHO_SPAN = 1800, 5400   -- ticks: one per 1.5 to 6 minutes

-- What kind of ground an id names: a bed, from the biome tables.
local function bed_for(here)
    local biome = tdw.biomes[here]
    if biome and biome.cave then
        return "cave"
    end
    if biome == nil then
        -- Not a biome: an AREA came back — the dark caves, the gloam, the
        -- shells, the tail. Everything under the surface band sounds of
        -- the underworld.
        return tdw.areas[here] and "underworld" or "wind"
    end
    return BEDS[here] or "wind"
end

local state = {}       -- uuid -> { bed, layer, echo }
local since = 0

tdw.on_tick(function(dt)
    since = since + dt
    if since < SAMPLE_EVERY then
        return
    end
    since = 0
    local time = game.time_of_day()
    local night = time < DAWN or time > DUSK
    for uuid in pairs(tdw.online) do
        local body = game.player_entity(uuid)
        local entity = body and game.entity(body)
        if entity then
            local px, py, pz = math.floor(entity.pos.x), math.floor(entity.pos.y), math.floor(entity.pos.z)
            local s = state[uuid]
            if s == nil then
                s = {}
                state[uuid] = s
            end
            local bed, layer
            -- `submerged` is a NUMBER — how much of the body is in fluid,
            -- 0 dry, 1 under — and 0 is truthy in Lua, so it is compared,
            -- not tested. Near 1 is "the water closed over the ears";
            -- wading stays in the biome's own air.
            if (entity.submerged or 0) > 0.75 then
                bed = "undersea"
            else
                local here = tdw.biome_under(px, py, pz)
                if here == nil then
                    -- Unloaded ground says nothing rather than "nowhere":
                    -- keep the bed AND the layer that were playing, exactly
                    -- as the HUD keeps its name.
                    bed, layer = s.bed, s.layer
                else
                    bed = bed_for(here)
                    if night and bed ~= "cave" and bed ~= "underworld" then
                        layer = NIGHT[here]
                    end
                end
            end
            if bed ~= s.bed then
                s.bed = bed
                if bed then
                    game.play_loop{ id = "bed", sound = bed, everywhere = true, player = uuid, gain = GAIN.bed, fade_ticks = FADE }
                else
                    game.stop_loop{ id = "bed", player = uuid, fade_ticks = FADE }
                end
            end
            if layer ~= s.layer then
                s.layer = layer
                if layer then
                    game.play_loop{ id = "layer", sound = layer, everywhere = true, player = uuid, gain = GAIN.layer, fade_ticks = FADE }
                else
                    game.stop_loop{ id = "layer", player = uuid, fade_ticks = FADE }
                end
            end
            -- The echo: rare, positioned a little off so it has a side,
            -- and rearmed from a seeded stream so two servers agree.
            if s.bed == "cave" then
                if s.echo == nil then
                    local seed = game.world_seed or tdw.seed or 0
                    local rng = game.rng_stream({ x = px, y = py, z = pz, seed = seed }, "cave_echo")
                    s.echo = ECHO_LEAST + rng:below(ECHO_SPAN)
                else
                    s.echo = s.echo - SAMPLE_EVERY
                    if s.echo <= 0 then
                        s.echo = nil
                        local seed = game.world_seed or tdw.seed or 0
                        local rng = game.rng_stream({ x = px, y = py, z = pz, seed = seed }, "cave_echo_dir")
                        local d = (rng:below(2) == 0) and -9 or 9
                        game.play_sound{ sound = "echo_dark", pos = { x = px + d, y = py, z = pz - d }, radius = 40, gain = 0.6 }
                    end
                end
            else
                s.echo = nil
            end
        end
    end
    -- A player who left takes their state with them, so coming back is a
    -- fresh start — which is also what re-tells them their loops, since
    -- the engine tells a joiner about nothing already playing.
    for uuid in pairs(state) do
        if not tdw.online[uuid] then
            state[uuid] = nil
        end
    end
end)

game.log("tiamat_default_world: the world has a sound")

return M
