-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- Rules of the world that are not one biome's.
--
-- Water and plants: running water breaks the plants a body walks through
-- (grass, ferns, flowers). That is the engine's now (`washes_away`, which
-- blocks.lua sets on every passable block, engine e4ac3a8); until
-- 2026-09-22 this file swept round every blocked flow for wet plants.
--
-- Leaves and water. Leaves placed into water, or against it, fall apart:
-- the placement is refused and the player keeps them. Water that reaches
-- a leaves block breaks it, and what it was is gone. The engine CAN drop it
-- as an item there, `game.spawn_entity{ item = stack }` (core_gear is the
-- worked example; engine-asks 11, answered 2026-09-11); not wired in yet.

local blocks = tdw.blocks
local LEAVES = "tiamat_default_world:oak_leaves"
-- Fluids another mod has asked this one to ignore (exports.lua,
-- `add_harmless_fluid`: Weather's rainwater). They break no leaves and
-- quench no lava — that mod makes steam of its own where they meet.
tdw.harmless_fluids = {}
local MERGE = { merge = true }

local function wet(x, y, z)
    local f = game.get_fluid{ x = x, y = y, z = z }
    return f ~= nil and not f.empty
end

game.register_on_place(function(event)
    if event.material ~= blocks.oak_leaves then
        return
    end
    local x, y, z = event.x, event.y, event.z
    if wet(x, y, z) or wet(x + 1, y, z) or wet(x - 1, y, z) or wet(x, y + 1, z)
        or wet(x, y - 1, z) or wet(x, y, z + 1) or wet(x, y, z - 1) then
        return "Leaves fall apart in water."
    end
end)

-- Lava and water (2026-09-16): "lava needs to create blocks that are a mix
-- of lava rock, stone, obsidian, and metal when they come into contact".
-- Where lava meets water or brine, beside it or on it, the LAVA's block
-- quenches: its fluid is gone and the block is solid, each of its 27 cells
-- one of the four by a hash of the block's place (the same meeting always
-- makes the same block). The engine reports a flow into a block of
-- ANOTHER fluid, and names it, since its solver change of this date;
-- before it the two lay side by side untold. The water is left as it was.
local LAVA = "tiamat_default_world:lava"
local QUENCHES = { ["tiamat_default_world:water"] = true, ["tiamat_default_world:brine"] = true }
-- Shares of the 27 cells, out of 20: lava rock 8, stone 5, obsidian 5, metal 2.
local QUENCH = {
    { "tiamat_default_world:stone", 5 },
    { "tiamat_default_world:obsidian", 5 },
    { "tiamat_default_world:metal", 2 },
}
local QUENCH_BASE = "tiamat_default_world:lava_rock"
local QUENCH_OF = 20

local function quench(pos)
    game.set_fluid(pos, { volume = 0 })
    game.set_block(pos, QUENCH_BASE)
    local h = (pos.x * 73856093) ~ (pos.y * 19349663) ~ (pos.z * 83492791)
    local masks = { 0, 0, 0 }
    for cell = 0, 26 do
        h = (h * 6364136223846793005 + 1442695040888963407) & 0x7fffffffffffffff
        local roll = (h >> 33) % QUENCH_OF
        local acc = QUENCH_OF - 12                      -- the first 8 of 20 stay lava rock
        for k, entry in ipairs(QUENCH) do
            if roll >= acc and roll < acc + entry[2] then
                masks[k] = masks[k] | (1 << cell)
            end
            acc = acc + entry[2]
        end
    end
    for k, entry in ipairs(QUENCH) do
        if masks[k] ~= 0 then
            game.set_block(pos, entry[1], masks[k], MERGE)
        end
    end
end

game.register_on_fluid_flow(function(event)
    if tdw.harmless_fluids[event.fluid] then
        return
    end
    if event.block == LEAVES then
        game.set_block(event.into, "engine:air")
        return
    end
    -- `meets` (engine, 2026-09-16) names the other fluid when one is in the
    -- way; an older engine never reports a meeting, and sends no `meets`.
    if tdw.harmless_fluids[event.meets or ""] then
        return
    end
    if event.fluid == LAVA and QUENCHES[event.meets or ""] then
        quench(event.from)
    elseif event.meets == LAVA and QUENCHES[event.fluid] then
        quench(event.into)
    end
end)
