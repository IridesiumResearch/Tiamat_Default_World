# SPDX-FileCopyrightText: Iridesium
# SPDX-License-Identifier: GPL-3.0-only
"""Generates the textures for mods/tiamot_default_world/textures.

One flat colour per block — nothing else, by design: any variation across a
surface is the renderer's (tint, and per-cell value jitter once the engine
has it), never baked into a picture. No dependencies beyond the standard
library; run it from the repository root:

    python tools/make_textures.py
"""
import struct
import zlib
from pathlib import Path

SIZE = 16
OUT = Path(__file__).resolve().parent.parent / "mods" / "tiamot_default_world" / "textures"

# id -> (r, g, b, grain). The grain is unused since 2026-09-10 (every texture
# is one flat colour); the column stays so old entries still parse.
#
# **The palette is Lord of the Rings.** Muted, earthy, a little grey in
# everything: moss greens rather than lime, umber soils, stone the colour of
# a Rohan hillside rock, water the dark green-blue of a Bree stream. Nothing
# saturated; the brightest thing in a scene should be light on a birch.
BLOCKS = {
    "stone":          (112, 110, 104,  0),
    "dirt":           ( 98,  78,  58,  0),
    "packed_dirt":    (124, 102,  72,  0),
    "grass":          ( 88, 122,  52,  0),
    "mud":            ( 52,  42,  34,  0),
    "gravel":      ( 96,  94,  88,  0),
    "granite":        (128, 124, 120,  0),
    "oak_log":        ( 84,  64,  44,  0),
    "oak_leaves":     ( 64, 100,  42,  0),
    "birch_log":      (206, 200, 186,  0),
    "dead_log":      (110, 102,  90,  0),
    "fern":           ( 52,  96,  54,  0),
    "tall_grass":     (116, 136,  60,  0),
    "bramble":        ( 72,  60,  44,  0),
    "ladys_mantle":       ( 96, 124,  70,  0),
    "ladys_mantle_bloom": (172, 176,  92,  0),
    "blue_lunaria":   (112, 122, 204,  0),   # the meadow flowers (2026-09-14)
    "roman_chamomile":(238, 234, 214,  0),
    "rose_bush":      ( 58,  90,  46,  0),
    "slate":          ( 72,  78,  90,  0),
    "dark_sediment":  ( 62,  64,  74,  0),   # the gloam's rock (2026-09-16)
    "light_sediment": (150, 146, 134,  0),
    "dark_basalt":    ( 44,  44,  48,  0),
    "dead_coral":     (178, 166, 150,  0),
    "sand":           (194, 180, 138,  0),
    "ocean_moss":     ( 40,  78,  62,  0),
    "barnacles":      (170, 166, 154,  0),
    "seagrass":       ( 66, 118,  58,  0),
    "willow_log":    ( 92,  82,  66,  0),
    "willow_leaves":  ( 96, 124,  62,  0),
    "willow_planks":  (176, 156, 120,  0),
    "water_iris":     ( 74, 116,  64,  0),
    "wild_mint":      ( 86, 126,  78,  0),
    "kelp":           ( 96, 104,  40,  0),
    "moss":           ( 70, 102,  54,  0),   # the rainforest (1.7): a deep wet green
    "black_mud":      ( 34,  30,  28,  0),
    "ironwood_log":   ( 62,  46,  40,  0),
    "ironwood_leaves":( 42,  78,  48,  0),
    "ironwood_planks":(122,  84,  62,  0),
    "climbing_ivy":   ( 60,  98,  52,  0),
    "monstera":       ( 58, 106,  56,  0),
    "pitcher_plant":  (122,  98,  56,  0),   # green going to red-brown at the mouths
    "kapok_log":     (170, 164, 150,  0),
    "kapok_leaves":   ( 86, 122,  58,  0),
    "kapok_planks":   (196, 180, 150,  0),
    "dry_clay":       (170, 142, 112,  0),
    "bone":           (214, 204, 182,  0),
    "clear_ice":      (196, 226, 240,  0),   # the frozen wastes (1.9): a cryo-lake's clear top
    "rust_red_sandstone": (146, 74, 52, 0),   # the arid mesa (2.0)
    "ochre_sandstone": (178, 132, 70,  0),
    "pale_terracotta": (198, 158, 128, 0),
    "juniper_log":   (128, 122, 112,  0),
    "juniper_needles":( 44,  66,  50,  0),
    "cactus":( 84, 112,  68,  0),
    "mulch":          (112,  70,  46,  0),   # the taiga (2.2)
    "volcanic_ash":   (196, 192, 184,  0),   # the badlands (2.1)
    "lava_rock":      ( 52,  44,  46,  0),   # the volcanic foothills (2.3)
    "pumice":         (178, 172, 162,  0),
    "sulfur":         (226, 184,  62,  0),
    "white_sand":     (226, 218, 198,  0),   # the coral shallows (2.4)
    "calcite":        (204, 202, 194,  0),
    "pink_algae":     (206,  96, 128,  0),
    "coral_magenta":  (176,  52, 118,  0),
    "coral_cyan":     ( 46, 156, 164,  0),
    "coral_amber":    (206, 140,  46,  0),
    "apple_log":     ( 96,  76,  56,  0),   # the flower forest (2.6)
    "apple_leaves":   ( 76, 110,  52,  0),
    "apple_blossom":  (238, 216, 220,  0),
    "cherry_log":    ( 84,  62,  58,  0),
    "cherry_leaves":  (222, 140, 168,  0),   # pink, not green (2026-09-16)
    "cherry_blossom": (232, 168, 186,  0),
    "birch_leaves":   (112, 148,  68,  0),
    "allium":         (150, 116, 188,  0),
    "peony":          (214, 128, 156,  0),
    "poppy":          (178,  54,  48,  0),
    "bluebell":       ( 94, 106, 190,  0),
    "lichen":         (158, 170, 142,  0),   # the Silverwood floor (2.8)
    "salt":           (234, 232, 224,  0),   # the Salt Pan (2.9)
    "obsidian":       ( 24,  20,  30,  0),   # the Obsidian Barrens (3.3)
    "dark_sand":     ( 40,  38,  42,  0),   # the Cinder Coast (3.5)
    "heather":        (150,  84, 150,  0),   # the Heather Moor (3.6)
    "acacia_log":    ( 88,  70,  56,  0),
    "acacia_leaves":  (104, 120,  56,  0),
    "reeds":          (134, 128,  78,  0),   # the Peat Fen (3.13)
    "redwood_log":    (128,  64,  46,  0),   # the Redwood Stands (3.14)
    "redwood_needles": ( 46,  82,  52,  0),
    "glow_polyp":     (150, 220, 240,  0),
    "mangrove_log":  ( 96,  62,  48,  0),   # the Mangrove Coast (3.10)
    "mangrove_leaves": ( 52,  92,  48,  0),
    "gorse":          (168, 160,  52,  0),
    "lava":           (214,  84,  22,  0),   # the fluid's block
    "metal":          (150, 124,  92,  0),   # quenched lava's beads (2026-09-16): dull raw bronze
    "glow_cap":       (150, 224, 226,  0),   # the river's mushrooms (2026-09-15)
    "charcoal":       ( 58,  56,  60,  0),
    "dried_mud":      (148, 132, 148,  0),
    "dead_sagebrush": (138, 128, 110,  0),   # the deep ocean (1.8): old, sea-stained bone
    "wet_clay":       (112,  90,  74,  0),
    "permafrost":     (118, 108,  98,  0),
    "snow":           (228, 232, 236,  0),
    "ice":            (126, 172, 228,  0),   # cold blue (2026-09-12; was a grey-blue near the snow's)
    "fir_log":        ( 68,  56,  46,  0),
    "fir_needles":    ( 40,  68,  54,  0),
    "rose_blooms":    (176,  42,  64,  0),
    "water":          ( 58,  92, 110,  0),
    "morphic_rock":    ( 40,  38,  44,  0),
    "magma_crust":    ( 96,  44,  30,  0),
    "magma":          (222, 112,  28,  0),
    "hot_fiber_stone":  (196, 168, 112,  0),
    "caul":           (112, 176, 104,  0),
    "cold_fiber_stone":    (140, 176, 200,  0),
    "scorch":         ( 66,  48,  36,  0),
    "marrow":         (214, 206, 190,  0),
    "apex_stone":     ( 54,  36,  62,  0),
    # The ores (2026-09-17), muted like the rest: metals a shade off the
    # stone they sit in, the coal near-black, the diamond a cold pale blue.
    "copper_ore":     (140,  96,  66,  0),
    "iron_ore":       (122,  96,  86,  0),
    "flint":          ( 56,  54,  58,  0),
    "coal":           ( 34,  32,  34,  0),
    "tin_ore":        (160, 162, 158,  0),
    "silver_ore":     (190, 194, 200,  0),
    "chromium_ore":   (134, 150, 152,  0),
    "lead_ore":       ( 90,  92, 106,  0),
    "gold_ore":       (196, 160,  74,  0),
    "diamond":        (172, 212, 220,  0),
    "orichalcum":     (196, 128,  84,  0),
    # The normal caves (2026-09-18).
    "maidenhair":     (108, 150,  92,  0),
    "crystal":        (196, 214, 226,  0),
    "cobbles":        (118, 108,  96,  0),
    "glow_algae":     ( 52, 120,  74,  0),
}

