; ZoomTen's Badger Demo
; Compile with RGBASM

_A_	EQU	$97
_B_	EQU	$98
_C_	EQU	$99
_D_	EQU	$9A
_E_	EQU	$9B
_F_	EQU	$9C
_G_	EQU	$9D
_H_	EQU	$9E
_I_	EQU	$9F
_J_	EQU	$A7
_K_	EQU	$A8
_L_	EQU	$A9
_M_	EQU	$AA
_N_	EQU	$AB
_O_	EQU	$AC
_P_	EQU	$AD
_Q_	EQU	$AE
_R_	EQU	$AF
_S_	EQU	$B7
_T_	EQU	$B8
_U_	EQU	$B9
_V_	EQU	$BA
_W_	EQU	$BB
_X_	EQU	$BC
_Y_	EQU	$BD
_Z_	EQU	$BE
_0_	EQU	$BF
_1_	EQU	$C0
_2_	EQU	$C1
_3_	EQU	$C2
_4_	EQU	$C3
_5_	EQU	$C4
_6_	EQU	$C5
_7_	EQU	$C6
_8_	EQU	$C7
_9_	EQU	$C8
_EX	EQU	$C9

INCLUDE "hardware_constants.inc"

hlMapPos: MACRO
; \1 = X
; \2 = Y
	ld hl, vBGMap0 + \1 + (\2 * $20)
	ENDM

ANIMATIONSPD	EQU	4

SECTION "WRAM", WRAM0
wFrameCounter:		ds 1
wScrollCounter:		ds 1
wTileBuffer:		ds 1
wRowBuffer:		ds 1
wColumnBuffer:		ds 1
wRegBackup:		ds 1
wScrollCounter2:	ds 1
wScrollCounter3:	ds 1
wScrollCounter4:	ds 1
wFrameDelay:		ds 1

; The rst vectors are unused.
SECTION "rst 00", ROM0 [$00]
	reti
SECTION "rst 08", ROM0 [$08]
	reti
SECTION "rst 10", ROM0 [$10]
	reti
SECTION "rst 18", ROM0 [$18]
        reti
SECTION "rst 20", ROM0 [$20]
        reti
SECTION "rst 28", ROM0 [$28]
	reti
SECTION "rst 30", ROM0 [$30]
	reti
SECTION "rst 38", ROM0 [$38]
	reti
; Hardware interrupts
SECTION "vblank", ROM0 [$40]
	jp Vblank
SECTION "hblank", ROM0 [$48]
	reti
SECTION "timer",  ROM0 [$50]
	reti
SECTION "serial", ROM0 [$58]
	reti
SECTION "joypad", ROM0 [$60]
	reti
	
SECTION "Program Entry",HOME[$100]
Entry:
	nop
	jp StartProgram
	
SECTION "Main Program",HOME[$150]
StartProgram:
	di			; init the whole thing
	ld sp, $FFFF		; set stack
	ld a, %11100100		; set background palette
	ld [rBGP],a
	
	xor a
	ld [rSCX],a		; reset scroll
	ld [rSCY],a
	ld hl, $c000
	ld bc, $dfff - $c000
.clearwram
	xor a
	ld [hli], a
	dec bc
	ld a, c
	or b
	jr nz, .clearwram
	call DisableLCD
	ld a, $4f
	ld hl, vBGMap0
	ld bc, vBGMap1 - vBGMap0
	call FillVRAM
	
	ld hl, vChars0		; load tiles
	ld de, BadgerTilesets
	ld bc, BadgerTilesets_End - BadgerTilesets_Start
	call CopyVRAM
	
	hlMapPos 0, 0		; load map (title)
	ld de, BadgerTilemap1
	ld bc, BadgerTilemap1_End - BadgerTilemap1_Start
	call CopyVRAM
; load background
	ld a, $0f		; gradient thingy
	hlMapPos 0, 5
	ld bc, $20
	call FillVRAM
	
	ld a, $0e		; grass
	hlMapPos 0, 6
	ld bc, $e0
	call FillVRAM
	ld a, $0e
	hlMapPos 0, $d
	ld bc, $a0
	call FillVRAM
	
	call PutSmallGrassTiles
	call PutBigGrassTiles
	
; load badgers
	ld a, 0			; frame
	hlMapPos $9, $b
	call LoadBadgerFrame
	ld a, 3			; frame
	hlMapPos 0, 8
	call LoadBadgerFrame
	ld a, 3			; frame
	hlMapPos $11, 8
	call LoadBadgerFrame
	
	ld a, %10010001
	ld [rLCDC], a		; enable LCD
	
	ld a, ANIMATIONSPD
	ld [wFrameDelay], a
	
	ld a,%00000001  ; Enable V-blank interrupt
	ld [rIE], a
	ei
