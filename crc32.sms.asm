.memorymap
slotsize $4000
slot 0 $0000
slot 1 $4000
slot 2 $8000
defaultslot 2
.endme
.rombankmap
bankstotal 3
banksize $4000
banks 3
.endro

;.sdsctag 1.0, "CRC32 test", "Test-bed for CRC32 algorithm optimisation", "Maxim"

.enum $c000
  RAM_CRC dl
.ende

.bank 0 slot 0
.org 0
.section "Entry" force
  di
  im 1
  jp main
.ends

.org $38
.section "Interrupt handler" force
  reti
.ends

.org $66
.section "NMI handler" force
  retn
.ends

.section "Main" free
main:
  ld sp, $dff0
  ; Init paging
  xor a
  ld ($fffd),a
  inc a
  ld ($fffe),a
  inc a
  ld ($ffff),a
  ; point to data
  ld de, data
  ld bc, 32*1024
  jp crc32 ; and ret for test
.ends

.section "CRC32 function" free
crc32:
; 32-bit crc routine
; entry: de points to data, bc = count
; exit: RAM_CRC updated

  ; init to $ffffffff
  ld hl, RAM_CRC
  ld a, $ff
  ld (hl), a
  inc hl
  ld (hl), a
  inc hl
  ld (hl), a
  inc hl
  ld (hl), a
  
--:
  ld a, (de)
  inc de
  ld hl, RAM_CRC
  push bc
  push de
    ; Lookup index = (low byte of crc) xor (new byte)
    ; point to low byte of old crc
    ld hl, RAM_CRC+3
    xor (hl) ; xor with new byte
    ld l, a
    ld h, 0
    add hl, hl ; use result as index into table of 4 byte entries
    add hl, hl
    ex de, hl
      ld hl, CRCLookupTable
      add hl, de ; point to selected entry in CRCLookupTable
    ex de, hl

    ; New CRC = ((old CRC) >> 8) xor (pointed data)
    ; llmmnnoo ; looked up value
    ; 00aabbcc ; shifted old CRC
    ; AABBCCDD ; new CRC is the byte-wise XOR
    
    ld a, (de) ; byte 1
    ld hl, RAM_CRC
    ld b, (hl)
    ld (hl), a
    inc de
    inc hl
    
    ld a, (de) ; byte 2
    xor b
    ld b, (hl)
    ld (hl), a
    inc de
    inc hl

    ld a, (de) ; byte 3
    xor b
    ld b, (hl)
    ld (hl), a
    inc de
    inc hl

    ld a, (de) ; byte 4
    xor b
    ld (hl), a
  pop de
  pop bc
  
  dec bc
  ld a, b
  or c
  jp nz, --
  
  ; Invert all bits when done
  ld hl, RAM_CRC
  ld a, (hl)
  cpl
  ld (hl), a
  inc hl
  ld a, (hl)
  cpl
  ld (hl), a
  inc hl
  ld a, (hl)
  cpl
  ld (hl), a
  inc hl
  ld a, (hl)
  cpl
  ld (hl), a
  
  ret

; 32-bit crc routine
; entry: a contains next byte, hl points to crc
; exit:  crc updated
UpdateChecksum:
  ret

CRCLookupTable:
.macro CRC
  .db (\1>>24)&$ff, (\1>>16)&$ff, (\1>>8)&$ff, \1&$ff
