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

; Algorithms:
;
; 1. "LUT"
;
; LUT is derived from the code in ZEXALL but somewhat optimised.
; With UNROLL:    128.2 cycles per data byte, 1517 bytes code, 1024 bytes table = 18.78s for 512KB
; Without UNROLL: 141.0 cycles per data byte,   72 bytes code, 1024 bytes table = 20.66s for 512KB
;
; 2. "CODEGEN"
;
; CODEGEN makes us generate code for each LUT entry instead of being data-driven.
;                 157.6 cycles per data byte, 4893 bytes code,  512 bytes table = 23.09s for 512KB
;
; 3. "ASYNCHRONOUS"
;
; ASYNCHRONOUS is from https://www.smspower.org/forums/18523-BitBangingAndCartridgeDumping
; and has a bunch of good optimisations that I also stole for LUT...
; - Keep the state in alternate registers
; - Align the table
; - Swap the counter bytes so djnz is on the inside
;
; 4. "Z80TEST"
;
; Taken from code at https://github.com/raxoft/z80test/blob/master/src/idea.asm. This is similar
; to ASYNCHRONOUS.

.define ALGORITHM "Z80TEST"
.define UNROLL

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
.section "Code-generated for each byte" force
  exx
    ; init dehl to $ffff
    ld de,$ffff
    ld h,d
    ld l,d
    ld bc, $4000 ; Initial address
  exx

  ld bc, $0080 ; byte count, byte-swapped

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
  ld h, (>FunctionTable)>>1
  add hl, hl 
  ; Jump to it
  ld a, (hl)
  inc hl
  ld h, (hl)
  ld l, a
  jp (hl)
CodeGenResume:
  ; Code will resume here:
  djnz --
  dec c
  jp nz,--

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
.ends

.section "Pointer table" align 512
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
  jp CodeGenResume
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
    POP HL ; restore the CRC pointer to push state back to RAM
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
      cpl
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

.if ALGORITHM == "Z80TEST"
.section "Z80Test version" force
  ; Set page count
  ld b, 2

  ; Init CRC state in shadow regs
  exx
    ld bc, $ffff
    ld d, b
    ld e, c
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

    ; CRC update.
    exx
      xor e

      ld l, a
      ld h, >crctable

      ld a, (hl)
      xor d
      ld e, a
      inc h

      ld a, (hl)
      xor c
      ld d, a
      inc h

      ld a, (hl)
      xor b
      ld c, a
      inc h

      ld b, (hl)
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
    ld a, e
    cpl
    ld (hl), a
    inc hl
    ld a, d
    cpl
    ld (hl), a
    inc hl
    ld a, c
    cpl
    ld (hl), a
    inc hl
    ld a, b
    cpl
    ld (hl), a
  exx
  ret ; to end the test

.ends