Badger_MainLoop:
	call BadgerUpdateFrames
	ld d, 0
	call WaitScanline
	xor a
	ld [rSCX], a
	ld d, 24
	call WaitScanline
	ld a, [wScrollCounter3]
	ld [rSCX], a
	ld d, 48
	call WaitScanline
	ld a, [wScrollCounter4]
	ld [rSCX], a
	ld d, 56
	call WaitScanline
	ld a, [wScrollCounter2]
	ld [rSCX], a
	ld d, 87
	call WaitScanline
	ld a, [wScrollCounter]
	ld [rSCX], a
	jr Badger_MainLoop

; SUBROUTINES

Vblank:
	push af
	push bc
	push de
	push hl
	pop hl
	pop de
	pop bc
	pop af
	reti
	
BadgerUpdateFrames:
	ld a, [wFrameDelay]
	and a
	jr z, .skip
	ld a, [wScrollCounter]
	dec a
	ld [wScrollCounter], a
	ld a, [wFrameDelay]
	dec a
	ld [wFrameDelay], a
	ret
.skip
	call UpdateBadgers
	ld a, ANIMATIONSPD
	ld [wFrameDelay], a
	ld a, [wScrollCounter2]
	dec a
	ld [wScrollCounter2], a
	call .updatescroll3
	call .updatescroll4
	ret
.updatescroll3
	push af
	ld a, [wScrollCounter2]
	and a, %00000001
	jr nz, .updatescroll3not
	ld a, [wScrollCounter3]
	dec a
	ld [wScrollCounter3], a
.updatescroll3not
	pop af
	ret
	
.updatescroll4
	push af
	ld a, [wScrollCounter3]
	and a, %0000001
	jr nz, .updatescroll4not
	ld a, [wScrollCounter4]
	dec a
	ld [wScrollCounter4], a
.updatescroll4not
	pop af
	ret
	
UpdateBadgers:
	ld a, [wFrameCounter]
	cp 2
	jr z, .reset
	inc a
	ld [wFrameCounter], a
	jr .updatepics
.reset
	xor a
	ld [wFrameCounter], a
.updatepics
	ld a, 7
	hlMapPos $1, $b
	call LoadBadgerFrame
	ld a, [wFrameCounter]
	hlMapPos $9, $b
	call LoadBadgerFrame
	ld a, [wFrameCounter]
	add 3
	hlMapPos 0, 8
	call LoadBadgerFrame
	ld a, [wFrameCounter]
	add 3
	hlMapPos $11, 8
	call LoadBadgerFrame
	ret
	
WaitVBLANK:
	ld [wRegBackup], a
	ld a,[rLCDC]
	bit 7, a
	jr z, .done
.wait
	ld a, [rLY]
	cp LY_VBLANK		; Vblank
	jr nz, .wait
.done
	ld a, [wRegBackup]
	ret
	
DisableLCD:			; Pokemon Red code
	xor a
	ld [rIF], a		; disable interrupts
	ld a, [rIE]
	ld b, a
	res 0, a
	ld [rIE], a
.wait
	ld a, [rLY]
	cp LY_VBLANK		; Vblank
	jr nz, .wait
	ld a, [rLCDC]
	and $ff ^ rLCDC_ENABLE_MASK
	ld [rLCDC], a
	ld a, b
	ld [rIE], a
	ret

FillVRAM:
; hl = destination
; a = fill byte
; bc = bytes
; d = backup for a
.loop
	call WaitVRAM
	ld [hli], a
	dec bc
	ld d, a
	ld a, b
	or c
	jr z, .skip
	ld a, d
	jr .loop
.skip
	reti
	
	
CopyVRAM:
; hl = destination
; de = source
; bc = bytes
.loop
	call WaitVRAM
	ld a, [de]
	ld [hli], a
	inc de
	dec c
	jr nz, .loop
	ld a, b
	and b
	jr z, .done
	dec b
	jr nz, .loop
.done
	ret

WaitScanline:
	ld [wRegBackup], a
.wait
	ld a, [rLY]
	cp d
	jr nz, .wait
	ld a, [wRegBackup]
WaitVRAM:
	ld [wRegBackup], a
.loop
        ld a,[rSTAT]
        and %00000010
        jr nz,.loop		; wait until okay
	ld a, [wRegBackup]
	ret
	
