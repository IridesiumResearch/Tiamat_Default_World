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
--   biomes()          every biome and depth area `biome_under` can name,
--                     with its display name and whether a world has it
--   depth_under(x, y, z)  blocks under the ground as generated, or nil
--   depth_band(x, y, z)   the depth band a place is in: id and name
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

-- **The biome list** (Progress, sibling ask W5, 2026-09-28): what
-- `biome_under` can answer, in catalogue order, so a discoveries view can
-- show what is not found yet under its real name and count what there is
-- to find. Every biome in the catalogue — `findable` true for those built
-- and placed in a world, false for the catalogue's ones still to come —
-- and after them the depth areas `biome_under` names a place deep under
-- the ground by when no cave biome claims it. A fresh table every call.
local DEPTH_AREAS = { normal_caves = true, dark_caves = true, abyss = true }
local function biomes()
    local ok, list = pcall(function()
        local out = {}
        local only = tdw.config.everywhere
        for _, biome in ipairs(tdw.biome_list) do
            local area = tdw.areas[biome.area]
            local findable = biome.built == true and biome.placed ~= false and (only == nil or only == biome.id)
            out[#out + 1] = { id = biome.id, name = biome.name, area = biome.area, area_name = area and area.name or nil,
                kind = biome.cave and "cave" or (area and area.kind) or "surface", findable = findable }
        end
        for _, band in ipairs(tdw.layers.DEPTH) do
            local area = tdw.areas[band.id]
            if DEPTH_AREAS[band.id] and area then
                out[#out + 1] = { id = band.id, name = area.name, area = band.id, area_name = area.name,
                    kind = "depth_area", findable = true }
            end
        end
        return out
    end)
    if not ok then
        return nil
    end
    return list
end

-- **Depth from the surface** (Progress, sibling ask W6, 2026-09-28). The
-- ground as GENERATED: the terrain program of the place's ring, whose value
-- is the depth under the surface in km — the same field the ground was
-- made from, read at one point. Negative over the ground. It does not know
-- what anybody has dug since, which for "how deep has this player been" is
-- what is wanted: a shaft does not make its own floor shallow. One point
-- sample: cheap enough for a player a tick, not for a field of them.
local function depth_under(x, y, z)
    x, y, z = number(x), number(y), number(z)
    if x == nil or y == nil or z == nil then
        return nil
    end
    local seed = game.world_seed or tdw.seed
    if seed == nil then
        return nil
    end
    local ok, depth = pcall(function()
        local u = (x * x + z * z) * 1e-6 / (shape.R_DISC * shape.R_DISC)
        local mode = shape.terrain_mode_for(u, u, { x = math.floor(x) // 16, y = math.floor(y) // 16, z = math.floor(z) // 16, seed = seed })
        return shape.top_for(mode).solid:at(math.floor(x) + 0.5, math.floor(y) + 0.5, math.floor(z) + 0.5, seed) * 1000.0
    end)
    if not ok then
        return nil
    end
    return depth
end
-- The world's depth band at a place: "surface", "normal_caves", "dark_caves"
-- or "abyss" (layers.DEPTH), and its name. By the smooth depth under the
-- base dome, which is what the bands are laid by: anything over the
-- normal caves is the surface, mountains included; nil only under the
-- abyss's own floor.
local function depth_band(x, y, z)
    x, y, z = number(x), number(y), number(z)
    if x == nil or y == nil or z == nil then
        return nil
    end
    local ok, id, name = pcall(function()
        local u = (x * x + z * z) * 1e-6 / (shape.R_DISC * shape.R_DISC)
        local depth = shape.dome_at(u) - (y - shape.Y0) * shape.SCALE
        for _, band in ipairs(tdw.layers.DEPTH) do
            if depth >= band.d[1] and depth < band.d[2] then
                local area = tdw.areas[band.id]
                return band.id, area and area.name or band.id
            end
        end
        -- Over the surface band's top: a mountain is still the surface.
        local first = tdw.layers.DEPTH[1]
        if depth < first.d[1] then
            local area = tdw.areas[first.id]
            return first.id, area and area.name or first.id
        end
        return nil
    end)
    if not ok then
        return nil
    end
    return id, name
end

game.export{
    version = 1,
    humidity = HUMIDITY,
    HUMIDITY_SPLIT = shape.HUMIDITY_SPLIT,
    climate = climate,
    biome_under = biome_under,
    add_soil_alias = add_soil_alias,
    add_harmless_fluid = add_harmless_fluid,
    biomes = biomes,
    depth_under = depth_under,
    depth_band = depth_band,
}

game.log("tiamat_default_world: exports published (version 1)")
