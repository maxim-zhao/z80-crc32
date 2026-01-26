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
; to ASYNCHRONOUS but has some additional optimisations:
; - The table is aligned and split into four
; - ...not sure :)

.define ALGORITHM "CLAUDE"
.define UNROLL

.enum $c000
  RAM_CRC dd ; Stored as big-endian...
.ende

.bank 0 slot 0
.org 0

.if ALGORITHM == "LUT"
.include "lut.asm"
.endif

.if ALGORITHM == "CODEGEN"
.include "codegen.asm"
.endif

.if ALGORITHM == "ASYNCHRONOUS"
.include "asynchronous.asm"
.endif

.if ALGORITHM == "Z80TEST"
.include "z80test-crc32.asm"
.endif

.if ALGORITHM == "CLAUDE"
.include "claude.asm"
.endif

; We fill with random data for CRCing
.bank 1
.org 0
data:
.incbin "data.bin" skip $0000 read $4000

.bank 2
.org 0
.incbin "data.bin" skip $4000 read $4000
