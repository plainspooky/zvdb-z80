; Test runner for ZVDB
        DEVICE ZXSPECTRUM128
        OUTPUT "test_runner.bin"
        
        ORG #6000
        
start:
        DI
        LD SP,#5FFF
        
        ; Load ZVDB code to #8000
        ; (In real use, would load from disk)
        
        ; Initialize ZVDB
        CALL #A700      ; init_db at main entry
        
        ; Create test vectors
        LD B,50         ; Add 50 vectors
        LD HL,vector_data
        
add_vectors:
        PUSH BC
        PUSH HL
        
        ; Modify vector
        LD A,B
        LD (HL),A       ; First byte = counter
        
        ; Add to database
        CALL #A757      ; add_vector
        
        POP HL
        POP BC
        DJNZ add_vectors
        
        ; Reindex for hash search
        CALL #A807      ; reindex
        
        ; Search for best match
        LD HL,query_data
        CALL #A77C      ; bf_search
        
        ; Store results
        LD (best_idx),A
        LD (best_scr),BC
        
        ; Also test hash function
        LD HL,query_data
        CALL #A7D1      ; calc_hash
        LD (hash_val),A
        
done:   
        EI
        RET

vector_data:
        ; Template vector
        DEFB    #FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
        DEFB    #00,#00,#00,#00,#00,#00,#00,#00
        DEFB    #AA,#AA,#AA,#AA,#55,#55,#55,#55
        DEFB    #F0,#F0,#F0,#F0,#0F,#0F,#0F,#0F
        
query_data:
        ; Query vector (similar to vector 25)
        DEFB    25,#FF,#FF,#FF,#FF,#FF,#FF,#FF
        DEFB    #00,#00,#00,#00,#00,#00,#00,#00
        DEFB    #AA,#AA,#AA,#AA,#55,#55,#55,#55
        DEFB    #F0,#F0,#F0,#F0,#0F,#0F,#0F,#0F

; Results storage
best_idx:       DEFB    0
best_scr:       DEFW    0
hash_val:       DEFB    0

        ; Pad to 1KB
        DEFS    #6400 - $, 0