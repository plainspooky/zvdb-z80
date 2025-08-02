; Test/demo program for zvdb-z80

        DEVICE ZXSPECTRUM128
        OUTPUT "zvdb_test.sna"
        
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
        
        ; Add some test vectors
        LD      HL,test_vec1
        CALL    add_vector
        
        LD      HL,test_vec2
        CALL    add_vector
        
        LD      HL,test_vec3
        CALL    add_vector
        
        ; Print status
        LD      HL,msg_added
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
        CALL    print_hex_byte
        
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

test_vec2:
        DEFB    #AA,#AA,#AA,#AA,#AA,#AA,#AA,#AA
        DEFB    #55,#55,#55,#55,#55,#55,#55,#55
        DEFB    #AA,#AA,#AA,#AA,#AA,#AA,#AA,#AA
        DEFB    #55,#55,#55,#55,#55,#55,#55,#55

test_vec3:
        DEFB    #F0,#F0,#F0,#F0,#F0,#F0,#F0,#F0
        DEFB    #0F,#0F,#0F,#0F,#0F,#0F,#0F,#0F
        DEFB    #F0,#F0,#F0,#F0,#F0,#F0,#F0,#F0
        DEFB    #0F,#0F,#0F,#0F,#0F,#0F,#0F,#0F

; Query vector (similar to test_vec1)
query_vec:
        DEFB    #FE,#FF,#FF,#FF,#FF,#FF,#FF,#FF
        DEFB    #01,#00,#00,#00,#00,#00,#00,#00
        DEFB    #FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
        DEFB    #00,#00,#00,#00,#00,#00,#00,#00

; Messages
msg_header:     DEFB    "ZVDB-Z80 Test Program",13,13,0
msg_added:      DEFB    "Added 3 test vectors",13,0
msg_indexed:    DEFB    "Database reindexed",13,0
msg_found:      DEFB    "Nearest vector: #",0
msg_score:      DEFB    " Score: #",0
msg_done:       DEFB    13,"Test complete",13,0

; Include main zvdb code
        INCLUDE "zvdb.asm"

        SAVESNA "zvdb_test.sna",start