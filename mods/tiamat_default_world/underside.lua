-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- THE SKY UNDER THE WORLD (2026-10-01): "below the surface only darkness
-- and stars should be seen in the sky, and the day/night cycle should not
-- be there."
--
-- The sponge (sponge.lua) opens the underside to the sky beyond the body,
-- and that sky was the overworld's, noon and all. Below LINE_Y, the top of
-- the flank (the rim's surface stands at 16.5 km, so nothing a player
-- walks on in the open is under it), a player's sky is laid black: no
-- sun, no colour, the same at every hour. Above it, the plain sky again.
--
-- **Stars are not in it yet.** The sky modifier scales and tints the sky
-- and has no say over the stars, which only the keyframes' `stars` shows,
-- so at night the stars are out under the world as over it and by day
-- they are not. Engine ask 44 asks for `stars` on the modifier.
--
-- **The modifier is one a player, and the Weather mod writes it too.** The
-- world cannot read Weather's `add_overlay` (Weather depends on the world,
-- and dependencies may not run both ways), so this writes the modifier
-- itself and writes it again every REASSERT ticks while the player is
-- under the line, so a write of Weather's is undone within a couple of
-- seconds. Underground Weather's own part is nil, so they rarely meet.
-- `underside_sky(x, y, z)` is exported so Weather can lay it as one of its
-- overlays instead (the world's sibling ask Wx-1), and then this goes.

local shape = tdw.shape
local M = {}
tdw.underside = M

M.LINE_Y = shape.Y0 + 14000                            -- world y: Spindle 14 km, the flank's top
local DARK = { intensity = 0.0, sky = { 0.0, 0.0, 0.0 }, sky_mix = 1.0, saturation = 0.0, ease_ticks = 200 }
local CHECK, REASSERT = 20, 40                         -- ticks between looks; between rewrites under the line
local under, since, tick = {}, {}, 0

-- True under the line.
function M.dark_at(x, y, z)
    return y < M.LINE_Y
end

if game.set_sky_modifier then
    tdw.on_tick(function(dt)
        tick = tick + dt
        if tick < CHECK or not tdw.online then
            return
        end
        tick = 0
        for uuid in pairs(tdw.online) do
            local body = game.player_entity(uuid)
            local e = body and game.entity(body)
            local p = e and e.pos
            if p then
                if M.dark_at(p.x, p.y, p.z) then
                    since[uuid] = (since[uuid] or REASSERT) + CHECK
                    if not under[uuid] or since[uuid] >= REASSERT then
                        game.set_sky_modifier(uuid, DARK)
                        under[uuid], since[uuid] = true, 0
                    end
                elseif under[uuid] then
                    game.set_sky_modifier(uuid, nil)
                    under[uuid], since[uuid] = nil, nil
                end
            end
        end
    end)
end

return M
