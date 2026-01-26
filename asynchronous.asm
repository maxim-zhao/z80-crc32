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
.include "crc32table.asm"
.ends
