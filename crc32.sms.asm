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

; With UNROLL:    225.2 cycles per data byte, 2549 bytes code, 1024 bytes table = 32.98s for 512KB
; Without UNROLL: 239.1 cycles per data byte,   97 bytes code, 1024 bytes table = 35.02s for 512KB
.define UNROLL
; CODEGEN makes us generate code for each LUT entry instead of being data-driven.
;                 179.7 cycles per data byte, 4897 bytes code,  512 bytes table = 26.31s for 512KB
.define ALGORITHM "ASYNCHRONOUS"

.enum $c000
  RAM_CRC dd ; Stored as big-endian...
.ende

.bank 0 slot 0
.org 0

.if ALGORITHM == "LUT"
.section "Test" force
  ; Set page count
  ld b, 2

; 32-bit crc routine
; entry: de points to data, b = number of 16KB pages to checksum
; exit: RAM_CRC holds the CRC32 of the data

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
  
  ret ; to end the test

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
.endif

.if ALGORITHM == "CODEGEN"
.section "CRC32 optimised more" force
  exx
    ; init dehl to $ffff
    ld d,$ff
    ld e,d
    ld h,d
    ld l,d
    ld bc, $4000 ; Initial address
  exx

  ld bc, $8000 ; byte count

  ; read a byte
--:
  exx
    ld a, (bc)
    inc bc

    ; xor with LSB of CRC32
    xor l
  exx
  ; Look up handler function for this result
  ld l, a
  ld h, 0
  add hl, hl 
  ld de, FunctionTable
  add hl, de
  ; Jump to it
  ld a, (hl)
  inc hl
  ld h, (hl)
  ld l, a
  ld pc, hl
-:
  ; Code will resume here:
  dec c ; This pattern only works when the initial value of c is 0
  jp nz,--
  djnz --

  ; Put in memory while inverting
  exx
    ld a, l
    cpl
    ld (RAM_CRC+0), a
    ld a, h
    cpl
    ld (RAM_CRC+1), a
    ld a, e
    cpl
    ld (RAM_CRC+2), a
    ld a, d
    cpl
    ld (RAM_CRC+3), a
  ret
  
CallHL:
  jp (hl)
    
FunctionTable:
.dw CRC0 CRC1 CRC2 CRC3 CRC4 CRC5 CRC6 CRC7 CRC8 CRC9 CRC10 CRC11 CRC12 CRC13 CRC14 CRC15 CRC16 CRC17 CRC18 CRC19 CRC20 CRC21 CRC22 CRC23 CRC24 CRC25 CRC26 CRC27 CRC28 CRC29 CRC30 CRC31 CRC32 CRC33 CRC34 CRC35 CRC36 CRC37 CRC38 CRC39 CRC40 CRC41 CRC42 CRC43 CRC44 CRC45 CRC46 CRC47 CRC48 CRC49 CRC50 CRC51 CRC52 CRC53 CRC54 CRC55 CRC56 CRC57 CRC58 CRC59 CRC60 CRC61 CRC62 CRC63 CRC64 CRC65 CRC66 CRC67 CRC68 CRC69 CRC70 CRC71 CRC72 CRC73 CRC74 CRC75 CRC76 CRC77 CRC78 CRC79 CRC80 CRC81 CRC82 CRC83 CRC84 CRC85 CRC86 CRC87 CRC88 CRC89 CRC90 CRC91 CRC92 CRC93 CRC94 CRC95 CRC96 CRC97 CRC98 CRC99 CRC100 CRC101 CRC102 CRC103 CRC104 CRC105 CRC106 CRC107 CRC108 CRC109 CRC110 CRC111 CRC112 CRC113 CRC114 CRC115 CRC116 CRC117 CRC118 CRC119 CRC120 CRC121 CRC122 CRC123 CRC124 CRC125 CRC126 CRC127 CRC128 CRC129 CRC130 CRC131 CRC132 CRC133 CRC134 CRC135 CRC136 CRC137 CRC138 CRC139 CRC140 CRC141 CRC142 CRC143 CRC144 CRC145 CRC146 CRC147 CRC148 CRC149 CRC150 CRC151 CRC152 CRC153 CRC154 CRC155 CRC156 CRC157 CRC158 CRC159 CRC160 CRC161 CRC162 CRC163 CRC164 CRC165 CRC166 CRC167 CRC168 CRC169 CRC170 CRC171 CRC172 CRC173 CRC174 CRC175 CRC176 CRC177 CRC178 CRC179 CRC180 CRC181 CRC182 CRC183 CRC184 CRC185 CRC186 CRC187 CRC188 CRC189 CRC190 CRC191 CRC192 CRC193 CRC194 CRC195 CRC196 CRC197 CRC198 CRC199 CRC200 CRC201 CRC202 CRC203 CRC204 CRC205 CRC206 CRC207 CRC208 CRC209 CRC210 CRC211 CRC212 CRC213 CRC214 CRC215 CRC216 CRC217 CRC218 CRC219 CRC220 CRC221 CRC222 CRC223 CRC224 CRC225 CRC226 CRC227 CRC228 CRC229 CRC230 CRC231 CRC232 CRC233 CRC234 CRC235 CRC236 CRC237 CRC238 CRC239 CRC240 CRC241 CRC242 CRC243 CRC244 CRC245 CRC246 CRC247 CRC248 CRC249 CRC250 CRC251 CRC252 CRC253 CRC254 CRC255