PutVRAMByte:
	call WaitVRAM
	ld [hl], a
	ret
LoadBadgerFrame:
	push hl
	ld hl, BadgerFrameData
	ld b, 0
	ld c, a
	add hl,bc
	add hl,bc
	add hl,bc
	ld a, [hli]
	ld [wTileBuffer], a
	ld a, [hli]
	ld [wRowBuffer], a
	ld a, [hl]
	ld [wColumnBuffer], a
	pop hl
; load a row
.loadrow
	ld a, [wRowBuffer]
	ld c, a
	ld a, [wTileBuffer]
	call WaitVRAM
.loadrowloop
	ld [hli], a
	inc a
	dec c
	jr nz, .loadrowloop
	
	ld a, [wTileBuffer]
	add $10
	ld [wTileBuffer], a
	ld a, [wColumnBuffer]
	dec a
	ld [wColumnBuffer], a
	jr z, .done
	
	ld a, [wRowBuffer]
.movemapvram1
	dec hl
	dec a
	jr nz, .movemapvram1
	
	ld a, $20
.movemapvram2
	inc hl
	dec a
	jr nz, .movemapvram2
	
	jr .loadrow
	
.done
	ret
	
BadgerFrameData:
; byte 0 = starting tile
; byte 1 = width
; byte 2 = height
	db $00		; 0
	db $07, $06
	db $07		; 1
	db $07, $06
	db $60		; 2
	db $07, $06
	db $67		; 3
	db $03, $03
	db $6a		; 4
	db $03, $03
	db $6d		; 5
	db $03, $03
	db $2e		; 6
	db $02, $02
	db $ca		; 7
	db $07, $04

PutSmallGrassTiles:
	ld a, $4e		; grass tile
	hlMapPos 1, 7
	call PutVRAMByte
	ld a, $4e		; grass tile
	hlMapPos 6, 7
	call PutVRAMByte
	ld a, $4e		; grass tile
	hlMapPos 9, 7
	call PutVRAMByte
	ld a, $4e		; grass tile
	hlMapPos 14, 7
	call PutVRAMByte
	ld a, $4e		; grass tile
	hlMapPos 20, 7
	call PutVRAMByte
	ld a, $4e		; grass tile
	hlMapPos 24, 7
	call PutVRAMByte
	ld a, $4e		; grass tile
	hlMapPos 30, 7
	call PutVRAMByte
	
	ld a, $4e		; grass tile
	hlMapPos 6, 6
	call PutVRAMByte
	ld a, $4e		; grass tile
	hlMapPos 10, 6
	call PutVRAMByte
	ld a, $4e		; grass tile
	hlMapPos 12, 6
	call PutVRAMByte
	ld a, $4e		; grass tile
	hlMapPos 16, 6
	call PutVRAMByte
	ld a, $4e		; grass tile
	hlMapPos 21, 6
	call PutVRAMByte
	ld a, $4e		; grass tile
	hlMapPos 25, 6
	call PutVRAMByte
	ld a, $4e		; grass tile
	hlMapPos 31, 6
	call PutVRAMByte
	ret
	
PutBigGrassTiles:
	ld a, 6			; big grass tile
	hlMapPos 4, 9
	call LoadBadgerFrame
	ld a, 6			; big grass tile
	hlMapPos $d, 9
	call LoadBadgerFrame
	ld a, 6			; big grass tile
	hlMapPos $1a, 9
	call LoadBadgerFrame
	
	ld a, 6			; big grass tile
	hlMapPos 7, $e
	call LoadBadgerFrame
	ld a, 6			; big grass tile
	hlMapPos $15, $e
	call LoadBadgerFrame
	ld a, 6			; big grass tile
	hlMapPos $1d, $e
	call LoadBadgerFrame
	ret
	
; INCLUDES

BadgerTilesets:
BadgerTilesets_Start:
	INCBIN "badgertiles.2bpp"
BadgerTilesets_End:

BadgerTilemap1:
BadgerTilemap1_Start:
	db _B_,_A_,_D_,_G_,_E_,_R_,$4F,_B_,_A_,_D_,_G_,_E_,_R_,$4F,_B_,_A_,_D_,_G_,_E_,_R_
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00					; spillover
	db $4F,$4F,$4F,$4F,$4F,$4F,$4F,_Z_,_O_,_O_,_M_,_T_,_E_,_N_,$4F,$4F,$4F,$4F,$4F,$4F
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00					; spillover
BadgerTilemap1_End: