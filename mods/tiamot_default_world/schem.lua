-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- Schematic helpers any biome can use: ellipsoids of a material written
-- into the world, merged, and ellipsoids of air carved out of it.
--
-- Everything is plain + - * / and comparisons on the cell lattice, nothing
-- from a library, and everything pushes into the current `tdw.edits` batch
-- — the caller owns the batch.

local M = {}
tdw.schem = M

local edits = tdw.edits
local FULL = game.OCCUPANCY_FULL
-- What a blind push (`opts.blind`) reads instead of the world: nothing
-- there, so every block of the shape is pushed. For a schematic at load.
local BLIND = { occupancy = 0 }

function M.at(x, y, z)
    return game.get_block{ x = x, y = y, z = z }
end

-- Bit for cell (cx, cy, cz), each 0..2, indexed x + 3*y + 9*z.
function M.bit(cx, cy, cz)
    return 1 << (cx + 3 * cy + 9 * cz)
end

-- **Recording.** Between `record_begin` and `record_schematic`, the pushes
-- below write nothing: each appends its SHAPE to a list, and
-- `record_schematic` has the engine cut the list natively
-- (`game.schematic_shapes`, 2026-09-14). The same tree code makes a
-- schematic either way; a rainforest megatree cut cell by cell in Lua was
-- past a generator call's instruction budget before the second one.
-- `jitter` and `carve` mean nothing to a recording.
M.recording = nil
local function id_of(material)
    return type(material) == "number" and material or game.get_block_id(material)
end
function M.record_begin()
    M.recording = {}
end
-- The recorded shapes as a schematic. `priorities` maps a material id to its
-- priority (default 0): a cell takes the highest-priority shape's material,
-- the later shape winning a tie.
function M.record_schematic(priorities)
    local list = M.recording
    M.recording = nil
    for _, shape in ipairs(list) do
        shape.priority = priorities[shape.material] or 0
    end
    return game.schematic_shapes(list)
end

local function hash(x, y, z)
    local h = (x * 73856093) ~ (y * 19349663) ~ (z * 83492791) ~ ((tdw.seed_int or 0) * 2654435761)
    return h ~ (h >> 17)
end
M.hash = hash

-- Sixteen headings round the compass, as unit vectors: the only way a
-- direction is turned here, since there is no trigonometry in Lua that
-- charter rule 4 allows. Heading k is k sixteenths of a turn.
M.DIR16 = {
    { 1.0, 0.0 }, { 0.9239, 0.3827 }, { 0.7071, 0.7071 }, { 0.3827, 0.9239 },
    { 0.0, 1.0 }, { -0.3827, 0.9239 }, { -0.7071, 0.7071 }, { -0.9239, 0.3827 },
    { -1.0, 0.0 }, { -0.9239, -0.3827 }, { -0.7071, -0.7071 }, { -0.3827, -0.9239 },
    { 0.0, -1.0 }, { 0.3827, -0.9239 }, { 0.7071, -0.7071 }, { 0.9239, -0.3827 },
}

-- The mask of the cells of block (bx, by, bz) inside an ellipsoid centred at
-- (cx, cy, cz) with half-widths (rx, ry, rz). `rough`, if given, nudges the
-- edge per cell by up to that much either way from the integer hash of the
-- cell, so the surface is ragged at the cell rather than clean.
function M.ellipsoid_mask(bx, by, bz, cx, cy, cz, rx, ry, rz, rough)
    local mask = 0
    for iz = 0, 2 do
        local dz = (bz + (iz + 0.5) / 3 - cz) / rz
        for iy = 0, 2 do
            local dy = (by + (iy + 0.5) / 3 - cy) / ry
            for ix = 0, 2 do
                local dx = (bx + (ix + 0.5) / 3 - cx) / rx
                local edge = 1.0
                if rough then
                    edge = 1.0 + rough * ((hash(bx * 3 + ix, by * 3 + iy, bz * 3 + iz) % 9) - 4) / 4
                end
                if dx * dx + dy * dy + dz * dz <= edge then
                    mask = mask | M.bit(ix, iy, iz)
                end
            end
        end
    end
    return mask
