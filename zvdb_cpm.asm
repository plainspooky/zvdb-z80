; zvdb-z80 CP/M version for Amstrad CPC
; Minimal Z80 implementation of ZVDB for CP/M systems
; Uses 1-bit quantization and random hyperplane indexing

; CP/M system calls
BDOS            EQU     5       ; BDOS entry point
C_READ          EQU     1       ; Console input
C_WRITE         EQU     2       ; Console output  
C_PRINT         EQU     9       ; Print string
C_READSTR       EQU     10      ; Buffered console input
F_OPEN          EQU     15      ; Open file
F_CLOSE         EQU     16      ; Close file
F_READ          EQU     20      ; Read sequential
F_WRITE         EQU     21      ; Write sequential
F_MAKE          EQU     22      ; Make file
F_DELETE        EQU     19      ; Delete file
DMA             EQU     26      ; Set DMA address

; CP/M memory layout
TPA             EQU     #0100   ; Transient Program Area start
BDOS_ENTRY      EQU     #0005   ; BDOS entry point
FCB             EQU     #005C   ; Default FCB
FCB2            EQU     #006C   ; Second FCB
DMA_BUF         EQU     #0080   ; Default DMA buffer

; Constants
VECTOR_BITS     EQU     256     ; Bits per vector
VECTOR_BYTES    EQU     32      ; Bytes per vector (256/8)
MAX_VECTORS     EQU     128     ; Maximum vectors (reduced for CP/M)
HASH_BITS       EQU     7       ; Bits for hash (128 buckets)
HYPERPLANES     EQU     8       ; Number of hyperplanes for hashing

        ORG     TPA

start:
        LD      SP,stack_top    ; Set up stack
        
        ; Print welcome message
        LD      DE,welcome_msg
        LD      C,C_PRINT
        CALL    BDOS
        
        CALL    init_db         ; Initialize database
        CALL    demo_ui         ; Run demo with UI
        
        ; Exit to CP/M
        JP      0               ; Warm boot

welcome_msg:
        DEFM    "ZVDB-Z80 CP/M Edition$"

; Initialize database
init_db:
        XOR     A
        LD      (vector_count),A
        
        ; Clear hash index
        LD      HL,hash_index
        LD      DE,hash_index+1
        LD      BC,128*2-1      ; Reduced for CP/M
        LD      (HL),0
        LDIR
        
        ; Initialize random hyperplanes
        LD      HL,hyperplanes
        LD      BC,HYPERPLANES * VECTOR_BYTES
        LD      A,#55
.init_hyper:
        LD      (HL),A
        INC     HL
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,.init_hyper
        
        ; Load some test vectors
        CALL    load_test_vectors
        
        RET

; Load test vectors with simple patterns
load_test_vectors:
        LD      B,16            ; Load 16 test vectors
        LD      HL,vectors_db
.load_loop:
        PUSH    BC
        PUSH    HL
        
        ; Create a simple pattern for each vector
        LD      C,VECTOR_BYTES
.pattern_loop:
        LD      A,B
        XOR     C
        LD      (HL),A
        INC     HL
        DEC     C
        JR      NZ,.pattern_loop
        
        POP     HL
        LD      DE,VECTOR_BYTES
        ADD     HL,DE
        
        LD      A,(vector_count)
        INC     A
        LD      (vector_count),A
        
        POP     BC
        DJNZ    .load_loop
        
        RET

; Demo UI with vector selection
demo_ui:
        CALL    clear_screen
        CALL    draw_ui_frame
        
        XOR     A
        LD      (selected_vector),A
        