.macro CRCEntry
  exx
.redefine b1 ((\1 >> 0) & $ff)
.if b1 == 0
  ld l, h
.else
  ld a, h
  xor b1
  ld l, a
.endif
.redefine b1 ((\1 >> 8) & $ff)
.if b1 == 0
  ld h, e
.else
  ld a, e
  xor b1
  ld h, a
.endif
.redefine b1 ((\1 >> 16) & $ff)
.if b1 == 0
  ld e, d
.else
  ld a, d
  xor b1
  ld e, a
.endif
.redefine b1 ((\1 >> 24) & $ff)
  ld d, b1
  exx
  jp -
.endm

CRC0:   CRCEntry $00000000
CRC1:   CRCEntry $77073096
CRC2:   CRCEntry $ee0e612c
CRC3:   CRCEntry $990951ba
CRC4:   CRCEntry $076dc419
CRC5:   CRCEntry $706af48f
CRC6:   CRCEntry $e963a535
CRC7:   CRCEntry $9e6495a3
CRC8:   CRCEntry $0edb8832
CRC9:   CRCEntry $79dcb8a4
CRC10:  CRCEntry $e0d5e91e
CRC11:  CRCEntry $97d2d988
CRC12:  CRCEntry $09b64c2b
CRC13:  CRCEntry $7eb17cbd
CRC14:  CRCEntry $e7b82d07
CRC15:  CRCEntry $90bf1d91
CRC16:  CRCEntry $1db71064
CRC17:  CRCEntry $6ab020f2
CRC18:  CRCEntry $f3b97148
CRC19:  CRCEntry $84be41de
CRC20:  CRCEntry $1adad47d
CRC21:  CRCEntry $6ddde4eb
CRC22:  CRCEntry $f4d4b551
CRC23:  CRCEntry $83d385c7
CRC24:  CRCEntry $136c9856
CRC25:  CRCEntry $646ba8c0
CRC26:  CRCEntry $fd62f97a
CRC27:  CRCEntry $8a65c9ec
CRC28:  CRCEntry $14015c4f
CRC29:  CRCEntry $63066cd9
CRC30:  CRCEntry $fa0f3d63
CRC31:  CRCEntry $8d080df5
CRC32:  CRCEntry $3b6e20c8
CRC33:  CRCEntry $4c69105e
CRC34:  CRCEntry $d56041e4
CRC35:  CRCEntry $a2677172
CRC36:  CRCEntry $3c03e4d1
CRC37:  CRCEntry $4b04d447
CRC38:  CRCEntry $d20d85fd
CRC39:  CRCEntry $a50ab56b
CRC40:  CRCEntry $35b5a8fa
CRC41:  CRCEntry $42b2986c
CRC42:  CRCEntry $dbbbc9d6
CRC43:  CRCEntry $acbcf940
CRC44:  CRCEntry $32d86ce3
CRC45:  CRCEntry $45df5c75
CRC46:  CRCEntry $dcd60dcf
CRC47:  CRCEntry $abd13d59
CRC48:  CRCEntry $26d930ac
CRC49:  CRCEntry $51de003a
CRC50:  CRCEntry $c8d75180
CRC51:  CRCEntry $bfd06116
CRC52:  CRCEntry $21b4f4b5
CRC53:  CRCEntry $56b3c423
CRC54:  CRCEntry $cfba9599
CRC55:  CRCEntry $b8bda50f
CRC56:  CRCEntry $2802b89e
CRC57:  CRCEntry $5f058808
CRC58:  CRCEntry $c60cd9b2
CRC59:  CRCEntry $b10be924
CRC60:  CRCEntry $2f6f7c87
CRC61:  CRCEntry $58684c11
CRC62:  CRCEntry $c1611dab
CRC63:  CRCEntry $b6662d3d
CRC64:  CRCEntry $76dc4190
CRC65:  CRCEntry $01db7106
CRC66:  CRCEntry $98d220bc
CRC67:  CRCEntry $efd5102a
CRC68:  CRCEntry $71b18589
CRC69:  CRCEntry $06b6b51f
CRC70:  CRCEntry $9fbfe4a5
CRC71:  CRCEntry $e8b8d433
CRC72:  CRCEntry $7807c9a2
CRC73:  CRCEntry $0f00f934
CRC74:  CRCEntry $9609a88e
CRC75:  CRCEntry $e10e9818
CRC76:  CRCEntry $7f6a0dbb
CRC77:  CRCEntry $086d3d2d
CRC78:  CRCEntry $91646c97
CRC79:  CRCEntry $e6635c01
CRC80:  CRCEntry $6b6b51f4
CRC81:  CRCEntry $1c6c6162
CRC82:  CRCEntry $856530d8
CRC83:  CRCEntry $f262004e
CRC84:  CRCEntry $6c0695ed
CRC85:  CRCEntry $1b01a57b
CRC86:  CRCEntry $8208f4c1
CRC87:  CRCEntry $f50fc457
CRC88:  CRCEntry $65b0d9c6
CRC89:  CRCEntry $12b7e950
CRC90:  CRCEntry $8bbeb8ea
CRC91:  CRCEntry $fcb9887c
CRC92:  CRCEntry $62dd1ddf
CRC93:  CRCEntry $15da2d49
CRC94:  CRCEntry $8cd37cf3
CRC95:  CRCEntry $fbd44c65
CRC96:  CRCEntry $4db26158
CRC97:  CRCEntry $3ab551ce
CRC98:  CRCEntry $a3bc0074
CRC99:  CRCEntry $d4bb30e2
CRC100: CRCEntry $4adfa541
CRC101: CRCEntry $3dd895d7
CRC102: CRCEntry $a4d1c46d
CRC103: CRCEntry $d3d6f4fb
CRC104: CRCEntry $4369e96a
CRC105: CRCEntry $346ed9fc
CRC106: CRCEntry $ad678846
CRC107: CRCEntry $da60b8d0
CRC108: CRCEntry $44042d73
CRC109: CRCEntry $33031de5
CRC110: CRCEntry $aa0a4c5f
CRC111: CRCEntry $dd0d7cc9
CRC112: CRCEntry $5005713c
CRC113: CRCEntry $270241aa
CRC114: CRCEntry $be0b1010
CRC115: CRCEntry $c90c2086
CRC116: CRCEntry $5768b525
CRC117: CRCEntry $206f85b3
CRC118: CRCEntry $b966d409
CRC119: CRCEntry $ce61e49f
CRC120: CRCEntry $5edef90e
CRC121: CRCEntry $29d9c998
CRC122: CRCEntry $b0d09822
CRC123: CRCEntry $c7d7a8b4
CRC124: CRCEntry $59b33d17
CRC125: CRCEntry $2eb40d81
CRC126: CRCEntry $b7bd5c3b
CRC127: CRCEntry $c0ba6cad
CRC128: CRCEntry $edb88320
CRC129: CRCEntry $9abfb3b6
CRC130: CRCEntry $03b6e20c
CRC131: CRCEntry $74b1d29a
CRC132: CRCEntry $ead54739
CRC133: CRCEntry $9dd277af
CRC134: CRCEntry $04db2615
CRC135: CRCEntry $73dc1683
CRC136: CRCEntry $e3630b12
CRC137: CRCEntry $94643b84
CRC138: CRCEntry $0d6d6a3e
CRC139: CRCEntry $7a6a5aa8
CRC140: CRCEntry $e40ecf0b
CRC141: CRCEntry $9309ff9d
CRC142: CRCEntry $0a00ae27
CRC143: CRCEntry $7d079eb1
CRC144: CRCEntry $f00f9344
CRC145: CRCEntry $8708a3d2
CRC146: CRCEntry $1e01f268
CRC147: CRCEntry $6906c2fe
CRC148: CRCEntry $f762575d
CRC149: CRCEntry $806567cb
CRC150: CRCEntry $196c3671
CRC151: CRCEntry $6e6b06e7
CRC152: CRCEntry $fed41b76
CRC153: CRCEntry $89d32be0
CRC154: CRCEntry $10da7a5a
CRC155: CRCEntry $67dd4acc
CRC156: CRCEntry $f9b9df6f
CRC157: CRCEntry $8ebeeff9
CRC158: CRCEntry $17b7be43
CRC159: CRCEntry $60b08ed5
CRC160: CRCEntry $d6d6a3e8
CRC161: CRCEntry $a1d1937e
CRC162: CRCEntry $38d8c2c4
CRC163: CRCEntry $4fdff252
CRC164: CRCEntry $d1bb67f1
CRC165: CRCEntry $a6bc5767
CRC166: CRCEntry $3fb506dd
CRC167: CRCEntry $48b2364b
CRC168: CRCEntry $d80d2bda
CRC169: CRCEntry $af0a1b4c
CRC170: CRCEntry $36034af6
CRC171: CRCEntry $41047a60
CRC172: CRCEntry $df60efc3
CRC173: CRCEntry $a867df55
CRC174: CRCEntry $316e8eef
CRC175: CRCEntry $4669be79
CRC176: CRCEntry $cb61b38c
CRC177: CRCEntry $bc66831a
CRC178: CRCEntry $256fd2a0
CRC179: CRCEntry $5268e236
CRC180: CRCEntry $cc0c7795
CRC181: CRCEntry $bb0b4703
CRC182: CRCEntry $220216b9
CRC183: CRCEntry $5505262f
CRC184: CRCEntry $c5ba3bbe
CRC185: CRCEntry $b2bd0b28
CRC186: CRCEntry $2bb45a92
CRC187: CRCEntry $5cb36a04
CRC188: CRCEntry $c2d7ffa7
CRC189: CRCEntry $b5d0cf31
CRC190: CRCEntry $2cd99e8b
CRC191: CRCEntry $5bdeae1d
CRC192: CRCEntry $9b64c2b0
CRC193: CRCEntry $ec63f226
CRC194: CRCEntry $756aa39c
CRC195: CRCEntry $026d930a
CRC196: CRCEntry $9c0906a9
CRC197: CRCEntry $eb0e363f
CRC198: CRCEntry $72076785
CRC199: CRCEntry $05005713
CRC200: CRCEntry $95bf4a82
CRC201: CRCEntry $e2b87a14
CRC202: CRCEntry $7bb12bae
CRC203: CRCEntry $0cb61b38
CRC204: CRCEntry $92d28e9b
CRC205: CRCEntry $e5d5be0d
CRC206: CRCEntry $7cdcefb7
CRC207: CRCEntry $0bdbdf21
CRC208: CRCEntry $86d3d2d4
CRC209: CRCEntry $f1d4e242
CRC210: CRCEntry $68ddb3f8
CRC211: CRCEntry $1fda836e
CRC212: CRCEntry $81be16cd
CRC213: CRCEntry $f6b9265b
CRC214: CRCEntry $6fb077e1
CRC215: CRCEntry $18b74777
CRC216: CRCEntry $88085ae6
CRC217: CRCEntry $ff0f6a70
CRC218: CRCEntry $66063bca
CRC219: CRCEntry $11010b5c
CRC220: CRCEntry $8f659eff
CRC221: CRCEntry $f862ae69
CRC222: CRCEntry $616bffd3
CRC223: CRCEntry $166ccf45
CRC224: CRCEntry $a00ae278
CRC225: CRCEntry $d70dd2ee
CRC226: CRCEntry $4e048354
CRC227: CRCEntry $3903b3c2
CRC228: CRCEntry $a7672661
CRC229: CRCEntry $d06016f7
CRC230: CRCEntry $4969474d
CRC231: CRCEntry $3e6e77db
CRC232: CRCEntry $aed16a4a
CRC233: CRCEntry $d9d65adc
CRC234: CRCEntry $40df0b66
CRC235: CRCEntry $37d83bf0
CRC236: CRCEntry $a9bcae53
CRC237: CRCEntry $debb9ec5
CRC238: CRCEntry $47b2cf7f
CRC239: CRCEntry $30b5ffe9
CRC240: CRCEntry $bdbdf21c
CRC241: CRCEntry $cabac28a
CRC242: CRCEntry $53b39330
CRC243: CRCEntry $24b4a3a6
CRC244: CRCEntry $bad03605
CRC245: CRCEntry $cdd70693
CRC246: CRCEntry $54de5729
CRC247: CRCEntry $23d967bf
CRC248: CRCEntry $b3667a2e
CRC249: CRCEntry $c4614ab8
CRC250: CRCEntry $5d681b02
CRC251: CRCEntry $2a6f2b94
CRC252: CRCEntry $b40bbe37
CRC253: CRCEntry $c30c8ea1
CRC254: CRCEntry $5a05df1b
CRC255: CRCEntry $2d02ef8d
.ends
.endif

