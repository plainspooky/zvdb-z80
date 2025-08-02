; Test program for paged memory zvdb-z80

        DEVICE ZXSPECTRUM128
        OUTPUT "zvdb_paged_test.sna"
        
        ORG     #6000

start:
        DI
        LD      SP,#5FFF
        
        ; Clear screen
        LD      HL,#4000
        LD      DE,#4001
        LD      BC,#1AFF
        LD      (HL),0
        LDIR
        
        ; Print header
        LD      HL,msg_header
        CALL    print_string
        
        ; Initialize database
        CALL    #8000          ; Call main/init_db
        
        ; Add test vectors across multiple pages
        LD      B,100          ; Add 100 vectors (will span 2 pages)
        LD      HL,test_vec1
.add_loop:
        PUSH    BC
        PUSH    HL
        
        ; Modify vector slightly for variety
        LD      A,B
        LD      (HL),A         ; First byte = loop counter
        
        CALL    add_vector
        
        POP     HL
        POP     BC
        DJNZ    .add_loop
        
        ; Print status
        LD      HL,msg_added
        CALL    print_string
        LD      HL,(vector_count)
        CALL    print_dec_hl
        LD      HL,msg_vectors
        CALL    print_string
        
        ; Reindex database
        CALL    reindex
        
        LD      HL,msg_indexed
        CALL    print_string
        
        ; Search for nearest to query
        LD      HL,query_vec
        CALL    bf_search      ; Returns DE=index, BC=score
        
        ; Print result
        PUSH    BC
        PUSH    DE
        LD      HL,msg_found
        CALL    print_string
        
        ; Print index
        POP     HL             ; Get index
        PUSH    HL
        CALL    print_dec_hl
        
        ; Print score
        LD      HL,msg_score
        CALL    print_string
        POP     DE
        POP     BC
        LD      H,B
        LD      L,C
        CALL    print_dec_hl
        
        ; Test hash search
        LD      HL,msg_hash_test
        CALL    print_string
        
        LD      HL,query_vec
        CALL    hash_search
        
        ; Check if found
        LD      A,D
        AND     E
        INC     A
        JR      Z,.no_hash_match
        
        ; Print hash result
        PUSH    BC
        LD      HL,msg_hash_found
        CALL    print_string
        EX      DE,HL
        CALL    print_dec_hl
        LD      HL,msg_score
        CALL    print_string
        POP     HL
        CALL    print_dec_hl
        JR      .done
        
.no_hash_match:
        LD      HL,msg_no_hash
        CALL    print_string
        
.done:
        ; Done
        LD      HL,msg_done
        CALL    print_string
        
halt_loop:
        HALT
        JR      halt_loop

; Print null-terminated string at HL
print_string:
        LD      A,(HL)
        OR      A
        RET     Z
        RST     #10
        INC     HL
        JR      print_string

; Print HL as decimal
print_dec_hl:
        PUSH    HL
        PUSH    DE
        PUSH    BC
        
        LD      DE,10000
        CALL    .print_digit
        LD      DE,1000
        CALL    .print_digit
        LD      DE,100
        CALL    .print_digit
        LD      DE,10
        CALL    .print_digit
        LD      A,L
        ADD     A,'0'
        RST     #10
        
        POP     BC
        POP     DE
        POP     HL
        RET
        
.print_digit:
        LD      A,'0'-1
.digit_loop:
        INC     A
        OR      A
        SBC     HL,DE
        JR      NC,.digit_loop
        ADD     HL,DE
        RST     #10
        RET

; Test vectors (32 bytes each, bit patterns)
test_vec1:
        DEFB    #FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
        DEFB    #00,#00,#00,#00,#00,#00,#00,#00
        DEFB    #FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
        DEFB    #00,#00,#00,#00,#00,#00,#00,#00

; Query vector (similar to test_vec1 with counter=50)
query_vec:
        DEFB    50,#FF,#FF,#FF,#FF,#FF,#FF,#FF
        DEFB    #00,#00,#00,#00,#00,#00,#00,#00
        DEFB    #FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
        DEFB    #00,#00,#00,#00,#00,#00,#00,#00

; Messages
msg_header:     DEFB    "ZVDB-Z80 Paged Memory Test",13,13,0
msg_added:      DEFB    "Added ",0
msg_vectors:    DEFB    " vectors",13,0
msg_indexed:    DEFB    "Database reindexed",13,0
msg_found:      DEFB    "Nearest vector: #",0
msg_score:      DEFB    " Score: ",0
msg_hash_test:  DEFB    13,"Testing hash search...",13,0
msg_hash_found: DEFB    "Hash match: #",0
msg_no_hash:    DEFB    "No hash match found",13,0
msg_done:       DEFB    13,"Test complete",13,0

; Include main zvdb code
        INCLUDE "zvdb_paged.asm"

        SAVESNA "zvdb_paged_test.sna",start