# Textures the designer drew by hand (2026-09-17): never overwritten here.
# Add a name to this set when a hand-made picture replaces a flat colour.
HAND_MADE = {
    "acacia_leaves", "apple_leaves", "birch_leaves", "cherry_blossom", "cherry_leaves",
    "fir_needles", "ironwood_leaves", "kapok_leaves", "mangrove_leaves", "oak_leaves",
    "willow_leaves",
}

# Alpha per texture; everything not listed is opaque.
ALPHA = {
    "crystal": 150,
    "water": 150,
    "clear_ice": 120,
}

# Foliage: the share of pixels that are HOLES. A block face is three cells
# across; each cell's face is split into a 3x3 of pixels and each pixel is
# fully opaque or fully gone, at random, from a stream seeded by the name.
# Binary alpha on purpose — the client alpha-tests foliage at 0.5, so there
# is nothing to sort and nothing to blend. At the 16-pixel tile a cell is 5
# or 6 pixels wide, so each of the nine is about two pixels.
HOLES = {
    "bramble": 0.50,
}
CELL_EDGES = [0, 5, 11, 16]     # the three cells across a 16-pixel face

# Leaves as ROUND DOTS: one pixel-circle per sub-node face, a little smaller
# than the cell so its corners are open, with the centre nudged and the
# radius varied per cell so the pattern does not repeat across a canopy.
# Read as round leaf clusters at a distance and as a cloud of dots up close,
# in the game's crisp style rather than a painterly one. Binary alpha.
# name -> (radius in pixels, radius jitter, centre jitter)
# The willow's leaves are the dot look, finer and denser than an oak's: a
# curtain read close up is many small leaves, not a few big ones.
DOTS_EXTRA = {"willow_leaves": (2.1, 0.5, 0.8)}
DOTS = {
    "oak_leaves": (2.6, 0.4, 0.6),
    "rose_bush": (2.9, 0.4, 0.5),   # a denser, rounder leaf than the oak's
    "gorse": (2.2, 0.5, 0.7),       # small dense spiny clumps (3.6)
    "mangrove_leaves": (2.5, 0.4, 0.6),  # thick glossy leaves (3.10)
    "acacia_leaves": (2.0, 0.4, 0.7),    # small leaves in flat pads (3.11)
    "redwood_needles": (1.9, 0.5, 0.7),  # fine sprays (3.14)
    "fir_needles": (2.3, 0.5, 0.7), # smaller, more scattered: needles in tufts
    "ironwood_leaves": (2.8, 0.3, 0.5),  # big, crowded: the canopy lets little through
    "climbing_ivy": (2.0, 0.5, 0.8),     # small leaves on a rope
    "kapok_leaves": (2.4, 0.5, 0.7),     # lighter and more open than the ironwood's
    "juniper_needles": (2.2, 0.6, 0.8),  # sparse, scattered
    "apple_leaves": (2.5, 0.4, 0.6),     # the flower forest's crowns (2.6)
    "cherry_leaves": (2.2, 0.5, 0.7),    # finer than the apple's
    "birch_leaves": (2.0, 0.5, 0.8),     # small and bright
    "apple_blossom": (2.8, 0.3, 0.5),    # crowded petals, not leaves
    "cherry_blossom": (2.6, 0.4, 0.5),
}