.ui_loop:
        CALL    display_vectors
        CALL    draw_plasma     ; Simple plasma effect
        CALL    update_scroller
        
        ; Check for key press
        LD      C,6             ; Direct console I/O
        LD      E,#FF           ; Input
        CALL    BDOS
        OR      A
        JR      Z,.ui_loop      ; No key pressed
        
        ; Handle key
        CP      'q'
        RET     Z               ; Quit
        CP      'Q'
        RET     Z
        
        CP      'j'             ; Down
        JR      Z,.move_down
        CP      's'
        JR      Z,.move_down
        
        CP      'k'             ; Up  
        JR      Z,.move_up
        CP      'w'
        JR      Z,.move_up
        
        CP      13              ; Enter
        JR      Z,.do_search
        CP      ' '
        JR      Z,.do_search
        
        JR      .ui_loop

.move_down:
        LD      A,(selected_vector)
        INC     A
        LD      B,A
        LD      A,(vector_count)
        CP      B
        JR      C,.ui_loop      ; Already at bottom
        LD      A,B
        LD      (selected_vector),A
        JR      .ui_loop

.move_up:
        LD      A,(selected_vector)
        OR      A
        JR      Z,.ui_loop      ; Already at top
        DEC     A
        LD      (selected_vector),A
        JR      .ui_loop

.do_search:
        CALL    perform_search
        CALL    display_results
        
        ; Wait for key
        LD      C,C_READ
        CALL    BDOS
        
        JR      .ui_loop

; Clear screen (ANSI escape sequence)
clear_screen:
        LD      DE,cls_seq
        LD      C,C_PRINT
        CALL    BDOS
        RET

cls_seq:
        DEFM    27,"[2J",27,"[H$"

; Draw UI frame
draw_ui_frame:
        LD      DE,ui_title
        LD      C,C_PRINT
        CALL    BDOS
        RET

ui_title:
        DEFM    27,"[1;1H"      ; Position cursor
        DEFM    "╔════════════════════════════════════════╗",13,10
        DEFM    "║  ZVDB-Z80 Vector Database Demo (CP/M)  ║",13,10
        DEFM    "╚════════════════════════════════════════╝",13,10
        DEFM    13,10
        DEFM    "Use W/S or J/K to select, Enter to search",13,10
        DEFM    "Q to quit",13,10,13,10,"$"

; Display vectors with 8x8 sprite representation
display_vectors:
        LD      DE,vector_list_pos
        LD      C,C_PRINT
        CALL    BDOS
        
        LD      A,(vector_count)
        LD      B,A
        XOR     A
        LD      (current_display),A
        
.display_loop:
        PUSH    BC
        
        ; Check if this is selected
        LD      A,(current_display)
        LD      B,A
        LD      A,(selected_vector)
        CP      B
        JR      NZ,.not_selected
        
        ; Highlight selected
        LD      DE,highlight_on
        LD      C,C_PRINT
        CALL    BDOS
        
.not_selected:
        ; Display vector number
        LD      A,(current_display)
        CALL    print_hex_byte
        
        LD      E,':'
        LD      C,C_WRITE
        CALL    BDOS
        LD      E,' '
        CALL    BDOS
        
        ; Display first 8 bytes as 8x8 sprite
        CALL    display_sprite
        
        ; Clear highlight if needed
        LD      A,(current_display)
        LD      B,A
        LD      A,(selected_vector)
        CP      B
        JR      NZ,.no_clear_highlight
        
        LD      DE,highlight_off
        LD      C,C_PRINT
        CALL    BDOS
        
.no_clear_highlight:
        ; New line
        LD      DE,crlf
        LD      C,C_PRINT
        CALL    BDOS
        
        LD      A,(current_display)
        INC     A
        LD      (current_display),A
        
        POP     BC
        DJNZ    .display_loop
        
        RET

vector_list_pos:
        DEFM    27,"[8;1H$"

highlight_on:
        DEFM    27,"[7m$"       ; Reverse video

highlight_off:
        DEFM    27,"[0m$"       ; Normal video

crlf:
        DEFM    13,10,"$"

