-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- THE SPONGE (2026-09-30): "from about y -10.8 km to about -33.3 we need to
-- break up the world with really strong noise that turns it into a
-- sponge-like fractal structure. Biomes will still exist in there but they
-- will be sliced and fragmented, with crazy holes and tunnels."
--
-- The underside's cone, between the core stack (whose lowest shell ends at
-- -9 km) and the Tail (-37 km), is carved into a sponge AFTER everything
-- else in the chunk is laid: the rock, whatever biome paints it, the ores.
-- So a biome built down here later is sliced by it without knowing, and
-- the sponge cuts through the body's outer wall too, so from outside the
-- underside is ragged and holed.
--
-- Four terms, each positive in the void, in blocks, the union of them all:
--   THE SPONGE   a four-octave noise over a cut just above its middle.
--                A 3D noise over zero is a sponge: both the solid and the
--                void run connected through everything, and the octaves
--                make it fractal, rooms of a few hundred blocks riddled
--                with holes of a few dozen and a few.
--   THE HOLES    a second, finer sponge over a high cut: pockets ten to
--                twenty blocks across punched through the solid a fifth
--                of the time, so no wall between two rooms is whole.
--   THE TUNNELS  where two independent noises are both near zero: lines,
--                so tubes, a network of them at two scales (twelve and four
--                wide), boring through the sponge's solid.
--   THE SLICES   the zero sheets of two slow noises, a couple of blocks
--                thick: planar cracks kilometres across that cut clean
--                through everything, which is what fragments the biomes.
--   THE FADE     all of it is pushed back over FADE blocks at either end
--                of the band, so it thins out rather than stopping at a
--                ceiling or a floor.
-- One fill, one program, only in chunks the band reaches (`into`).

local shape = tdw.shape
local n = shape.node
local M = {}
tdw.sponge = M

M.TOP_Y, M.BOTTOM_Y = -10.8, -33.3                   -- Spindle km
local FADE = 800                                      -- blocks, inward from each end
local TOP_B = shape.Y0 + M.TOP_Y * 1000                -- world y
local BOTTOM_B = shape.Y0 + M.BOTTOM_Y * 1000
local FADE_PUSH = 90.0                                -- blocks the field is lowered by at a band's very end

-- A one-octave noise climbs about one unit in 0.625 / frequency blocks near
-- its zero (stone_labyrinth.lua), so |n| * that is roughly the distance to
-- its zero in blocks.
local function k_of(freq) return 0.625 / freq end

local SPONGE_FREQ, SPONGE_OCTAVES, SPONGE_CUT, SPONGE_K = 1 / 260, 4, 0.03, 110.0
local HOLE_FREQ, HOLE_OCTAVES, HOLE_CUT, HOLE_K = 1 / 45, 2, 0.16, 40.0
local TUNNELS = {                                      -- stream, frequency, half-width in blocks
    { "sponge_tube_big", 1 / 110, 6.0 },
    { "sponge_tube_fine", 1 / 30, 2.0 },
}
local SLICES = {                                       -- stream, frequency, half-thickness in blocks
    { "sponge_slice_a", 1 / 1600, 1.2 },
    { "sponge_slice_b", 1 / 1300, 1.0 },
}

local FIELD = nil
local function field()
    if FIELD then return FIELD end
    local v = n.mul(n.sub(n.noise("sponge", SPONGE_FREQ, SPONGE_OCTAVES, 1.0), n.const(SPONGE_CUT)), n.const(SPONGE_K))
    v = n.max(v, n.mul(n.sub(n.noise("sponge_holes", HOLE_FREQ, HOLE_OCTAVES, 1.0), n.const(HOLE_CUT)), n.const(HOLE_K)))
    for _, t in ipairs(TUNNELS) do
        local stream, freq, w = t[1], t[2], t[3]
        local a = n.mul(n.abs(n.noise(stream .. "_a", freq, 1, 1.0)), n.const(k_of(freq)))
        local b = n.mul(n.abs(n.noise(stream .. "_b", freq, 1, 1.0)), n.const(k_of(freq)))
        v = n.max(v, n.sub(n.const(w), n.max(a, b)))
    end
    for _, s in ipairs(SLICES) do
        local stream, freq, w = s[1], s[2], s[3]
        v = n.max(v, n.sub(n.const(w), n.mul(n.abs(n.noise(stream, freq, 1, 1.0)), n.const(k_of(freq)))))
    end
    -- The fade: 1 inside the band, falling to 0 over FADE at either end.
    local y = n.Y()
    local ramp = n.clamp(n.mul(n.min(n.sub(y, n.const(BOTTOM_B)), n.sub(n.const(TOP_B), y)), n.const(1.0 / FADE)), 0.0, 1.0)
    v = n.sub(v, n.mul(n.sub(n.const(1.0), ramp), n.const(FADE_PUSH)))
    FIELD = shape.compile("sponge", v)
    return FIELD
end
M.field = field

-- Carve the chunk, if the band reaches it. `Ylo`, `Yhi`: its Spindle km.
function M.into(buf, Ylo, Yhi)
    if Yhi < M.BOTTOM_Y or Ylo > M.TOP_Y then
        return false
    end
    buf:fill_density(field(), game.AIR, shape.SURFACE_DETAIL)
    return true
end

return M