.section "CRC table" align 256  
crctable:
.db $00 ; 00 00000000
.db $96 ; 01 77073096
.db $2c ; 02 ee0e612c
.db $ba ; 03 990951ba
.db $19 ; 04 076dc419
.db $8f ; 05 706af48f
.db $35 ; 06 e963a535
.db $a3 ; 07 9e6495a3
.db $32 ; 08 0edb8832
.db $a4 ; 09 79dcb8a4
.db $1e ; 0a e0d5e91e
.db $88 ; 0b 97d2d988
.db $2b ; 0c 09b64c2b
.db $bd ; 0d 7eb17cbd
.db $07 ; 0e e7b82d07
.db $91 ; 0f 90bf1d91
.db $64 ; 10 1db71064
.db $f2 ; 11 6ab020f2
.db $48 ; 12 f3b97148
.db $de ; 13 84be41de
.db $7d ; 14 1adad47d
.db $eb ; 15 6ddde4eb
.db $51 ; 16 f4d4b551
.db $c7 ; 17 83d385c7
.db $56 ; 18 136c9856
.db $c0 ; 19 646ba8c0
.db $7a ; 1a fd62f97a
.db $ec ; 1b 8a65c9ec
.db $4f ; 1c 14015c4f
.db $d9 ; 1d 63066cd9
.db $63 ; 1e fa0f3d63
.db $f5 ; 1f 8d080df5
.db $c8 ; 20 3b6e20c8
.db $5e ; 21 4c69105e
.db $e4 ; 22 d56041e4
.db $72 ; 23 a2677172
.db $d1 ; 24 3c03e4d1
.db $47 ; 25 4b04d447
.db $fd ; 26 d20d85fd
.db $6b ; 27 a50ab56b
.db $fa ; 28 35b5a8fa
.db $6c ; 29 42b2986c
.db $d6 ; 2a.dbbbc9d6
.db $40 ; 2b acbcf940
.db $e3 ; 2c 32d86ce3
.db $75 ; 2d 45df5c75
.db $cf ; 2e dcd60dcf
.db $59 ; 2f abd13d59
.db $ac ; 30 26d930ac
.db $3a ; 31 51de003a
.db $80 ; 32 c8d75180
.db $16 ; 33 bfd06116
.db $b5 ; 34 21b4f4b5
.db $23 ; 35 56b3c423
.db $99 ; 36 cfba9599
.db $0f ; 37 b8bda50f
.db $9e ; 38 2802b89e
.db $08 ; 39 5f058808
.db $b2 ; 3a c60cd9b2
.db $24 ; 3b b10be924
.db $87 ; 3c 2f6f7c87
.db $11 ; 3d 58684c11
.db $ab ; 3e c1611dab
.db $3d ; 3f b6662d3d
.db $90 ; 40 76dc4190
.db $06 ; 41 01db7106
.db $bc ; 42 98d220bc
.db $2a ; 43 efd5102a
.db $89 ; 44 71b18589
.db $1f ; 45 06b6b51f
.db $a5 ; 46 9fbfe4a5
.db $33 ; 47 e8b8d433
.db $a2 ; 48 7807c9a2
.db $34 ; 49 0f00f934
.db $8e ; 4a 9609a88e
.db $18 ; 4b e10e9818
.db $bb ; 4c 7f6a0dbb
.db $2d ; 4d 086d3d2d
.db $97 ; 4e 91646c97
.db $01 ; 4f e6635c01
.db $f4 ; 50 6b6b51f4
.db $62 ; 51 1c6c6162
.db $d8 ; 52 856530d8
.db $4e ; 53 f262004e
.db $ed ; 54 6c0695ed
.db $7b ; 55 1b01a57b
.db $c1 ; 56 8208f4c1
.db $57 ; 57 f50fc457
.db $c6 ; 58 65b0d9c6
.db $50 ; 59 12b7e950
.db $ea ; 5a 8bbeb8ea
.db $7c ; 5b fcb9887c
.db $df ; 5c 62dd1ddf
.db $49 ; 5d 15da2d49
.db $f3 ; 5e 8cd37cf3
.db $65 ; 5f fbd44c65
.db $58 ; 60 4db26158
.db $ce ; 61 3ab551ce
.db $74 ; 62 a3bc0074
.db $e2 ; 63 d4bb30e2
.db $41 ; 64 4adfa541
.db $d7 ; 65 3dd895d7
.db $6d ; 66 a4d1c46d
.db $fb ; 67 d3d6f4fb
.db $6a ; 68 4369e96a
.db $fc ; 69 346ed9fc
.db $46 ; 6a ad678846
.db $d0 ; 6b da60b8d0
.db $73 ; 6c 44042d73
.db $e5 ; 6d 33031de5
.db $5f ; 6e aa0a4c5f
.db $c9 ; 6f dd0d7cc9
.db $3c ; 70 5005713c
.db $aa ; 71 270241aa
.db $10 ; 72 be0b1010
.db $86 ; 73 c90c2086
.db $25 ; 74 5768b525
.db $b3 ; 75 206f85b3
.db $09 ; 76 b966d409
.db $9f ; 77 ce61e49f
.db $0e ; 78 5edef90e
.db $98 ; 79 29d9c998
.db $22 ; 7a b0d09822
.db $b4 ; 7b c7d7a8b4
.db $17 ; 7c 59b33d17
.db $81 ; 7d 2eb40d81
.db $3b ; 7e b7bd5c3b
.db $ad ; 7f c0ba6cad
.db $20 ; 80 edb88320
.db $b6 ; 81 9abfb3b6
.db $0c ; 82 03b6e20c
.db $9a ; 83 74b1d29a
.db $39 ; 84 ead54739
.db $af ; 85 9dd277af
.db $15 ; 86 04db2615
.db $83 ; 87 73dc1683
.db $12 ; 88 e3630b12
.db $84 ; 89 94643b84
.db $3e ; 8a 0d6d6a3e
.db $a8 ; 8b 7a6a5aa8
.db $0b ; 8c e40ecf0b
.db $9d ; 8d 9309ff9d
.db $27 ; 8e 0a00ae27
.db $b1 ; 8f 7d079eb1
.db $44 ; 90 f00f9344
.db $d2 ; 91 8708a3d2
.db $68 ; 92 1e01f268
.db $fe ; 93 6906c2fe
.db $5d ; 94 f762575d
.db $cb ; 95 806567cb
.db $71 ; 96 196c3671
.db $e7 ; 97 6e6b06e7
.db $76 ; 98 fed41b76
.db $e0 ; 99 89d32be0
.db $5a ; 9a 10da7a5a
.db $cc ; 9b 67dd4acc
.db $6f ; 9c f9b9df6f
.db $f9 ; 9d 8ebeeff9
.db $43 ; 9e 17b7be43
.db $d5 ; 9f 60b08ed5
.db $e8 ; a0 d6d6a3e8
.db $7e ; a1 a1d1937e
.db $c4 ; a2 38d8c2c4
.db $52 ; a3 4fdff252
.db $f1 ; a4 d1bb67f1
.db $67 ; a5 a6bc5767
.db $dd ; a6 3fb506dd
.db $4b ; a7 48b2364b
.db $da ; a8 d80d2bda
.db $4c ; a9 af0a1b4c
.db $f6 ; aa 36034af6
.db $60 ; ab 41047a60
.db $c3 ; ac df60efc3
.db $55 ; ad a867df55
.db $ef ; ae 316e8eef
.db $79 ; af 4669be79
.db $8c ; b0 cb61b38c
.db $1a ; b1 bc66831a
.db $a0 ; b2 256fd2a0
.db $36 ; b3 5268e236
.db $95 ; b4 cc0c7795
.db $03 ; b5 bb0b4703
.db $b9 ; b6 220216b9
.db $2f ; b7 5505262f
.db $be ; b8 c5ba3bbe
.db $28 ; b9 b2bd0b28
.db $92 ; ba 2bb45a92
.db $04 ; bb 5cb36a04
.db $a7 ; bc c2d7ffa7
.db $31 ; bd b5d0cf31
.db $8b ; be 2cd99e8b
.db $1d ; bf 5bdeae1d
.db $b0 ; c0 9b64c2b0
.db $26 ; c1 ec63f226
.db $9c ; c2 756aa39c
.db $0a ; c3 026d930a
.db $a9 ; c4 9c0906a9
.db $3f ; c5 eb0e363f
.db $85 ; c6 72076785
.db $13 ; c7 05005713
.db $82 ; c8 95bf4a82
.db $14 ; c9 e2b87a14
.db $ae ; ca 7bb12bae
.db $38 ; cb 0cb61b38
.db $9b ; cc 92d28e9b
.db $0d ; cd e5d5be0d
.db $b7 ; ce 7cdcefb7
.db $21 ; cf 0bdbdf21
.db $d4 ; d0 86d3d2d4
.db $42 ; d1 f1d4e242
.db $f8 ; d2 68ddb3f8
.db $6e ; d3 1fda836e
.db $cd ; d4 81be16cd
.db $5b ; d5 f6b9265b
.db $e1 ; d6 6fb077e1
.db $77 ; d7 18b74777
.db $e6 ; d8 88085ae6
.db $70 ; d9 ff0f6a70
.db $ca ; da 66063bca
.db $5c ;.db 11010b5c
.db $ff ; dc 8f659eff
.db $69 ; dd f862ae69
.db $d3 ; de 616bffd3
.db $45 ; df 166ccf45
.db $78 ; e0 a00ae278
.db $ee ; e1 d70dd2ee
.db $54 ; e2 4e048354
.db $c2 ; e3 3903b3c2
.db $61 ; e4 a7672661
.db $f7 ; e5 d06016f7
.db $4d ; e6 4969474d
.db $db ; e7 3e6e77db
.db $4a ; e8 aed16a4a
.db $dc ; e9 d9d65adc
.db $66 ; ea 40df0b66
.db $f0 ; eb 37d83bf0
.db $53 ; ec a9bcae53
.db $c5 ; ed debb9ec5
.db $7f ; ee 47b2cf7f
.db $e9 ; ef 30b5ffe9
.db $1c ; f0 bdbdf21c
.db $8a ; f1 cabac28a
.db $30 ; f2 53b39330
.db $a6 ; f3 24b4a3a6
.db $05 ; f4 bad03605
.db $93 ; f5 cdd70693
.db $29 ; f6 54de5729
.db $bf ; f7 23d967bf
.db $2e ; f8 b3667a2e
.db $b8 ; f9 c4614ab8
.db $02 ; fa 5d681b02
.db $94 ; fb 2a6f2b94
.db $37 ; fc b40bbe37
.db $a1 ; fd c30c8ea1
.db $1b ; fe 5a05df1b
.db $8d ; ff 2d02ef8d