end

-- An ellipsoid of `material`, merged: its cells become the material and
-- every other cell keeps what it held. Whole blocks are left alone unless
-- `opts.over_whole` — nothing of a buried thing shows there. With
-- `opts.carve` the material should be air and the ellipsoid is taken OUT
-- of whatever is there, whole blocks included. `opts.rough` as above;
-- `opts.jitter` is a stream and scales each block's part by 0.8 .. 1.1.
---@param opts { rough: number?, jitter: Tiamot.Stream?, carve: boolean?, over_whole: boolean? }?
function M.push_ellipsoid(material, cx, cy, cz, rx, ry, rz, opts)
    opts = opts or {}
    if M.recording then
        M.recording[#M.recording + 1] = { kind = "ellipsoid", material = id_of(material),
            centre = { cx, cy, cz }, radii = { rx, ry, rz }, rough = opts.rough }
        return
    end
    for bz = math.floor(cz - rz), math.floor(cz + rz) do
        for by = math.floor(cy - ry), math.floor(cy + ry) do
            for bx = math.floor(cx - rx), math.floor(cx + rx) do
                local scale = 1.0
                if opts.jitter then
                    scale = 0.8 + opts.jitter:below(7) / 20
                end
                local mask = M.ellipsoid_mask(bx, by, bz, cx, cy, cz, rx * scale, ry * scale, rz * scale, opts.rough)
                if mask ~= 0 then
                    local b = opts.blind and BLIND or M.at(bx, by, bz)
                    if b ~= nil then
                        if opts.carve then
                            mask = mask & b.occupancy
                            if mask ~= 0 then
                                edits.push({ x = bx, y = by, z = bz }, material, mask, true)
                            end
                        elseif opts.over_whole or b.occupancy ~= FULL then
                            edits.push({ x = bx, y = by, z = bz }, material, mask, true)
                        end
                    end
                end
            end
        end
    end
end

-- **A trunk is a path with a thickness, not a stack of blocks.** Give a
-- list of points — `{ x, y, z, r }` each, in blocks, `r` the radius there —
-- and every cell within `r` of the line through them becomes the material,
-- with the radius carried smoothly from one point to the next. A trunk
-- tapers because its last point is thinner than its first; a branch leaves
-- at whatever angle its points do; a frond droops because its points do.
-- Stacked blocks can do none of that, which is why a palm built out of them
-- looked like a signpost.
--
-- The distance from a cell to a segment, and nothing else: `t` is how far
-- along the segment the nearest point is, clamped into it so the ends are
-- round caps, and everything stays squared so there is no root to take.
-- Plain + - * / and comparisons, as the rest of this file is.
local function segment_mask(bx, by, bz, ax, ay, az, dx, dy, dz, len2, r0, dr, rough)
    local mask = 0
    for iz = 0, 2 do
        local pz = bz + (iz + 0.5) / 3 - az
        for iy = 0, 2 do
            local py = by + (iy + 0.5) / 3 - ay
            for ix = 0, 2 do
                local px = bx + (ix + 0.5) / 3 - ax
                local t = 0.0
                if len2 > 0.0 then
                    t = (px * dx + py * dy + pz * dz) / len2
                    if t < 0.0 then t = 0.0 elseif t > 1.0 then t = 1.0 end
                end
                local ex, ey, ez = px - dx * t, py - dy * t, pz - dz * t
                local r = r0 + dr * t
                if rough then
                    r = r * (1.0 + rough * ((hash(bx * 3 + ix, by * 3 + iy, bz * 3 + iz) % 9) - 4) / 4)
                end
                if ex * ex + ey * ey + ez * ez <= r * r then
                    mask = mask | M.bit(ix, iy, iz)
                end
            end
        end
    end
    return mask
