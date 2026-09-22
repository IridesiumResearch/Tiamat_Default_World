-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- One of each engine hook for the whole mod, with subscribers.
--
-- The engine keeps ONE callback per hook per mod: a second `register_on_chat`
-- is refused at load, and a second `register_on_tick` quietly replaces the
-- first — which is how the edit queue's drain stopped running the day the
-- player file registered its own tick after it, and no tree was placed for
-- two days. So every file that wants a tick or a chat word subscribes here,
-- and this file holds the engine's one registration of each.

local M = {}
local ticks = {}

-- **Every terraced fluid fill goes through here** (2026-09-22). The engine
-- reads a fill's `within` on the one plane y = 0.5 for the whole world, and
-- a chunk where that plane says "no water" while the chunk's own heights
-- might say "some" used to be skipped in silence; since engine ask 35 was
-- answered it is an ERROR, and an error in generation disables the mod
-- everywhere. The plane is still the answer for every column either way (it
-- is what keeps two layers of one column agreeing), so the mod takes the
-- error as the "no water here" it replaced, counts it, and says so now and
-- then. Most of the mod's regions carry a noise or a biome mask stretched
-- tall rather than truly flat, and their edges are where this happens.
-- Any other error is raised as before.
local terraced_skips, terraced_logged = {}, 0
function tdw.fill_terraced(buf, spec, name)
    local ok, err = pcall(buf.fill_fluid_terraced, buf, spec)
    if ok then
        return err
    end
    if not tostring(err):find("reads `within`", 1, true) then
        error(err, 0)
    end
    name = name or "?"
    terraced_skips[name] = (terraced_skips[name] or 0) + 1
    terraced_logged = terraced_logged + 1
    if terraced_logged == 1 or terraced_logged % 256 == 0 then
        local parts = {}
        for k, v in pairs(terraced_skips) do parts[#parts + 1] = k .. " " .. v end
        table.sort(parts)
        game.log("tiamot_default_world: terraced fills skipped where `within` reads height: " .. table.concat(parts, ", "))
    end
    return 0
end
local commands, command_order = {}, {}

-- Runs `fn(dt_ticks)` every tick, after everything subscribed before it.
---@param fn fun(dt_ticks: integer)
function tdw.on_tick(fn)
    ticks[#ticks + 1] = fn
end

-- A chat COMMAND: `/name args...` (2026-09-14: "have all the commands for
-- this mod standardized with a / beforehand"). `fn(player, args)` gets the
-- speaker's UUID and the words after the name, and the line is swallowed.
-- The name is matched case-insensitively. `usage` is what `/help` prints.
--
-- **A command answers.** The engine's chat hook takes `false` to mean "this
-- line is not going anywhere" and tells the speaker so — which comes out as
-- "a mod refused that message", and reads as an error when it was a command
-- being obeyed. A STRING stops the line the same way and shows the speaker
-- that string instead, so every command returns one: what it did, or why
-- it could not.
---@param name string
---@param usage string
---@param fn fun(player: string, args: string[]): string?
function tdw.on_command(name, usage, fn)
    name = string.lower(name)
    assert(not commands[name], "command registered twice: /" .. name)
    commands[name] = { fn = fn, usage = usage }
    command_order[#command_order + 1] = name
end

tdw.on_command("help", "/help — these commands", function()
    local lines = {}
    for _, name in ipairs(command_order) do
        lines[#lines + 1] = commands[name].usage
    end
    return table.concat(lines, "\n")
end)

-- The world pre-pass (engine `game.register_on_world_init`, ONE per mod:
-- a second registration replaces the first, which is how the seas' maps
-- went unbuilt on 2026-09-15): every file that builds maps subscribes here,
-- in load order.
local inits = nil
function tdw.on_world_init(fn)
    if inits == nil then
        inits = {}
        game.register_on_world_init(function()
            for _, each in ipairs(inits) do
                each()
            end
        end)
    end
    inits[#inits + 1] = fn
end

-- A chunk's tint (engine `game.register_chunk_tint`, one per mod, as the
-- fog): the first subscriber to answer a chunk with a colour speaks for it;
-- the rest of the world is white.
local tints = nil
function tdw.on_chunk_tint(fn)
    if tints == nil then
        tints = {}
        game.register_chunk_tint(function(pos)
            for _, each in ipairs(tints) do
                local r, g, b = each(pos)
                if r ~= nil then
                    return r, g, b
                end
            end
            return 1.0, 1.0, 1.0
        end)
    end
    tints[#tints + 1] = fn
end

-- A chunk's fog (engine `game.register_chunk_fog`, one per mod): every
-- biome that wants mist subscribes here, and the first to answer a chunk
-- with a table speaks for it. Nil where the engine has no fog.
local fogs = nil
if game.register_chunk_fog then
    function tdw.on_chunk_fog(fn)
        if fogs == nil then
            fogs = {}
            game.register_chunk_fog(function(pos)
                for _, each in ipairs(fogs) do
                    local answer = each(pos)
                    if answer ~= nil then
                        return answer
                    end
                end
                return nil
            end)
        end
        fogs[#fogs + 1] = fn
    end
end

-- Runs `fn(x, y, z)` when a block of `material` gets a random tick, until
-- one subscriber returns true — two biomes share the grass block, and each
-- takes only the ticks on its own ground.
local random_ticks = {}
---@param material integer
---@param fn fun(x: integer, y: integer, z: integer): boolean?
function tdw.on_random_tick(material, fn)
    local list = random_ticks[material]
    if list == nil then
        list = {}
        random_ticks[material] = list
        game.register_random_tick(material, function(event)
            for _, f in ipairs(list) do
                if f(event.x, event.y, event.z) then
                    return
                end
            end
        end)
    end
    list[#list + 1] = fn
end

-- Completed digs, for anything that wants a say: the first non-nil answer
-- is the mod's answer (the engine's ladder: false, a reason, or "" to
-- cancel quietly having handled it yourself).
local digs = {}
function tdw.on_dig_complete(fn)
    digs[#digs + 1] = fn
end
game.register_on_dig_complete(function(event)
    for _, fn in ipairs(digs) do
        local answer = fn(event)
        if answer ~= nil then
            return answer
        end
    end
end)

-- Each subscriber under a pcall so a failure is LOGGED with its message:
-- the engine disables the mod on a tick error and says only that it
-- happened. The error is re-raised, so the outcome is the engine's.
game.register_on_tick(function(dt_ticks)
    for _, fn in ipairs(ticks) do
        local ok, err = pcall(fn, dt_ticks)
        if not ok then
            game.log("tiamot_default_world: tick failed: " .. tostring(err))
            error(err, 0)
        end
    end
end)

-- A line that starts with `/` and names one of this mod's commands runs it.
-- Anything else — plain chat, or a `/command` this mod does not have — is
-- left alone, so another mod's commands still reach it.
game.register_on_chat(function(event)
    local name, rest = string.match(event.text, "^%s*/(%S+)%s*(.-)%s*$")
    if name == nil then
        return
    end
    local command = commands[string.lower(name)]
    if command == nil then
        return
    end
    local args = {}
    for word in string.gmatch(rest, "%S+") do
        args[#args + 1] = word
    end
    local ok, reply = pcall(command.fn, event.player, args)
    if not ok then
        game.log("tiamot_default_world: the command `" .. event.text .. "` errored: " .. tostring(reply))
        return "that did not work — the log says why"
    end
    return type(reply) == "string" and reply or "done"
end)

return M
