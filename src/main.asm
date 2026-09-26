; Operation C (USA): Level Select v1.0
; Assembles with RGBDS 1.0.x. This source contains only replacement/injected
; sections; it is linked over an otherwise $FF-filled overlay image.

DEF wLives      EQU $DED9
DEF wWeapon     EQU $DED3 ; menu-only weapon selection, 1-5
DEF wArea       EQU $DEDB
DEF wMenuRow    EQU $DEDC
DEF wKeysNew    EQU $DEE7
DEF wWindowX    EQU $DEF4
DEF wMenuParam  EQU $DEF8
DEF wAnimTimer  EQU $DEC6
DEF wScreenMode EQU $DEC1

DEF wStage      EQU $C886
DEF wLifeCount  EQU $C888
DEF wWeaponLive EQU $C882

DEF ArrowTileID EQU $01

SECTION "Unlock stock stage select", ROMX[$4041], BANK[3]
    db $C3 ; JP instead of JP NZ (preserve the original $08A6 operand)

SECTION "Expanded menu init hook", ROMX[$4057], BANK[3]
    jp MenuInit

SECTION "Expanded menu input hook", ROMX[$409F], BANK[3]
    jp MenuInput

SECTION "Expanded menu launch hook", ROMX[$40E1], BANK[3]
    jp LaunchTail

SECTION "Expanded menu draw hook", ROMX[$410B], BANK[3]
    jp DrawMenuGateway

SECTION "Infinite lives hook", ROMX[$56C4], BANK[3]
    jp LifeHook

; Preserve the stock continue/stage-start routines while masking the infinite
; flag stored in the otherwise-BCD default-lives byte.
SECTION "Lives reload hook 1", ROM0[$3E60]
    call GetLivesValue

SECTION "Lives reload hook 2", ROM0[$3E73]
    call GetLivesValue

SECTION "Expanded menu code", ROM0[$3E8B]

MenuInit:
    ld a, 1
    ld [wArea], a
    ld [wWeapon], a
    ld a, 2
    ld [wLives], a
    xor a
    ld [wMenuRow], a

    ; The expanded tilemap lives in bank 6. This routine executes from fixed
    ; ROM while the temporary bank switch is active.
    ld a, 6
    ld [$2180], a
    call LoadArrowTile
    call DrawExpandedMenu
    ld a, 3
    ld [$2180], a

    ; Preserve the stock right-to-left slide. The expanded map begins with its
    ; border (no blank leading row), so the window covers the TM but not the C.
    ld de, $A550
    call $0DC0
    ld a, $5F
    ld [wMenuParam], a
    ld a, $16
    ld [wScreenMode], a
    xor a
    ld [wAnimTimer], a
    call $0500
    jp $08A6

MenuInput:
    ld a, [wKeysNew]
    bit 7, a
    jp nz, $08A6 ; Start: use the original confirmation/launch states

    and $0C
    jr z, .horizontal
    ld a, $10
    call $0536
    ld a, [wKeysNew]
    bit 3, a
    jr z, .rowUp
.rowDown:
    ld a, [wMenuRow]
    inc a
    cp 3
    jr c, .storeRow
    xor a
    jr .storeRow
.rowUp:
    ld a, [wMenuRow]
    or a
    jr nz, .decrementRow
    ld a, 3
.decrementRow:
    dec a
.storeRow:
    ld [wMenuRow], a
    jp DrawMenuGateway

.horizontal:
    ld a, [wKeysNew]
    and $03
    ret z
    ld a, $10
    call $0536
    ld a, [wMenuRow]
    or a
    jr z, .area
    dec a
    jr z, .weapon
    ld a, [wKeysNew]
    bit 0, a
    push af
    call nz, LivesNext
    pop af
    call z, LivesPrevious
    jr .redraw
.area:
    ld a, [wKeysNew]
    bit 0, a
    push af
    call nz, AreaNext
    pop af
    call z, AreaPrevious
    jr .redraw
.weapon:
    ld a, [wKeysNew]
    bit 0, a
    push af
    call nz, WeaponNext
    pop af
    call z, WeaponPrevious
.redraw:
    jp DrawMenuGateway

LivesNext:
    ld a, [wLives]
    bit 7, a
    jr z, .finite
    ld a, $02
    ld [wLives], a
    ret
.finite:
    cp $02
    jr z, .five
    cp $04
    jr z, .ten
    cp $09
    jr z, .twenty
    ld a, $89
    ld [wLives], a
    ret
.five:
    ld a, $04
    jr .store
.ten:
    ld a, $09
    jr .store
