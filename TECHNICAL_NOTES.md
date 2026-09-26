# Technical notes

Operation C: Level Select is an assembly overlay for the USA Rev. 0
release of Operation C. It expands the game's hidden stage selector without
shipping any original ROM data as a complete game image.

## Menu state

- Area selection: `$DEDB`
- Weapon selection: `$DED3`
- Lives/default-lives setting: `$DED9`
- Active menu row: `$DEDC`

The high bit of `$DED9` marks Infinite lives. Stock routines that reload the
default life count are hooked through a helper that masks this flag before
returning the game's BCD value.

## Weapon initialization

Selecting a weapon installs the complete five-byte runtime preset at
`$C881-$C885`. This matches the structure used by the native power-up handler;
setting only the displayed weapon ID produces incorrect projectile behavior and
graphics.

## Bank placement

Bank 3's trailing stage-data region is intentionally left untouched. Menu
continuation code is stored in unused bank 4 space, while the expanded tilemap,
weapon presets, and arrow graphic are stored in unused bank 6 space. Fixed-bank
gateways temporarily select the required bank and restore bank 3 afterward.

## Build process

`build.py` verifies the clean-ROM SHA-256, assembles `src/main.asm` with
RGBDS, overlays only declared sections, repairs the Game Boy global checksum,
and writes both a patched test ROM and a BPS patch. The source ROM is read-only.
