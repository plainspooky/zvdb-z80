; Test program for zvdb-z80 with << 5 addressing
        DEVICE ZXSPECTRUM128
        
        ORG     #6000

start:
        DI
        LD      SP,#5FFF
        
        ; Initialize ZVDB at #8000
        CALL    #8000          ; init_db
        
        ; Add test vectors
        LD      B,20           ; Add 20 vectors
        LD      HL,test_vec1
.add_loop:
        PUSH    BC
        PUSH    HL
        
        ; Modify first byte for variety
        LD      A,B
        LD      (HL),A
        
        ; Add vector
        LD      DE,add_vector
        CALL    call_zvdb
        
        POP     HL
        POP     BC
        DJNZ    .add_loop
        
        ; Reindex database
        LD      DE,reindex
        CALL    call_zvdb
        
        ; Search for nearest vector
        LD      HL,query_vec
        LD      DE,bf_search
        CALL    call_zvdb
        
        ; Store results
        LD      (result_index),A
        LD      (result_score),BC
        
        HALT

; Call ZVDB function at DE
call_zvdb:
        PUSH    DE
        RET

; Test data
test_vec1:
        DEFB    #FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
        DEFB    #00,#00,#00,#00,#00,#00,#00,#00
        DEFB    #AA,#AA,#AA,#AA,#AA,#AA,#AA,#AA
        DEFB    #55,#55,#55,#55,#55,#55,#55,#55

query_vec:
        DEFB    10,#FF,#FF,#FF,#FF,#FF,#FF,#FF
        DEFB    #00,#00,#00,#00,#00,#00,#00,#00
        DEFB    #AA,#AA,#AA,#AA,#AA,#AA,#AA,#AA
        DEFB    #55,#55,#55,#55,#55,#55,#55,#55

result_index:   DEFB    0
result_score:   DEFW    0

        ; Include zvdb implementation
        ORG     #8000
        INCLUDE "zvdb.asm"

        SAVESNA "zvdb_test.sna", start