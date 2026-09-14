-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- The name of the biome you have just walked into: small, top middle, for a
-- second. The server decides what it says and when to stop saying it
-- (whereami.lua); this only draws what arrives, which is what a HUD script
-- is for — draw, do not compute.
--
-- The canvas is 1080 virtual pixels tall and as wide as the window, and the
-- "top" anchor puts x = 0 in the middle of it, so the name is centred
-- whatever shape the window is.

local SHADOW = { r = 0, g = 0, b = 0 }
local INK = { r = 242, g = 238, b = 226 }
local SIZE = 26
local Y = 44

hud.on_draw(function(state)
    local name = state.values.biome
    if type(name) ~= "string" or name == "" then
        return
    end
    -- Drawn twice, the dark copy a pixel down and right: a pale word over a
    -- bright sky is unreadable otherwise, and the engine has no outlined
    -- text.
    hud.text{ anchor = "top", x = 1, y = Y + 1, text = name, size = SIZE, colour = SHADOW }
    hud.text{ anchor = "top", x = 0, y = Y, text = name, size = SIZE, colour = INK }
end)
