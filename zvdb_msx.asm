; zvdb-z80 MSX-DOS version
; Minimal Z80 implementation of ZVDB for MSX systems
;
; It runs in any MSX2, MSX2+ or MSX turbo R machine or a MSX1 using any
; 80 columns card installed (set the 80 columns mode first).
;
; Uses 1-bit quantization and random hyperplane indexing

; CP/M system calls (MSX-DOS shares same system calls)
BDOS            EQU     5       ; BDOS entry point
BOOT            EQU     0       ; Warm boot
C_READ          EQU     1       ; Console input
C_WRITE         EQU     2       ; Console output  
C_KEY           EQU     6       ; Get key
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

; MSX system calls
CALSLT          EQU     #001C   ; Call a routine in any slot
CHGCLR          EQU     #0062   ; Change Colors
CHGET           EQU     #009F   ; Character Get
CHPUT           EQU     #00A2   ; Character Put
CLS             EQU     #00C3   ; Clear Screen
INITXT          EQU     #006C   ; Change to 40/80 column text mode

; MSX system variables
LINL40          EQU     #F3AE   ; Screen width for SCREEN 0
EXPTBL          EQU     #FCC1   ; Expanded slots table
PUTPNT          EQU     #F3F8   ; Address to put a char in keyboard buffer
GETPNT          EQU     #F3FA   ; Address to get a char in keyboard buffer
CSRY            EQU     #F3DC   ; Cursor position Y
CSRX            EQU     #F3DD   ; Cursor position X

        ORG     TPA

start:
        CALL    check_80_columns

skip:
        ; Print welcome message
        LD      DE,welcome_msg
        CALL    print_str
        
        CALL    init_db         ; Initialize database
        CALL    demo_ui         ; Run demo with UI
        
        LD      B,0 + 1
        LD      C,21 + 1
        CALL    set_cursor_xy   ; Set cursor in the bottom of screen

back_to_dos:
        ; Back to MSX-DOS
        LD      C,0
        JP      BDOS            ; Warm boot (safer)

welcome_msg:
        DEFM    "ZVDB-Z80 MSX Edition",0

; Check if MSX is 80 column text mode
check_80_columns:
        LD      A,(LINL40)
        CP      80
        RET     Z
        
        LD      DE,.width_80_msg
        CALL    print_str
        JP      back_to_dos

.width_80_msg:
        DEFM    "Change to 80 columns first!",13,10,0

; Call ROM routines
call_slot:
        LD      IY,(EXPTBL-1)   ; Where the ROM lives :)
        JP      CALSLT

; Print character
print_char:
        LD      IX,CHPUT
        JP      call_slot

; Print string
print_str:
        LD      A,(DE)
        CP      0
        RET     Z
        CALL    print_char
        INC     DE
        JR      print_str

; Get a key without block console
check_key:
        LD      HL,(PUTPNT)
        LD      DE,(GETPNT)
        SBC     HL,DE
        XOR     A
        OR      H
        OR      L
        CP      0
        RET     Z

        LD      IX,CHGET
        JP      call_slot

; Clear screen
clear_screen:
        ; Just because use CLS routine doesn't not work :/
        ; LD      IX,CLS
        ; CALL    call_slot
        LD      A,12
        JP      print_char

; Set cursor position
set_cursor_xy:
        PUSH    AF
        PUSH    BC

        INC     B
        INC     C

        LD      A,C
        LD      (CSRY),A
        LD      A,B
        LD      (CSRX),A

        POP     BC
        POP     AF
        RET

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

        LD      A,"#" ; #CC           ; "🮘"
        LD      (vector_char),A

        CALL    display_vectors

        XOR     A
        LD      (current_display),A
        LD      (selected_vector),A

.ui_redraw
        LD      A,#FF ; #DB           ; "█"
        LD      (vector_char),A

        ; Highlight the current vector
        CALL    .draw_vector

        LD      A,"#" ; #CC           ; "🮘"
        LD      (vector_char),A

.ui_loop:
        CALL    draw_plasma     ; Simple plasma effect
        CALL    update_scroller

        ; Check for a key pressed
        call    check_key
        OR      A
        JR      Z,.ui_loop      ; No key pressed

        ; Disable highlight
        PUSH    AF
        CALL    .draw_vector
        POP     AF

        ; Handle key
        CP      "q"
        RET     Z
        CP      "Q"
        RET     Z               ; Quit

        CP      31              ; Down
        JR      Z,.move_down

        CP      30              ; Up  
        JR      Z,.move_up

        CP      13              ; Enter
        JR      Z,.do_search

        CP      32              ; Space
        JR      Z,.do_search
        
        JR      .ui_loop

.draw_vector:
        LD      A,(selected_vector)
        LD      (current_display),A
        LD      B,A
        JP      display_vector

.move_down:
        LD      A,(selected_vector)
        INC     A
        LD      B,A
        LD      A,(vector_count)
        DEC     A
        CP      B
        JR      C,.ui_redraw    ; Already at bottom
        LD      A,B
        LD      (selected_vector),A
        JR      .ui_redraw

.move_up:
        LD      A,(selected_vector)
        OR      A
        JR      Z,.ui_redraw    ; Already at top
        DEC     A
        LD      (selected_vector),A
        JR      .ui_redraw

.do_search:
        CALL    perform_search
        CALL    display_results
        
        ; Wait for key
        LD      C,C_READ
        CALL    BDOS
        
        JR      .ui_redraw

