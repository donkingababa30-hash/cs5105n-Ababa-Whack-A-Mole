# Week 5 — UI / UX & Audio

A small 2D platformer built in **Godot 4.7** for the Week 5 activity: a HUD, a main
menu, mixed sound effects and music on separate audio buses, and one accessibility
feature.

## Controls

| Action | Keys |
| --- | --- |
| Move | `←` / `→` or `A` / `D` |
| Jump | `Space` / `W` / `↑` |
| Dash | `Shift` |
| Pause | `Esc` |

## What was added (mapped to the brief)

1. **CanvasLayer HUD** (`scripts/hud.gd`) — score (coins collected), a timer and a
   3-heart health bar, all updating live from the `Game` autoload. Lives on its own
   CanvasLayer so it stays fixed on screen and keeps working while paused.
2. **Main menu** (`main_menu.tscn`) — Start / Options / Quit. The level also has a
   pause menu (`Esc`) and a **Level Complete / Game Over** panel with
   *Play Again* and *Main Menu*, so the player can restart or leave at any time.
3. **Audio** — SFX and music routed through separate buses (see below).
4. **Accessibility** — a colourblind-safe palette toggle (see below).
5. **Peer playtest** — see "Playtest" below.
6. **Commit message:** `Week 5: UI + audio + accessibility`

## Audio design

* **Buses** — `default_bus_layout.tres` defines `Master` → `Music` (−8 dB) and
  `SFX` (−2 dB). Every sound player is assigned to one of these buses, and the
  menu sliders change each bus independently, so music and effects can be
  balanced without re-exporting anything.
* **SFX** — a round-robin pool of 10 `AudioStreamPlayer`s (`scripts/game.gd`), so
  overlapping sounds such as a coin and a jump never cut each other off.
* **Music** — a single looping player; the 8-second track is set to loop forward.
* **Clips** — all synthesised procedurally (the "leverage AI" step): `jump`,
  `dash`, `coin`, `hurt`, `click`, `win`, `gameover`, and `music`, in
  `assets/audio/`.

## Accessibility feature — colourblind-safe palette

Toggle: **Main Menu → Options → "Colourblind-safe palette (Okabe-Ito)"**.

The default palette uses a red hazard against a green goal — the classic red/green
pair that is hardest to distinguish for players with deuteranopia or protanopia.
The colourblind palette swaps every gameplay-critical colour for the
**Okabe-Ito** set, removing that pair entirely:

| Element | Default | Colourblind |
| --- | --- | --- |
| Hazard spikes | red `#E6494D` | vermillion `#D55E00` |
| Goal flag | green `#4ACF6F` | blue `#0072B2` |
| Ground / platforms | warm brown + green | cooler brown + bluish-green |

Colour is never the only signal: spikes are triangular, coins are round, and the
goal is a flag, so the level is readable without relying on hue at all.

### Quick accessibility checklist (2D game)

- [x] Colour is never the only cue — pair colour with shape, position or sound.
- [x] A colourblind-safe palette option.
- [x] All text has an outline so it stays readable over moving backgrounds.
- [x] Menus and HUD are readable at the default window size (36 px score/timer).
- [ ] Remappable keys (not implemented this week — a good next step).
- [ ] On-screen subtitle/caption option for important audio cues.
- [ ] Screen-shake / flashing reduction option.
- [ ] Controller-only navigation of the menus.

## Playtest

Run a 5-minute peer playtest (watch one person play without helping them), then
record **one** observed problem and the change you made in response.

*Observation and change already made:* during testing the player spawned right
next to the first platform and was **walled in** — the platform sat at a height the
jump could not clear, so the player could only travel a few pixels. Change made:
raised the jump height slightly and repositioned/lowered the platforms so each one
is reachable from the one before it. The level is now completable end-to-end
(verified automatically — see the smoke test below).

Use this template for your own notes:

```
Playtester:            <name / initials>
Observed:              <what they struggled with, in one sentence>
Change made:           <the single change you made>
Before → After:        <e.g. "died at spike 2 every run" → "clears it after 1 try">
```

## Verifying it works

`tests/probe.tscn` is a headless smoke test. Run it with:

```bash
godot --headless --path . res://tests/probe.tscn
```

It checks that the palette switches and reverts, that the audio buses and music
stream are configured, and that an auto-player can traverse the level to the goal.

## Project structure

```
main_menu.tscn / scripts/main_menu.gd   Main menu + Options (accessibility & audio)
main.tscn      / scripts/game_level.gd  The level: layout, timer, pause & results
scripts/game.gd                         Autoload: state, audio, palette, settings
scripts/hud.gd                          HUD (score / timer / health) + overlays
coin.tscn spike.tscn goal.tscn          Collectible, hazard, goal + their scripts
player.tscn / player.gd                 The character (movement, dash, damage)
default_bus_layout.tres                 Music / SFX audio buses
assets/audio/                           Generated SFX + music
assets/generated/                       Generated sprites (coin, spike, heart, flag, sky)
tests/probe.tscn                        Headless smoke test
```