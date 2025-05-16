WLA-Z80 = wla-z80
WLALINK = wlalink
GENERATED_FILES = *.sms *.o *.sym
Z80BENCH = z80bench

all: crc32.sms

crc32.sms.o: crc32.sms.asm
	$(WLA-Z80) -o $@ $<

crc32.sms: crc32.sms.o linkfile
	$(WLALINK) -d -r -v -s -A linkfile $@

clean:
	del $(GENERATED_FILES)

test: crc32.sms
	$(Z80BENCH) crc32.sms --ram-compare=data.bin.crc32@c000
