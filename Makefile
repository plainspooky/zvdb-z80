# Makefile for zvdb-z80

ASM = sjasmplus
ASMFLAGS = 

all: zvdb_test.sna zvdb_paged_test.sna zvdb_compact_test.sna

zvdb_test.sna: test.asm zvdb.asm
	$(ASM) $(ASMFLAGS) --lst=zvdb.lst test.asm

zvdb_paged_test.sna: test_paged.asm zvdb_paged.asm
	$(ASM) $(ASMFLAGS) --lst=zvdb_paged.lst test_paged.asm

zvdb_compact_test.sna: test_compact.asm zvdb.asm
	$(ASM) $(ASMFLAGS) --lst=zvdb_compact.lst test_compact.asm

clean:
	rm -f *.sna *.lst *.exp *.sym

.PHONY: all clean