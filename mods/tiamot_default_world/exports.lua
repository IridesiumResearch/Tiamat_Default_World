-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- What this mod publishes to the others (engine `game.export`, 482958a).
-- The contract is Weather's `docs/exports-contract.md` (2026-09-17); this
-- is version 1 of it, whole.
--
-- **An exported function must not error.** It runs in THIS mod's sandbox
-- when another mod calls it, and an error here disables the Spindle — the
-- whole world. So every one of them checks its arguments, runs the work
-- under `pcall`, and answers nil (or false) rather than raising.
--
-- What is published:
--   version = 1
--   humidity          the humidity field, compiled, +/-0.5 (no dither)
--   HUMIDITY_SPLIT    the wet/dry line in that field's units
--   climate(x, z)     the ring temperature, 0..1: T = 4t(1 - t), t = r/R
--   biome_under(x, y, z)  the biome id at a place, or nil
--   add_soil_alias(block, dry)   another mod's block counts as one of ours
--   add_harmless_fluid(fluid)    a fluid the leaves and the lava ignore
--
-- THE RING TEMPERATURE is not a field this mod generates from — the rings
-- are placed by radius and the biomes carry the climate themselves — but
-- it is the curve the placement follows: the Crown is ice, the middle
-- rings are mild, the Hem is cold again, so T = 4t(1 - t) peaks at half
-- the radius. Weather mirrors exactly this, so the two agree whether or
-- not the export is there.

local shape = tdw.shape

local HUMIDITY = shape.compile("export.humidity", shape.humidity())
local INV_R2 = 1e-6 / (shape.R_DISC * shape.R_DISC)

-- sqrt without `math.sqrt`: Newton's method from 1, twenty steps of + - * /
-- only, which is what Weather's mirror runs, so both sides answer the same
-- bits on every machine.
local function root(u)
    if u < 1e-8 then
        return 0.0
    end
    local g = 1.0
    for _ = 1, 20 do
        g = 0.5 * (g + u / g)
    end
    return g
end

local function number(v)
    return type(v) == "number" and v == v and v or nil
end

-- 0 at the axis and at the rim, 1 half way out.
local function climate(x, z)
    x, z = number(x), number(z)
    if x == nil or z == nil then
        return nil
    end
    local t = root((x * x + z * z) * INV_R2)
    if t > 1.0 then
        t = 1.0
    end
    local T = 4.0 * t * (1.0 - t)
    if T < 0.0 then
        return 0.0
    end
    return T
end

local function biome_under(x, y, z)
    x, y, z = number(x), number(y), number(z)
    if x == nil or y == nil or z == nil then
        return nil
    end
    local ok, id = pcall(tdw.biome_under, math.floor(x), math.floor(y), math.floor(z))
    if not ok then
        return nil
    end
    return id
end

-- **The aliases** (Weather's damp ground): another mod's block is to count
-- as one of ours wherever this mod compares materials — `tdw.soil_under`,
-- the HUD's owner table, and the growth rules that ask what a plant stands
-- on. Both names are kept as STRINGS and resolved on first use: the damp
-- blocks register after this mod has loaded, so their ids do not exist yet.
local function add_soil_alias(block, dry)
    if type(block) ~= "string" or type(dry) ~= "string" then
        return false
    end
    tdw.soil_alias_names[block] = dry
    tdw.soil_alias_ready = false
    return true
end

-- **The harmless fluids** (Weather's rainwater): a fluid that neither
-- breaks leaves (rules.lua) nor quenches lava into rock.
local function add_harmless_fluid(fluid)
    if type(fluid) ~= "string" then
        return false
    end
    tdw.harmless_fluids[fluid] = true
    return true
end

game.export{
    version = 1,
    humidity = HUMIDITY,
    HUMIDITY_SPLIT = shape.HUMIDITY_SPLIT,
    climate = climate,
    biome_under = biome_under,
    add_soil_alias = add_soil_alias,
    add_harmless_fluid = add_harmless_fluid,
}

game.log("tiamot_default_world: exports published (version 1)")
