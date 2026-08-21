# PETSCII Robots — BBC Micro / Acorn Electron port

![PETSCII](https://user-images.githubusercontent.com/74630735/198894939-83a67166-d7b4-40d9-bf35-f9c8b00fac93.jpg)

6502 assembly ports of [PETSCII Robots](https://github.com/JimmyDansbo/PETSCIIRobots-C64)
by Jimmy Dansbo, targeting the BBC Micro (disc) and Acorn Electron (tape).

## Requirements

- [cc65](https://cc65.github.io/) toolchain (`ca65`, `ld65`)
- Python 3 (for disc/tape image builders)

## Building

```
make          # BBC Micro binary (robots)
make ssd      # robots.ssd — DFS disc image with !BOOT, boot option 3 (*EXEC)
make robots_e # Acorn Electron binary (robots_e)
make uef      # robots_e.uef — tape image
make clean
```

## Running

### BBC Micro

`robots.ssd` is a 400-sector DFS image containing `ROBOTS` (loads to &0E00)
and a `!BOOT` file. Boot option 3 is set, so shift-break (or your emulator's
autoboot) runs the game directly.

### Acorn Electron

`robots_e.uef` contains a single tape file `ROBOTS` (load/run address &0E00).
Load with `*TAPE` then `CHAIN ""` (or via the tape menu in your emulator).

Emulators: [b-em](https://github.com/stardot/b-em) or
[beebem](https://github.com/tom-seddon/beebem) for the BBC version;
[Elkulator](http://www.stairwaytohell.com/elkulator/) or
[jsbeeb](https://bbc.xania.org/?electron) for the Electron version.

## Controls

| Key   | Action        |
|-------|---------------|
| Cursor arrows | Move |
| SPACE | Fire          |
| X     | Search        |
| M     | Move object   |
| U     | Use item      |
| D     | Select weapon |
| A     | Select item   |
| Q     | Quit          |

## Repository layout

```
src/robots.s     BBC Micro source (Mode 7, SN76489 sound)
src/robots_e.s   Electron source
inc/bbc.inc      BBC hardware register definitions
inc/electron.inc Electron hardware register definitions
cfg/bbc-mode7.cfg linker config: CODE &0E00-, screen &7C00 (Mode 7)
cfg/electron.cfg linker config: CODE &0E00-, screen &8000-ish
mkssd.py         builds DFS .ssd images and .uef tape images
```

Both binaries load at &0E00. Zero page usage follows the original C64
layout (&00-&2B game variables); unit slots 0-31 hold the player,
enemies, hidden items, bullets/bombs/magnets.