# A single round BLOOM in the middle of the tile, a little high, with a
# scalloped edge: the whole tile is one cell's card, so one flower a cell.
BLOOMS = {
    "rose_blooms": 5.2,
    "monstera": 7.0,     # one broad leaf the width of the card
    "peony": 6.0,        # the flower forest (2.6): a heavy double bloom
    "poppy": 4.0,        # one scarlet cup on a thin stem
}

# Items are PICTURES — a rose on its stem — because an item is never in the
# world; the flat-colour rule is the world's. Drawn from a few strokes.
ITEMS = {
    "rose": {"petal": (176, 42, 64), "heart": (120, 24, 44), "stem": (58, 90, 46)},
}

# Ferns as blocky FRONDS rather than dots (dots read as leaves, 2026-09-10):
# one small feather per sub-node face — a stem with leaflets either side,
# tapering to the tip — turned a random quarter per cell so a carpet of
# them fans every way. Still crisp and blocky; binary alpha.
FROND = [
    "..#..",
    ".###.",
    "..#..",
    "#####",
    "..#..",
]
FRONDS = {"fern"}

# Grass as a SPRITE: blades. The engine draws a run of billboard cells as
# one square card with the whole tile across it, and its atlas tile is
# sixteen pixels whatever the file is, so a card a block tall is sixteen
# pixels a block and a one-pixel blade is a sixteenth of a block wide —
# a blade, not a stroke. Five of them per card, one to a fifth of the tile
# and jittered inside it so they never bunch, most reaching near the top,
# each leaning and bending its own way. Binary alpha.
DOTS.update(DOTS_EXTRA)