.endm
  CRC $00000000
  CRC $77073096
  CRC $ee0e612c
  CRC $990951ba
  CRC $076dc419
  CRC $706af48f
  CRC $e963a535
  CRC $9e6495a3
  CRC $0edb8832
  CRC $79dcb8a4
  CRC $e0d5e91e
  CRC $97d2d988
  CRC $09b64c2b
  CRC $7eb17cbd
  CRC $e7b82d07
  CRC $90bf1d91
  CRC $1db71064
  CRC $6ab020f2
  CRC $f3b97148
  CRC $84be41de
  CRC $1adad47d
  CRC $6ddde4eb
  CRC $f4d4b551
  CRC $83d385c7
  CRC $136c9856
  CRC $646ba8c0
  CRC $fd62f97a
  CRC $8a65c9ec
  CRC $14015c4f
  CRC $63066cd9
  CRC $fa0f3d63
  CRC $8d080df5
  CRC $3b6e20c8
  CRC $4c69105e
  CRC $d56041e4
  CRC $a2677172
  CRC $3c03e4d1
  CRC $4b04d447
  CRC $d20d85fd
  CRC $a50ab56b
  CRC $35b5a8fa
  CRC $42b2986c
  CRC $dbbbc9d6
  CRC $acbcf940
  CRC $32d86ce3
  CRC $45df5c75
  CRC $dcd60dcf
  CRC $abd13d59
  CRC $26d930ac
  CRC $51de003a
  CRC $c8d75180
  CRC $bfd06116
  CRC $21b4f4b5
  CRC $56b3c423
  CRC $cfba9599
  CRC $b8bda50f
  CRC $2802b89e
  CRC $5f058808
  CRC $c60cd9b2
  CRC $b10be924
  CRC $2f6f7c87
  CRC $58684c11
  CRC $c1611dab
  CRC $b6662d3d
  CRC $76dc4190
  CRC $01db7106
  CRC $98d220bc
  CRC $efd5102a
  CRC $71b18589
  CRC $06b6b51f
  CRC $9fbfe4a5
  CRC $e8b8d433
  CRC $7807c9a2
  CRC $0f00f934
  CRC $9609a88e
  CRC $e10e9818
  CRC $7f6a0dbb
  CRC $086d3d2d
  CRC $91646c97
  CRC $e6635c01
  CRC $6b6b51f4
  CRC $1c6c6162
  CRC $856530d8
  CRC $f262004e
  CRC $6c0695ed
  CRC $1b01a57b
  CRC $8208f4c1
  CRC $f50fc457
  CRC $65b0d9c6
  CRC $12b7e950
  CRC $8bbeb8ea
  CRC $fcb9887c
  CRC $62dd1ddf
  CRC $15da2d49
  CRC $8cd37cf3
  CRC $fbd44c65
  CRC $4db26158
  CRC $3ab551ce
  CRC $a3bc0074
  CRC $d4bb30e2
  CRC $4adfa541
  CRC $3dd895d7
  CRC $a4d1c46d
  CRC $d3d6f4fb
  CRC $4369e96a
  CRC $346ed9fc
  CRC $ad678846
  CRC $da60b8d0
  CRC $44042d73
  CRC $33031de5
  CRC $aa0a4c5f
  CRC $dd0d7cc9
  CRC $5005713c
  CRC $270241aa
  CRC $be0b1010
  CRC $c90c2086
  CRC $5768b525
  CRC $206f85b3
  CRC $b966d409
  CRC $ce61e49f
  CRC $5edef90e
  CRC $29d9c998
  CRC $b0d09822
  CRC $c7d7a8b4
  CRC $59b33d17
  CRC $2eb40d81
  CRC $b7bd5c3b
  CRC $c0ba6cad
  CRC $edb88320
  CRC $9abfb3b6
  CRC $03b6e20c
  CRC $74b1d29a
  CRC $ead54739
  CRC $9dd277af
  CRC $04db2615
  CRC $73dc1683
  CRC $e3630b12
  CRC $94643b84
  CRC $0d6d6a3e
  CRC $7a6a5aa8
  CRC $e40ecf0b
  CRC $9309ff9d
  CRC $0a00ae27
  CRC $7d079eb1
  CRC $f00f9344
  CRC $8708a3d2
  CRC $1e01f268
  CRC $6906c2fe
  CRC $f762575d
  CRC $806567cb
  CRC $196c3671
  CRC $6e6b06e7
  CRC $fed41b76
  CRC $89d32be0
  CRC $10da7a5a
  CRC $67dd4acc
  CRC $f9b9df6f
  CRC $8ebeeff9
  CRC $17b7be43
  CRC $60b08ed5
  CRC $d6d6a3e8
  CRC $a1d1937e
  CRC $38d8c2c4
  CRC $4fdff252
  CRC $d1bb67f1
  CRC $a6bc5767
  CRC $3fb506dd
  CRC $48b2364b
  CRC $d80d2bda
  CRC $af0a1b4c
  CRC $36034af6
  CRC $41047a60
  CRC $df60efc3
  CRC $a867df55
  CRC $316e8eef
  CRC $4669be79
  CRC $cb61b38c
  CRC $bc66831a
  CRC $256fd2a0
  CRC $5268e236
  CRC $cc0c7795
  CRC $bb0b4703
  CRC $220216b9
  CRC $5505262f
  CRC $c5ba3bbe
  CRC $b2bd0b28
  CRC $2bb45a92
  CRC $5cb36a04
  CRC $c2d7ffa7
  CRC $b5d0cf31
  CRC $2cd99e8b
  CRC $5bdeae1d
  CRC $9b64c2b0
  CRC $ec63f226
  CRC $756aa39c
  CRC $026d930a
  CRC $9c0906a9
  CRC $eb0e363f
  CRC $72076785
  CRC $05005713
  CRC $95bf4a82
  CRC $e2b87a14
  CRC $7bb12bae
  CRC $0cb61b38
  CRC $92d28e9b
  CRC $e5d5be0d
  CRC $7cdcefb7
  CRC $0bdbdf21
  CRC $86d3d2d4
  CRC $f1d4e242
  CRC $68ddb3f8
  CRC $1fda836e
  CRC $81be16cd
  CRC $f6b9265b
  CRC $6fb077e1
  CRC $18b74777
  CRC $88085ae6
  CRC $ff0f6a70
  CRC $66063bca
  CRC $11010b5c
  CRC $8f659eff
  CRC $f862ae69
  CRC $616bffd3
  CRC $166ccf45
  CRC $a00ae278
  CRC $d70dd2ee
  CRC $4e048354
  CRC $3903b3c2
  CRC $a7672661
  CRC $d06016f7
  CRC $4969474d
  CRC $3e6e77db
  CRC $aed16a4a
  CRC $d9d65adc
  CRC $40df0b66
  CRC $37d83bf0
  CRC $a9bcae53
  CRC $debb9ec5
  CRC $47b2cf7f
  CRC $30b5ffe9
  CRC $bdbdf21c
  CRC $cabac28a
  CRC $53b39330
  CRC $24b4a3a6
  CRC $bad03605
  CRC $cdd70693
  CRC $54de5729
  CRC $23d967bf
  CRC $b3667a2e
  CRC $c4614ab8
  CRC $5d681b02
  CRC $2a6f2b94
  CRC $b40bbe37
  CRC $c30c8ea1
  CRC $5a05df1b
  CRC $2d02ef8d
.ends

; We fill with random data for CRCing
.bank 1 slot 1
.org 0
data:
;.dbrnd 16*1024
.dsb 16*1024 0

.bank 2 slot 2
.org 0
;.dbrnd 16*1024
.dsb 16*1024 0