end

-- A path of `material`, merged, one push per block however many segments
-- cross it. `opts` is `push_ellipsoid`'s: `rough`, `carve`, `over_whole`,
-- `blind`.
---@param points number[][] `{ x, y, z, r }` each, in blocks
---@param opts { rough: number?, carve: boolean?, over_whole: boolean?, blind: boolean? }?
function M.push_path(material, points, opts)
    opts = opts or {}
    if #points < 2 then
        return
    end
    if M.recording then
        M.recording[#M.recording + 1] = { kind = "path", material = id_of(material), points = points, rough = opts.rough }
        return
    end
    -- Gathered per block first: two segments meeting at a point cover the
    -- same blocks, and a schematic that names one block twice is a
    -- schematic half again as big for nothing.
    local masks, order = {}, {}
    for i = 1, #points - 1 do
        local a, b = points[i], points[i + 1]
        local ax, ay, az, r0 = a[1], a[2], a[3], a[4]
        local dx, dy, dz = b[1] - ax, b[2] - ay, b[3] - az
        local dr = b[4] - r0
        local len2 = dx * dx + dy * dy + dz * dz
        local reach = (r0 > b[4] and r0 or b[4]) * (opts.rough and 1.6 or 1.05) + 0.5
        local lo = function(p, q) return math.floor((p < q and p or q) - reach) end
        local hi = function(p, q) return math.floor((p > q and p or q) + reach) end
        for cz = lo(az, b[3]), hi(az, b[3]) do
            for cy = lo(ay, b[2]), hi(ay, b[2]) do
                for cx = lo(ax, b[1]), hi(ax, b[1]) do
                    -- **The block before its cells.** Most blocks in a
                    -- segment's box are nowhere near the segment — a trunk is
                    -- slender and its box is not — and testing twenty-seven
                    -- cells to find that out cost a tree a quarter of a
                    -- million tests and the VM its instruction budget. The
                    -- block's centre against the segment, plus half a block's
                    -- diagonal, rejects them for ten.
                    local px, py, pz = cx + 0.5 - ax, cy + 0.5 - ay, cz + 0.5 - az
                    local t = 0.0
                    if len2 > 0.0 then
                        t = (px * dx + py * dy + pz * dz) / len2
                        if t < 0.0 then t = 0.0 elseif t > 1.0 then t = 1.0 end
                    end
                    local ex, ey, ez = px - dx * t, py - dy * t, pz - dz * t
                    local near = reach + 0.867
                    local mask = 0
                    if ex * ex + ey * ey + ez * ez <= near * near then
                        mask = segment_mask(cx, cy, cz, ax, ay, az, dx, dy, dz, len2, r0, dr, opts.rough)
                    end
                    if mask ~= 0 then
                        local key = cx .. ":" .. cy .. ":" .. cz
                        if masks[key] == nil then
                            order[#order + 1] = { cx, cy, cz, key }
                            masks[key] = mask
                        else
                            masks[key] = masks[key] | mask
                        end
                    end
                end
            end
        end
    end
    for _, at in ipairs(order) do
        local bx, by, bz, key = at[1], at[2], at[3], at[4]
        local mask = masks[key]
        local b = opts.blind and BLIND or M.at(bx, by, bz)
        if b ~= nil then
            if opts.carve then
                mask = mask & b.occupancy
                if mask ~= 0 then
                    edits.push({ x = bx, y = by, z = bz }, material, mask, true)
                end
            elseif opts.over_whole or b.occupancy ~= FULL then
                edits.push({ x = bx, y = by, z = bz }, material, mask, true)
            end
        end
    end
end

-- The point on a path at height `h`: between the two points that bracket
-- it, the radius too. For a branch leaving a trunk at a height.
function M.path_point(points, h)
    for i = 2, #points do
        local a, b = points[i - 1], points[i]
        if h <= b[2] or i == #points then
            local t = b[2] ~= a[2] and (h - a[2]) / (b[2] - a[2]) or 0.0
            if t < 0.0 then t = 0.0 elseif t > 1.0 then t = 1.0 end
            return a[1] + (b[1] - a[1]) * t, h, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t
        end
    end
    local p = points[1]
    return p[1], p[2], p[3], p[4]
end

-- The current edit batch, TAKEN rather than queued, as a plain list:
-- `{dx, dy, dz, material id, mask}` each. A shape pushed blind at a root of
-- (0, 0, 0) comes back as a structure to stamp.
function M.capture()
    local out = {}
    for _, e in ipairs(edits.take()) do
        local at, material, mask = e[1], e[2], e[3]
        local id = type(material) == "number" and material or game.get_block_id(material)
        out[#out + 1] = { at.x, at.y, at.z, id, mask or FULL }
    end
    return out
end

-- One entry per block and material, WOOD FIRST, and nothing else in a cell
-- the wood holds: a clump of leaves pushed over a branch's tip took the
-- branch's cells, since a merge write takes every cell it names. `woody` is
-- a set of material ids. Each entry gains a sixth field, whether it is wood.
function M.merged(list, woody)
    local order, by_block = {}, {}
    for _, e in ipairs(list) do
        local key = e[1] .. ":" .. e[2] .. ":" .. e[3]
        local masks = by_block[key]
        if masks == nil then
            masks = {}
            by_block[key] = masks
            order[#order + 1] = { e[1], e[2], e[3], masks }
        end
        masks[e[4]] = (masks[e[4]] or 0) | e[5]
    end
    local out = {}
    for _, o in ipairs(order) do
        local masks, wood = o[4], 0
        local ids = {}
        for id in pairs(masks) do ids[#ids + 1] = id end
        table.sort(ids)
        for _, id in ipairs(ids) do
            if woody[id] then
                wood = wood | masks[id]
                out[#out + 1] = { o[1], o[2], o[3], id, masks[id], true }
            end
        end
        for _, id in ipairs(ids) do
            local rest = masks[id] & ~wood
            if not woody[id] and rest ~= 0 then
                out[#out + 1] = { o[1], o[2], o[3], id, rest, false }
            end
        end
    end
    return out
end

-- A list of `{dx, dy, dz, material id, mask, ...}` as a schematic for the
-- scatter.
function M.schematic_of(list)
    local out = {}
    for i, e in ipairs(list) do
        out[i] = { e[1], e[2], e[3], e[4], e[5] }
    end
    return game.schematic(out)
end

-- The current batch as a schematic, taken rather than queued.
function M.schematic_of_batch()
    return M.schematic_of(M.capture())
end

-- The named cells of one block, merged; recorded as cells when recording.
function M.push_cells(material, x, y, z, mask)
    if M.recording then
        M.recording[#M.recording + 1] = { kind = "cells", material = id_of(material), at = { x, y, z }, mask = mask }
        return
    end
    edits.push({ x = x, y = y, z = z }, material, mask, true)
end

-- Whether every chunk a box touches is loaded — `at` is nil in one that is
-- not, and an edit into one is dropped. Sampled every eight blocks.
function M.loaded_box(x0, y0, z0, x1, y1, z1)
    local function steps(a, b)
        local out = {}
        for v = a, b, 8 do out[#out + 1] = v end
        out[#out + 1] = b
        return out
    end
    for _, sx in ipairs(steps(x0, x1)) do
        for _, sy in ipairs(steps(y0, y1)) do
            for _, sz in ipairs(steps(z0, z1)) do
                if M.at(sx, sy, sz) == nil then
                    return false
                end
            end
        end
    end
    return true
end

-- Between two bounds, inclusive, from the stream: { least, extra }.
function M.pick(rng, range)
    return range[1] + rng:below(range[2] + 1)
end

return M