BLADES = {
    "tall_grass": (5, 11, 16),   # blades per card; shortest, tallest in pixels
    "water_iris": (4, 12, 16),   # tall blades, few of them
    "wild_mint": (6, 5, 9),      # low and bushy
    "seagrass": (5, 12, 16),     # long, most of the card
    "kelp": (3, 14, 16),         # three broad-ish stems the height of the card
    "pitcher_plant": (3, 9, 14), # three fat tubes
    "dead_sagebrush": (7, 5, 11), # brittle, many short sticks
    "reeds": (4, 13, 16),          # tall, a few stems a card (3.13)
}

# Rosettes and sprays, for the mantle: a rosette is a few round leaves
# low in the tile, overlapping, on short stems; a spray is thin stems from
# the bottom edge ending in small dot clusters high in the tile.
ROSETTES = {
    "ladys_mantle": 5,
}
# Mushrooms as a SPRITE: a few thin stems from the bottom edge, each under
# a flat cap a few pixels wide, the tallest reaching half the tile.
CAPS = {
    "glow_cap": 3,
}
SPRAYS = {
    "ladys_mantle_bloom": 5,
    "blue_lunaria": 4,       # a few tall stems, a card a block high
    "roman_chamomile": 6,    # many short ones, a card a third of a block
    "allium": 3,             # three tall stems under globes (2.6)
    "heather": 8,            # many short wiry stems in flower (3.6)
    "glow_polyp": 3,         # a few stalks under glowing heads (3.9)
    "bluebell": 5,           # nodding bells, a card a block high
}


