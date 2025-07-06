        DEVICE ZXSPECTRUM128
        
        ORG #6000

start:
        DI
        LD SP,#5FFF
        
        ; Simple test
        LD HL,#8000
        LD (HL),#42
        INC HL
        LD (HL),#43
        
        HALT

        ORG #8000
        INCLUDE "zvdb.asm"

        SAVEBIN "zvdb.bin", #8000, #2840   ; Save 10KB of ZVDB code
        SAVESNA "zvdb_final.sna", start