.if ALGORITHM == "ASYNCHRONOUS"
.section "Asynchronous' version" force
  ld hl, $4000
  ld bc, $8000
  ; init CRC
  ld de, RAM_CRC+3
  ld a, $ff
  ld (de), a
  dec de
  ld (de), a
  dec de
  ld (de), a
  dec de
  ld (de), a
  call CRC32
  jp CRC32_Finalise ; and end

;CRC32
;==============
;by asynchronous
;2021
;smspower.org
;Register usage:
;HL = pointer to block being CRC32'ed
;BC = number of bytes being CRC32'ed
;DE = pointer to CRC32 in RAM (source and result)

CRC32:         
  PUSH AF                     ;preserve all used registers
  PUSH BC      
  PUSH DE      
  PUSH HL      
    ; swap b and c for faster looping
    ld a,b
    ld b,c
    ld c,a
    ; save CRC pointer for the end
    push de 
      ; get current CRC into d'e'b'c'
      push de
      exx
        pop hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
      exx
      
CRC32_Loop:         
      LD A,(HL)                  ;get the next byte to be CRC'ed
      EXX                        ;switch to BC',DE',HL'
      XOR C                     ;XOR the byte with the LSB of the CRC32
      LD L,A                     ;generate the LUT ptr
      LD H,(>CRCLookupTable >> 2) ;MSB of LUT >> 2 NOTE! LUT base address must be on a 1KB boundary e.g. $C400
      ADD HL,HL      
      ADD HL,HL      
      LD A,B                     ;XOR the LUT with the CRC >> 8
      XOR (HL)      
      LD C,A      
      INC HL      
      LD A,E      
      XOR (HL)      
      LD B,A      
      INC HL      
      LD A,D      
      XOR (HL)      
      LD E,A      
      INC HL      
      LD D,(HL)      
      EXX                        ;switch back to BC,DE,HL            
      INC HL                     ;increment pointer to next byte to be CRC'ed
      DJNZ CRC32_Loop            ;and loop
      DEC C      
      JR NZ,CRC32_Loop
      EXX                        ;the (almost) final CRC32 is in BC',DE'
    POP HL                     
    LD (HL),C
    INC HL
    LD (HL),B
    INC HL
    LD (HL),E
    INC HL
    LD (HL),D
    EXX      
    POP HL      
    POP DE      
    POP BC      
    POP AF      
    RET      

CRC32_Finalise:                                 
    PUSH AF
    PUSH BC
    PUSH DE
      LD B,4
CRC32_Finalise_Loop:
      LD A,(DE)
      XOR $FF
      LD (DE),A
      INC DE
      DJNZ CRC32_Finalise_Loop
    POP DE
    POP BC
    POP AF
    RET
 .ends

.section "Lookup table" align 1024 
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

.endif

; We fill with random data for CRCing
.bank 1
.org 0
data:
.incbin "data.bin" skip $0000 read $4000

.bank 2
.org 0
.incbin "data.bin" skip $4000 read $4000