.db $00 ; 00 00000000
.db $30 ; 01 77073096
.db $61 ; 02 ee0e612c
.db $51 ; 03 990951ba
.db $c4 ; 04 076dc419
.db $f4 ; 05 706af48f
.db $a5 ; 06 e963a535
.db $95 ; 07 9e6495a3
.db $88 ; 08 0edb8832
.db $b8 ; 09 79dcb8a4
.db $e9 ; 0a e0d5e91e
.db $d9 ; 0b 97d2d988
.db $4c ; 0c 09b64c2b
.db $7c ; 0d 7eb17cbd
.db $2d ; 0e e7b82d07
.db $1d ; 0f 90bf1d91
.db $10 ; 10 1db71064
.db $20 ; 11 6ab020f2
.db $71 ; 12 f3b97148
.db $41 ; 13 84be41de
.db $d4 ; 14 1adad47d
.db $e4 ; 15 6ddde4eb
.db $b5 ; 16 f4d4b551
.db $85 ; 17 83d385c7
.db $98 ; 18 136c9856
.db $a8 ; 19 646ba8c0
.db $f9 ; 1a fd62f97a
.db $c9 ; 1b 8a65c9ec
.db $5c ; 1c 14015c4f
.db $6c ; 1d 63066cd9
.db $3d ; 1e fa0f3d63
.db $0d ; 1f 8d080df5
.db $20 ; 20 3b6e20c8
.db $10 ; 21 4c69105e
.db $41 ; 22 d56041e4
.db $71 ; 23 a2677172
.db $e4 ; 24 3c03e4d1
.db $d4 ; 25 4b04d447
.db $85 ; 26 d20d85fd
.db $b5 ; 27 a50ab56b
.db $a8 ; 28 35b5a8fa
.db $98 ; 29 42b2986c
.db $c9 ; 2a.dbbbc9d6
.db $f9 ; 2b acbcf940
.db $6c ; 2c 32d86ce3
.db $5c ; 2d 45df5c75
.db $0d ; 2e dcd60dcf
.db $3d ; 2f abd13d59
.db $30 ; 30 26d930ac
.db $00 ; 31 51de003a
.db $51 ; 32 c8d75180
.db $61 ; 33 bfd06116
.db $f4 ; 34 21b4f4b5
.db $c4 ; 35 56b3c423
.db $95 ; 36 cfba9599
.db $a5 ; 37 b8bda50f
.db $b8 ; 38 2802b89e
.db $88 ; 39 5f058808
.db $d9 ; 3a c60cd9b2
.db $e9 ; 3b b10be924
.db $7c ; 3c 2f6f7c87
.db $4c ; 3d 58684c11
.db $1d ; 3e c1611dab
.db $2d ; 3f b6662d3d
.db $41 ; 40 76dc4190
.db $71 ; 41 01db7106
.db $20 ; 42 98d220bc
.db $10 ; 43 efd5102a
.db $85 ; 44 71b18589
.db $b5 ; 45 06b6b51f
.db $e4 ; 46 9fbfe4a5
.db $d4 ; 47 e8b8d433
.db $c9 ; 48 7807c9a2
.db $f9 ; 49 0f00f934
.db $a8 ; 4a 9609a88e
.db $98 ; 4b e10e9818
.db $0d ; 4c 7f6a0dbb
.db $3d ; 4d 086d3d2d
.db $6c ; 4e 91646c97
.db $5c ; 4f e6635c01
.db $51 ; 50 6b6b51f4
.db $61 ; 51 1c6c6162
.db $30 ; 52 856530d8
.db $00 ; 53 f262004e
.db $95 ; 54 6c0695ed
.db $a5 ; 55 1b01a57b
.db $f4 ; 56 8208f4c1
.db $c4 ; 57 f50fc457
.db $d9 ; 58 65b0d9c6
.db $e9 ; 59 12b7e950
.db $b8 ; 5a 8bbeb8ea
.db $88 ; 5b fcb9887c
.db $1d ; 5c 62dd1ddf
.db $2d ; 5d 15da2d49
.db $7c ; 5e 8cd37cf3
.db $4c ; 5f fbd44c65
.db $61 ; 60 4db26158
.db $51 ; 61 3ab551ce
.db $00 ; 62 a3bc0074
.db $30 ; 63 d4bb30e2
.db $a5 ; 64 4adfa541
.db $95 ; 65 3dd895d7
.db $c4 ; 66 a4d1c46d
.db $f4 ; 67 d3d6f4fb
.db $e9 ; 68 4369e96a
.db $d9 ; 69 346ed9fc
.db $88 ; 6a ad678846
.db $b8 ; 6b da60b8d0
.db $2d ; 6c 44042d73
.db $1d ; 6d 33031de5
.db $4c ; 6e aa0a4c5f
.db $7c ; 6f dd0d7cc9
.db $71 ; 70 5005713c
.db $41 ; 71 270241aa
.db $10 ; 72 be0b1010
.db $20 ; 73 c90c2086
.db $b5 ; 74 5768b525
.db $85 ; 75 206f85b3
.db $d4 ; 76 b966d409
.db $e4 ; 77 ce61e49f
.db $f9 ; 78 5edef90e
.db $c9 ; 79 29d9c998
.db $98 ; 7a b0d09822
.db $a8 ; 7b c7d7a8b4
.db $3d ; 7c 59b33d17
.db $0d ; 7d 2eb40d81
.db $5c ; 7e b7bd5c3b
.db $6c ; 7f c0ba6cad
.db $83 ; 80 edb88320
.db $b3 ; 81 9abfb3b6
.db $e2 ; 82 03b6e20c
.db $d2 ; 83 74b1d29a
.db $47 ; 84 ead54739
.db $77 ; 85 9dd277af
.db $26 ; 86 04db2615
.db $16 ; 87 73dc1683
.db $0b ; 88 e3630b12
.db $3b ; 89 94643b84
.db $6a ; 8a 0d6d6a3e
.db $5a ; 8b 7a6a5aa8
.db $cf ; 8c e40ecf0b
.db $ff ; 8d 9309ff9d
.db $ae ; 8e 0a00ae27
.db $9e ; 8f 7d079eb1
.db $93 ; 90 f00f9344
.db $a3 ; 91 8708a3d2
.db $f2 ; 92 1e01f268
.db $c2 ; 93 6906c2fe
.db $57 ; 94 f762575d
.db $67 ; 95 806567cb
.db $36 ; 96 196c3671
.db $06 ; 97 6e6b06e7
.db $1b ; 98 fed41b76
.db $2b ; 99 89d32be0
.db $7a ; 9a 10da7a5a
.db $4a ; 9b 67dd4acc
.db $df ; 9c f9b9df6f
.db $ef ; 9d 8ebeeff9
.db $be ; 9e 17b7be43
.db $8e ; 9f 60b08ed5
.db $a3 ; a0 d6d6a3e8
.db $93 ; a1 a1d1937e
.db $c2 ; a2 38d8c2c4
.db $f2 ; a3 4fdff252
.db $67 ; a4 d1bb67f1
.db $57 ; a5 a6bc5767
.db $06 ; a6 3fb506dd
.db $36 ; a7 48b2364b
.db $2b ; a8 d80d2bda
.db $1b ; a9 af0a1b4c
.db $4a ; aa 36034af6
.db $7a ; ab 41047a60
.db $ef ; ac df60efc3
.db $df ; ad a867df55
.db $8e ; ae 316e8eef
.db $be ; af 4669be79
.db $b3 ; b0 cb61b38c
.db $83 ; b1 bc66831a
.db $d2 ; b2 256fd2a0
.db $e2 ; b3 5268e236
.db $77 ; b4 cc0c7795
.db $47 ; b5 bb0b4703
.db $16 ; b6 220216b9
.db $26 ; b7 5505262f
.db $3b ; b8 c5ba3bbe
.db $0b ; b9 b2bd0b28
.db $5a ; ba 2bb45a92
.db $6a ; bb 5cb36a04
.db $ff ; bc c2d7ffa7
.db $cf ; bd b5d0cf31
.db $9e ; be 2cd99e8b
.db $ae ; bf 5bdeae1d
.db $c2 ; c0 9b64c2b0
.db $f2 ; c1 ec63f226
.db $a3 ; c2 756aa39c
.db $93 ; c3 026d930a
.db $06 ; c4 9c0906a9
.db $36 ; c5 eb0e363f
.db $67 ; c6 72076785
.db $57 ; c7 05005713
.db $4a ; c8 95bf4a82
.db $7a ; c9 e2b87a14
.db $2b ; ca 7bb12bae
.db $1b ; cb 0cb61b38
.db $8e ; cc 92d28e9b
.db $be ; cd e5d5be0d
.db $ef ; ce 7cdcefb7
.db $df ; cf 0bdbdf21
.db $d2 ; d0 86d3d2d4
.db $e2 ; d1 f1d4e242
.db $b3 ; d2 68ddb3f8
.db $83 ; d3 1fda836e
.db $16 ; d4 81be16cd
.db $26 ; d5 f6b9265b
.db $77 ; d6 6fb077e1
.db $47 ; d7 18b74777
.db $5a ; d8 88085ae6
.db $6a ; d9 ff0f6a70
.db $3b ; da 66063bca
.db $0b ;.db 11010b5c
.db $9e ; dc 8f659eff
.db $ae ; dd f862ae69
.db $ff ; de 616bffd3
.db $cf ; df 166ccf45
.db $e2 ; e0 a00ae278
.db $d2 ; e1 d70dd2ee
.db $83 ; e2 4e048354
.db $b3 ; e3 3903b3c2
.db $26 ; e4 a7672661
.db $16 ; e5 d06016f7
.db $47 ; e6 4969474d
.db $77 ; e7 3e6e77db
.db $6a ; e8 aed16a4a
.db $5a ; e9 d9d65adc
.db $0b ; ea 40df0b66
.db $3b ; eb 37d83bf0
.db $ae ; ec a9bcae53
.db $9e ; ed debb9ec5
.db $cf ; ee 47b2cf7f
.db $ff ; ef 30b5ffe9
.db $f2 ; f0 bdbdf21c
.db $c2 ; f1 cabac28a
.db $93 ; f2 53b39330
.db $a3 ; f3 24b4a3a6
.db $36 ; f4 bad03605
.db $06 ; f5 cdd70693
.db $57 ; f6 54de5729
.db $67 ; f7 23d967bf
.db $7a ; f8 b3667a2e
.db $4a ; f9 c4614ab8
.db $1b ; fa 5d681b02
.db $2b ; fb 2a6f2b94
.db $be ; fc b40bbe37
.db $8e ; fd c30c8ea1
.db $df ; fe 5a05df1b
.db $ef ; ff 2d02ef8d