; Display 8x8 sprite from vector data
display_sprite:
        ; Get vector address
        LD      A,(current_display)
        LD      L,A
        LD      H,0
        ADD     HL,HL           ; x2
        ADD     HL,HL           ; x4
        ADD     HL,HL           ; x8
        ADD     HL,HL           ; x16
        ADD     HL,HL           ; x32
        LD      DE,vectors_db
        ADD     HL,DE
        
        ; Display 8 bytes as 8x8 sprite
        LD      B,8
.sprite_loop:
        PUSH    BC
        LD      A,(HL)
        INC     HL
        PUSH    HL
        
        ; Display 8 bits
        LD      B,8
.bit_loop:
        RLA
        JR      C,.set_bit
        LD      E,' '
        JR      .show_bit
.set_bit:
        LD      E,'█'
.show_bit:
        PUSH    AF
        PUSH    BC
        LD      C,C_WRITE
        CALL    BDOS
        POP     BC
        POP     AF
        DJNZ    .bit_loop
        
        LD      E,' '
        LD      C,C_WRITE
        CALL    BDOS
        
        POP     HL
        POP     BC
        DJNZ    .sprite_loop
        
        RET

; Simple plasma effect
draw_plasma:
        LD      A,(plasma_phase)
        INC     A
        LD      (plasma_phase),A
        ; Simplified - would implement full plasma
        RET

; Update scrolling text
update_scroller:
        LD      DE,scroller_pos
        LD      C,C_PRINT
        CALL    BDOS
        
        ; Update scroll position
        LD      HL,(scroll_ptr)
        LD      A,(HL)
        CP      '$'             ; End marker
        JR      NZ,.not_end
        LD      HL,scroll_text
.not_end:
        LD      (scroll_ptr),HL
        
        ; Display 40 chars
        LD      B,40
.scroll_loop:
        LD      A,(HL)
        CP      '$'
        JR      NZ,.show_char
        LD      HL,scroll_text
        LD      A,(HL)
.show_char:
        LD      E,A
        PUSH    BC
        PUSH    HL
        LD      C,C_WRITE
        CALL    BDOS
        POP     HL
        POP     BC
        INC     HL
        DJNZ    .scroll_loop
        
        RET

scroller_pos:
        DEFM    27,"[24;1H$"    ; Bottom line

scroll_text:
        DEFM    "*** ZVDB-Z80 CP/M EDITION *** GREETINGS TO ALL DEMOSCENERS! "
        DEFM    "SPECIAL THANKS TO SIRIL/RD AND OISEE/4D FOR THE MUSIC... "
        DEFM    "THIS IS A VECTOR DATABASE DEMO RUNNING ON YOUR AMSTRAD CPC! "
        DEFM    "                    ","$"

; Perform search
perform_search:
        ; Get selected vector as query
        LD      A,(selected_vector)
        LD      L,A
        LD      H,0
        ADD     HL,HL           ; x32
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        LD      DE,vectors_db
        ADD     HL,DE
        LD      DE,query_vector
        LD      BC,VECTOR_BYTES
        LDIR
        
        ; Brute force search
        CALL    bf_search
        RET

; Display search results
display_results:
        LD      DE,results_msg
        LD      C,C_PRINT
        CALL    BDOS
        
        LD      A,(best_index)
        CALL    print_hex_byte
        
        LD      DE,score_msg
        LD      C,C_PRINT
        CALL    BDOS
        
        LD      HL,(best_score)
        CALL    print_hex_word
        
        LD      DE,crlf
        LD      C,C_PRINT
        CALL    BDOS
        RET

results_msg:
        DEFM    13,10,"Best match: Vector $"

score_msg:
        DEFM    " Score: $"

; Print hex byte in A
print_hex_byte:
        PUSH    AF
        RRA
        RRA
        RRA
        RRA
        AND     #0F
        CALL    print_hex_digit
        POP     AF
        AND     #0F
        CALL    print_hex_digit
        RET

print_hex_digit:
        CP      10
        JR      C,.digit
        ADD     A,'A'-10
        JR      .print
.digit:
        ADD     A,'0'
