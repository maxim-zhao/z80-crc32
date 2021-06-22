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

; With UNROLL:    225.2 cycles per data byte, 2549 bytes code, 1024 bytes table
; Without UNROLL: 239.1 cycles per data byte,   97 bytes code, 1024 bytes table
.define UNROLL

.enum $c000
  RAM_CRC dd ; Stored as big-endian...
.ende

.bank 0 slot 0
.org 0
.section "Entry" force
  ; Set page count
  ld b, 2
  jp crc32 ; and ret for test
.ends

.section "CRC32 function" free
crc32:
; 32-bit crc routine
; entry: de points to data, bc = count
; exit: RAM_CRC updated

  ; init to $ffffffff
  exx
    ld hl, RAM_CRC+3
    ld a, $ff
    ld (hl), a
    dec hl
    ld (hl), a
    dec hl
    ld (hl), a
    dec hl
    ld (hl), a
  exx
  
  ld de, $4000 ; Initial address
  
  
_bank_loop:
  push bc
    
    ; Unrolling 64 times mans we need to loop only 256 times to cover 16KB
.ifdef UNROLL
.define UNROLL_COUNT 16*1024/256
    ld b, 0 ; to get 256 loops
.else
    ld bc, 16*1024
.endif
    
_bytes_in_bank_loop:

.ifdef UNROLL
.repeat UNROLL_COUNT
.endif
    ld a, (de)
    inc de
    
    exx
      ; Lookup index = (low byte of crc) xor (new byte)
      ; hl is already pointing at the low byte of the crc
      xor (hl) ; xor with new byte
      ld l, a
      ld h, 0
      add hl, hl ; use result as index into table of 4 byte entries
      add hl, hl
      ex de, hl
        ld hl, CRCLookupTable+3 ; to point to LSB
        add hl, de ; point to selected entry in CRCLookupTable
      ex de, hl

      ; New CRC = ((old CRC) >> 8) xor (pointed data)
      ; llmmnnoo ; looked up value
      ; 00aabbcc ; shifted old CRC
      ; AABBCCDD ; new CRC is the byte-wise XOR
      ld hl, RAM_CRC+3 ; point at dest byte
      
      ld a, (de) ; byte 1
      ; no xor for first byte
      ld b, (hl) ; save old value for next byte
      ld (hl), a
      dec de
      dec hl
      
      ld a, (de) ; byte 2
      xor b
      ld b, (hl)
      ld (hl), a
      dec de
      dec hl

      ld a, (de) ; byte 3
      xor b
      ld b, (hl)
      ld (hl), a
      dec de
      dec hl

      ld a, (de) ; byte 4
      xor b
      ld (hl), a
    exx

.ifdef UNROLL
.endr
    dec b
    jp nz, _bytes_in_bank_loop
.else
    dec c
    jp nz, _bytes_in_bank_loop
    dec b
    jp nz, _bytes_in_bank_loop
.endif
  pop bc

  dec b
  jp nz, _bank_loop
  
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

