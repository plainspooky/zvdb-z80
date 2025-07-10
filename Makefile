# Makefile for zvdb-z80

ASM = sjasmplus
ASMFLAGS = 
BUILDDIR = build

all: $(BUILDDIR)/zvdb_test.sna $(BUILDDIR)/zvdb_paged_test.sna $(BUILDDIR)/zvdb_compact_test.sna $(BUILDDIR)/zvdb_ui.sna $(BUILDDIR)/zvdb_cpm.com

$(BUILDDIR):
	mkdir -p $(BUILDDIR)

$(BUILDDIR)/zvdb_test.sna: test.asm zvdb.asm | $(BUILDDIR)
	$(ASM) $(ASMFLAGS) --lst=$(BUILDDIR)/zvdb.lst test.asm
	@if [ -f zvdb_test.sna ]; then mv zvdb_test.sna $(BUILDDIR)/; fi

$(BUILDDIR)/zvdb_paged_test.sna: test_paged.asm zvdb_paged.asm | $(BUILDDIR)
	$(ASM) $(ASMFLAGS) --lst=$(BUILDDIR)/zvdb_paged.lst test_paged.asm
	@if [ -f zvdb_paged_test.sna ]; then mv zvdb_paged_test.sna $(BUILDDIR)/; fi

$(BUILDDIR)/zvdb_compact_test.sna: test_compact.asm zvdb.asm | $(BUILDDIR)
	$(ASM) $(ASMFLAGS) --lst=$(BUILDDIR)/zvdb_compact.lst test_compact.asm
	@if [ -f zvdb_compact_test.sna ]; then mv zvdb_compact_test.sna $(BUILDDIR)/; fi

$(BUILDDIR)/zvdb_ui.sna: zvdb_ui.asm | $(BUILDDIR)
	$(ASM) $(ASMFLAGS) --lst=$(BUILDDIR)/zvdb_ui.lst zvdb_ui.asm
	@if [ -f zvdb_ui.sna ]; then mv zvdb_ui.sna $(BUILDDIR)/; fi

$(BUILDDIR)/zvdb_cpm.com: zvdb_cpm.asm | $(BUILDDIR)
	$(ASM) $(ASMFLAGS) --lst=$(BUILDDIR)/zvdb_cpm.lst --raw=$(BUILDDIR)/zvdb_cpm.com zvdb_cpm.asm

clean:
	rm -rf $(BUILDDIR)
	rm -f *.sna *.lst *.exp *.sym *.bin *.tap

.PHONY: all clean