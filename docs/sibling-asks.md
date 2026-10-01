<!-- SPDX-FileCopyrightText: Iridesium -->
<!-- SPDX-License-Identifier: GPL-3.0-only -->

# Asks of the sibling mods

What the world mod needs from the other default mods. Each says what is
wanted, what stands in meanwhile, and the smallest change that would do.
Newest first. The siblings' asks of the world are in their own repos'
`docs/sibling-asks.md`.

## Tiamat Weather

### Wx-1. Lay the underside's black sky as an overlay (2026-10-01): OPEN

**Wanted.** Under the world's flank (Spindle 14 km and down: the carved
underside, under the core stack) a player's sky is black at every hour,
the designer's "below the surface only darkness and stars". The world
exports `underside_sky(x, y, z)`, true there. Weather composing it as one
of its overlays (`intensity = 0, sky = { 0, 0, 0 }, sky_mix = 1,
saturation = 0`) would keep it in step with everything else on the
modifier.

**Standing in.** The world cannot read Weather's `add_overlay`: Weather
optionally depends on the world, and the engine allows no cycle. So
`underside.lua` writes `set_sky_modifier` itself while a player is under
the line, and again every 40 ticks, so a write of Weather's is undone
within two seconds; and writes `nil` once when they climb back over it,
which clears Weather's own part until Weather next sends. Another mod's
overlay (a night-sight potion) is lost under the line meanwhile.

**Smallest change.** In Weather's evaluation, `add_overlay(uuid,
"tiamat_default_world:underside", DARK)` while `underside_sky` is true at
the player and `nil` when it is not. Say when it lands and the world
takes its writer out.

## Tiamat Default Life

### L-1. The blind fish of the grottoes (2026-10-01): OPEN, low

**Wanted.** The Blind Fish Grottoes' brief (3.4, the dark caves): "pale,
sightless fish gliding beneath the surface" of crystal-clear, motionless
pools one to four deep. A creature, so Life's.

**What the world has for them.** Clear `water` laid full and at rest in
broad pools, 2.05, 2.75 and 3.45 km down, in the Gloam's province over
0.33; `biome_under` answers `blind_fish_grottoes` in them, and the
variant (3.4.1 Albino Coral Cenote) answers the same biome.

**Smallest change.** A pale fish that spawns in water where `biome_under`
says `blind_fish_grottoes`.