CRCLookupTable:
.dd $00000000 $77073096 $ee0e612c $990951ba $076dc419 $706af48f $e963a535 $9e6495a3
.dd $0edb8832 $79dcb8a4 $e0d5e91e $97d2d988 $09b64c2b $7eb17cbd $e7b82d07 $90bf1d91
.dd $1db71064 $6ab020f2 $f3b97148 $84be41de $1adad47d $6ddde4eb $f4d4b551 $83d385c7
.dd $136c9856 $646ba8c0 $fd62f97a $8a65c9ec $14015c4f $63066cd9 $fa0f3d63 $8d080df5
.dd $3b6e20c8 $4c69105e $d56041e4 $a2677172 $3c03e4d1 $4b04d447 $d20d85fd $a50ab56b
.dd $35b5a8fa $42b2986c $dbbbc9d6 $acbcf940 $32d86ce3 $45df5c75 $dcd60dcf $abd13d59
.dd $26d930ac $51de003a $c8d75180 $bfd06116 $21b4f4b5 $56b3c423 $cfba9599 $b8bda50f
.dd $2802b89e $5f058808 $c60cd9b2 $b10be924 $2f6f7c87 $58684c11 $c1611dab $b6662d3d
.dd $76dc4190 $01db7106 $98d220bc $efd5102a $71b18589 $06b6b51f $9fbfe4a5 $e8b8d433
.dd $7807c9a2 $0f00f934 $9609a88e $e10e9818 $7f6a0dbb $086d3d2d $91646c97 $e6635c01
.dd $6b6b51f4 $1c6c6162 $856530d8 $f262004e $6c0695ed $1b01a57b $8208f4c1 $f50fc457
.dd $65b0d9c6 $12b7e950 $8bbeb8ea $fcb9887c $62dd1ddf $15da2d49 $8cd37cf3 $fbd44c65
.dd $4db26158 $3ab551ce $a3bc0074 $d4bb30e2 $4adfa541 $3dd895d7 $a4d1c46d $d3d6f4fb
.dd $4369e96a $346ed9fc $ad678846 $da60b8d0 $44042d73 $33031de5 $aa0a4c5f $dd0d7cc9
.dd $5005713c $270241aa $be0b1010 $c90c2086 $5768b525 $206f85b3 $b966d409 $ce61e49f
.dd $5edef90e $29d9c998 $b0d09822 $c7d7a8b4 $59b33d17 $2eb40d81 $b7bd5c3b $c0ba6cad
.dd $edb88320 $9abfb3b6 $03b6e20c $74b1d29a $ead54739 $9dd277af $04db2615 $73dc1683
.dd $e3630b12 $94643b84 $0d6d6a3e $7a6a5aa8 $e40ecf0b $9309ff9d $0a00ae27 $7d079eb1
.dd $f00f9344 $8708a3d2 $1e01f268 $6906c2fe $f762575d $806567cb $196c3671 $6e6b06e7
.dd $fed41b76 $89d32be0 $10da7a5a $67dd4acc $f9b9df6f $8ebeeff9 $17b7be43 $60b08ed5
.dd $d6d6a3e8 $a1d1937e $38d8c2c4 $4fdff252 $d1bb67f1 $a6bc5767 $3fb506dd $48b2364b
.dd $d80d2bda $af0a1b4c $36034af6 $41047a60 $df60efc3 $a867df55 $316e8eef $4669be79
.dd $cb61b38c $bc66831a $256fd2a0 $5268e236 $cc0c7795 $bb0b4703 $220216b9 $5505262f
.dd $c5ba3bbe $b2bd0b28 $2bb45a92 $5cb36a04 $c2d7ffa7 $b5d0cf31 $2cd99e8b $5bdeae1d
.dd $9b64c2b0 $ec63f226 $756aa39c $026d930a $9c0906a9 $eb0e363f $72076785 $05005713
.dd $95bf4a82 $e2b87a14 $7bb12bae $0cb61b38 $92d28e9b $e5d5be0d $7cdcefb7 $0bdbdf21
.dd $86d3d2d4 $f1d4e242 $68ddb3f8 $1fda836e $81be16cd $f6b9265b $6fb077e1 $18b74777
.dd $88085ae6 $ff0f6a70 $66063bca $11010b5c $8f659eff $f862ae69 $616bffd3 $166ccf45
.dd $a00ae278 $d70dd2ee $4e048354 $3903b3c2 $a7672661 $d06016f7 $4969474d $3e6e77db
.dd $aed16a4a $d9d65adc $40df0b66 $37d83bf0 $a9bcae53 $debb9ec5 $47b2cf7f $30b5ffe9
.dd $bdbdf21c $cabac28a $53b39330 $24b4a3a6 $bad03605 $cdd70693 $54de5729 $23d967bf
.dd $b3667a2e $c4614ab8 $5d681b02 $2a6f2b94 $b40bbe37 $c30c8ea1 $5a05df1b $2d02ef8d
.ends

; We fill with random data for CRCing
.bank 1
.org 0
data:
.incbin "data.bin" skip $0000 read $4000

.bank 2
.org 0
.incbin "data.bin" skip $4000 read $4000
