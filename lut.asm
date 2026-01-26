.section "Test" force
  ; Set page count
  ld b, 2

; 32-bit crc routine
; entry: de points to data, b = number of 16KB pages to checksum
; exit: RAM_CRC holds the CRC32 of the data

  ; init to $ffffffff
  exx
    ld d,$ff
    ld e,d
    ld b,d
    ld c,d
  exx
  
  ld de, $4000 ; Initial address
  
  
_bank_loop:
  push bc
    
    ; Unrolling 64 times means we need to loop only 256 times to cover 16KB
.ifdef UNROLL
.define UNROLL_COUNT 16*1024/256
    ld b, 0 ; to get 256 loops
.else
    ld b, <(16*1024)
    ld c, >(16*1024)
.endif
    
_bytes_in_bank_loop:

.ifdef UNROLL
.repeat UNROLL_COUNT
.endif
    ld a, (de)
    inc de
    
    exx
      ; Lookup index = (low byte of crc) xor (new byte)
      xor c ; xor with new byte
      ld l, a
      ld h, >CRCLookupTable >> 2
      add hl, hl ; use result as index into table of 4 byte entries
      add hl, hl

      ; New CRC = ((old CRC) >> 8) xor (pointed data)
      ; llmmnnoo ; looked up value
      ; 00aabbcc ; shifted old CRC
      ; AABBCCDD ; new CRC is the byte-wise XOR
      
      ld a, b
      xor (hl)
      inc hl
      ld c, a
      
      ld a, e
      xor (hl)
      inc hl
      ld b, a
      
      ld a, d
      xor (hl)
      inc hl
      ld e, a
      
      ld d,(hl)
    exx

.ifdef UNROLL
.endr
    dec b
    jp nz, _bytes_in_bank_loop
.else
    djnz _bytes_in_bank_loop
    dec c
    jp nz, _bytes_in_bank_loop
.endif
  pop bc

  dec b
  jp nz, _bank_loop
  
  ; Invert all bits when done
  exx
    ld hl, RAM_CRC
    ld a, c
    cpl
    ld (hl), a
    inc hl
    ld a, b
    cpl
    ld (hl), a
    inc hl
    ld a, e
    cpl
    ld (hl), a
    inc hl
    ld a, d
    cpl
    ld (hl), a
  exx
  ret ; to end the test
.ends

.section "CRC table" align 1024
CRCLookupTable:
.include "crc32table.asm"
.ends
