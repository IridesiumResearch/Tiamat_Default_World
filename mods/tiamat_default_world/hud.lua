-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- The name of the biome you have just walked into, in the bottom right
-- corner, fading in and out over ten seconds. The server decides what it
-- says and how opaque it is (whereami.lua), a few times a second; this only
-- draws what arrives, which is what a HUD script is for — draw, do not
-- compute.
--
-- The canvas is 1080 virtual pixels tall and as wide as the window. The
-- engine draws text from its anchor point to the right and down whatever
-- the anchor, so a name hugging the right edge is pushed left by an
-- estimate of its own width: there is no measuring text from here.
--
-- **Colours are positional**, `{ r, g, b, a }`: the engine reads the list
-- by index, and the named `{ r = ... }` form this file used until
-- 2026-09-29 was ignored, which drew the shadow white.

local SIZE = 20
local RIGHT = 28                  -- virtual pixels from the right edge to the name's end
local UP = 172                    -- from the bottom to the name's top: clear of the hotbar's corner
local PER_CHAR = 0.52             -- the proportional face's mean advance, per point of size

hud.on_draw(function(state)
    local name = state.values.biome
    local alpha = tonumber(state.values.alpha) or 0
    if type(name) ~= "string" or name == "" or alpha <= 0 then
        return
    end
    local x = RIGHT + math.floor(#name * SIZE * PER_CHAR)
    local ink = math.floor(255 * alpha)
    -- Drawn twice, the dark copy a pixel down and right: a pale word over a
    -- bright sky is unreadable otherwise, and the engine has no outlined
    -- text. The shadow fades a little faster, so a fading name does not
    -- leave a dark ghost behind it.
    hud.text{ anchor = "bottom_right", x = x - 1, y = UP - 1, text = name, size = SIZE, colour = { 0, 0, 0, math.floor(200 * alpha * alpha) } }
    hud.text{ anchor = "bottom_right", x = x, y = UP, text = name, size = SIZE, colour = { 242, 238, 226, ink } }
end)
