.section "Test" force

; Z80 CRC32 Calculator for Sega Master System
; Computes CRC32 for data at $4000..$bfff
; Result stored little-endian at $c000
; Uses standard CRC32 polynomial (0xedb88320)
; Assembler: WLA DX
;
; Assumes pre-computed CRC table at label 'crc_table'
; Table format: 256 entries x 4 bytes (little-endian), standard polynomial
; First entry should be: $00, $00, $00, $00
; Second entry should be: $77, $07, $30, $96

; Compute CRC32 for data at $4000..$bfff
; Result written to $c000 (little-endian)
; Strategy: Keep CRC in IX:DE throughout (IX=low word, DE=high word)
compute_crc32:
        ; Initialize CRC to 0xffffffff in IX:DE
        ld ix, $ffff
        ld de, $ffff
        
        ; HL = data pointer
        ld hl, $4000
        
.loop:
        ; Check if done (hl >= $c000)
        ld a, h
        cp $c0
        jp nc, .done
        
        ; Process 8 bytes
.rept 8
        ; Get data byte and XOR with IX low byte
        ld a, (hl)
        inc hl
        xor ixl
        
        ; Calculate table address (a * 4)
        ld c, a
        ld b, 0
        push hl
        ld hl, crc_table
        add hl, bc
        add hl, bc
        add hl, bc
        add hl, bc
        
        ; Load table[index] into BC:HL'
        ld c, (hl)
        inc hl
        ld b, (hl)
        inc hl
        push de
        ld e, (hl)
        inc hl
        ld d, (hl)
        ; BC = table[0:1], DE = table[2:3]
        
        ; Compute new CRC = (old_crc >> 8) ^ table[index]
        ; Shifted CRC is: IXH, E_old, D_old, 0
        ld a, ixh
        xor c
        ld ixl, a
        
        pop hl          ; HL = old DE (high word)
        ld a, l
        xor b
        ld ixh, a
        
        ld a, h
        xor e
        ld e, a
        
        ld d, d         ; D = table[3] (already in D)
        
        pop hl
.endr
        
        jp .loop
        
.done:
        ; Invert IX:DE and store at $c000
        ld a, ixl
        cpl
        ld ($c000), a
        ld a, ixh
        cpl
        ld ($c001), a
        ld a, e
        cpl
        ld ($c002), a
        ld a, d
        cpl
        ld ($c003), a
        
        ret
.ends

.section "table" free align 256
crc_table:
.include "crc32table.asm"

.ends