.twenty:
    ld a, $19
.store:
    ld [wLives], a
    ret

LivesPrevious:
    ld a, [wLives]
    bit 7, a
    jr z, .finite
    ld a, $19
    ld [wLives], a
    ret
.finite:
    cp $02
    jr z, .infinite
    cp $04
    jr z, .three
    cp $09
    jr z, .five
    ld a, $09
    jr .store
.infinite:
    ld a, $89
    ld [wLives], a
    ret
.three:
    ld a, $02
    jr .store
.five:
    ld a, $04
.store:
    ld [wLives], a
    ret

DrawTile:
    ld e, a
    call $0C4B
    ld [hl], b
    inc l
    ld [hl], c
    inc l
    ld a, $81
    ld [hli], a
    ld a, e
    ld [hli], a
    set 6, b
    ld [bc], a
    res 6, b
    jp $0C65

DrawString8:
    push bc
    call $0C4B
    pop bc
    ld [hl], b
    inc l
    ld [hl], c
    inc l
    ld a, $81
    ld [hli], a
    ld a, 8
.loop:
    push af
    ld a, [de]
    inc de
    ld [hli], a
    set 6, b
    ld [bc], a
    res 6, b
    inc c
    pop af
    dec a
    jr nz, .loop
    jp $0C65

LaunchTail:
    ; Weapon types need five related runtime values, not just the weapon ID.
    ; Switch to bank 6 while this fixed-bank routine applies the chosen preset.
    ld a, 6
    ld [$2180], a
    call ApplyWeaponSettings
    ld a, 3
    ld [$2180], a
    xor a
    ld [wMenuRow], a
    ld a, [wLives]
    bit 7, a
    jr z, .storeLives
    ld a, $09
.storeLives:
    jp LaunchStore

GetLivesValue:
    ld a, [wLives]
    and $7F
    ret

DrawMenuGateway:
    ld a, 4
    ld [$2180], a
    call DrawMenu
    ld a, 3
    ld [$2180], a
    ret

; Keep bank 3's trailing stage-data region completely untouched. Area 4 reads
; it late in the stage, so even apparent $FF padding there is not safe scratch
; space. Bank 4's unused tail holds the redraw code and its local strings.
SECTION "Expanded menu continuation", ROMX[$7E15], BANK[4]

DrawMenu:
    ; Erase all cursor positions, then draw the arrow at the active row.
    xor a
    ld bc, $9C62
    call DrawTile
    xor a
    ld bc, $9C82
    call DrawTile
    xor a
    ld bc, $9CA2
    call DrawTile

    ld a, [wMenuRow]
    swap a
    add a, a
    add a, $62
    ld c, a
    ld b, $9C
    ld a, ArrowTileID
    call DrawTile

    ; Area number.
    ld a, [wArea]
    add a, $04
    ld bc, $9C71
    call DrawTile

    ; Weapon name.
    ld a, [wWeapon]
    and $7F
    dec a
    add a, a
    add a, a
    add a, a
    ld e, a
    ld d, 0
    ld hl, WeaponNames
    add hl, de
    ld d, h
    ld e, l
    ld bc, $9C8A
    call DrawString8

    ; Lives field.
    ld a, [wLives]
    bit 7, a
    jr z, .finiteLives
    ld de, InfiniteText
    ld bc, $9CAA
    jp DrawString8
.finiteLives:
    ld de, Blank8
    ld bc, $9CAA
    call DrawString8
    ld a, [wLives]
    add a, 1
    daa
    push af
    and $0F
    add a, $04
    ld bc, $9CB1
    call DrawTile
    pop af
    swap a
    and $0F
    ret z
    add a, $04
    ld bc, $9CB0
    jp DrawTile

WeaponNames:
    db $00, $00, $1D, $1E, $21, $1C, $10, $1B ; NORMAL, right-aligned
    db $22, $1F, $21, $14, $10, $13, $00, $07 ; SPREAD 3
    db $22, $1F, $21, $14, $10, $13, $00, $09 ; SPREAD 5
    db $00, $00, $17, $1E, $1C, $18, $1D, $16 ; HOMING, right-aligned
    db $00, $00, $00, $00, $15, $18, $21, $14 ; FIRE, right-aligned

InfiniteText:
    db $18, $1D, $15, $18, $1D, $18, $23, $14
Blank8:
    ds 8, $00

SECTION "Launch settings tail", ROMX[$40E4], BANK[3]
LaunchStore:
    ld [wLifeCount], a
    ld a, [wArea]
    ld [wStage], a
    ld a, $02
    ld [$C8FB], a
    jp $089B

; Reclaim routines made unreachable by the new hooks.
SECTION "Area selectors", ROMX[$405A], BANK[3]
AreaNext:
    ld a, [wArea]
    inc a
    cp 6
    jr c, .store
    ld a, 1
.store:
    ld [wArea], a
    ret

AreaPrevious:
    ld a, [wArea]
    dec a
    jr nz, .store
    ld a, 5
.store:
    ld [wArea], a
    ret

SECTION "Infinite lives routine", ROMX[$40A2], BANK[3]
LifeHook:
    ld a, [wLives]
    bit 7, a
    jr nz, .keepLife
    ld a, [wLifeCount]
    or a
    jp z, $56D5
    sub 1
    daa
    ld [wLifeCount], a
.keepLife:
    ld hl, $C002
    inc [hl]
    ret

SECTION "Weapon selectors", ROMX[$410E], BANK[3]
WeaponNext:
    ld hl, wWeapon
    ld a, [hl]
    ld b, a
    and $7F
    inc a
    cp 6
    jr c, .merge
    ld a, 1
.merge:
    bit 7, b
    jr z, .store
    set 7, a
.store:
    ld [hl], a
    ret

WeaponPrevious:
    ld hl, wWeapon
    ld a, [hl]
    ld b, a
    and $7F
    dec a
    jr nz, .merge
    ld a, 5
.merge:
    bit 7, b
    jr z, .store
    set 7, a
.store:
    ld [hl], a
    ret

; Leave 32 bytes of the original $FF tail intact before using bank 6 padding.
SECTION "Expanded menu map", ROMX[$7E74], BANK[6]
DrawExpandedMenu:
    ; Write the complete panel directly while it is still offscreen. Updating
    ; both VRAM and the game's shadow tilemap avoids overflowing its small
    ; one-frame tile command buffer—the cause of the intermittent border gaps.
    ld de, ExpandedMenuTiles
    ld hl, $9C01
    ld b, 7
.row:
    ld c, 18
.tile:
    call $0DB7
    ld a, [de]
    inc de
    ld [hli], a
    dec l
    set 6, h
    ld [hl], a
    res 6, h
    inc l
    dec c
    jr nz, .tile
    ld a, l
    add a, 14
    ld l, a
    dec b
    jr nz, .row
    ret

ExpandedMenuTiles:
    ; Top border.
    db $C0
    ds 16, $C1
    db $C2
    ; Header.
    db $C5, $00, $00
    db $22, $23, $10, $16, $14, $00, $22, $14, $1B, $14, $12, $23
    db $00, $00, $C5
    ; Blank spacer.
    db $C5
    ds 16, $00
    db $C5
    ; Area.
    db $C5, $01, $10, $21, $14, $10
    ds 10, $00
    db $05, $C5
    ; Weapon.
    db $C5, $00, $26, $14, $10, $1F, $1E, $1D, $00
    db $00, $00, $1D, $1E, $21, $1C, $10, $1B
    db $C5
    ; Lives.
    db $C5, $00, $1B, $18, $25, $14, $22, $00, $00
    ds 7, $00
    db $07
    db $C5
    ; Bottom border.
    db $C3
    ds 16, $C1
    db $C4

; Runtime weapon state used by the game's pickup code. Each preset maps to
; $C881-$C885, including the weapon ID in the middle byte.
ApplyWeaponSettings:
    ld a, [wWeapon]
    and $7F
    dec a
    ld b, a
    add a, a
    add a, a
    add a, b
    ld hl, WeaponSettings
    rst $28 ; HL += A
    ld de, $C881
    ld b, 5
.copy:
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, .copy
    xor a
    ld [wWeapon], a
    ret

WeaponSettings:
    db $05, $01, $0E, $04, $16 ; Normal
    db $06, $02, $10, $0B, $1A ; Spread 3
    db $0A, $03, $10, $08, $20 ; Spread 5
    db $06, $04, $10, $08, $38 ; Homing
    db $02, $05, $05, $08, $16 ; Fire

LoadArrowTile:
    ld de, ArrowTileData
    ld hl, $9010 ; signed tile ID $01
    ld b, 16
.loop:
    call $0DB7 ; wait until VRAM is accessible
    ld a, [de]
    inc de
    ld [hli], a
    dec b
    jr nz, .loop
    ret

ArrowTileData:
    db %00000000, %00000000
    db %00100000, %00100000
    db %00110000, %00110000
    db %00111000, %00111000
    db %00111100, %00111100
    db %00111000, %00111000
    db %00110000, %00110000
    db %00100000, %00100000
