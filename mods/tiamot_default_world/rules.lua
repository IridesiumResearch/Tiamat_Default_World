-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- Rules of the world that are not one biome's.
--
-- Water and plants: running water breaks the plants a body walks through
-- (grass, ferns, flowers), below.
--
-- Leaves and water. Leaves placed into water, or against it, fall apart:
-- the placement is refused and the player keeps them. Water that reaches
-- a leaves block breaks it, and what it was is gone. The engine CAN drop it
-- as an item there, `game.spawn_entity{ item = stack }` (core_gear is the
-- worked example; engine-asks 11, answered 2026-09-11); not wired in yet.

local blocks = tdw.blocks
local LEAVES = "tiamot_default_world:oak_leaves"
-- Fluids another mod has asked this one to ignore (exports.lua,
-- `add_harmless_fluid`: Weather's rainwater). They break no leaves and
-- quench no lava — that mod makes steam of its own where they meet.
tdw.harmless_fluids = {}
local MERGE = { merge = true }

local function wet(x, y, z)
    local f = game.get_fluid{ x = x, y = y, z = z }
    return f ~= nil and not f.empty
end

-- Water washing plants away: places the fluid hook noted, a few a tick,
-- each swept WASH_R round on its own level and the one under it. A
-- washable plant with water in its block goes; the water stays. The queue
-- is bounded and forgets its oldest: running water keeps reporting, so a
-- place missed now comes round again.
local WASH_R, WASH_PER_TICK, WASH_QUEUE = 3, 12, 256
local pending, seen = {}, {}
local function note_wash(pos)
    local key = pos.x .. ":" .. pos.y .. ":" .. pos.z
    if seen[key] then
        return
    end
    if #pending >= WASH_QUEUE then
        seen[table.remove(pending, 1).key] = nil
    end
    seen[key] = true
    pending[#pending + 1] = { x = pos.x, y = pos.y, z = pos.z, key = key }
end
local function wash_round(c)
    local q = { x = 0, y = 0, z = 0 }
    for dy = 0, -1, -1 do
        for dx = -WASH_R, WASH_R do
            for dz = -WASH_R, WASH_R do
                q.x, q.y, q.z = c.x + dx, c.y + dy, c.z + dz
                local b = game.get_block(q)
                if b and tdw.washes_away[b.material] and wet(q.x, q.y, q.z) then
                    game.set_block({ x = q.x, y = q.y, z = q.z }, "engine:air")
                end
            end
        end
    end
end
tdw.on_tick(function()
    for _ = 1, math.min(WASH_PER_TICK, #pending) do
        local c = table.remove(pending, 1)
        seen[c.key] = nil
        wash_round(c)
    end
end)

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
local LAVA = "tiamot_default_world:lava"
local QUENCHES = { ["tiamot_default_world:water"] = true, ["tiamot_default_world:brine"] = true }
-- Shares of the 27 cells, out of 20: lava rock 8, stone 5, obsidian 5, metal 2.
local QUENCH = {
    { "tiamot_default_world:stone", 5 },
    { "tiamot_default_world:obsidian", 5 },
    { "tiamot_default_world:metal", 2 },
}
local QUENCH_BASE = "tiamot_default_world:lava_rock"
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
    -- Grass and the other plants a body walks through (2026-09-18, "Grass
    -- should probably get broken by water"). A tuft is a few cells of its
    -- block, so water is let INTO it and no flow into it is ever refused:
    -- the engine has nothing to report about the plant itself. What it
    -- does report, while water is moving, is the water's edge pressing
    -- sideways on whatever stops it (measured: a flood over a meadow, 1,208
    -- reports in fifteen seconds, all sideways, none from a plant's block).
    -- And this hook cannot READ the world (every `get_block` in it is nil),
    -- only queue writes. So the report's place is noted here and washed on
    -- the next tick (below). Engine-asks 37 is the direct way.
    if event.fluid ~= LAVA then
        note_wash(event.from)
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