.print:
        LD      E,A
        LD      C,C_WRITE
        CALL    BDOS
        RET

; Print hex word in HL
print_hex_word:
        LD      A,H
        CALL    print_hex_byte
        LD      A,L
        CALL    print_hex_byte
        RET

; Include core ZVDB routines (adapted from zvdb.asm)

; Brute force search
bf_search:
        LD      HL,#0000
        LD      (best_score),HL
        XOR     A
        LD      (best_index),A
        
        LD      A,(vector_count)
        OR      A
        RET     Z               ; No vectors
        
        LD      B,A
        XOR     A
        LD      (current_index),A
        
.search_loop:
        PUSH    BC
        
        ; Get vector address
        LD      A,(current_index)
        LD      L,A
        LD      H,0
        ADD     HL,HL           ; x32
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        LD      DE,vectors_db
        ADD     HL,DE
        
        ; Calculate similarity
        LD      DE,query_vector
        CALL    dot_product_1bit
        
        ; Compare with best
        LD      DE,(best_score)
        OR      A               ; Clear carry
        SBC     HL,DE
        JR      C,.not_better
        ADD     HL,DE           ; Restore score
        LD      (best_score),HL
        LD      A,(current_index)
        LD      (best_index),A
        
.not_better:
        LD      A,(current_index)
        INC     A
        LD      (current_index),A
        
        POP     BC
        DJNZ    .search_loop
        
        RET

; Calculate dot product for 1-bit vectors
; HL = vector1, DE = vector2
; Returns: HL = similarity (256 - 2*hamming_distance)
dot_product_1bit:
        PUSH    BC
        PUSH    DE
        
        LD      BC,0            ; Hamming distance counter
        LD      A,VECTOR_BYTES
        
.dot_loop:
        PUSH    AF
        LD      A,(DE)
        XOR     (HL)            ; XOR gives different bits
        
        ; Count bits
        CALL    count_bits
        ADD     A,C
        LD      C,A
        JR      NC,.no_carry
        INC     B
.no_carry:
        
        INC     HL
        INC     DE
        POP     AF
        DEC     A
        JR      NZ,.dot_loop
        
        ; Calculate 256 - 2*hamming
        LD      H,B
        LD      L,C
        ADD     HL,HL           ; x2
        EX      DE,HL
        LD      HL,256
        OR      A
        SBC     HL,DE
        
        POP     DE
        POP     BC
        RET

; Count bits in A
count_bits:
        PUSH    HL
        LD      H,popcount_table/256
        LD      L,A
        LD      A,(HL)
        POP     HL
        RET

; Variables
vector_count:   DEFB    0
selected_vector: DEFB   0
current_display: DEFB   0
current_index:  DEFB    0
best_score:     DEFW    0
best_index:     DEFB    0
plasma_phase:   DEFB    0
scroll_ptr:     DEFW    scroll_text

; Buffers and tables
query_vector:   DEFS    VECTOR_BYTES
temp_vector:    DEFS    VECTOR_BYTES

; Vector database (reduced size for CP/M)
vectors_db:     DEFS    VECTOR_BYTES * MAX_VECTORS

; Hash index
hash_index:     DEFS    128 * 2

; Hyperplanes
hyperplanes:    DEFS    HYPERPLANES * VECTOR_BYTES

; Popcount table
        ALIGN   256
popcount_table:
        DEFB    0,1,1,2,1,2,2,3,1,2,2,3,2,3,3,4
        DEFB    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5
        DEFB    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5
        DEFB    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6
        DEFB    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5
        DEFB    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6
        DEFB    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6
        DEFB    3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7
        DEFB    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5
        DEFB    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6
        DEFB    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6
        DEFB    3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7
        DEFB    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6
        DEFB    3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7
        DEFB    3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7
        DEFB    4,5,5,6,5,6,6,7,5,6,6,7,6,7,7,8

; Stack space
        DEFS    256
stack_top:

        END     start