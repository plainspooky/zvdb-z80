; Build test for zvdb-z80
        DEVICE ZXSPECTRUM128

        ORG     #8000
        
        ; Main initialization
start:
        DI
        LD      SP,#7FFF
        CALL    init_db
        
        ; Add test vectors
        LD      B,5
        LD      HL,test_data
.loop:  
        CALL    add_vector
        DJNZ    .loop
        
        ; Search
        LD      HL,test_data
        CALL    bf_search
        
        RET

test_data:
        DEFS    32,#55

        ; Include the actual implementation
        INCLUDE "zvdb.asm"

        SAVESNA "zvdb_build.sna", start