; Draw UI frame
draw_ui_frame:
        CALL    clear_screen

        LD      DE,ui_title
        CALL    print_str
        RET

ui_title:
        ; Frame glyphs are located in characters between 0 and 31 of ASCII
        ; table, so to correctly print then I need to print the ASCII code
        ; 1 and then send the glyph ASCII code plus 64.
        DEFM    27,"x5"             ; Disable cursor

        DEFM    1,"X"               ; "┌"
    .35 DEFM    1,"W"               ; "─"
        DEFM    1,"Y",13,10         ; "┐"

        DEFM    1,"V"               ; "│"
        DEFM    " ZVDB-Z80 Vector Database Demo MSX "
        DEFM    1,"V",13,10         ; "│"

        DEFM    1,"Z"               ; "└"
    .35 DEFM    1,"W"               ; "─"
        DEFM    1,"[",13,10         ; "┘"

        DEFM    "Use arrows keys to select, <Enter> to search or "
        DEFM    "<Q> to quit",13,10,0

; Display vectors with 8x8 sprite representation
display_vectors:
        LD      A,(vector_count)
        LD      B,A

        XOR     A
        LD      (current_display),A

.display_loop:
        PUSH    BC
        CALL    display_vector
        POP     BC

        LD      A,(current_display)
        INC     A
        LD      (current_display),A

        DJNZ    .display_loop
        RET

VECTOR_POS_Y:       EQU 5
VECTOR_POS_X:       EQU 0

display_vector:
        ; Set cursor position
        ADD     A,VECTOR_POS_Y + 1
        LD      (CSRY),A

        LD      A,VECTOR_POS_X + 1
        LD      (CSRX),A

        ; Display vector number
        LD      A,(current_display)
        CALL    print_hex_byte
        
        LD      A,":"
        CALL    print_char 

        LD      A," "
        CALL    print_char
        
        ; Display first 8 bytes as 8x8 sprite
        CALL    display_sprite
        

        ; New line
        LD      DE,crlf
        CALL    print_str
        
        RET

; Display 8x8 sprite from vector data
display_sprite:
        LD      A,(vector_char)
        LD      C,A

        ; Get vector address
        LD      A,(current_display)
        LD      L,A
        LD      H,0
    .5  ADD     HL,HL           ; x32
        LD      DE,vectors_db
        ADD     HL,DE

        LD      DE,print_buffer

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
        PUSH    AF
        
        JR      C,.set_bit
        LD      A," "           ; use a space
        JR      .show_bit
.set_bit:
        LD      A,C             ; use a glyph
.show_bit:
        CALL    .push_char
        POP     AF
        DJNZ    .bit_loop

        LD      A," "
        CALL    .push_char

        POP     HL
        POP     BC
        DJNZ    .sprite_loop

        XOR     A
        CALL    .push_char
        
        LD      DE,print_buffer
        CALL    print_str

        RET
.push_char:
        LD      (DE),A
        INC     DE
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
        LD      B,40
        LD      C,22
        CALL    set_cursor_xy

        LD      A,(scroll_text)
        LD      C,A

        LD      HL,scroll_text + 1
        LD      DE,scroll_text
        LD      B,scroll_text_end - scroll_text - 1
.update_message:       
        LD      A,(HL)
        LD      (DE),A
        INC     HL
        INC     DE         
        DJNZ    .update_message

        LD      A,C
        LD      (DE),A

        LD      HL,scroll_text
        LD      B,40
.scroll_loop:
        PUSH BC
        PUSH HL

        LD      A,(HL)
        CALL    print_char

        POP     HL
        POP     BC

        INC     HL
        DJNZ    .scroll_loop
 
        RET

scroll_text:
        DEFM    "*** ZVDB-Z80 MSX EDITION *** GREETINGS TO ALL "
        DEFM    "DEMOSCENERS! SPECIAL THANKS TO SIRIL/RD AND OISEE/4D "
        DEFM    "FOR THE MUSIC... THIS IS A VECTOR DATABASE DEMO RUNNING "
        DEFM    "ON YOUR MSX!                   "
scroll_text_end:
        

; Perform search
perform_search:
        ; Get selected vector as query
        LD      A,(selected_vector)
        LD      L,A
        LD      H,0
    .5  ADD     HL,HL           ; x32
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
        CALL    print_str
        
        LD      A,(best_index)
        CALL    print_hex_byte
        
        LD      DE,score_msg
        CALL    print_str
        
        LD      HL,(best_score)
        CALL    print_hex_word
        
        LD      DE,crlf
        CALL    print_str
        RET

results_msg:
        DEFM    27,"Y",32+22," Best match: Vector ",0

score_msg:
        DEFM    " Score: ",0

; Print hex byte in A
print_hex_byte:
        PUSH    AF
    .4  RRA
        AND     #0F
        CALL    print_hex_digit
        POP     AF
        AND     #0F
        CALL    print_hex_digit
        RET

print_hex_digit:
        CP      10
        JR      C,.digit
        ADD     A,"A"-10
        JR      .print
.digit:
        ADD     A,"0"
.print:
        call    print_char
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
    .5  ADD     HL,HL           ; x32
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
crlf:           DEFM    13,10,0
vector_count:   DEFB    0
vector_char:    DEFB    0
selected_vector: DEFB   0
current_display: DEFB   0
current_index:  DEFB    0
best_score:     DEFW    0
best_index:     DEFB    0
plasma_phase:   DEFB    0
scroll_ptr:     DEFW    scroll_text

; To build strings before sent to screen
print_buffer:
            .80 DEFB    0

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