.db $00 ; 00 00000000
.db $07 ; 01 77073096
.db $0e ; 02 ee0e612c
.db $09 ; 03 990951ba
.db $6d ; 04 076dc419
.db $6a ; 05 706af48f
.db $63 ; 06 e963a535
.db $64 ; 07 9e6495a3
.db $db ; 08 0edb8832
.db $dc ; 09 79dcb8a4
.db $d5 ; 0a e0d5e91e
.db $d2 ; 0b 97d2d988
.db $b6 ; 0c 09b64c2b
.db $b1 ; 0d 7eb17cbd
.db $b8 ; 0e e7b82d07
.db $bf ; 0f 90bf1d91
.db $b7 ; 10 1db71064
.db $b0 ; 11 6ab020f2
.db $b9 ; 12 f3b97148
.db $be ; 13 84be41de
.db $da ; 14 1adad47d
.db $dd ; 15 6ddde4eb
.db $d4 ; 16 f4d4b551
.db $d3 ; 17 83d385c7
.db $6c ; 18 136c9856
.db $6b ; 19 646ba8c0
.db $62 ; 1a fd62f97a
.db $65 ; 1b 8a65c9ec
.db $01 ; 1c 14015c4f
.db $06 ; 1d 63066cd9
.db $0f ; 1e fa0f3d63
.db $08 ; 1f 8d080df5
.db $6e ; 20 3b6e20c8
.db $69 ; 21 4c69105e
.db $60 ; 22 d56041e4
.db $67 ; 23 a2677172
.db $03 ; 24 3c03e4d1
.db $04 ; 25 4b04d447
.db $0d ; 26 d20d85fd
.db $0a ; 27 a50ab56b
.db $b5 ; 28 35b5a8fa
.db $b2 ; 29 42b2986c
.db $bb ; 2a.dbbbc9d6
.db $bc ; 2b acbcf940
.db $d8 ; 2c 32d86ce3
.db $df ; 2d 45df5c75
.db $d6 ; 2e dcd60dcf
.db $d1 ; 2f abd13d59
.db $d9 ; 30 26d930ac
.db $de ; 31 51de003a
.db $d7 ; 32 c8d75180
.db $d0 ; 33 bfd06116
.db $b4 ; 34 21b4f4b5
.db $b3 ; 35 56b3c423
.db $ba ; 36 cfba9599
.db $bd ; 37 b8bda50f
.db $02 ; 38 2802b89e
.db $05 ; 39 5f058808
.db $0c ; 3a c60cd9b2
.db $0b ; 3b b10be924
.db $6f ; 3c 2f6f7c87
.db $68 ; 3d 58684c11
.db $61 ; 3e c1611dab
.db $66 ; 3f b6662d3d
.db $dc ; 40 76dc4190
.db $db ; 41 01db7106
.db $d2 ; 42 98d220bc
.db $d5 ; 43 efd5102a
.db $b1 ; 44 71b18589
.db $b6 ; 45 06b6b51f
.db $bf ; 46 9fbfe4a5
.db $b8 ; 47 e8b8d433
.db $07 ; 48 7807c9a2
.db $00 ; 49 0f00f934
.db $09 ; 4a 9609a88e
.db $0e ; 4b e10e9818
.db $6a ; 4c 7f6a0dbb
.db $6d ; 4d 086d3d2d
.db $64 ; 4e 91646c97
.db $63 ; 4f e6635c01
.db $6b ; 50 6b6b51f4
.db $6c ; 51 1c6c6162
.db $65 ; 52 856530d8
.db $62 ; 53 f262004e
.db $06 ; 54 6c0695ed
.db $01 ; 55 1b01a57b
.db $08 ; 56 8208f4c1
.db $0f ; 57 f50fc457
.db $b0 ; 58 65b0d9c6
.db $b7 ; 59 12b7e950
.db $be ; 5a 8bbeb8ea
.db $b9 ; 5b fcb9887c
.db $dd ; 5c 62dd1ddf
.db $da ; 5d 15da2d49
.db $d3 ; 5e 8cd37cf3
.db $d4 ; 5f fbd44c65
.db $b2 ; 60 4db26158
.db $b5 ; 61 3ab551ce
.db $bc ; 62 a3bc0074
.db $bb ; 63 d4bb30e2
.db $df ; 64 4adfa541
.db $d8 ; 65 3dd895d7
.db $d1 ; 66 a4d1c46d
.db $d6 ; 67 d3d6f4fb
.db $69 ; 68 4369e96a
.db $6e ; 69 346ed9fc
.db $67 ; 6a ad678846
.db $60 ; 6b da60b8d0
.db $04 ; 6c 44042d73
.db $03 ; 6d 33031de5
.db $0a ; 6e aa0a4c5f
.db $0d ; 6f dd0d7cc9
.db $05 ; 70 5005713c
.db $02 ; 71 270241aa
.db $0b ; 72 be0b1010
.db $0c ; 73 c90c2086
.db $68 ; 74 5768b525
.db $6f ; 75 206f85b3
.db $66 ; 76 b966d409
.db $61 ; 77 ce61e49f
.db $de ; 78 5edef90e
.db $d9 ; 79 29d9c998
.db $d0 ; 7a b0d09822
.db $d7 ; 7b c7d7a8b4
.db $b3 ; 7c 59b33d17
.db $b4 ; 7d 2eb40d81
.db $bd ; 7e b7bd5c3b
.db $ba ; 7f c0ba6cad
.db $b8 ; 80 edb88320
.db $bf ; 81 9abfb3b6
.db $b6 ; 82 03b6e20c
.db $b1 ; 83 74b1d29a
.db $d5 ; 84 ead54739
.db $d2 ; 85 9dd277af
.db $db ; 86 04db2615
.db $dc ; 87 73dc1683
.db $63 ; 88 e3630b12
.db $64 ; 89 94643b84
.db $6d ; 8a 0d6d6a3e
.db $6a ; 8b 7a6a5aa8
.db $0e ; 8c e40ecf0b
.db $09 ; 8d 9309ff9d
.db $00 ; 8e 0a00ae27
.db $07 ; 8f 7d079eb1
.db $0f ; 90 f00f9344
.db $08 ; 91 8708a3d2
.db $01 ; 92 1e01f268
.db $06 ; 93 6906c2fe
.db $62 ; 94 f762575d
.db $65 ; 95 806567cb
.db $6c ; 96 196c3671
.db $6b ; 97 6e6b06e7
.db $d4 ; 98 fed41b76
.db $d3 ; 99 89d32be0
.db $da ; 9a 10da7a5a
.db $dd ; 9b 67dd4acc
.db $b9 ; 9c f9b9df6f
.db $be ; 9d 8ebeeff9
.db $b7 ; 9e 17b7be43
.db $b0 ; 9f 60b08ed5
.db $d6 ; a0 d6d6a3e8
.db $d1 ; a1 a1d1937e
.db $d8 ; a2 38d8c2c4
.db $df ; a3 4fdff252
.db $bb ; a4 d1bb67f1
.db $bc ; a5 a6bc5767
.db $b5 ; a6 3fb506dd
.db $b2 ; a7 48b2364b
.db $0d ; a8 d80d2bda
.db $0a ; a9 af0a1b4c
.db $03 ; aa 36034af6
.db $04 ; ab 41047a60
.db $60 ; ac df60efc3
.db $67 ; ad a867df55
.db $6e ; ae 316e8eef
.db $69 ; af 4669be79
.db $61 ; b0 cb61b38c
.db $66 ; b1 bc66831a
.db $6f ; b2 256fd2a0
.db $68 ; b3 5268e236
.db $0c ; b4 cc0c7795
.db $0b ; b5 bb0b4703
.db $02 ; b6 220216b9
.db $05 ; b7 5505262f
.db $ba ; b8 c5ba3bbe
.db $bd ; b9 b2bd0b28
.db $b4 ; ba 2bb45a92
.db $b3 ; bb 5cb36a04
.db $d7 ; bc c2d7ffa7
.db $d0 ; bd b5d0cf31
.db $d9 ; be 2cd99e8b
.db $de ; bf 5bdeae1d
.db $64 ; c0 9b64c2b0
.db $63 ; c1 ec63f226
.db $6a ; c2 756aa39c
.db $6d ; c3 026d930a
.db $09 ; c4 9c0906a9
.db $0e ; c5 eb0e363f
.db $07 ; c6 72076785
.db $00 ; c7 05005713
.db $bf ; c8 95bf4a82
.db $b8 ; c9 e2b87a14
.db $b1 ; ca 7bb12bae
.db $b6 ; cb 0cb61b38
.db $d2 ; cc 92d28e9b
.db $d5 ; cd e5d5be0d
.db $dc ; ce 7cdcefb7
.db $db ; cf 0bdbdf21
.db $d3 ; d0 86d3d2d4
.db $d4 ; d1 f1d4e242
.db $dd ; d2 68ddb3f8
.db $da ; d3 1fda836e
.db $be ; d4 81be16cd
.db $b9 ; d5 f6b9265b
.db $b0 ; d6 6fb077e1
.db $b7 ; d7 18b74777
.db $08 ; d8 88085ae6
.db $0f ; d9 ff0f6a70
.db $06 ; da 66063bca
.db $01 ;.db 11010b5c
.db $65 ; dc 8f659eff
.db $62 ; dd f862ae69
.db $6b ; de 616bffd3
.db $6c ; df 166ccf45
.db $0a ; e0 a00ae278
.db $0d ; e1 d70dd2ee
.db $04 ; e2 4e048354
.db $03 ; e3 3903b3c2
.db $67 ; e4 a7672661
.db $60 ; e5 d06016f7
.db $69 ; e6 4969474d
.db $6e ; e7 3e6e77db
.db $d1 ; e8 aed16a4a
.db $d6 ; e9 d9d65adc
.db $df ; ea 40df0b66
.db $d8 ; eb 37d83bf0
.db $bc ; ec a9bcae53
.db $bb ; ed debb9ec5
.db $b2 ; ee 47b2cf7f
.db $b5 ; ef 30b5ffe9
.db $bd ; f0 bdbdf21c
.db $ba ; f1 cabac28a
.db $b3 ; f2 53b39330
.db $b4 ; f3 24b4a3a6
.db $d0 ; f4 bad03605
.db $d7 ; f5 cdd70693
.db $de ; f6 54de5729
.db $d9 ; f7 23d967bf
.db $66 ; f8 b3667a2e
.db $61 ; f9 c4614ab8
.db $68 ; fa 5d681b02
.db $6f ; fb 2a6f2b94
.db $0b ; fc b40bbe37
.db $0c ; fd c30c8ea1
.db $05 ; fe 5a05df1b
.db $02 ; ff 2d02ef8d

