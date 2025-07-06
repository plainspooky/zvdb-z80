; Simple test for zvdb-z80 core functionality

        DEVICE ZXSPECTRUM128
        
        ORG     #6000

        ; Include main code first
        INCLUDE "zvdb.asm"

start:
        DI
        LD      SP,#5FFF
        
        ; Initialize database
        CALL    init_db
        
        ; Add some test vectors
        LD      B,10           ; Add 10 test vectors
        LD      HL,test_vec
.add_loop:
        PUSH    BC
        LD      A,B
        LD      (HL),A         ; Modify first byte
        CALL    add_vector
        POP     BC
        DJNZ    .add_loop
        
        ; Search for best match
        LD      HL,query_vec
        CALL    bf_search
        
        ; Results in A (index) and BC (score)
        HALT

; Test vector (32 bytes)
test_vec:
        DEFB    #FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
        DEFB    #00,#00,#00,#00,#00,#00,#00,#00
        DEFB    #AA,#AA,#AA,#AA,#AA,#AA,#AA,#AA
        DEFB    #55,#55,#55,#55,#55,#55,#55,#55

; Query vector
query_vec:
        DEFB    #05,#FF,#FF,#FF,#FF,#FF,#FF,#FF
        DEFB    #00,#00,#00,#00,#00,#00,#00,#00
        DEFB    #AA,#AA,#AA,#AA,#AA,#AA,#AA,#AA
        DEFB    #55,#55,#55,#55,#55,#55,#55,#55

        SAVESNA "test_simple.sna", start