def lcg(seed):
    state = seed & 0xFFFFFFFF
    while True:
        state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
        yield state >> 16


def png(width, height, rows):
    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + bytes(row) for row in rows)
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b""))


def texture(name, r, g, b, grain):
    """A single flat colour. The grain and the border are gone (2026-09-10):
    the designer wants one colour per material, and the per-cell variation
    is the renderer's to do, not the texture's. Foliage additionally has
    holes: the colour never varies, only whether a pixel is there."""
    holes = HOLES.get(name)
    alpha = ALPHA.get(name, 255)
    rosette = ROSETTES.get(name)
    if rosette is not None:
        rng = lcg(sum(ord(c) * 31 ** i for i, c in enumerate(name)) + 3)
        discs = []
        for _ in range(rosette):
            mx = 3 + (next(rng) % 100) / 10                 # 3 .. 13
            my = 8 + (next(rng) % 60) / 10                  # 8 .. 14: the lower half
            rr = 2.4 + (next(rng) % 12) / 10                # 2.4 .. 3.6
            discs.append((mx, my, rr * rr))
        rows = []
        for y in range(SIZE):
            row = []
            for x in range(SIZE):
                px, py = x + 0.5, y + 0.5
                on = any((px - mx) ** 2 + (py - my) ** 2 <= r2 for mx, my, r2 in discs)
                # A scallop: the very edge of a disc is nibbled every other pixel.
                edge = any(r2 - 1.4 <= (px - mx) ** 2 + (py - my) ** 2 <= r2 for mx, my, r2 in discs)
                if edge and (x + y) % 2 == 0:
                    on = False
                row += [r, g, b, 255 if on else 0]
            rows.append(row)
        return png(SIZE, SIZE, rows)
    spray = SPRAYS.get(name)
    if spray is not None:
        rng = lcg(sum(ord(c) * 31 ** i for i, c in enumerate(name)) + 9)
        on = [[False] * SIZE for _ in range(SIZE)]
        for _ in range(spray):
            x = 4 + (next(rng) % 90) / 10                   # a stem from the bottom
            lean = ((next(rng) % 1000) / 1000 - 0.5) * 0.6
            top = 6 + next(rng) % 6                         # stem height 6 .. 11
            for i in range(top):
                bx = int(x + lean * i)
                if 0 <= bx < SIZE:
                    on[SIZE - 1 - i][bx] = True
            # The head: a small cluster of dots round the stem's top.
            hx, hy = x + lean * top, SIZE - 1 - top
            for _ in range(4 + next(rng) % 4):
                dx = ((next(rng) % 1000) / 1000 - 0.5) * 4
                dy = ((next(rng) % 1000) / 1000 - 0.5) * 3
                px, py = int(hx + dx), int(hy + dy)
                for ox in (0, 1):
                    for oy in (0, 1):
                        if 0 <= px + ox < SIZE and 0 <= py + oy < SIZE:
                            on[py + oy][px + ox] = True
        rows = [[v for x in range(SIZE) for v in (r, g, b, 255 if on[y][x] else 0)] for y in range(SIZE)]
        return png(SIZE, SIZE, rows)
    if name in FRONDS:
        rng = lcg(sum(ord(c) * 31 ** i for i, c in enumerate(name)) + 13)
        on = [[False] * SIZE for _ in range(SIZE)]
        for cy in range(3):
            for cx in range(3):
                turns = next(rng) % 4
                pattern = [list(row) for row in FROND]
                for _ in range(turns):
                    pattern = [list(row) for row in zip(*pattern[::-1])]
                x0, y0 = CELL_EDGES[cx], CELL_EDGES[cy]
                for py, row in enumerate(pattern):
                    for px, v in enumerate(row):
                        if v == "#" and x0 + px < SIZE and y0 + py < SIZE:
                            on[y0 + py][x0 + px] = True
        rows = [[v for x in range(SIZE) for v in (r, g, b, 255 if on[y][x] else 0)] for y in range(SIZE)]
        return png(SIZE, SIZE, rows)
    caps = CAPS.get(name)
    if caps is not None:
        rng = lcg(sum(ord(c) * 31 ** i for i, c in enumerate(name)) + 7)
        on = [[False] * SIZE for _ in range(SIZE)]
        slot = SIZE / caps
        for i in range(caps):
            x = int(slot * (i + 0.5) + ((next(rng) % 1000) / 1000 - 0.5) * 2.0)
            tall = 3 + next(rng) % 5                      # the stem, pixels
            wide = 1 + next(rng) % 2                      # the cap's half-width
            for h in range(tall):
                if 0 <= x < SIZE:
                    on[SIZE - 1 - h][x] = True
            for dx in range(-wide, wide + 1):
                if 0 <= x + dx < SIZE:
                    on[SIZE - 1 - tall][x + dx] = True
                    if abs(dx) < wide and SIZE - 2 - tall >= 0:
                        on[SIZE - 2 - tall][x + dx] = True
        rows = [[v for x in range(SIZE) for v in (r, g, b, 255 if on[y][x] else 0)] for y in range(SIZE)]
        return png(SIZE, SIZE, rows)
    blades = BLADES.get(name)
    if blades is not None:
        count, shortest, tallest = blades
        rng = lcg(sum(ord(c) * 31 ** i for i, c in enumerate(name)) + 5)
        on = [[False] * SIZE for _ in range(SIZE)]
        slot = SIZE / count
        for i in range(count):
            # One blade to a slot, rooted near its middle: the jitter is
            # under a pixel, so two roots are never in touching pixels and
            # a blade is a blade from the ground up, not a shared stroke.
            x = slot * (i + 0.5) + ((next(rng) % 1000) / 1000 - 0.5) * 0.9
            top = shortest + next(rng) % (tallest - shortest + 1)
            lean = ((next(rng) % 1000) / 1000 - 0.5) * 0.4      # pixels per pixel of height
            bend = ((next(rng) % 1000) / 1000 - 0.5) * 4.0      # how far the tip curls, in pixels
            for h in range(top):
                t = h / top
                bx = int(x + lean * h + bend * t * t)
                if 0 <= bx < SIZE:
                    on[SIZE - 1 - h][bx] = True
        rows = [[v for x in range(SIZE) for v in (r, g, b, 255 if on[y][x] else 0)] for y in range(SIZE)]
        return png(SIZE, SIZE, rows)
    bloom = BLOOMS.get(name)
    if bloom is not None:
        mx, my = SIZE / 2, SIZE / 2 - 1
        rows = []
        for y in range(SIZE):
            row = []
            for x in range(SIZE):
                px, py = x + 0.5, y + 0.5
                d2 = (px - mx) ** 2 + (py - my) ** 2
                on = d2 <= bloom * bloom
                # Petals: the rim is nibbled in a pattern, so it is not a coin.
                if on and d2 >= bloom * bloom - 3.0 and (x * 3 + y * 5) % 4 == 0:
                    on = False
                row += [r, g, b, 255 if on else 0]
            rows.append(row)
        return png(SIZE, SIZE, rows)
    dots = DOTS.get(name)
    if dots is not None:
        radius, r_jit, c_jit = dots
        rng = lcg(sum(ord(c) * 31 ** i for i, c in enumerate(name)) + 11)
        discs = []
        for cy in range(3):
            for cx in range(3):
                x0, x1 = CELL_EDGES[cx], CELL_EDGES[cx + 1]
                y0, y1 = CELL_EDGES[cy], CELL_EDGES[cy + 1]
                mx = (x0 + x1) / 2 + ((next(rng) % 1000) / 1000 - 0.5) * 2 * c_jit
                my = (y0 + y1) / 2 + ((next(rng) % 1000) / 1000 - 0.5) * 2 * c_jit
                rr = radius + ((next(rng) % 1000) / 1000 - 0.5) * 2 * r_jit
                discs.append((mx, my, rr * rr))
        rows = []
        for y in range(SIZE):
            row = []
            for x in range(SIZE):
                px, py = x + 0.5, y + 0.5
                on = any((px - mx) ** 2 + (py - my) ** 2 <= r2 for mx, my, r2 in discs)
                row += [r, g, b, 255 if on else 0]
            rows.append(row)
        return png(SIZE, SIZE, rows)
    if holes is None:
        rows = [[v for _ in range(SIZE) for v in (r, g, b, alpha)] for _ in range(SIZE)]
        return png(SIZE, SIZE, rows)
    rng = lcg(sum(ord(c) * 31 ** i for i, c in enumerate(name)) + 7)
    # One decision per sub-pixel of each cell: a 9x9 grid of decisions over
    # the face, each covering about two texture pixels.
    keep = {}
    for cy in range(3):
        for cx in range(3):
            for sy in range(3):
                for sx in range(3):
                    keep[(cx, sx, cy, sy)] = (next(rng) % 1000) >= holes * 1000
    rows = []
    for y in range(SIZE):
        cy = next(i for i in range(3) if CELL_EDGES[i] <= y < CELL_EDGES[i + 1])
        sy = min(2, (y - CELL_EDGES[cy]) * 3 // (CELL_EDGES[cy + 1] - CELL_EDGES[cy]))
        row = []
        for x in range(SIZE):
            cx = next(i for i in range(3) if CELL_EDGES[i] <= x < CELL_EDGES[i + 1])
            sx = min(2, (x - CELL_EDGES[cx]) * 3 // (CELL_EDGES[cx + 1] - CELL_EDGES[cx]))
            row += [r, g, b, 255 if keep[(cx, sx, cy, sy)] else 0]
        rows.append(row)
    return png(SIZE, SIZE, rows)


def item_picture(name, colours):
    """An item icon: a rose — petals, a darker heart, a stem with one leaf."""
    petal, heart, stem = colours["petal"], colours["heart"], colours["stem"]
    pixels = [[(0, 0, 0, 0)] * SIZE for _ in range(SIZE)]
    def put(x, y, c):
        if 0 <= x < SIZE and 0 <= y < SIZE:
            pixels[y][x] = (c[0], c[1], c[2], 255)
    mx, my, radius = 8.0, 5.0, 3.6
    for y in range(SIZE):
        for x in range(SIZE):
            d2 = (x + 0.5 - mx) ** 2 + (y + 0.5 - my) ** 2
            if d2 <= radius * radius:
                put(x, y, heart if d2 <= 1.3 else petal)
    for y in range(9, 16):
        put(7, y, stem)
    for x in range(8, 11):
        put(x, 11, stem)
    put(9, 10, stem)
    rows = [[v for x in range(SIZE) for v in pixels[y][x]] for y in range(SIZE)]
    return png(SIZE, SIZE, rows)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (r, g, b, grain) in BLOCKS.items():
        if name in HAND_MADE:
            print(f"kept {name}.png (hand-made)")
            continue
        (OUT / f"{name}.png").write_bytes(texture(name, r, g, b, grain))
        print(f"wrote {name}.png")
    for name, colours in ITEMS.items():
        (OUT / f"{name}.png").write_bytes(item_picture(name, colours))
        print(f"wrote {name}.png")


if __name__ == "__main__":
    main()