.db $00 ; 00 00000000
.db $77 ; 01 77073096
.db $ee ; 02 ee0e612c
.db $99 ; 03 990951ba
.db $07 ; 04 076dc419
.db $70 ; 05 706af48f
.db $e9 ; 06 e963a535
.db $9e ; 07 9e6495a3
.db $0e ; 08 0edb8832
.db $79 ; 09 79dcb8a4
.db $e0 ; 0a e0d5e91e
.db $97 ; 0b 97d2d988
.db $09 ; 0c 09b64c2b
.db $7e ; 0d 7eb17cbd
.db $e7 ; 0e e7b82d07
.db $90 ; 0f 90bf1d91
.db $1d ; 10 1db71064
.db $6a ; 11 6ab020f2
.db $f3 ; 12 f3b97148
.db $84 ; 13 84be41de
.db $1a ; 14 1adad47d
.db $6d ; 15 6ddde4eb
.db $f4 ; 16 f4d4b551
.db $83 ; 17 83d385c7
.db $13 ; 18 136c9856
.db $64 ; 19 646ba8c0
.db $fd ; 1a fd62f97a
.db $8a ; 1b 8a65c9ec
.db $14 ; 1c 14015c4f
.db $63 ; 1d 63066cd9
.db $fa ; 1e fa0f3d63
.db $8d ; 1f 8d080df5
.db $3b ; 20 3b6e20c8
.db $4c ; 21 4c69105e
.db $d5 ; 22 d56041e4
.db $a2 ; 23 a2677172
.db $3c ; 24 3c03e4d1
.db $4b ; 25 4b04d447
.db $d2 ; 26 d20d85fd
.db $a5 ; 27 a50ab56b
.db $35 ; 28 35b5a8fa
.db $42 ; 29 42b2986c
.db $db ; 2a.dbbbc9d6
.db $ac ; 2b acbcf940
.db $32 ; 2c 32d86ce3
.db $45 ; 2d 45df5c75
.db $dc ; 2e dcd60dcf
.db $ab ; 2f abd13d59
.db $26 ; 30 26d930ac
.db $51 ; 31 51de003a
.db $c8 ; 32 c8d75180
.db $bf ; 33 bfd06116
.db $21 ; 34 21b4f4b5
.db $56 ; 35 56b3c423
.db $cf ; 36 cfba9599
.db $b8 ; 37 b8bda50f
.db $28 ; 38 2802b89e
.db $5f ; 39 5f058808
.db $c6 ; 3a c60cd9b2
.db $b1 ; 3b b10be924
.db $2f ; 3c 2f6f7c87
.db $58 ; 3d 58684c11
.db $c1 ; 3e c1611dab
.db $b6 ; 3f b6662d3d
.db $76 ; 40 76dc4190
.db $01 ; 41 01db7106
.db $98 ; 42 98d220bc
.db $ef ; 43 efd5102a
.db $71 ; 44 71b18589
.db $06 ; 45 06b6b51f
.db $9f ; 46 9fbfe4a5
.db $e8 ; 47 e8b8d433
.db $78 ; 48 7807c9a2
.db $0f ; 49 0f00f934
.db $96 ; 4a 9609a88e
.db $e1 ; 4b e10e9818
.db $7f ; 4c 7f6a0dbb
.db $08 ; 4d 086d3d2d
.db $91 ; 4e 91646c97
.db $e6 ; 4f e6635c01
.db $6b ; 50 6b6b51f4
.db $1c ; 51 1c6c6162
.db $85 ; 52 856530d8
.db $f2 ; 53 f262004e
.db $6c ; 54 6c0695ed
.db $1b ; 55 1b01a57b
.db $82 ; 56 8208f4c1
.db $f5 ; 57 f50fc457
.db $65 ; 58 65b0d9c6
.db $12 ; 59 12b7e950
.db $8b ; 5a 8bbeb8ea
.db $fc ; 5b fcb9887c
.db $62 ; 5c 62dd1ddf
.db $15 ; 5d 15da2d49
.db $8c ; 5e 8cd37cf3
.db $fb ; 5f fbd44c65
.db $4d ; 60 4db26158
.db $3a ; 61 3ab551ce
.db $a3 ; 62 a3bc0074
.db $d4 ; 63 d4bb30e2
.db $4a ; 64 4adfa541
.db $3d ; 65 3dd895d7
.db $a4 ; 66 a4d1c46d
.db $d3 ; 67 d3d6f4fb
.db $43 ; 68 4369e96a
.db $34 ; 69 346ed9fc
.db $ad ; 6a ad678846
.db $da ; 6b da60b8d0
.db $44 ; 6c 44042d73
.db $33 ; 6d 33031de5
.db $aa ; 6e aa0a4c5f
.db $dd ; 6f dd0d7cc9
.db $50 ; 70 5005713c
.db $27 ; 71 270241aa
.db $be ; 72 be0b1010
.db $c9 ; 73 c90c2086
.db $57 ; 74 5768b525
.db $20 ; 75 206f85b3
.db $b9 ; 76 b966d409
.db $ce ; 77 ce61e49f
.db $5e ; 78 5edef90e
.db $29 ; 79 29d9c998
.db $b0 ; 7a b0d09822
.db $c7 ; 7b c7d7a8b4
.db $59 ; 7c 59b33d17
.db $2e ; 7d 2eb40d81
.db $b7 ; 7e b7bd5c3b
.db $c0 ; 7f c0ba6cad
.db $ed ; 80 edb88320
.db $9a ; 81 9abfb3b6
.db $03 ; 82 03b6e20c
.db $74 ; 83 74b1d29a
.db $ea ; 84 ead54739
.db $9d ; 85 9dd277af
.db $04 ; 86 04db2615
.db $73 ; 87 73dc1683
.db $e3 ; 88 e3630b12
.db $94 ; 89 94643b84
.db $0d ; 8a 0d6d6a3e
.db $7a ; 8b 7a6a5aa8
.db $e4 ; 8c e40ecf0b
.db $93 ; 8d 9309ff9d
.db $0a ; 8e 0a00ae27
.db $7d ; 8f 7d079eb1
.db $f0 ; 90 f00f9344
.db $87 ; 91 8708a3d2
.db $1e ; 92 1e01f268
.db $69 ; 93 6906c2fe
.db $f7 ; 94 f762575d
.db $80 ; 95 806567cb
.db $19 ; 96 196c3671
.db $6e ; 97 6e6b06e7
.db $fe ; 98 fed41b76
.db $89 ; 99 89d32be0
.db $10 ; 9a 10da7a5a
.db $67 ; 9b 67dd4acc
.db $f9 ; 9c f9b9df6f
.db $8e ; 9d 8ebeeff9
.db $17 ; 9e 17b7be43
.db $60 ; 9f 60b08ed5
.db $d6 ; a0 d6d6a3e8
.db $a1 ; a1 a1d1937e
.db $38 ; a2 38d8c2c4
.db $4f ; a3 4fdff252
.db $d1 ; a4 d1bb67f1
.db $a6 ; a5 a6bc5767
.db $3f ; a6 3fb506dd
.db $48 ; a7 48b2364b
.db $d8 ; a8 d80d2bda
.db $af ; a9 af0a1b4c
.db $36 ; aa 36034af6
.db $41 ; ab 41047a60
.db $df ; ac df60efc3
.db $a8 ; ad a867df55
.db $31 ; ae 316e8eef
.db $46 ; af 4669be79
.db $cb ; b0 cb61b38c
.db $bc ; b1 bc66831a
.db $25 ; b2 256fd2a0
.db $52 ; b3 5268e236
.db $cc ; b4 cc0c7795
.db $bb ; b5 bb0b4703
.db $22 ; b6 220216b9
.db $55 ; b7 5505262f
.db $c5 ; b8 c5ba3bbe
.db $b2 ; b9 b2bd0b28
.db $2b ; ba 2bb45a92
.db $5c ; bb 5cb36a04
.db $c2 ; bc c2d7ffa7
.db $b5 ; bd b5d0cf31
.db $2c ; be 2cd99e8b
.db $5b ; bf 5bdeae1d
.db $9b ; c0 9b64c2b0
.db $ec ; c1 ec63f226
.db $75 ; c2 756aa39c
.db $02 ; c3 026d930a
.db $9c ; c4 9c0906a9
.db $eb ; c5 eb0e363f
.db $72 ; c6 72076785
.db $05 ; c7 05005713
.db $95 ; c8 95bf4a82
.db $e2 ; c9 e2b87a14
.db $7b ; ca 7bb12bae
.db $0c ; cb 0cb61b38
.db $92 ; cc 92d28e9b
.db $e5 ; cd e5d5be0d
.db $7c ; ce 7cdcefb7
.db $0b ; cf 0bdbdf21
.db $86 ; d0 86d3d2d4
.db $f1 ; d1 f1d4e242
.db $68 ; d2 68ddb3f8
.db $1f ; d3 1fda836e
.db $81 ; d4 81be16cd
.db $f6 ; d5 f6b9265b
.db $6f ; d6 6fb077e1
.db $18 ; d7 18b74777
.db $88 ; d8 88085ae6
.db $ff ; d9 ff0f6a70
.db $66 ; da 66063bca
.db $11 ;.db 11010b5c
.db $8f ; dc 8f659eff
.db $f8 ; dd f862ae69
.db $61 ; de 616bffd3
.db $16 ; df 166ccf45
.db $a0 ; e0 a00ae278
.db $d7 ; e1 d70dd2ee
.db $4e ; e2 4e048354
.db $39 ; e3 3903b3c2
.db $a7 ; e4 a7672661
.db $d0 ; e5 d06016f7
.db $49 ; e6 4969474d
.db $3e ; e7 3e6e77db
.db $ae ; e8 aed16a4a
.db $d9 ; e9 d9d65adc
.db $40 ; ea 40df0b66
.db $37 ; eb 37d83bf0
.db $a9 ; ec a9bcae53
.db $de ; ed debb9ec5
.db $47 ; ee 47b2cf7f
.db $30 ; ef 30b5ffe9
.db $bd ; f0 bdbdf21c
.db $ca ; f1 cabac28a
.db $53 ; f2 53b39330
.db $24 ; f3 24b4a3a6
.db $ba ; f4 bad03605
.db $cd ; f5 cdd70693
.db $54 ; f6 54de5729
.db $23 ; f7 23d967bf
.db $b3 ; f8 b3667a2e
.db $c4 ; f9 c4614ab8
.db $5d ; fa 5d681b02
.db $2a ; fb 2a6f2b94
.db $b4 ; fc b40bbe37
.db $c3 ; fd c30c8ea1
.db $5a ; fe 5a05df1b
.db $2d ; ff 2d02ef8d
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
