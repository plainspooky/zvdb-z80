; Test program for compact zvdb-z80 with << 5 addressing

        DEVICE ZXSPECTRUM128
        
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
        
        ; Add many test vectors to show compact storage
        LD      B,200          ; Add 200 vectors
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
        LD      A,(vector_count)
        CALL    print_dec_a
        LD      HL,msg_vectors
        CALL    print_string
        
        ; Show memory usage
        LD      HL,msg_memory
        CALL    print_string
        LD      A,(vector_count)
        LD      L,A
        LD      H,0
        ; Multiply by 32
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        CALL    print_dec_hl
        LD      HL,msg_bytes
        CALL    print_string
        
        ; Reindex database
        CALL    reindex
        
        LD      HL,msg_indexed
        CALL    print_string
        
        ; Search for nearest to query
        LD      HL,query_vec
        CALL    bf_search
        
        ; Print result
        PUSH    AF
        PUSH    BC
        LD      HL,msg_found
        CALL    print_string
        
        ; Print index
        POP     BC
        POP     AF
        PUSH    BC
        CALL    print_dec_a
        
        ; Print score  
        LD      HL,msg_score
        CALL    print_string
        POP     BC
        LD      A,B
        CALL    print_hex_byte
        LD      A,C
        CALL    print_hex_byte
        
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

; Print A as decimal
print_dec_a:
        PUSH    AF
        PUSH    BC
        PUSH    HL
        
        LD      L,A
        LD      H,0
        CALL    print_dec_hl
        
        POP     HL
        POP     BC
        POP     AF
        RET

; Print HL as decimal (simplified, max 999)
print_dec_hl:
        PUSH    HL
        PUSH    DE
        PUSH    BC
        
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
        CP      '0'
        JR      NZ,.print_it
        LD      A,' '          ; Leading zero suppression
.print_it:
        RST     #10
        RET

; Print hex byte in A
print_hex_byte:
        PUSH    AF
        RRCA
        RRCA
        RRCA
        RRCA
        AND     #0F
        CALL    print_hex_digit
        POP     AF
        AND     #0F
print_hex_digit:
        CP      10
        JR      C,.digit
        ADD     A,'A'-10
        JR      .print
.digit:
        ADD     A,'0'
.print:
        RST     #10
        RET

; Test vectors (32 bytes each, bit patterns)
test_vec1:
        DEFB    #FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
        DEFB    #00,#00,#00,#00,#00,#00,#00,#00
        DEFB    #FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
        DEFB    #00,#00,#00,#00,#00,#00,#00,#00

; Query vector (similar to test_vec1 with counter=100)
query_vec:
        DEFB    100,#FF,#FF,#FF,#FF,#FF,#FF,#FF
        DEFB    #00,#00,#00,#00,#00,#00,#00,#00
        DEFB    #FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
        DEFB    #00,#00,#00,#00,#00,#00,#00,#00

; Messages
msg_header:     DEFB    "ZVDB-Z80 Compact Test (<<5)",13,13,0
msg_added:      DEFB    "Added ",0
msg_vectors:    DEFB    " vectors",13,0
msg_memory:     DEFB    "Memory used: ",0
msg_bytes:      DEFB    " bytes",13,0
msg_indexed:    DEFB    "Database reindexed",13,0
msg_found:      DEFB    "Nearest vector: #",0
msg_score:      DEFB    " Score: #",0
msg_done:       DEFB    13,"Test complete",13,0

; Include main zvdb code
        INCLUDE "zvdb.asm"

        SAVESNA "zvdb_compact_test.sna",start